// CM-043: local-only Linux bundle for the Ubuntu runner (docs/cm-043-linux-bundle-contract.md).
// The portal only packages files; it never executes anything on the target.
import { createHash } from "node:crypto";
import { execFileSync } from "node:child_process";
import { readFileSync, readdirSync } from "node:fs";
import path from "node:path";
import { gzipSync } from "node:zlib";
import { z } from "zod";

export const BUNDLE_DIR = "configureme-bundle";
const PY_FILE = /^[a-z_]+\.py$/;
const STEP_ID = /^[a-z0-9-]{1,40}$/;
const COMMIT = /^[0-9a-f]{40}$/;

export type CatalogStep = { id: string; title: string; dependsOn: string[]; packages: { name: string; version?: string }[] };
export type LinuxCatalog = { raw: Buffer; revision: string; steps: CatalogStep[] };
export type BundleFile = { path: string; content: Buffer };

/** Only the env flag AND a loopback Host header enable the local bundle. */
export function isLocalBundleEnabled(host: string | null, env: string | undefined = process.env.CONFIGUREME_LOCAL_LINUX_BUNDLE): boolean {
  if (env !== "1" || !host) return false;
  const name = host.replace(/:\d{1,5}$/, "").toLowerCase();
  return name === "127.0.0.1" || name === "localhost";
}

export function loadCatalog(root = process.cwd()): LinuxCatalog {
  const raw = readFileSync(path.join(root, "linux", "catalog.json"));
  const parsed = JSON.parse(raw.toString("utf8")) as { formatId?: string; steps?: CatalogStep[] };
  if (parsed.formatId !== "configureme/linux-catalog" || !Array.isArray(parsed.steps)) throw new Error("Unerwarteter Linux-Katalog.");
  return { raw, revision: sha256(raw), steps: parsed.steps };
}

export const bundleSelectionSchema = z.object({
  steps: z.array(z.string().regex(STEP_ID)).min(1).max(32),
  // huu-server-01 decision: the docker group stays off; the bundle offers no other value.
  addInvokingUserToDockerGroup: z.literal(false),
}).strict();
export type BundleSelection = z.infer<typeof bundleSelectionSchema>;

export class BundleSelectionError extends Error {}

/** Re-validate untrusted browser input against the catalog; returns steps in catalog order. */
export function resolveSteps(catalog: LinuxCatalog, selection: BundleSelection): string[] {
  const byId = new Map(catalog.steps.map((step) => [step.id, step]));
  const chosen = new Set<string>();
  for (const id of selection.steps) {
    if (!byId.has(id)) throw new BundleSelectionError(`Unbekannter Schritt: ${id}`);
    if (chosen.has(id)) throw new BundleSelectionError(`Doppelter Schritt: ${id}`);
    chosen.add(id);
  }
  for (const id of chosen) for (const dep of byId.get(id)!.dependsOn)
    if (!chosen.has(dep)) throw new BundleSelectionError(`${id} benötigt ${dep}.`);
  return catalog.steps.map((step) => step.id).filter((id) => chosen.has(id));
}

export function createPlan(catalog: LinuxCatalog, steps: string[]): Buffer {
  const plan = {
    formatId: "configureme/linux-plan", schemaVersion: 1, catalogRevision: catalog.revision, authorization: "none",
    target: { os: "ubuntu-24.04", architecture: "amd64" }, steps, options: { addInvokingUserToDockerGroup: false },
  };
  return Buffer.from(`${JSON.stringify(plan, null, 2)}\n`, "utf8");
}

/** Commit of the checkout; refuses when linux/ differs from it, so the manifest never names a wrong commit. */
export function sourceCommit(root = process.cwd()): string {
  const git = (...args: string[]) => execFileSync("git", ["-C", root, ...args], { encoding: "utf8", timeout: 5000 }).trim();
  const commit = git("rev-parse", "HEAD");
  if (!COMMIT.test(commit)) throw new Error("Commit konnte nicht bestimmt werden.");
  if (git("status", "--porcelain", "--", "linux")) throw new Error("linux/ hat uncommittete Änderungen; Bundle nur aus einem sauberen Commit.");
  return commit;
}

