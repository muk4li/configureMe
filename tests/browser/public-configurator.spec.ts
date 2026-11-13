import { test, expect } from "@playwright/test";
import { readFile } from "node:fs/promises";
const sessionKey = "configureme:public-selection:v1";
const externalRequests: string[] = [];
test.beforeEach(async ({ context }) => {
  // Browser scenarios have no reason to contact vendors, GitHub or private infrastructure.
  externalRequests.length = 0;
  await context.route("**/*", route => {
    if (route.request().url().startsWith("http://127.0.0.1:3100/")) return route.continue();
    externalRequests.push(route.request().url());
    return route.abort();
  });
});
test.afterEach(() => { expect(externalRequests).toEqual([]); });
async function open(page: import("@playwright/test").Page) {
  await page.goto("/"); await expect(page.locator("#configurator")).toHaveAttribute("data-ready", "true");
}
test("anonymous profile combination and session edits survive reload and stay tab-local", async ({ page, context }) => {
  await open(page);
  await expect(page.getByRole("heading", { name: "Make it your computer." })).toBeVisible();
  await page.getByRole("checkbox", { name: "Developer toolkit", exact: true }).check();
  await expect(page.getByRole("checkbox", { name: "GitHub CLI", exact: true })).toBeChecked();
  await page.getByRole("checkbox", { name: "Visual Studio Code", exact: true }).uncheck();
  await page.locator("#configureGit").selectOption("false");
  await page.reload(); await expect(page.locator("#configurator")).toHaveAttribute("data-ready", "true");
  await expect(page.getByRole("checkbox", { name: "Developer toolkit", exact: true })).toBeChecked();
  await expect(page.getByRole("checkbox", { name: "Visual Studio Code", exact: true })).not.toBeChecked();
  await expect(page.locator("#configureGit")).toHaveValue("false");
  const independentTab = await context.newPage(); await open(independentTab);
  await expect(independentTab.getByRole("checkbox", { name: "Developer toolkit", exact: true })).not.toBeChecked();
});
test("shows option conflicts and never silently drops choices on a platform switch", async ({ page }) => {
  await open(page); await page.locator("#windows-target").selectOption("windows-server-2022");
  await page.getByRole("checkbox", { name: "Developer toolkit", exact: true }).check();
  await page.getByRole("checkbox", { name: "Server operations", exact: true }).check();
  await expect(page.locator("#configurator").getByRole("alert")).toContainText("Profiles disagree");
  await page.locator("#interactiveAuthentication").selectOption("false");
  await expect(page.locator("#configurator").getByRole("alert")).toHaveCount(0);
  await page.locator("#windows-target").selectOption("windows-11");
  await expect(page.getByRole("checkbox", { name: "Server operations", exact: true })).toBeChecked();
  await expect(page.locator("#configurator").getByRole("alert")).toContainText("unavailable for this target");
  await expect(page.getByRole("button", { name: "Export preview JSON" })).toBeDisabled();
});
test("required dependencies cannot be silently removed", async ({ page }) => {
  await open(page); await page.getByRole("button", { name: "Clear this selection" }).click();
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).check();
  // A required checkbox intentionally stays checked; assert the refusal below.
  await page.getByRole("checkbox", { name: "Git", exact: true }).click();
  await expect(page.locator("#configurator").getByRole("alert")).toContainText("git is required by github-cli");
  await expect(page.getByRole("checkbox", { name: "Git", exact: true })).toBeChecked();
  await page.getByRole("button", { name: "Undo git", exact: true }).click();
  await expect(page.locator("#configurator").getByRole("alert")).toHaveCount(0);
});
test("exports only server-validated non-executable JSON, never a bootstrap", async ({ page }) => {
  const calls: string[] = []; page.on("request", request => calls.push(request.url()));
  await open(page);
  const downloaded = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export preview JSON" }).click();
  const download = await downloaded;
  expect(download.suggestedFilename()).toBe("configureme-preview.json");
  const plan = JSON.parse(await readFile((await download.path())!, "utf8"));
  expect(plan).toMatchObject({ executable: false, valid: true, kind: "configureme-preview", source: { kind: "local-fixture" }, distribution: { enabled: false } });
  expect(calls.some(url => url.includes("/api/bootstrap"))).toBe(false);
  await expect(page.getByRole("status")).toContainText("Server validated");
});
test("discards tampered storage and works when storage is unavailable", async ({ page, context }) => {
  await page.addInitScript(key => sessionStorage.setItem(key, '{"command":"not-allowed"}'), sessionKey);
  await open(page); await expect(page.getByRole("status")).toContainText("discarded");
  const unavailable = await context.newPage();
  await unavailable.addInitScript(() => {
    Object.defineProperty(Storage.prototype, "getItem", { value() { throw new DOMException("Blocked", "SecurityError"); } });
    Object.defineProperty(Storage.prototype, "setItem", { value() { throw new DOMException("Blocked", "SecurityError"); } });
  });
  await open(unavailable);
  await expect(unavailable.getByRole("status")).toContainText("storage is unavailable");
  await unavailable.getByRole("checkbox", { name: "Developer toolkit", exact: true }).check();
  await expect(unavailable.getByRole("checkbox", { name: "GitHub CLI", exact: true })).toBeChecked();
});
test("handles empty upstream errors without raw JSON parser messages", async ({ page }) => {
  await open(page);
  await page.route("**/api/public/plan", route => route.fulfill({ status: 500, body: "" }));
  await page.getByRole("button", { name: "Validate plan on server" }).click();
  await expect(page.locator("#configurator").getByRole("alert")).toContainText("HTTP 500");
  await expect(page.locator("#configurator").getByRole("alert")).not.toContainText("JSON.parse");
});
test("a changed selection cannot download an earlier validated response", async ({ page }) => {
  await open(page);
  let release!: () => void;
  let started!: () => void;
  const gate = new Promise<void>(resolve => { release = resolve; });
  const arrived = new Promise<void>(resolve => { started = resolve; });
  await page.route("**/api/public/plan", async route => {
    started(); await gate;
    await route.fulfill({ response: await route.fetch() });
  });
  await page.getByRole("button", { name: "Export preview JSON" }).click();
  await arrived;
  await page.getByRole("checkbox", { name: "Developer toolkit", exact: true }).check();
  release();
  await expect(page.locator("#configurator").getByRole("alert")).toContainText("selection changed");
});
test("malformed successful responses receive a readable error", async ({ page }) => {
  await open(page);
  await page.route("**/api/public/plan", route => route.fulfill({ status: 200, contentType: "application/json", body: "{" }));
  await page.getByRole("button", { name: "Validate plan on server" }).click();
  await expect(page.locator("#configurator").getByRole("alert")).toContainText("server returned invalid JSON");
});
test("production HTTP boundaries keep anonymous planning separate from private routes", async ({ request }) => {
  expect((await request.get("/api/profiles")).status()).toBe(401);
  expect((await request.post("/api/bootstrap", { data: {} })).status()).toBe(401);
  expect((await request.get("/dashboard", { maxRedirects: 0 })).status()).toBe(307);
  expect((await request.post("/api/public/plan", { headers: { origin: "https://evil.invalid" }, data: {} })).status()).toBe(403);
  expect((await request.post("/api/public/plan", { headers: { origin: "http://127.0.0.1:3100" }, data: { command: "not-allowed" } })).status()).toBe(400);
});
for (const width of [375, 768, 1440]) test(`layout remains usable at ${width}px`, async ({ page }) => {
  await page.setViewportSize({ width, height: 900 }); await open(page);
  await expect(page.getByRole("button", { name: "Export preview JSON" })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  await page.screenshot({ path: test.info().outputPath(`public-${width}.png`), fullPage: true });
});
