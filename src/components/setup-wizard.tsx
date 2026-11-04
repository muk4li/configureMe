"use client";

import { useMemo, useState } from "react";
import { catalog, type PackageDefinition } from "@/lib/catalog";
import type { Profile } from "@/lib/profiles";

const steps = ["Target", "Packages", "Review"];
const serverQuickSetupLabels: Record<string, string> = {
  git: "Manual fallback",
  "github-cli": "Official signed MSI",
  vscode: "Official signed user setup",
  "nodejs-lts": "Active LTS MSI",
  python: "Manual fallback",
  "dotnet-10-sdk": "Official signed SDK installer",
  "powershell-7": "Official signed MSI",
  "seven-zip": "Official signed installer",
  firefox: "Official signed MSI",
  "openssh-client": "Windows capability",
  "github-copilot-desktop": "Manual / support warning",
  teams: "Web fallback",
  "docker-desktop": "Detection only / unsupported",
  "github-copilot-cli": "Optional / manual",
};

function dependenciesFor(ids: string[]) {
  const resolved = new Set<string>();
  const add = (id: string) => {
    const item = catalog.find((candidate) => candidate.id === id);
    for (const dependency of item?.dependencies ?? []) add(dependency);
    resolved.add(id);
  };
  ids.forEach(add);
  return [...resolved];
}

