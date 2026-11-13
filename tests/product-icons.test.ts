import { createHash } from "node:crypto";
import { expect, it } from "vitest";
import icons from "../src/assets/product-icons.json";
import provenance from "../third_party/simple-icons/provenance.json";
import { publicCatalog } from "../src/lib/public-planning";
it("ships only known, licensed local path assets with recorded integrity", () => {
  expect(provenance.version).toBe("16.37.0");
  for (const [id, icon] of Object.entries(icons)) {
    expect(publicCatalog.some(item => item.id === id)).toBe(true);
    const source = provenance.assets.find(asset => asset.packageIds.includes(id));
    expect(source).toBeDefined();
    expect(["CC0-1.0", "CC-BY-3.0", "MIT"]).toContain(source!.license.type);
    expect(createHash("sha256").update(icon.path).digest("hex")).toBe(source!.pathSha256);
    expect(icon.path).toMatch(/^[MmZzLlHhVvCcSsQqTtAa0-9.,+eE -]+$/);
    expect(icon.hex).toMatch(/^[0-9A-F]{6}$/);
  }
});
