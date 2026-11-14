import { execFileSync } from "node:child_process";
import { mkdtemp, mkdir, readFile, writeFile, copyFile, rm } from "node:fs/promises";
import { tmpdir } from "node:os";
import path from "node:path";
import JSZip from "jszip";
import { expect, it } from "vitest";
import { createLinuxBundle, linuxBundleFiles } from "../src/lib/linux-bundle";
import { initialLinuxSelection } from "../src/lib/linux-planning";

it("builds byte-identical bounded bundles from a clean real Git checkout, and the trusted Python consumer verifies/extracts them", async () => {
  const root = await mkdtemp(path.join(tmpdir(), "configureme-clean-bundle-"));
  const artifactRoot = await mkdtemp(path.join(tmpdir(), "configureme-bundle-artifact-"));
  const git = (args: string[]) => execFileSync("git", ["-c", "core.hooksPath=", ...args], { cwd: root, stdio: "pipe", windowsHide: true });
  const python = process.platform === "win32" ? "python" : "python3";
  try {
    for (const name of linuxBundleFiles) {
      await mkdir(path.dirname(path.join(root, name)), { recursive: true }); await copyFile(name, path.join(root, name));
    }
    git(["init", "--template="]); git(["add", "."]);
    git(["-c", "user.name=Synthetic Test", "-c", "user.email=fixture@example.invalid", "commit", "--no-gpg-sign", "-qm", "fixture"]);
    const first = await createLinuxBundle(initialLinuxSelection, root), second = await createLinuxBundle(initialLinuxSelection, root);
    expect(first.archive).toEqual(second.archive);
    const zip = await JSZip.loadAsync(first.archive);
    expect(Object.values(zip.files).every(file => !file.dir && file.date.toISOString() === "1980-01-01T00:00:00.000Z")).toBe(true);
    const archivePath = path.join(artifactRoot, "bundle.zip"), destination = path.join(artifactRoot, "extracted");
    await writeFile(archivePath, first.archive);
    execFileSync(python, ["linux/verify_bundle.py", archivePath, "--expected-sha256", first.sha256, "--extract-to", destination], { stdio: "pipe", windowsHide: true });
    expect(await readFile(path.join(destination, "plan.json"), "utf8")).toContain('"authorization": "none"');
    expect(() => execFileSync(python, ["linux/verify_bundle.py", archivePath, "--expected-sha256", first.sha256, "--extract-to", destination], { stdio: "pipe" })).toThrow();
    expect(() => execFileSync(python, ["linux/verify_bundle.py", archivePath, "--expected-sha256", "0".repeat(64)], { stdio: "pipe" })).toThrow();
    // Rebuild ZIPs with matching outer hashes to exercise inner integrity, not just SHA mismatch.
    for (const change of ["tamper", "missing", "traversal", "catalog", "sums", "symlink"]) {
      const corrupt = await JSZip.loadAsync(first.archive);
      if (change === "tamper") corrupt.file("linux/runner.py", "untrusted");
      if (change === "missing") corrupt.remove("linux/host.py");
      if (change === "traversal") corrupt.file("../outside", "untrusted", { createFolders: false });
      if (change === "catalog") corrupt.file("linux/catalog.json", "{}");
      if (change === "sums") corrupt.file("SHA256SUMS", "");
      if (change === "symlink") corrupt.files["linux/host.py"].unixPermissions = 0o120777;
      const bad = await corrupt.generateAsync({ type: "nodebuffer", platform: change === "symlink" ? "UNIX" : "DOS" });
      await writeFile(archivePath, bad);
      const { createHash } = await import("node:crypto");
      const hash = createHash("sha256").update(bad).digest("hex");
      expect(() => execFileSync(python, ["linux/verify_bundle.py", archivePath, "--expected-sha256", hash], { stdio: "pipe" })).toThrow();
    }
    await writeFile(path.join(root, "linux/runner.py"), "dirty");
    await expect(createLinuxBundle(initialLinuxSelection, root)).rejects.toThrow("clean Git checkout");
  } finally { await rm(root, { recursive: true, force: true }); await rm(artifactRoot, { recursive: true, force: true }); }
}, 30000);
