import { NextResponse, type NextRequest } from "next/server";
import { getSession, isAllowedUser } from "@/lib/auth";
import { linuxSelectionSchema } from "@/lib/linux-planning";
import { createLinuxBundle } from "@/lib/linux-bundle";
import { isPublicOriginAllowed, readPublicJson, PublicInputError } from "@/lib/public-request";
import { isRateLimited } from "@/lib/rate-limit";
export const runtime = "nodejs";
let active = 0;
export function localLinuxBundleEnabled() { return process.env.CONFIGUREME_LOCAL_LINUX_DOWNLOADS === "1"; }
export async function POST(request: NextRequest) {
  const headers = { "Cache-Control": "private, no-store", "X-Content-Type-Options": "nosniff" };
  const fail = (status: number, message: string) => NextResponse.json({ error: message }, { status, headers });
  if (!localLinuxBundleEnabled()) return fail(404, "Local Linux development download is disabled.");
  let origin: URL;
  try { origin = new URL(process.env.APP_URL ?? ""); } catch { return fail(403, "Configure an explicit loopback APP_URL."); }
  if (!['localhost', '127.0.0.1', '[::1]'].includes(origin.hostname) || origin.username || origin.password ||
      !['http:', 'https:'].includes(origin.protocol) || origin.pathname !== '/' || origin.search || origin.hash ||
      request.headers.get("host") !== origin.host || !isPublicOriginAllowed(request, origin.origin))
    return fail(403, "Local origin/host refused. LAN bundle delivery is not approved.");
  const session = await getSession();
  if (!session || !isAllowedUser(session.username)) return fail(401, "Private portal sign-in is required.");
  if (isRateLimited("linux-bundle", 5)) return fail(429, "Please wait before downloading again.");
  if (active >= 2) return fail(503, "Download capacity reached.");
  active++;
  try {
    const result = await createLinuxBundle(linuxSelectionSchema.parse(await readPublicJson(request)));
    return new NextResponse(new Uint8Array(result.archive), { headers: { ...headers, "Content-Type": "application/zip",
      "Content-Disposition": 'attachment; filename="configureme-ubuntu-24.04-amd64-development.zip"',
      "X-Artifact-SHA256": result.sha256, "X-Source-Commit": result.sourceCommit } });
  } catch (error) {
    return fail(error instanceof PublicInputError ? error.status : 422, "Development bundle refused: selection/source checkout must validate and be clean.");
  } finally { active--; }
}
