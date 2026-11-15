"use client";
import { useEffect, useMemo, useState } from "react";

type Step = { id: string; title: string; dependsOn: string[]; packages: string[] };
// Preset huu-server-01 (linux/plans/huu-server-01.json) plus the accepted tools.
const PRESET = ["base-tools", "docker-apt-repository", "docker-engine", "unattended-upgrades"];
const DEFAULT_TOOLS = ["tool-jq", "tool-python3-venv"];
type Result = { name: string; sha256: string; commit: string };

export function LinuxBundleBuilder() {
  const [steps, setSteps] = useState<Step[]>([]);
  const [selected, setSelected] = useState<Set<string>>(new Set([...PRESET, ...DEFAULT_TOOLS]));
  const [status, setStatus] = useState("");
  const [result, setResult] = useState<Result | null>(null);
  useEffect(() => {
    fetch("/api/local/linux-bundle").then((r) => r.ok ? r.json() : Promise.reject(new Error(`HTTP ${r.status}`)))
      .then((data: { steps: Step[] }) => setSteps(data.steps)).catch((e: Error) => setStatus(`Katalog nicht ladbar: ${e.message}`));
  }, []);
  const missing = useMemo(() => steps.filter((s) => selected.has(s.id)).flatMap((s) => s.dependsOn.filter((d) => !selected.has(d)).map((d) => `${s.id} benötigt ${d}`)), [steps, selected]);
  const toggle = (id: string) => setSelected((old) => { const next = new Set(old); if (next.has(id)) next.delete(id); else next.add(id); return next; });
  async function download() {
    setStatus("Bundle wird erstellt …"); setResult(null);
    const response = await fetch("/api/local/linux-bundle", { method: "POST", headers: { "content-type": "application/json" },
      body: JSON.stringify({ steps: steps.filter((s) => selected.has(s.id)).map((s) => s.id), addInvokingUserToDockerGroup: false }) });
    if (!response.ok) { const body = await response.json().catch(() => ({})) as { error?: string }; setStatus(`Fehler: ${body.error ?? `HTTP ${response.status}`}`); return; }
    const blob = await response.blob();
    const name = response.headers.get("x-bundle-name") ?? "configureme-linux.tar.gz";
    const url = URL.createObjectURL(blob); const link = document.createElement("a");
    link.href = url; link.download = name; link.click(); URL.revokeObjectURL(url);
    setResult({ name, sha256: response.headers.get("x-bundle-sha256") ?? "", commit: response.headers.get("x-bundle-commit") ?? "" });
    setStatus("Heruntergeladen.");
  }
  const group = (tools: boolean) => steps.filter((s) => s.id.startsWith("tool-") === tools);
  return <section className="linux-bundle">
    <p className="eyebrow">LOKALER MODUS · CM-043</p>
    <h1>Linux-Server (Ubuntu 24.04)</h1>
    <p className="hero-lead">Profil <strong>huu-server-01</strong> mit optionalen Werkzeugen. Das Portal erzeugt nur ein Archiv; ausgeführt wird es von dir per SSH auf der VM.</p>
    {[["Profil huu-server-01", false], ["Zusätzliche Werkzeuge", true]].map(([label, tools]) => <fieldset key={String(label)}>
      <legend>{label as string}</legend>
      {group(tools as boolean).map((s) => <label key={s.id} className="linux-step">
        <input type="checkbox" checked={selected.has(s.id)} onChange={() => toggle(s.id)} />
        <span><strong>{s.title}</strong><small>{s.id} · {s.packages.join(", ") || "Repository/Schlüssel"}</small></span>
      </label>)}
    </fieldset>)}
    <p className="hero-note">Docker-Gruppe: aus (Docker nur mit sudo).</p>
    {missing.length > 0 && <p className="notice">{missing.join("; ")}</p>}
    <button className="button button-primary" disabled={!steps.length || !selected.size || missing.length > 0} onClick={download}>Bundle herunterladen</button>
    {status && <p role="status">{status}</p>}
    {result && <div className="linux-result">
      <p>Archiv: <code>{result.name}</code><br />SHA-256: <code>{result.sha256}</code><br />Commit: <code>{result.commit}</code></p>
      <pre>{`scp .\\${result.name} <benutzer>@huu-server-01:~/
sha256sum ~/${result.name}
tar -xzf ~/${result.name} -C ~ && cd ~/configureme-bundle
python3 linux/runner.py --plan plan.json
sudo python3 linux/runner.py --plan plan.json --apply`}</pre>
    </div>}
  </section>;
}
