import { NextResponse } from "next/server";
import { getSession } from "@/lib/auth";
import { listProfiles } from "@/lib/profiles";

export async function GET() {
  if (!(await getSession())) {
    return NextResponse.json({ error: "Authentication required." }, { status: 401 });
  }
  return NextResponse.json({ profiles: await listProfiles() }, { headers: { "Cache-Control": "private, no-store" } });
}
