import JSZip from "jszip";
import { describe, expect, it } from "vitest";
import { readLegacyBundleResponse } from "../src/lib/legacy-bundle-response";
describe("legacy authenticated bundle response UX", () => {
  for (const [body, type] of [["", "application/json"], ["{", "application/json"], ["<html>upstream failed</html>", "text/html"]])
    it(`keeps HTTP failure understandable for ${JSON.stringify(body)}`, async () => {
      await expect(readLegacyBundleResponse(new Response(body, { status: 500, headers: { "content-type": type } })))
        .rejects.toThrow("HTTP 500");
    });
  it("retains a bounded, plain JSON API error", async () => {
    await expect(readLegacyBundleResponse(Response.json({ error: "Resolve\nthis conflict" }, { status: 400 }))).rejects.toThrow("Resolve this conflict");
  });
  it("refuses HTML/JSON success and ZIP-labelled damaged bodies before download", async () => {
    for (const [body, type] of [["<html>login</html>", "text/html"], ["{}", "application/json"], ["", "application/zip"], ["html", "application/zip"]])
      await expect(readLegacyBundleResponse(new Response(body, { headers: { "content-type": type } }))).rejects.toThrow();
  });
  it("preserves an actual ZIP byte-for-byte without claiming signature trust", async () => {
    const zip = new JSZip(); zip.file("plan.json", "{}");
    const bytes = await zip.generateAsync({ type: "uint8array" });
    const result = await readLegacyBundleResponse(new Response(new Uint8Array(bytes), { headers: { "content-type": "application/zip" } }));
    expect(new Uint8Array(await result.arrayBuffer())).toEqual(bytes);
  });
});
