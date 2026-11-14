import { NextResponse, type NextRequest } from "next/server";
import { resolveLinuxSelection } from "@/lib/linux-planning";
import { linuxRevision } from "@/lib/linux-bundle";
import { isPublicOriginAllowed, readPublicJson, PublicInputError } from "@/lib/public-request";
import { isPublicPlanRateLimited } from "@/lib/public-rate-limit";
export const runtime = "nodejs";
let active = 0;
export async function POST(request: NextRequest) {
  const headers = { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" };
  if (!isPublicOriginAllowed(request, request.nextUrl.origin)) return NextResponse.json({ error: "Invalid origin." }, { status: 403, headers });
  if (isPublicPlanRateLimited()) return NextResponse.json({ error: "Please wait." }, { status: 429, headers });
  if (active >= 4) return NextResponse.json({ error: "Capacity reached." }, { status: 503, headers });
  active++;
  try {
    return NextResponse.json({ valid: true, executable: false, releaseApproved: false, plan: resolveLinuxSelection(await readPublicJson(request), await linuxRevision()) }, { headers });
  } catch (error) {
    return NextResponse.json({ error: "Invalid Linux selection or catalog." }, { status: error instanceof PublicInputError ? error.status : 400, headers });
  } finally { active--; }
}
