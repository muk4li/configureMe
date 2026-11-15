import { execFileSync } from "node:child_process";
import { mkdtempSync, writeFileSync } from "node:fs";
import { tmpdir } from "node:os";
import path from "node:path";
import { gunzipSync } from "node:zlib";
import { describe, expect, it } from "vitest";
import { bundleSelectionSchema, buildBundle, isLocalBundleEnabled, loadCatalog, resolveSteps } from "../src/lib/linux-bundle";

const COMMIT = "a".repeat(40);
const preset = { steps: ["base-tools", "docker-apt-repository", "docker-engine", "unattended-upgrades", "tool-jq"], addInvokingUserToDockerGroup: false as const };

describe("CM-043 local Linux bundle", () => {
  it("is enabled only with the env flag and a loopback Host", () => {
    expect(isLocalBundleEnabled("127.0.0.1:3000", "1")).toBe(true);
    expect(isLocalBundleEnabled("localhost", "1")).toBe(true);
    expect(isLocalBundleEnabled("127.0.0.1:3000", undefined)).toBe(false);
    expect(isLocalBundleEnabled("192.168.1.5:3000", "1")).toBe(false);
    expect(isLocalBundleEnabled("localhost.evil.test", "1")).toBe(false);
    expect(isLocalBundleEnabled(null, "1")).toBe(false);
  });
  it("revalidates the selection and orders steps like the catalog", () => {
    const catalog = loadCatalog();
    expect(resolveSteps(catalog, { steps: ["tool-tree", "base-tools"], addInvokingUserToDockerGroup: false })).toEqual(["base-tools", "tool-tree"]);
    expect(() => resolveSteps(catalog, { steps: ["docker-engine"], addInvokingUserToDockerGroup: false })).toThrow("benötigt");
    expect(() => resolveSteps(catalog, { steps: ["tool-rm-rf"], addInvokingUserToDockerGroup: false })).toThrow("Unbekannt");
    expect(() => resolveSteps(catalog, { steps: ["tool-jq", "tool-jq"], addInvokingUserToDockerGroup: false })).toThrow("Doppelt");
    expect(bundleSelectionSchema.safeParse({ ...preset, addInvokingUserToDockerGroup: true }).success).toBe(false);
    expect(bundleSelectionSchema.safeParse({ ...preset, command: "x" }).success).toBe(false);
    expect(bundleSelectionSchema.safeParse({ ...preset, steps: ["; rm -rf /"] }).success).toBe(false);
  });
  it("produces byte-identical archives for identical input", () => {
    const a = buildBundle(preset, process.cwd(), COMMIT), b = buildBundle(preset, process.cwd(), COMMIT);
    expect(a.archiveSha256).toBe(b.archiveSha256);
    expect(a.archive.readUInt32LE(4)).toBe(0);
    const tar = gunzipSync(a.archive).toString("latin1");
    expect(tar).toContain("configureme-bundle/MANIFEST.json");
    expect(tar).not.toContain("configureme-bundle/linux/plans");
  });
  it("is accepted by the Python manifest check and plan validator", () => {
    const dir = mkdtempSync(path.join(tmpdir(), "cm043-"));
    const archive = path.join(dir, "b.tar.gz");
    writeFileSync(archive, buildBundle(preset, process.cwd(), COMMIT).archive);
    const script = `
import sys, tarfile, os
tarfile.open(sys.argv[1]).extractall(sys.argv[2], filter="data")
root = os.path.join(sys.argv[2], "configureme-bundle")
sys.path.insert(0, os.path.join(root, "linux"))
import bundle_manifest
class FileHost:
    def read_file(self, p):
        return open(p, "rb").read() if os.path.isfile(p) else None
    def list_dir(self, p):
        return sorted(os.listdir(p))
commit, errors = bundle_manifest.verify(FileHost(), root)
assert commit == "${COMMIT}" and errors == [], errors
print("ok")`;
    expect(execFileSync("python3", ["-I", "-c", script, archive, dir], { encoding: "utf8" }).trim()).toBe("ok");
  });
});
