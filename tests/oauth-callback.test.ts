import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { GET } from "../src/app/api/auth/github/callback/route";
import { isRateLimited } from "../src/lib/rate-limit";
import { sessionCookieName, verifySessionToken } from "../src/lib/auth";

vi.mock("../src/lib/rate-limit", () => ({ isRateLimited: vi.fn(() => false) }));
const stateCookie = "configureme_oauth_state";
const fetchMock = vi.fn<typeof fetch>();
function request(actual = "matching-state", expected = "matching-state", code = "fixture-code") {
  const url = new URL("https://portal.example/api/auth/github/callback");
  url.searchParams.set("state", actual); url.searchParams.set("code", code);
  return new NextRequest(url, { headers: { cookie: `${stateCookie}=${expected}` } });
}
function expectCleared(response: Awaited<ReturnType<typeof GET>>) {
  expect(response.cookies.get(stateCookie)?.value).toBe("");
  expect(response.headers.get("set-cookie")).toContain("Expires=Thu, 01 Jan 1970 00:00:00 GMT");
}
beforeEach(() => {
  vi.clearAllMocks(); vi.mocked(isRateLimited).mockReturnValue(false);
  vi.stubEnv("NODE_ENV", "production"); vi.stubEnv("APP_URL", "https://portal.example");
  vi.stubEnv("AUTH_SECRET", "fixture-only-auth-secret-more-than-32-characters");
  vi.stubEnv("GITHUB_CLIENT_ID", "fixture-client"); vi.stubEnv("GITHUB_CLIENT_SECRET", "fixture-secret");
  vi.stubEnv("INITIAL_ADMIN_GITHUB_USER", "fixture-owner"); vi.stubEnv("ALLOWED_GITHUB_USERS", "fixture-user");
  vi.stubGlobal("fetch", fetchMock);
});
afterEach(() => { vi.unstubAllEnvs(); vi.unstubAllGlobals(); });
describe("OAuth callback state byte comparison", () => {
  it.each(["é", "☃", "a", "longer-state"])("refuses mismatched state %s without upstream calls or exceptions", async actual => {
    const response = await GET(request(actual, "b"));
    expect(response.status).toBe(307);
    expect(response.headers.get("location")).toBe("https://portal.example/?auth=failed");
    expect(fetchMock).not.toHaveBeenCalled(); expectCleared(response);
  });
  it("refuses different same-byte-length values before any OAuth exchange", async () => {
    const response = await GET(request("aa", "bb"));
    expect(response.headers.get("location")).toBe("https://portal.example/?auth=failed");
    expect(fetchMock).not.toHaveBeenCalled(); expectCleared(response);
  });
  it("valid matching ASCII state reaches configured OAuth and retains session/allowlist checks", async () => {
    fetchMock.mockResolvedValueOnce(Response.json({ access_token: "fixture-token" }))
      .mockResolvedValueOnce(Response.json({ login: "fixture-user" }));
    const response = await GET(request());
    expect(response.headers.get("location")).toBe("https://portal.example/dashboard");
    expect(fetchMock).toHaveBeenCalledTimes(2);
    expect(verifySessionToken(response.cookies.get(sessionCookieName())!.value)?.username).toBe("fixture-user");
    expectCleared(response);
  });
  it("matching state without configured OAuth fails unavailable without upstream calls", async () => {
    vi.stubEnv("GITHUB_CLIENT_SECRET", "");
    const response = await GET(request());
    expect(response.headers.get("location")).toBe("https://portal.example/?auth=unavailable");
    expect(fetchMock).not.toHaveBeenCalled(); expectCleared(response);
  });
  it("valid state never bypasses the user allowlist", async () => {
    fetchMock.mockResolvedValueOnce(Response.json({ access_token: "fixture-token" }))
      .mockResolvedValueOnce(Response.json({ login: "not-allowed" }));
    const response = await GET(request());
    expect(response.headers.get("location")).toBe("https://portal.example/?auth=forbidden");
    expect(response.cookies.get(sessionCookieName())).toBeUndefined(); expectCleared(response);
  });
  it("keeps rate-limit and missing-code failures before upstream work", async () => {
    vi.mocked(isRateLimited).mockReturnValueOnce(true);
    const limited = await GET(request());
    expect(limited.headers.get("location")).toBe("https://portal.example/?auth=rate-limited"); expectCleared(limited);
    const missing = await GET(request("matching-state", "matching-state", ""));
    expect(missing.headers.get("location")).toBe("https://portal.example/?auth=failed"); expectCleared(missing);
    expect(fetchMock).not.toHaveBeenCalled();
  });
});
