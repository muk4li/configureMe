"use client";

import { useMemo, useRef, useState } from "react";
import { modeFor, modeLabels, optionLabels, optionNames, publicCatalog, publicSnapshot, resolvePublicPlan,
  targetNames, targets, type OptionName, type PublicPlan, type PublicSelection, type WindowsTarget } from "@/lib/public-planning";
import { freshSelection } from "@/lib/public-session";
import { usePublicSelection } from "./use-public-selection";

export function PublicConfigurator() {
  const { selection, ready, note: storageNote, saveSelection } = usePublicSelection();
  const [busy, setBusy] = useState(false);
  const [error, setError] = useState("");
  const [serverPlan, setServerPlan] = useState<PublicPlan>();
  const revision = useRef(0);
  const plan = useMemo(() => resolvePublicPlan(selection), [selection]);
  const categories = [...new Set(publicCatalog.map(item => item.category))];

  function update(next: PublicSelection) {
    revision.current++;
    saveSelection(next);
    setServerPlan(undefined); setError("");
  }
  function toggleProfile(id: string) {
    update({ ...selection, profileIds: selection.profileIds.includes(id)
      ? selection.profileIds.filter(value => value !== id) : [...selection.profileIds, id] });
  }
  function togglePackage(id: string, checked: boolean) {
    update({ ...selection,
      addedPackageIds: checked ? [...new Set([...selection.addedPackageIds, id])] : selection.addedPackageIds.filter(value => value !== id),
      removedPackageIds: checked ? selection.removedPackageIds.filter(value => value !== id) : [...new Set([...selection.removedPackageIds, id])],
    });
  }
  function chooseOption(key: OptionName, value: string) {
    const options = { ...selection.options };
    if (value === "profiles") delete options[key];
    else options[key] = value === "true";
    update({ ...selection, options });
  }
  async function validate(exportJson: boolean) {
    setBusy(true); setError(""); setServerPlan(undefined);
    const requestedRevision = revision.current;
    try {
      const response = await fetch("/api/public/plan", { method: "POST", headers: { "Content-Type": "application/json" }, body: JSON.stringify(selection) });
      if (!response.ok) throw new Error(`Plan validation failed (HTTP ${response.status}). Please retry after resolving the selection.`);
      if (!response.headers.get("content-type")?.includes("application/json")) throw new Error("The server returned an unexpected response. Please retry.");
      let verified: PublicPlan;
      try { verified = await response.json(); }
      catch { throw new Error("The server returned invalid JSON. Please retry."); }
      if (requestedRevision !== revision.current) throw new Error("The selection changed. Validate the current selection again.");
      if (!verified || verified.kind !== "configureme-preview" || verified.executable !== false || !verified.valid)
        throw new Error("The server refused this plan. Resolve the visible conflicts before exporting.");
      setServerPlan(verified);
      if (exportJson) {
        const url = URL.createObjectURL(new Blob([JSON.stringify(verified, null, 2) + "\n"], { type: "application/json" }));
        const link = document.createElement("a"); link.href = url; link.download = "configureme-preview.json";
        link.click(); setTimeout(() => URL.revokeObjectURL(url), 1_000);
      }
    } catch (exception) { setError(exception instanceof Error ? exception.message : "The plan could not be checked."); }
    finally { setBusy(false); }
  }
  const profileNames = new Map(publicSnapshot.profiles.map(profile => [profile.id, profile.name]));
  const displaySource = (id: string) => id === "session" ? "Your addition" : profileNames.get(id) ?? id;

  return <section id="configurator" className="public-configurator" aria-labelledby="configurator-title" data-ready={ready}>
    <div className="page-heading">
      <div><div className="eyebrow">YOUR WINDOWS SETUP · NO LOGIN REQUIRED</div><h1 id="configurator-title">Make it <span>your computer.</span></h1>
        <p>Combine profiles, fine-tune your tools and review the plan. Nothing installs from your browser.</p></div>
      <span className="badge badge-warning">Preview · local fixtures</span>
    </div>
    <p className="fixture-note">These synthetic profiles are bundled development fixtures ({publicSnapshot.snapshotId}), not an integrated myConfigs-data snapshot. Sign-in is optional and adds no installation permissions.</p>
    {storageNote && <p className="notice" role="status">{storageNote}</p>}
    <fieldset className="config-controls" disabled={!ready}>
      <legend className="sr-only">Configure this browser session</legend>
      <div className="configuration-grid">
        <div className="configuration-main">
          <section className="panel config-section" aria-labelledby="target-title">
            <div className="config-heading"><span className="step-number">01</span><h2 id="target-title">Choose your Windows target</h2><span className="badge">x64 only</span></div>
            <label className="field-label" htmlFor="windows-target">Operating system</label>
            <select id="windows-target" className="select-control" value={selection.target}
              onChange={event => update({ ...selection, target: event.target.value as WindowsTarget })}>
              {targets.map(target => <option key={target} value={target}>{targetNames[target]}</option>)}
            </select>
            <p className="config-hint">Switching targets preserves your choices and shows incompatibilities. Installer support still needs target-system validation.</p>
          </section>
          <section className="config-section" aria-labelledby="profiles-title">
            <div className="config-heading"><span className="step-number">02</span><h2 id="profiles-title">Start with profiles</h2><span className="config-hint">Combine any that fit</span></div>
            <div className="public-profile-grid">
              {publicSnapshot.profiles.map(profile => {
                const available = profile.targets.includes(selection.target);
                const selected = selection.profileIds.includes(profile.id);
                return <label key={profile.id} className={`profile-card public-profile ${selected ? "selected" : ""}`}>
                  <div className="card-topline"><input type="checkbox" checked={selected} disabled={!available && !selected}
                    onChange={() => toggleProfile(profile.id)} aria-label={profile.name} />
                    <span>{available ? `${profile.packages.length} packages` : "Server 2022 only"}</span></div>
                  <h3>{profile.name}</h3><p>{profile.description}</p>
                </label>;
              })}
            </div>
          </section>
          <section className="panel config-section" aria-labelledby="packages-title">
            <div className="config-heading"><span className="step-number">03</span><h2 id="packages-title">Fine-tune your software</h2></div>
            <p className="config-hint">Dependencies stay visible. Manual, web and detection-only entries do not promise automatic installation.</p>
            {categories.map(category => <fieldset className="package-category" key={category}><legend>{category}</legend>
              {publicCatalog.filter(item => item.category === category).map(item => {
                const resolved = plan.packages.find(candidate => candidate.id === item.id);
                const mode = modeFor(item, selection.target);
                return <label className="choice-row public-package" key={item.id}>
                  <input type="checkbox" aria-label={item.name} checked={Boolean(resolved)} disabled={mode === "unavailable" && !resolved}
                    onChange={event => togglePackage(item.id, event.target.checked)} />
                  <span><strong>{item.name}</strong><small>{modeLabels[mode]}</small>
                    {resolved && <small className="package-origin">{resolved.requestedBy.map(displaySource).join(", ")}
                      {resolved.requiredBy.length > 0 && ` · Required by ${resolved.requiredBy.join(", ")}`}</small>}
                  </span><span className={`badge ${mode === "unavailable" || ["manual", "web-fallback", "detection-only"].includes(mode) ? "badge-warning" : ""}`}>{mode}</span>
                </label>;
              })}
            </fieldset>)}
            {(selection.addedPackageIds.length > 0 || selection.removedPackageIds.length > 0) && <div className="session-changes">
              <h3>Your package overrides</h3>
              {[...selection.addedPackageIds.map(id => ({ id, kind: "Added" })), ...selection.removedPackageIds.map(id => ({ id, kind: "Removed" }))].map(change =>
                <div key={change.id} className="summary-row"><span>{change.kind}: {change.id}</span><button type="button" className="text-link" onClick={() => update({ ...selection,
                  addedPackageIds: selection.addedPackageIds.filter(id => id !== change.id), removedPackageIds: selection.removedPackageIds.filter(id => id !== change.id) })}>Undo {change.id}</button></div>)}
            </div>}
          </section>
          <section className="panel config-section" aria-labelledby="options-title">
            <div className="config-heading"><span className="step-number">04</span><h2 id="options-title">Session preferences</h2></div>
            <p className="config-hint">Planning hints only. No accounts, Git settings or system preferences are changed here.</p>
            {optionNames.map(key => <div className="option-field" key={key}><label className="field-label" htmlFor={key}>{optionLabels[key]}</label>
              <select className="select-control" id={key} value={selection.options[key] === undefined ? "profiles" : String(selection.options[key])} onChange={event => chooseOption(key, event.target.value)}>
                <option value="profiles">Use profile defaults</option><option value="true">Yes · override for this session</option><option value="false">No · override for this session</option>
              </select><small className="config-hint">Resolved: {plan.options[key] === undefined ? "not set" : String(plan.options[key])} · {(plan.optionSources[key] ?? []).map(displaySource).join(", ")}</small>
            </div>)}
          </section>
        </div>
        <aside className="panel public-summary" aria-labelledby="review-title">
          <div className="eyebrow">YOUR CONFIGURATION</div><h2 id="review-title">Review before you run</h2>
          <div className="summary-row"><span>Target</span><strong>{targetNames[selection.target]}</strong></div>
          <div className="summary-row"><span>Profiles</span><strong>{selection.profileIds.length}</strong></div>
          <div className="summary-row"><span>Resolved packages</span><strong data-testid="package-count">{plan.packages.length}</strong></div>
          <p className="config-hint">{plan.packages.filter(item => item.mode === "detection-only").length} detection-only · {plan.packages.filter(item => item.mode === "manual" || item.mode === "web-fallback").length} manual / web</p>
          <ol className="resolved-list">{plan.packages.map(item => <li key={item.id}>{item.name}{item.requiredBy.length > 0 && <small>Dependency of {item.requiredBy.join(", ")}</small>}</li>)}</ol>
          {plan.issues.length > 0 ? <div className="error-note" role="alert"><strong>Resolve these conflicts</strong><ul>{plan.issues.map((issue, index) => <li key={index}>{issue.message}</li>)}</ul></div>
            : <p className="success-note">{plan.packages.length ? "Locally consistent · server review required" : "No packages selected · add a profile or a package"}</p>}
          <div className="preview-actions">
            <button className="button button-primary" type="button" disabled={busy || !plan.valid} onClick={() => void validate(false)}>{busy ? "Checking…" : "Validate plan on server"}</button>
            <button className="button button-quiet" type="button" disabled={busy || !plan.valid} onClick={() => void validate(true)}>Export preview JSON</button>
          </div>
          {serverPlan && <p className="success-note" role="status">Server validated · {serverPlan.packages.length} packages. This is a non-executable preview.</p>}
          {error && <p className="error-note" role="alert">{error}</p>}
          <details><summary>Inspect the resolved preview</summary><pre className="plan-json">{JSON.stringify(serverPlan ?? plan, null, 2)}</pre></details>
          <div className="security-note"><strong>Setup downloads are not released yet.</strong><p>You can export the complete reviewed plan as JSON. Executable ZIP/EXE downloads remain blocked until release trust and Windows acceptance are approved.</p></div>
          <button className="button button-quiet reset-selection" type="button" onClick={() => update({ ...freshSelection(), target: selection.target, profileIds: [] })}>Clear this selection</button>
          <p className="config-hint">Stored only for this browser tab/session. No login, secrets, telemetry or private infrastructure connection.</p>
        </aside>
      </div>
    </fieldset>
  </section>;
}
