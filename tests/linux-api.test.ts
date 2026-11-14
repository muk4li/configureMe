import { afterEach, beforeEach, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST } from "../src/app/api/linux/bundle/route";
import { getSession, isAllowedUser } from "../src/lib/auth";
import { createLinuxBundle } from "../src/lib/linux-bundle";
import { initialLinuxSelection } from "../src/lib/linux-planning";
vi.mock("../src/lib/auth", () => ({ getSession: vi.fn(), isAllowedUser: vi.fn() }));
vi.mock("../src/lib/linux-bundle", () => ({ createLinuxBundle: vi.fn() }));
vi.mock("../src/lib/rate-limit", () => ({ isRateLimited: vi.fn(() => false) }));
const request = (headers: Record<string,string> = {}, body: unknown = initialLinuxSelection) => new NextRequest("http://localhost:3000/api/linux/bundle", {
  method: "POST", headers: { host: "localhost:3000", origin: "http://localhost:3000", "content-type": "application/json", ...headers }, body: JSON.stringify(body),
});
beforeEach(() => {
  vi.clearAllMocks(); vi.stubEnv("CONFIGUREME_LOCAL_LINUX_DOWNLOADS", "1"); vi.stubEnv("APP_URL", "http://localhost:3000");
  vi.mocked(getSession).mockResolvedValue(undefined); vi.mocked(isAllowedUser).mockReturnValue(true);
  vi.mocked(createLinuxBundle).mockResolvedValue({ archive: Buffer.from("PK\x03\x04"), sha256: "a".repeat(64), sourceCommit: "b".repeat(40) });
});
afterEach(() => vi.unstubAllEnvs());
it("defaults closed and never enables anonymous executable downloads", async () => {
  vi.stubEnv("CONFIGUREME_LOCAL_LINUX_DOWNLOADS", ""); expect((await POST(request())).status).toBe(404);
  vi.stubEnv("CONFIGUREME_LOCAL_LINUX_DOWNLOADS", "1"); expect((await POST(request())).status).toBe(401);
  expect(createLinuxBundle).not.toHaveBeenCalled();
});
it("refuses malicious host/origin/cross-site and non-loopback application configuration", async () => {
  for (const headers of [{ host: "evil.invalid" }, { origin: "https://evil.invalid" }, { "sec-fetch-site": "cross-site" }, { origin: "" }] as Record<string,string>[])
    expect((await POST(request(headers))).status).toBe(403);
  vi.stubEnv("APP_URL", "https://public.example.invalid"); expect((await POST(request())).status).toBe(403);
  expect(createLinuxBundle).not.toHaveBeenCalled();
});
it("requires current allowlist and rejects injected selection fields", async () => {
  vi.mocked(getSession).mockResolvedValue({ username: "synthetic-user", role: "user", expiresAt: Date.now()+10000 });
  vi.mocked(isAllowedUser).mockReturnValue(false); expect((await POST(request())).status).toBe(401);
  vi.mocked(isAllowedUser).mockReturnValue(true); expect((await POST(request({}, { ...initialLinuxSelection, command: "bad" }))).status).toBe(422);
  expect(createLinuxBundle).not.toHaveBeenCalled();
});
it("serves authenticated local development bytes without claiming release trust", async () => {
  vi.mocked(getSession).mockResolvedValue({ username: "synthetic-user", role: "user", expiresAt: Date.now()+10000 });
  const response = await POST(request()); expect(response.status).toBe(200);
  expect(response.headers.get("cache-control")).toBe("private, no-store");
  expect(response.headers.get("content-type")).toBe("application/zip");
});
