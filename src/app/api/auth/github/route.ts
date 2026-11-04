import { randomBytes } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import { getGitHubCallbackUrl } from "@/lib/oauth";

const STATE_COOKIE = "configureme_oauth_state";

export async function GET(request: NextRequest) {
  const clientId = process.env.GITHUB_CLIENT_ID;
  const callbackUrl = getGitHubCallbackUrl(request.nextUrl.origin);

  if (!clientId || !process.env.GITHUB_CLIENT_SECRET || !process.env.AUTH_SECRET || !callbackUrl) {
    return NextResponse.redirect(new URL("/?auth=unavailable", request.url));
  }

  const state = randomBytes(32).toString("base64url");
  const authorizationUrl = new URL("https://github.com/login/oauth/authorize");
  authorizationUrl.searchParams.set("client_id", clientId);
  authorizationUrl.searchParams.set("redirect_uri", callbackUrl);
  authorizationUrl.searchParams.set("scope", "read:user");
  authorizationUrl.searchParams.set("state", state);

  const response = NextResponse.redirect(authorizationUrl);
  response.cookies.set(STATE_COOKIE, state, {
    httpOnly: true,
    secure: process.env.NODE_ENV === "production",
    sameSite: "lax",
    path: "/",
    maxAge: 600,
  });
  return response;
}
