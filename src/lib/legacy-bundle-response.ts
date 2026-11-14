// Download UX only; this is not artifact authentication or installer verification.
export async function readLegacyBundleResponse(response: Response): Promise<Blob> {
  const mediaType = response.headers.get("content-type")?.split(";")[0].trim().toLowerCase();
  if (!response.ok) {
    let message = `The bundle could not be created (HTTP ${response.status}). Please retry.`;
    if (mediaType === "application/json") {
      try {
        const body: unknown = await response.json();
        if (body && typeof body === "object" && "error" in body && typeof body.error === "string" && body.error.trim())
          message = body.error.replace(/[\r\n\t]/g, " ").trim().slice(0, 240);
      } catch { /* Keep a usable HTTP error for empty/truncated/non-JSON responses. */ }
    }
    throw new Error(message);
  }
  if (mediaType !== "application/zip") throw new Error("The server did not return a ZIP bundle. Nothing was downloaded.");
  const blob = await response.blob();
  const header = new Uint8Array(await blob.slice(0, 4).arrayBuffer());
  if (header.length !== 4 || header[0] !== 0x50 || header[1] !== 0x4b ||
      !((header[2] === 3 && header[3] === 4) || (header[2] === 5 && header[3] === 6)))
    throw new Error("The ZIP response is empty or damaged. Nothing was downloaded.");
  return blob;
}
