"use client";
import { useMemo, useState } from "react";
import { initialLinuxSelection, linuxCatalog, linuxProfiles, resolveLinuxSelection, validateLinuxPlan, type LinuxSelection } from "@/lib/linux-planning";
export function LinuxConfigurator({ revision, downloadEnabled }: { revision: string; downloadEnabled: boolean }) {
  const [selection, setSelection] = useState<LinuxSelection>(initialLinuxSelection);
  const [busy, setBusy] = useState(false), [message, setMessage] = useState("");
  const review = useMemo(() => {
    try { return { plan: resolveLinuxSelection(selection, revision), error: "" }; }
    catch { return { plan: undefined, error: "Resolve empty selection, required dependencies or Docker-group conflicts before export." }; }
  }, [selection, revision]);
  function update(next: LinuxSelection) { setSelection(next); setMessage(""); }
  async function request(download: boolean) {
    setBusy(true); setMessage("");
    try {
      const response = await fetch(download ? "/api/linux/bundle" : "/api/public/linux-plan", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(selection) });
      if (!response.ok) throw new Error(`Request refused (HTTP ${response.status}). Bundle download needs an explicitly enabled local portal, private sign-in and a clean checkout.`);
      let blob: Blob, filename: string;
      if (download) {
        if (response.headers.get("content-type")?.split(";")[0] !== "application/zip") throw new Error("Unexpected bundle response.");
        blob = await response.blob(); filename = "configureme-ubuntu-24.04-amd64-development.zip";
      } else {
        if (!response.headers.get("content-type")?.includes("application/json")) throw new Error("Unexpected plan response.");
        let result; try { result = await response.json(); validateLinuxPlan(result.plan, revision); } catch { throw new Error("Invalid Linux plan response. Please retry."); }
        blob = new Blob([JSON.stringify(result.plan, null, 2) + "\n"], { type: "application/json" }); filename = "configureme-linux-plan.v1.json";
      }
      const url = URL.createObjectURL(blob), link = document.createElement("a");
      link.href = url; link.download = filename; link.click(); setTimeout(() => URL.revokeObjectURL(url), 1000);
      setMessage(download ? "Unsigned development bundle downloaded. Independently verify source and archive hash before running any included code." : "Server-validated Linux plan exported. JSON grants no installation rights.");
    } catch (error) { setMessage(error instanceof Error ? error.message : "Request failed."); }
    finally { setBusy(false); }
  }
  return <section aria-labelledby="linux-title">
    <div className="page-heading"><div><div className="eyebrow">LOCAL UBUNTU SETUP · NO REMOTE EXECUTION</div><h1 id="linux-title">Ubuntu Server setup</h1><p>Plan here. Review and run locally on your Ubuntu VM.</p></div></div>
    <fieldset className="config-controls" disabled={busy}><legend className="sr-only">Linux setup selection</legend>
      <div className="configuration-grid"><div className="configuration-main">
        <section className="panel config-section"><h2>Ubuntu Server 24.04 · amd64</h2><p>Python 3.12+. No firewall, Hyper-V, Caddy or SSH provisioning. Existing Windows setup is separate.</p></section>
        <section className="config-section"><h2>Combine Linux profiles</h2><div className="public-profile-grid">{linuxProfiles.map(profile => <label className="profile-card public-profile" key={profile.id}>
          <input type="checkbox" aria-label={profile.name} checked={selection.profileIds.includes(profile.id)} onChange={event => update({ ...selection, profileIds: event.target.checked ? [...selection.profileIds, profile.id] : selection.profileIds.filter(id => id !== profile.id) })} />
          <h3>{profile.name}</h3><p>{profile.description}</p>
        </label>)}</div></section>
        <section className="panel config-section"><h2>Components and dependencies</h2>{linuxCatalog.steps.map(step => {
          const requiredBy = review.plan?.steps.filter(id => (linuxCatalog.steps.find(item => item.id === id)!.dependsOn as string[]).includes(step.id)) ?? [];
          return <label className="choice-row" key={step.id}><input type="checkbox" aria-label={step.title} checked={review.plan?.steps.includes(step.id) ?? false} disabled={requiredBy.length > 0}
            onChange={event => update({ ...selection, addedStepIds: event.target.checked ? [...new Set([...selection.addedStepIds, step.id])] : selection.addedStepIds.filter(id => id !== step.id), removedStepIds: event.target.checked ? selection.removedStepIds.filter(id => id !== step.id) : [...new Set([...selection.removedStepIds, step.id])] })} />
            <span><strong>{step.title}</strong><small>{step.packages.map(item => "version" in item ? `${item.name}=${item.version}` : item.name).join(", ") || "Official Docker key and repository"}</small>{requiredBy.length > 0 && <small>Required by {requiredBy.join(", ")}</small>}</span></label>;
        })}</section>
        <section className="panel config-section"><h2>Optional Docker group</h2><label><input type="checkbox" checked={selection.addInvokingUserToDockerGroup} disabled={!review.plan?.steps.includes("docker-engine") && !selection.addInvokingUserToDockerGroup} onChange={event => update({ ...selection, addInvokingUserToDockerGroup: event.target.checked })} /> Add invoking user to Docker group</label><p className="notice">Off by default. Docker group membership is root-equivalent. The runner uses SUDO_USER locally; no username or credential is sent here.</p></section>
      </div><aside className="panel config-summary"><h2>Review Linux plan</h2>
        <p>Catalog revision: <code style={{ overflowWrap: "anywhere" }}>{revision}</code></p>
        <ol>{review.plan?.steps.map(id => <li key={id}>{id}</li>)}</ol>
        {review.error && <p className="error-note" role="alert">{review.error}</p>}
        <div className="preview-actions"><button className="button button-primary" disabled={!review.plan} onClick={() => void request(false)}>Export Linux plan JSON</button><button className="button button-quiet" disabled={!review.plan || !downloadEnabled} onClick={() => void request(true)}>Download development Linux bundle</button></div>
        <p className="security-note"><strong>Not a released installer.</strong> Bundle download is disabled by default; when enabled it requires private sign-in and an exact loopback host/origin. No anonymous executable download or LAN delivery is enabled. Same-download SHA256 is not independent provenance.</p>
        <p>Use the separately trusted Git/offline handoff if download is unavailable. Never run downloaded Python before independent verification. Apply is a separate local, interactive operator decision.</p>
        {message && <p className="notice" role="status">{message}</p>}
      </aside></div>
    </fieldset>
  </section>;
}
