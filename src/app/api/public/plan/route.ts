import { NextResponse, type NextRequest } from "next/server";
import { createSetupPlan } from "@/lib/setup-plan";
import { resolvePublicPlan, selectionSchema } from "@/lib/public-planning";
import { isPublicOriginAllowed, PublicInputError, readPublicJson } from "@/lib/public-request";
import { isPublicPlanRateLimited } from "@/lib/public-rate-limit";

export const runtime = "nodejs";
let activeRequests = 0;
const headers = { "Cache-Control": "no-store", "X-Content-Type-Options": "nosniff" };
function error(message: string, status: number, retryAfter?: string) {
  return NextResponse.json({ error: message }, { status, headers: { ...headers, ...(retryAfter ? { "Retry-After": retryAfter } : {}) } });
}
export async function POST(request: NextRequest) {
  if (!isPublicOriginAllowed(request, request.nextUrl.origin)) return error("Invalid request origin.", 403);
  // Dedicated bounded global bucket; no client identity or key-eviction assumptions.
  if (isPublicPlanRateLimited()) return error("Too many preview requests. Please wait.", 429, "60");
  if (activeRequests >= 4) return error("Preview capacity reached. Please retry.", 503, "1");
  activeRequests++;
  try {
    const parsed = selectionSchema.safeParse(await readPublicJson(request));
    if (!parsed.success) return error("Invalid or incompatible public selection.", 400);
    const preview = resolvePublicPlan(parsed.data);
    if (request.nextUrl.searchParams.get("export") === "setup-plan-v1") {
      if (!preview.valid || !preview.packages.length) return error("Resolve the selection before exporting a setup plan.", 422);
      return NextResponse.json(createSetupPlan(parsed.data), { headers });
    }
    return NextResponse.json(preview, { headers });
  } catch (exception) {
    if (exception instanceof PublicInputError) return error(exception.message, exception.status);
    return error("The public plan could not be validated.", 500);
  } finally { activeRequests--; }
}