export function SetupWizard({ profiles, initialProfileId }: { profiles: Profile[]; initialProfileId?: string }) {
  const [step, setStep] = useState(0);
  const [profileId, setProfileId] = useState(
    profiles.some((profile) => profile.id === initialProfileId) ? initialProfileId! : profiles[0]?.id ?? "",
  );
  const profile = profiles.find((candidate) => candidate.id === profileId);
  const [packageIds, setPackageIds] = useState<string[]>(profile?.packages ?? []);
  const [error, setError] = useState("");
  const [downloading, setDownloading] = useState(false);
  const [downloaded, setDownloaded] = useState(false);
  const resolvedIds = useMemo(() => dependenciesFor(packageIds), [packageIds]);
  const availablePackages = useMemo(
    () => catalog.filter((item) => item.platforms.windows?.supported && (
      profile?.id === "windows-server-2022-developer" || Boolean(item.windowsPackageId)
    )),
    [profile?.id],
  );

  function chooseProfile(id: string) {
    const next = profiles.find((candidate) => candidate.id === id);
    setProfileId(id);
    setPackageIds(next?.platform === "windows" ? next.packages : []);
    setDownloaded(false);
  }

  function togglePackage(id: string) {
    setPackageIds((current) => current.includes(id) ? current.filter((value) => value !== id) : [...current, id]);
    setDownloaded(false);
  }

  async function downloadBundle() {
    if (!profile || resolvedIds.length === 0) return;
    setError("");
    setDownloading(true);
    setDownloaded(false);
    try {
      const response = await fetch("/api/bootstrap", {
        method: "POST",
        headers: { "Content-Type": "application/json" },
        body: JSON.stringify({
          schemaVersion: 1,
          catalogVersion: "1",
          profileId: profile.id,
          platform: profile.platform,
          architecture: "x64",
          packages: packageIds,
        }),
      });
      if (!response.ok) {
        const body: { error?: string } = await response.json();
        throw new Error(body.error ?? "The bundle could not be created.");
      }
      const blob = await response.blob();
      const url = URL.createObjectURL(blob);
      const link = document.createElement("a");
      link.href = url;
      link.download = profile.id === "windows-server-2022-developer"
        ? "configureMe-WindowsServer2022-Developer-QuickSetup.zip"
        : `configureme-${profile.id}.zip`;
      document.body.append(link);
      link.click();
      link.remove();
      URL.revokeObjectURL(url);
      setDownloaded(true);
    } catch (reason) {
      setError(reason instanceof Error ? reason.message : "The bundle could not be created.");
    } finally {
      setDownloading(false);
    }
  }

  const stepContent = step === 0 ? (
    <>
      <h2>Choose your starting profile</h2>
      <p>Automated bootstrap is currently in preview for Windows x64 only. The Windows Server 2022 profile uses a standalone PowerShell package without a WinGet dependency.</p>
      <div className="choice-list">
        <label className="choice-row"><input type="radio" name="platform" checked readOnly /><span><strong>Windows x64</strong><small>Windows 10/11 legacy WinGet preview and a standalone Windows Server 2022 quick setup.</small></span><em>Preview</em></label>
        <label className="choice-row" aria-disabled="true"><input type="radio" name="platform" disabled /><span><strong>Linux</strong><small>Package adapters are not enabled yet.</small></span><em>Planned</em></label>
        <label className="choice-row" aria-disabled="true"><input type="radio" name="platform" disabled /><span><strong>macOS</strong><small>Homebrew / PKG support is not enabled yet.</small></span><em>Planned</em></label>
        <label className="field-label" htmlFor="profile-select">Profile</label>
        <select id="profile-select" className="select-control" value={profileId} onChange={(event) => chooseProfile(event.target.value)}>
          {profiles.map((item) => <option key={item.id} value={item.id}>{item.name} — {item.platform}</option>)}
        </select>
      </div>
    </>
  ) : step === 1 ? (
    <>
      <h2>Select the packages</h2>
      <p>{profile?.id === "windows-server-2022-developer"
        ? "The standalone package uses verified official installers where available and reports manual or unsupported items explicitly."
        : "This legacy Windows plan includes only packages with a fixed, catalog-owned WinGet strategy."}</p>
      <div className="choice-list">
        {availablePackages.map((item: PackageDefinition) => (
          <label className="choice-row" key={item.id}>
            <input type="checkbox" checked={packageIds.includes(item.id)} onChange={() => togglePackage(item.id)} />
            <span><strong>{item.name}</strong><small>{item.description}</small></span>
            <em>{profile?.id === "windows-server-2022-developer"
              ? serverQuickSetupLabels[item.id]
              : item.platforms.windows?.label}</em>
          </label>
        ))}
      </div>
      {profile?.platform !== "windows" && <div className="platform-notice">This profile is a planning example only. Select a Windows profile to create an automated bundle.</div>}
    </>
  ) : (
    <>
      <h2>Review before downloading</h2>
      <p>The bootstrap checks the machine, shows the requested packages, and asks you to type YES before installation.</p>
      <div className="panel" style={{ padding: 14 }}>
        <div className="summary-row"><span>Operating system</span><strong>{profile?.id === "windows-server-2022-developer" ? "Windows Server 2022 Desktop Experience · x64" : profile?.id === "windows-server" ? "Windows Server · x64 (limited)" : "Windows 10 / 11 · x64"}</strong></div>
        <div className="summary-row"><span>Profile</span><strong>{profile?.name}</strong></div>
        <div className="summary-row"><span>Installer</span><strong>{profile?.id === "windows-server-2022-developer" ? "Standalone PowerShell bootstrap; no WinGet required" : "WinGet"}</strong></div>
        <ul className="summary-packages">{resolvedIds.map((id) => <li key={id}>{catalog.find((item) => item.id === id)?.name ?? id}</li>)}</ul>
      </div>
      {error && <div className="error-note" role="alert">{error}</div>}
      {downloaded && <div className="success-note" role="status">Bundle downloaded. Review its contents before running it.</div>}
      <div className="security-note">This bundle is unsigned. SHA-256 detects accidental file corruption but does not prove publisher identity. Download only from a trusted HTTPS portal; review files before execution.</div>
      <button className="button button-primary button-small" type="button" onClick={downloadBundle} disabled={downloading || resolvedIds.length === 0 || profile?.platform !== "windows"}>
        {downloading ? "Preparing bundle…" : "Download Windows bundle"}
      </button>
    </>
  );

  return (
    <div className="wizard-layout">
      <section className="panel wizard-card" aria-label="Setup wizard">
        <ol className="wizard-steps">
          {steps.map((label, index) => <li className={index === step ? "current" : ""} key={label} aria-current={index === step ? "step" : undefined}>{index + 1}. {label}</li>)}
        </ol>
        {stepContent}
        <div className="wizard-actions">
          <button className="button button-quiet button-small" type="button" onClick={() => setStep((current) => Math.max(0, current - 1))} disabled={step === 0}>Back</button>
          {step < 2 && <button className="button button-primary button-small" type="button" onClick={() => setStep((current) => Math.min(2, current + 1))} disabled={profile?.platform !== "windows" || (step === 1 && resolvedIds.length === 0)}>Continue →</button>}
        </div>
      </section>
      <aside className="panel summary-panel">
        <h3>Plan summary</h3>
        <div className="summary-row"><span>Platform</span><strong>Windows x64</strong></div>
        <div className="summary-row"><span>Profile</span><strong>{profile?.name ?? "—"}</strong></div>
        <div className="summary-row"><span>Packages</span><strong>{resolvedIds.length}</strong></div>
        <ul className="summary-packages">{resolvedIds.slice(0, 7).map((id) => <li key={id}>{catalog.find((item) => item.id === id)?.name ?? id}</li>)}</ul>
        <div className="security-note">No browser-based installation. No personal secrets are included in the bundle.</div>
      </aside>
    </div>
  );
}