export function instructions(commit: string, archiveName: string): string {
  return [
    "configureMe Linux-Bundle (CM-043) - Ubuntu Server 24.04 amd64",
    `Quell-Commit: ${commit}`,
    "",
    "1. Auf dem Windows-Host (PowerShell) kopieren:",
    `   scp .\\${archiveName} <benutzer>@huu-server-01:~/`,
    "2. Auf der VM die Prüfsumme mit der Anzeige im Browser vergleichen:",
    `   sha256sum ~/${archiveName}`,
    "3. Entpacken:",
    `   tar -xzf ~/${archiveName} -C ~ && cd ~/${BUNDLE_DIR}`,
    "4. Dry-Run (ändert nichts):",
    "   python3 linux/runner.py --plan plan.json",
    "5. Bericht linux-runner-report.txt prüfen. Danach nur nach eigener Freigabe:",
    "   sudo python3 linux/runner.py --plan plan.json --apply",
    "",
    "Der Runner prüft MANIFEST.json vor jedem Lauf. Das belegt Unverändertheit,",
    "nicht die Herkunft: Archiv-Hash und Commit selbst vergleichen.",
    "",
  ].join("\n");
}

export function collectFiles(root: string, catalog: LinuxCatalog, plan: Buffer, commit: string, archiveName: string): BundleFile[] {
  const linuxDir = path.join(root, "linux");
  const python = readdirSync(linuxDir).filter((name) => PY_FILE.test(name)).sort();
  const files: BundleFile[] = [
    ...python.map((name) => ({ path: `linux/${name}`, content: readFileSync(path.join(linuxDir, name)) })),
    { path: "linux/catalog.json", content: catalog.raw },
    { path: "plan.json", content: plan },
    { path: "ANLEITUNG.txt", content: Buffer.from(instructions(commit, archiveName), "utf8") },
  ];
  const manifest = {
    formatId: "configureme/linux-bundle", schemaVersion: 1, sourceCommit: commit, catalogRevision: catalog.revision,
    planSha256: sha256(plan), files: files.map((file) => ({ path: file.path, sha256: sha256(file.content) })),
  };
  return [...files, { path: "MANIFEST.json", content: Buffer.from(`${JSON.stringify(manifest, null, 2)}\n`, "utf8") }];
}

export function sha256(data: Buffer): string { return createHash("sha256").update(data).digest("hex"); }

function octal(value: number, width: number): string { return value.toString(8).padStart(width - 1, "0") + "\0"; }
function header(name: string, size: number, type: "0" | "5"): Buffer {
  if (Buffer.byteLength(name) > 100) throw new Error(`Pfad zu lang: ${name}`);
  const block = Buffer.alloc(512);
  block.write(name, 0, "utf8");
  block.write(octal(type === "5" ? 0o755 : 0o644, 8), 100);
  block.write(octal(0, 8), 108); block.write(octal(0, 8), 116);
  block.write(octal(size, 12), 124); block.write(octal(0, 12), 136);
  block.fill(" ", 148, 156);
  block.write(type, 156);
  block.write("ustar\0", 257); block.write("00", 263);
  block.write("root", 265); block.write("root", 297);
  let sum = 0; for (const byte of block) sum += byte;
  block.write(`${sum.toString(8).padStart(6, "0")}\0 `, 148);
  return block;
}

/** Reproducible tar.gz: fixed order, mtime 0, uid/gid 0, fixed modes, gzip header without mtime/OS variance. */
export function createTarGz(files: BundleFile[]): Buffer {
  const parts: Buffer[] = [];
  const dirs = [...new Set(files.map((file) => path.posix.dirname(file.path)).filter((dir) => dir !== "."))].sort();
  parts.push(header(`${BUNDLE_DIR}/`, 0, "5"));
  for (const dir of dirs) parts.push(header(`${BUNDLE_DIR}/${dir}/`, 0, "5"));
  for (const file of files) {
    parts.push(header(`${BUNDLE_DIR}/${file.path}`, file.content.length, "0"), file.content);
    const pad = (512 - (file.content.length % 512)) % 512;
    if (pad) parts.push(Buffer.alloc(pad));
  }
  parts.push(Buffer.alloc(1024));
  const gz = gzipSync(Buffer.concat(parts), { level: 9 });
  gz.writeUInt32LE(0, 4); gz[9] = 3; // mtime 0, OS "Unix" on every host platform
  return gz;
}

export function buildBundle(selection: BundleSelection, root = process.cwd(), commit = sourceCommit(root)) {
  const catalog = loadCatalog(root);
  const steps = resolveSteps(catalog, selection);
  const archiveName = `configureme-linux-${commit.slice(0, 12)}.tar.gz`;
  const files = collectFiles(root, catalog, createPlan(catalog, steps), commit, archiveName);
  const archive = createTarGz(files);
  return { archive, archiveName, archiveSha256: sha256(archive), commit, steps, catalogRevision: catalog.revision };
}
