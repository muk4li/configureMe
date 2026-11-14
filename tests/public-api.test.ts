import { afterEach, beforeEach, describe, expect, it, vi } from "vitest";
import { NextRequest } from "next/server";
import { POST } from "../src/app/api/public/plan/route";
import { POST as bootstrap } from "../src/app/api/bootstrap/route";
import { GET as privateProfiles } from "../src/app/api/profiles/route";
import { getSession } from "../src/lib/auth";
import { validateSetupPlan } from "../src/lib/setup-plan";
import { freshSelection } from "../src/lib/public-session";
import { isPublicPlanRateLimited } from "../src/lib/public-rate-limit";
import { PublicInputError, readPublicJson } from "../src/lib/public-request";
vi.mock("../src/lib/public-rate-limit", () => ({ isPublicPlanRateLimited: vi.fn(() => false) }));
vi.mock("../src/lib/auth", () => ({ getSession: vi.fn(async () => undefined) }));
const url = "http://localhost:3000/api/public/plan";
function request(body: unknown = freshSelection(), headers: Record<string, string> = {}) {
  return new NextRequest(url, { method: "POST", headers: { origin: "http://localhost:3000", "content-type": "application/json", ...headers }, body: JSON.stringify(body) });
}
beforeEach(() => { vi.clearAllMocks(); vi.stubEnv("APP_URL", "http://localhost:3000"); vi.mocked(isPublicPlanRateLimited).mockReturnValue(false); });
afterEach(() => { vi.unstubAllEnvs(); });
describe("bounded anonymous preview API", () => {
  it("exports a distinct server-resolved setup contract without auth or executable distribution", async () => {
    const body = { ...freshSelection(), target: "windows-server-2022", profileIds: [], addedPackageIds: ["github-cli"] };
    const exportRequest = (input: unknown) => new NextRequest(`${url}?export=setup-plan-v1`, {
      method: "POST", headers: { origin: "http://localhost:3000", "content-type": "application/json" }, body: JSON.stringify(input),
    });
    const response = await POST(exportRequest(body));
    expect(response.status).toBe(200);
    expect(response.headers.get("cache-control")).toBe("no-store");
    const plan = validateSetupPlan(await response.json());
    expect(plan.authorization).toBe("none");
    expect(plan.packages.map(item => item.id)).toEqual(["git", "github-cli"]);
    expect(getSession).not.toHaveBeenCalled();
    expect((await POST(exportRequest({ ...body, removedPackageIds: ["git"] }))).status).toBe(422);
    expect((await POST(exportRequest({ ...body, command: "arbitrary" }))).status).toBe(400);
    expect((await POST(exportRequest({ ...body, addedPackageIds: ["unknown"] }))).status).toBe(422);
  });
  it("plans without cookies, OAuth or private provider access and never emits executable content", async () => {
    const response = await POST(request());
    expect(response.status).toBe(200); expect(response.headers.get("cache-control")).toBe("no-store");
    expect(await response.json()).toMatchObject({ valid: true, kind: "configureme-preview", executable: false, distribution: { enabled: false } });
    expect(getSession).not.toHaveBeenCalled();
  });
  it("does not grant anonymous access to protected profiles or ZIP generation", async () => {
    expect((await bootstrap(request())).status).toBe(401);
    expect((await privateProfiles()).status).toBe(401);
  });
  it("rejects cross-origin, absent Origin and cross-site requests", async () => {
    for (const headers of [{ origin: "https://evil.invalid" }, { origin: "" }, { "sec-fetch-site": "cross-site" }] as Record<string, string>[])
      expect((await POST(request(freshSelection(), headers))).status).toBe(403);
  });
  it("rejects large declared or streamed bodies, bad media types and malformed JSON", async () => {
    expect((await POST(request({}, { "content-length": "999999" }))).status).toBe(413);
    expect((await POST(request({}, { "content-type": "text/plain" }))).status).toBe(415);
    const raw = (body: string) => new NextRequest(url, { method: "POST", headers: { origin: "http://localhost:3000", "content-type": "application/json" }, body });
    expect((await POST(raw(" ".repeat(8193)))).status).toBe(413);
    expect((await POST(raw("{"))).status).toBe(400);
  });
  it("rejects unknown payload fields and recomputes semantic errors instead of trusting client valid flags", async () => {
    expect((await POST(request({ ...freshSelection(), valid: true, packages: ["untrusted"] }))).status).toBe(400);
    const response = await POST(request({ ...freshSelection(), profileIds: ["missing"] }));
    expect(await response.json()).toMatchObject({ valid: false, issues: [{ code: "UNKNOWN_PROFILE" }] });
  });
  it("still refuses an injected dependency exclusion even though normal UI actions prevent it", async () => {
    const response = await POST(request({ ...freshSelection(), profileIds: [], addedPackageIds: ["github-cli"], removedPackageIds: ["git"] }));
    const plan = await response.json();
    expect(plan.valid).toBe(false); expect(plan.executable).toBe(false);
    expect(plan.issues.map((issue: { code: string }) => issue.code)).toContain("REQUIRED_REMOVAL");
  });
  it("returns bounded rate-limit errors before doing body work", async () => {
    vi.mocked(isPublicPlanRateLimited).mockReturnValue(true);
    const response = await POST(request());
    expect(response.status).toBe(429); expect(response.headers.get("retry-after")).toBe("60");
  });
  it("bounds concurrent bodies and releases the capacity after every response", async () => {
    const controllers: ReadableStreamDefaultController<Uint8Array>[] = [];
    const pending = Array.from({ length: 4 }, () => POST(new NextRequest(url, {
      method: "POST", headers: { origin: "http://localhost:3000", "content-type": "application/json" },
      body: new ReadableStream({ start(controller) { controllers.push(controller); } }), duplex: "half",
    } as ConstructorParameters<typeof NextRequest>[1])));
    expect((await POST(request())).status).toBe(503);
    controllers.forEach(controller => { controller.enqueue(new TextEncoder().encode(JSON.stringify(freshSelection()))); controller.close(); });
    expect((await Promise.all(pending)).map(response => response.status)).toEqual([200, 200, 200, 200]);
    expect((await POST(request())).status).toBe(200);
  });
  it("times out a stalled input without waiting indefinitely", async () => {
    const stalled = new Request(url, { method: "POST", headers: { "content-type": "application/json" }, body: new ReadableStream(), duplex: "half" } as RequestInit);
    await expect(readPublicJson(stalled, 8192, 5)).rejects.toMatchObject<Partial<PublicInputError>>({ status: 408 });
  });
});
