import { createHash } from "node:crypto";
import { execFile } from "node:child_process";
import { promisify } from "node:util";
import { lstat, readFile, realpath } from "node:fs/promises";
import path from "node:path";
import JSZip from "jszip";
import { linuxCatalog, resolveLinuxSelection } from "./linux-planning";
const exec = promisify(execFile);
const hash = (data: Buffer | string) => createHash("sha256").update(data).digest("hex");
export const linuxBundleFiles = ["linux/runner.py", "linux/host.py", "linux/detect.py", "linux/linux_plan.py", "linux/report.py", "linux/steps.py", "linux/trusted.py", "linux/verify_bundle.py", "linux/catalog.json", "schemas/linux-plan-v1.schema.json", "contracts/linux-plan-v1.policy.json"].sort();
export async function linuxRevision(root = process.cwd()) {
  const bytes = await readFile(path.join(root, "linux/catalog.json"));
  if (JSON.stringify(JSON.parse(bytes.toString("utf8"))) !== JSON.stringify(linuxCatalog)) throw new Error("Linux catalog changed after build.");
  return hash(bytes);
}
async function sourceState(root: string) {
  const options = { cwd: root, timeout: 5000, maxBuffer: 65536, windowsHide: true, env: { ...process.env, GIT_OPTIONAL_LOCKS: "0" } };
  const commit = (await exec("git", ["-c", "core.fsmonitor=false", "-c", "core.hooksPath=", "rev-parse", "--verify", "HEAD"], options)).stdout.trim();
  if (!/^[a-f0-9]{40,64}$/.test(commit) || (await exec("git", ["-c", "core.fsmonitor=false", "-c", "core.hooksPath=", "status", "--porcelain", "--untracked-files=normal"], options)).stdout.trim())
    throw new Error("Linux development bundles require an unchanged clean Git checkout.");
  return commit;
}
export async function createLinuxBundle(input: unknown, root = process.cwd()) {
  const before = await sourceState(root);
  const revision = await linuxRevision(root);
  const plan = resolveLinuxSelection(input, revision);
  const contents = new Map<string, Buffer>();
  // Payloads are explicitly allowlisted in outputFileTracingIncludes; never recursively trace the checkout root (.git/env).
  const base = await realpath(/* turbopackIgnore: true */ root);
  for (const name of linuxBundleFiles) {
    const filename = path.join(base, name), actual = await realpath(filename), relative = path.relative(base, actual);
    if ((await lstat(filename)).isSymbolicLink() || relative.startsWith("..") || path.isAbsolute(relative)) throw new Error("Unsafe Linux bundle source.");
    const bytes = await readFile(filename);
    if (bytes.length > 1048576) throw new Error("Linux bundle source exceeds limit.");
    contents.set(name, bytes);
  }
  contents.set("plan.json", Buffer.from(JSON.stringify(plan, null, 2) + "\n"));
  contents.set("README.md", Buffer.from(`# configureMe Ubuntu 24.04/amd64 development bundle\n\nUNSIGNED DEVELOPMENT ARTIFACT — NOT A RELEASE OR PRIVILEGED DISTRIBUTION APPROVAL.\nSource commit: ${before}\nCatalog SHA256: ${revision}\n\nA checksum supplied by this download does NOT prove independent origin. Before running ANY bundled Python code, obtain the archive SHA256 and source commit through a separate trusted channel and compare them. Use verify_bundle.py from an independently reviewed pinned Git checkout, not an unverified download.\n\n1. Independently verify archive SHA256/source and runner code.\n2. From the trusted checkout: python3 linux/verify_bundle.py bundle.zip --expected-sha256 <independent-sha256> --extract-to <new-directory>\n3. As your ordinary user, in the extracted directory: python3 linux/runner.py --plan plan.json\n4. Review reports. Only after a separate operator decision: sudo python3 linux/runner.py --plan plan.json --apply\n5. Interactive hostname confirmation is required; then repeat Dry-Run to verify desired state.\n\nPython >=3.12; Ubuntu24.04/amd64 only. No portal/SSH agent, elevation, firewall/Hyper-V/Caddy setup, unattended reboot or secret provisioning. Docker group defaults false and is root-equivalent if explicitly selected. Pin/key audit must be checked before first Apply.\n`));
  const files = [...contents].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([name, bytes]) => ({ path: name, sizeBytes: bytes.length, sha256: hash(bytes) }));
  const manifest = { formatId: "configureme/linux-bundle", schemaVersion: 1, authorization: "none", releaseApproved: false,
    manualVerificationRequired: true, sourceCommit: before, sourceClean: true, catalogRevision: revision, files };
  contents.set("manifest.json", Buffer.from(JSON.stringify(manifest, null, 2) + "\n"));
  contents.set("SHA256SUMS", Buffer.from([...contents].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0).map(([name, bytes]) => `${hash(bytes)}  ${name}\n`).join("")));
  if (await sourceState(root) !== before) throw new Error("Source changed during bundle creation.");
  const zip = new JSZip();
  for (const [name, bytes] of [...contents].sort(([a], [b]) => a < b ? -1 : a > b ? 1 : 0))
    zip.file(name, bytes, { date: new Date("1980-01-01T00:00:00Z"), createFolders: false });
  const archive = await zip.generateAsync({ type: "nodebuffer", compression: "DEFLATE", compressionOptions: { level: 6 }, platform: "DOS" });
  return { archive, sha256: hash(archive), sourceCommit: before };
}
