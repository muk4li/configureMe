import { NextResponse, type NextRequest } from "next/server";
import { sessionCookieName } from "@/lib/auth";
import { getPublicBaseUrl, isExpectedRequestOrigin } from "@/lib/oauth";

export async function POST(request: NextRequest) {
  const origin = request.headers.get("origin");
  if (!isExpectedRequestOrigin(origin, request.nextUrl.origin)) {
    return NextResponse.json({ error: "Invalid request origin." }, { status: 403 });
  }
  const publicBase = getPublicBaseUrl(request.nextUrl.origin) ?? new URL(request.url);
  const response = NextResponse.redirect(new URL("/", publicBase), { status: 303 });
  response.cookies.set(sessionCookieName(), "", {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 0,
  });
  return response;
}
