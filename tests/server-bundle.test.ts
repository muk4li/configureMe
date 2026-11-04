import { createHash } from "node:crypto";
import JSZip from "jszip";
import { describe, expect, it } from "vitest";
import { createServer2022Bundle } from "../src/lib/server-bundle";

describe("standalone Server 2022 web bundle", () => {
  it("includes every imported worker module, trusted catalog and matching manifest", async () => {
    const archive = await createServer2022Bundle(["git", "github-cli"]);
    const zip = await JSZip.loadAsync(archive);
    const prefix = "configureMe-QuickSetup/";
    const bootstrap = await zip.file(`${prefix}bootstrap.ps1`)!.async("string");
    const modules = [...bootstrap.matchAll(/Join-Path \$moduleDirectory "([^"]+\.psm1)"/g)].map(match => match[1]);
    expect(modules).toContain("GuiWorker.psm1");
    for (const moduleName of modules) expect(zip.file(`${prefix}modules/${moduleName}`)).not.toBeNull();
    expect(zip.file(`${prefix}config/catalog.json`)).not.toBeNull();
    const profile = JSON.parse(await zip.file(`${prefix}config/windows-server-2022-developer.json`)!.async("string"));
    expect(profile.packages).toEqual(["git", "github-cli"]);
    const manifest = JSON.parse(await zip.file(`${prefix}manifest.json`)!.async("string"));
    expect(manifest.files).toHaveLength(12);
    for (const file of manifest.files) {
      const contents = await zip.file(prefix + file.path)!.async("nodebuffer");
      expect(contents.length).toBe(file.sizeBytes);
      expect(createHash("sha256").update(contents).digest("hex")).toBe(file.sha256);
    }
    expect(await createServer2022Bundle(["git", "github-cli"])).toEqual(archive);
  });
});
