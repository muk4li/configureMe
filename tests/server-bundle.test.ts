import { createHash } from "node:crypto";
import JSZip from "jszip";
import { describe, expect, it, vi } from "vitest";
import { createServer2022Bundle } from "../src/lib/server-bundle";

describe("standalone Server 2022 web bundle", () => {
  it("has stable raw ZIP timestamps and bytes across clock ticks and local time zones", async () => {
    const originalZone = process.env.TZ;
    // Only Date is controlled, specifically to cross DOS two-second boundaries.
    // I/O, compression, manifest content and archive equality are real.
    vi.useFakeTimers({ toFake: ["Date"] });
    try {
      let reference: Buffer | undefined;
      for (const zone of ["UTC", "America/Los_Angeles", "Pacific/Kiritimati"]) {
        process.env.TZ = zone;
        for (const instant of ["2026-01-01T00:00:00Z", "2026-06-01T12:34:04Z"]) {
          vi.setSystemTime(new Date(instant));
          const archive = await createServer2022Bundle(["git", "github-cli"]);
          if (reference) expect(archive).toEqual(reference);
          reference = archive;
          const zip = await JSZip.loadAsync(archive);
          expect(Object.values(zip.files)).toHaveLength(13);
          expect(Object.values(zip.files).every(entry => !entry.dir)).toBe(true);
          for (const entry of Object.values(zip.files))
            expect(entry.date.toISOString()).toBe("1980-01-01T00:00:00.000Z");
          // ZIP local and central headers both store time=0, date=33 (1980-01-01).
          let localHeaders = 0, centralHeaders = 0;
          for (let offset = 0; offset <= archive.length - 46; offset++) {
            const signature = archive.readUInt32LE(offset);
            if (signature === 0x04034b50 || signature === 0x02014b50) {
              const timeOffset = signature === 0x04034b50 ? 10 : 12;
              expect(archive.readUInt16LE(offset + timeOffset)).toBe(0);
              expect(archive.readUInt16LE(offset + timeOffset + 2)).toBe(33);
              if (signature === 0x04034b50) localHeaders++; else centralHeaders++;
            }
          }
          expect(localHeaders).toBe(13); expect(centralHeaders).toBe(13);
        }
      }
    } finally {
      if (originalZone === undefined) delete process.env.TZ; else process.env.TZ = originalZone;
      vi.useRealTimers();
    }
  });
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
