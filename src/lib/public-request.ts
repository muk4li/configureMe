export class PublicInputError extends Error {
  constructor(public readonly status: number, message: string) { super(message); }
}
export async function readPublicJson(request: Request, maxBytes = 8_192, timeoutMs = 5_000): Promise<unknown> {
  if (request.headers.get("content-type")?.split(";")[0].trim().toLowerCase() !== "application/json")
    throw new PublicInputError(415, "Content-Type must be application/json.");
  if (Number(request.headers.get("content-length") ?? 0) > maxBytes)
    throw new PublicInputError(413, "Request is too large.");
  const reader = request.body?.getReader();
  if (!reader) throw new PublicInputError(400, "A JSON selection is required.");
  let timer: ReturnType<typeof setTimeout> | undefined;
  const deadline = new Promise<never>((_, reject) => {
    timer = setTimeout(() => reject(new PublicInputError(408, "Request body timed out.")), timeoutMs);
  });
  let total = 0;
  const chunks: Uint8Array[] = [];
  try {
    while (true) {
      const { done, value } = await Promise.race([reader.read(), deadline]);
      if (done) break;
      total += value.byteLength;
      if (total > maxBytes) throw new PublicInputError(413, "Request is too large.");
      chunks.push(value);
    }
    const bytes = new Uint8Array(total);
    let offset = 0;
    for (const chunk of chunks) { bytes.set(chunk, offset); offset += chunk.byteLength; }
    try { return JSON.parse(new TextDecoder("utf-8", { fatal: true }).decode(bytes)); }
    catch { throw new PublicInputError(400, "Request must contain valid UTF-8 JSON."); }
  } finally {
    clearTimeout(timer);
    void reader.cancel().catch(() => {});
    reader.releaseLock();
  }
}
// This public pure computation grants no authority. Origin checks are abuse controls, not login.
export function isPublicOriginAllowed(request: Request, requestOrigin: string): boolean {
  if (request.headers.get("sec-fetch-site") === "cross-site") return false;
  try {
    return request.headers.get("origin") === new URL(process.env.APP_URL ?? requestOrigin).origin;
  } catch { return false; }
}
