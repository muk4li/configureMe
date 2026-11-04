import { beforeEach, describe, expect, it, vi } from "vitest";
import { createHmac } from "node:crypto";
import { createSessionToken, verifySessionToken } from "../src/lib/auth";
import { getGitHubCallbackUrl, isExpectedRequestOrigin } from "../src/lib/oauth";

describe("signed sessions", () => {
  beforeEach(() => {
    process.env.AUTH_SECRET = "test-only-auth-secret-that-is-long-enough";
  });

  it("accepts a valid session and rejects a modified token", () => {
    const token = createSessionToken("test-user", "user");
    expect(verifySessionToken(token)?.username).toBe("test-user");
    expect(verifySessionToken(`${token.slice(0, -1)}x`)).toBeUndefined();
  });

  it("rejects malformed, expired, and invalid-identity claims", () => {
    expect(verifySessionToken("not-a-token")).toBeUndefined();

    const payload = Buffer.from(JSON.stringify({
      username: "test-user",
      role: "user",
      expiresAt: Date.now() - 1,
    })).toString("base64url");
    const signature = createHmac("sha256", process.env.AUTH_SECRET!).update(payload).digest("base64url");
    expect(verifySessionToken(`${payload}.${signature}`)).toBeUndefined();
  });

  it("requires a configured HTTPS origin for production OAuth", () => {
    vi.stubEnv("NODE_ENV", "production");
    delete process.env.APP_URL;
    expect(getGitHubCallbackUrl("https://portal.example")).toBeUndefined();
    process.env.APP_URL = "http://portal.example";
    expect(getGitHubCallbackUrl("https://portal.example")).toBeUndefined();
    process.env.APP_URL = "https://portal.example";
    expect(getGitHubCallbackUrl("https://internal.example")).toBe(
      "https://portal.example/api/auth/github/callback",
    );
    vi.unstubAllEnvs();
    delete process.env.APP_URL;
  });

  it("checks the browser origin against the public origin behind a production proxy", () => {
    vi.stubEnv("NODE_ENV", "production");
    vi.stubEnv("APP_URL", "https://portal.example");
    expect(isExpectedRequestOrigin("https://portal.example", "http://internal:3000")).toBe(true);
    expect(isExpectedRequestOrigin("https://attacker.example", "http://internal:3000")).toBe(false);
    vi.unstubAllEnvs();
    delete process.env.APP_URL;
  });
});
