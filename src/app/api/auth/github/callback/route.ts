import { timingSafeEqual } from "node:crypto";
import { NextResponse, type NextRequest } from "next/server";
import {
  createSessionToken,
  isAllowedUser,
  isInitialAdmin,
  sessionCookieName,
  sessionCookieOptions,
} from "@/lib/auth";
import { isRateLimited } from "@/lib/rate-limit";
import { getGitHubCallbackUrl } from "@/lib/oauth";

const STATE_COOKIE = "configureme_oauth_state";

function authFailure(request: NextRequest, reason = "failed") {
  const response = NextResponse.redirect(new URL(`/?auth=${reason}`, request.url));
  response.cookies.delete(STATE_COOKIE);
  return response;
}

export async function GET(request: NextRequest) {
  if (isRateLimited("oauth-callback", 20)) return authFailure(request, "rate-limited");

  const code = request.nextUrl.searchParams.get("code");
  const state = request.nextUrl.searchParams.get("state");
  const expectedState = request.cookies.get(STATE_COOKIE)?.value;
  if (!code || code.length > 512 || !state || !expectedState || state.length !== expectedState.length) {
    return authFailure(request);
  }
  const actualState = Buffer.from(state);
  const savedState = Buffer.from(expectedState);
  if (!timingSafeEqual(actualState, savedState)) return authFailure(request);

  const clientId = process.env.GITHUB_CLIENT_ID;
  const clientSecret = process.env.GITHUB_CLIENT_SECRET;
  const redirectUri = getGitHubCallbackUrl(request.nextUrl.origin);
  if (!clientId || !clientSecret || !process.env.AUTH_SECRET || !redirectUri) {
    return authFailure(request, "unavailable");
  }

  try {
    const tokenResponse = await fetch("https://github.com/login/oauth/access_token", {
      method: "POST",
      headers: { Accept: "application/json", "Content-Type": "application/json" },
      body: JSON.stringify({
        client_id: clientId,
        client_secret: clientSecret,
        code,
        redirect_uri: redirectUri,
      }),
      signal: AbortSignal.timeout(10_000),
      cache: "no-store",
    });
    if (!tokenResponse.ok) return authFailure(request);
    const tokenData: { access_token?: string; error?: string } = await tokenResponse.json();
    if (!tokenData.access_token) return authFailure(request);

    const userResponse = await fetch("https://api.github.com/user", {
      headers: {
        Accept: "application/vnd.github+json",
        Authorization: `Bearer ${tokenData.access_token}`,
        "X-GitHub-Api-Version": "2022-11-28",
      },
      signal: AbortSignal.timeout(10_000),
      cache: "no-store",
    });
    if (!userResponse.ok) return authFailure(request);
    const user: { login?: unknown } = await userResponse.json();
    if (typeof user.login !== "string" || !/^[a-zA-Z0-9-]{1,39}$/.test(user.login)) {
      return authFailure(request);
    }
    if (!isAllowedUser(user.login)) return authFailure(request, "forbidden");

    const response = NextResponse.redirect(new URL("/dashboard", request.url));
    response.cookies.delete(STATE_COOKIE);
    response.cookies.set(
      sessionCookieName(),
      createSessionToken(user.login, isInitialAdmin(user.login) ? "admin" : "user"),
      sessionCookieOptions(),
    );
    return response;
  } catch {
    return authFailure(request);
  }
}
