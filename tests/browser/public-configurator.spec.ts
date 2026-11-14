import { test, expect } from "@playwright/test";
import { parseSetupPlan } from "../../src/lib/setup-plan";
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
  await expect(page.getByRole("alert", { name: "Incompatible selected tools" })).toContainText(".NET 10 SDK");
  await expect(page.locator(".category-tools").getByRole("checkbox", { name: ".NET 10 SDK", exact: true })).toHaveCount(0);
  await expect(page.getByRole("button", { name: "Export preview JSON" })).toBeDisabled();
});
test("required dependencies stay checked without creating exclusions or API conflicts", async ({ page }) => {
  await open(page); await page.getByRole("button", { name: "Clear this selection" }).click();
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).check();
  const git = page.getByRole("checkbox", { name: "Git", exact: true });
  await expect(git).toBeChecked(); await expect(git).toBeDisabled();
  await expect(page.locator('[data-package-id="git"]')).toContainText("Required for GitHub CLI");
  // Attempt the physical click despite Playwright's disabled-control guard;
  // the native disabled checkbox must still leave intent and payload unchanged.
  await page.locator('[data-package-id="git"] label').click({ force: true });
  const stored = await page.evaluate(key => JSON.parse(sessionStorage.getItem(key)!), sessionKey);
  expect(stored.removedPackageIds).not.toContain("git");
  await expect(page.locator("#configurator").getByRole("alert")).toHaveCount(0);
  const result = page.waitForResponse(response => response.url().endsWith("/api/public/plan"));
  await page.getByRole("button", { name: "Validate plan on server" }).click();
  const response = await result;
  expect(response.request().postDataJSON().removedPackageIds).not.toContain("git");
  expect(await response.json()).toMatchObject({ valid: true });
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).uncheck();
  await expect(git).not.toBeChecked();
});
test("explicit parent selection visibly restores a previously excluded dependency", async ({ page }) => {
  await open(page);
  await page.getByRole("checkbox", { name: "Git", exact: true }).uncheck();
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).check();
  await expect(page.getByRole("checkbox", { name: "Git", exact: true })).toBeChecked();
  await expect(page.locator(".dependency-selection-note")).toContainText("previous exclusions were cleared");
  await expect(page.locator("#configurator").getByRole("alert")).toHaveCount(0);
  const response = page.waitForResponse(response => response.url().endsWith("/api/public/plan"));
  await page.getByRole("button", { name: "Validate plan on server" }).click();
  expect(await (await response).json()).toMatchObject({ valid: true });
});
test("a separate direct choice survives removal of the parent and reload", async ({ page }) => {
  await open(page); await page.getByRole("button", { name: "Clear this selection" }).click();
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).check();
  await page.getByRole("button", { name: "Also keep Git separately", exact: true }).click();
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).uncheck();
  await page.reload(); await expect(page.locator("#configurator")).toHaveAttribute("data-ready", "true");
  await expect(page.getByRole("checkbox", { name: "Git", exact: true })).toBeChecked();
  await expect(page.getByRole("checkbox", { name: "Git", exact: true })).toBeEnabled();
  await expect(page.locator('[data-package-id="git"]')).toContainText("Selected by you");
});
test("shared dependency remains for another parent or a profile", async ({ page }) => {
  await open(page); await page.getByRole("button", { name: "Clear this selection" }).click();
  await page.locator("#windows-target").selectOption("windows-server-2022");
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).check();
  await page.getByRole("checkbox", { name: "GitHub Copilot Desktop", exact: true }).check();
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).uncheck();
  await expect(page.getByRole("checkbox", { name: "Git", exact: true })).toBeChecked();
  await expect(page.locator('[data-package-id="git"]')).toContainText("Required for GitHub Copilot Desktop");
  await page.getByRole("checkbox", { name: "Everyday essentials", exact: true }).check();
  await page.getByRole("checkbox", { name: "GitHub Copilot Desktop", exact: true }).uncheck();
  await expect(page.getByRole("checkbox", { name: "Git", exact: true })).toBeChecked();
  await expect(page.locator('[data-package-id="git"]')).toContainText("Everyday essentials");
});
test("legacy dependency exclusions remain visible and server-refused until explicitly repaired", async ({ page }) => {
  await page.addInitScript(key => sessionStorage.setItem(key, JSON.stringify({ schemaVersion: 1, snapshotId: "local-fixture-v1", architecture: "x64", target: "windows-11", profileIds: [], addedPackageIds: ["github-cli"], removedPackageIds: ["git"], options: {} })), sessionKey);
  await open(page);
  await expect(page.locator("#configurator").getByRole("alert")).toContainText("git is required by github-cli");
  await expect(page.getByRole("button", { name: "Export preview JSON" })).toBeDisabled();
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
test("target filtering hides empty categories and preserves incompatible choices visibly", async ({ page, request }) => {
  await open(page);
  await expect(page.locator(".category-tools").getByRole("checkbox", { name: ".NET 10 SDK", exact: true })).toHaveCount(0);
  await expect(page.locator(".package-category legend").filter({ hasText: "Browsers" })).toHaveCount(0);
  const initialCount = await page.locator(".category-tools input").count();
  await expect(page.getByTestId("visible-catalog-count")).toHaveText(`${initialCount} available tools for this target`);
  await page.locator("#windows-target").selectOption("windows-server-2022");
  await page.getByRole("checkbox", { name: ".NET 10 SDK", exact: true }).check();
  await expect(page.locator(".package-category legend").filter({ hasText: "Browsers" })).toHaveCount(1);
  await page.locator("#windows-target").selectOption("windows-11");
  await expect(page.getByRole("alert", { name: "Incompatible selected tools" })).toContainText(".NET 10 SDK");
  await expect(page.getByRole("button", { name: "Export preview JSON" })).toBeDisabled();
  const payload = await page.evaluate(key => JSON.parse(sessionStorage.getItem(key)!), sessionKey);
  expect(payload.addedPackageIds).toContain("dotnet-10-sdk");
  const response = await request.post("/api/public/plan", { headers: { origin: "http://127.0.0.1:3100" }, data: payload });
  expect(await response.json()).toMatchObject({ valid: false });
  await page.getByRole("button", { name: "Remove .NET 10 SDK", exact: true }).click();
  await expect(page.getByRole("alert", { name: "Incompatible selected tools" })).toHaveCount(0);
});
test("existing preferences explain scope, defaults and individual choices without acting on the computer", async ({ page }) => {
  await open(page);
  await expect(page.getByRole("heading", { name: "Settings for this plan" })).toBeVisible();
  await expect(page.locator("#configureGit-help")).toContainText("No name, email or Git configuration is changed");
  await page.locator("#configureGit").selectOption("true");
  await expect(page.getByTestId("preference-configureGit")).toContainText("Your choice: include reminder");
  await page.reload(); await expect(page.locator("#configurator")).toHaveAttribute("data-ready", "true");
  await expect(page.locator("#configureGit")).toHaveValue("true");
  const response = page.waitForResponse(response => response.url().endsWith("/api/public/plan"));
  await page.getByRole("button", { name: "Validate plan on server" }).click();
  expect(await (await response).json()).toMatchObject({ valid: true, options: { configureGit: true }, optionSources: { configureGit: ["session"] } });
  await page.getByRole("checkbox", { name: "Git", exact: true }).uncheck();
  await page.getByRole("checkbox", { name: "Visual Studio Code", exact: true }).uncheck();
  await expect(page.getByRole("heading", { name: "Settings for this plan" })).toHaveCount(0);
  await expect(page.locator(".public-summary")).toContainText("Saved choices for tools not selected");
  expect(await page.evaluate(key => JSON.parse(sessionStorage.getItem(key)!).options.configureGit, sessionKey)).toBe(true);
  await page.getByRole("checkbox", { name: "Python", exact: true }).check();
  await expect(page.getByRole("heading", { name: "Settings for this plan" })).toHaveCount(0);
});
test("a large server plan keeps sticky actions reachable without overlapping the viewport", async ({ page }) => {
  await page.setViewportSize({ width: 1280, height: 720 }); await open(page);
  await page.locator("#windows-target").selectOption("windows-server-2022");
  for (const checkbox of await page.locator(".category-tools input").all()) {
    if (!await checkbox.isChecked() && await checkbox.isEnabled()) await checkbox.check();
  }
  await page.locator(".software-catalog").scrollIntoViewIfNeeded();
  const button = page.getByRole("button", { name: "Export preview JSON" });
  await button.scrollIntoViewIfNeeded();
  const cart = await page.locator(".public-summary").boundingBox(); const action = await button.boundingBox();
  expect(cart!.y).toBeGreaterThanOrEqual(0); expect(cart!.y + cart!.height).toBeLessThanOrEqual(721);
  expect(action!.y).toBeGreaterThanOrEqual(cart!.y); expect(action!.y + action!.height).toBeLessThanOrEqual(cart!.y + cart!.height);
  const response = page.waitForResponse(response => response.url().endsWith("/api/public/plan"));
  await page.getByRole("button", { name: "Validate plan on server" }).click();
  expect(await (await response).json()).toMatchObject({ valid: true });
});
for (const width of [375, 768, 1280, 1440, 1920]) test(`layout remains usable at ${width}px`, async ({ page }) => {
  await page.setViewportSize({ width, height: 900 }); await open(page);
  await expect(page.getByRole("button", { name: "Export preview JSON" })).toBeVisible();
  expect(await page.evaluate(() => document.documentElement.scrollWidth <= window.innerWidth)).toBe(true);
  const layout = await page.evaluate(() => {
    const main = document.querySelector(".configuration-main")!.getBoundingClientRect();
    const cart = document.querySelector(".public-summary")!.getBoundingClientRect();
    const rows = [...document.querySelectorAll(".category-tools")].map(group => [...group.children].map(child => {
      const rect = child.getBoundingClientRect(); return { x: rect.x, y: rect.y, width: rect.width, height: rect.height };
    }));
    return { main: { top: main.top, right: main.right }, cart: { top: cart.top, left: cart.left }, rows, gridWidth: document.querySelector(".configuration-grid")!.getBoundingClientRect().width };
  });
  if (width >= 1280) {
    expect(Math.abs(layout.main.top - layout.cart.top)).toBeLessThan(2);
    expect(layout.cart.left).toBeGreaterThan(layout.main.right);
    const tools = layout.rows.find(rows => rows.length >= 2)!;
    expect(Math.abs(tools[0].y - tools[1].y)).toBeLessThan(2);
    expect(tools[1].x).toBeGreaterThanOrEqual(tools[0].x + tools[0].width);
    if (width === 1920) expect(layout.gridWidth / width).toBeGreaterThan(.72);
    await page.locator(".software-catalog").scrollIntoViewIfNeeded();
    const sticky = await page.locator(".public-summary").boundingBox();
    expect(sticky!.y).toBeGreaterThanOrEqual(0); expect(sticky!.y + sticky!.height).toBeLessThanOrEqual(901);
  } else {
    const tools = layout.rows.find(rows => rows.length >= 2)!;
    expect(Math.abs(tools[0].x - tools[1].x)).toBeLessThan(2);
    expect(tools[1].y).toBeGreaterThanOrEqual(tools[0].y + tools[0].height);
  }
  const exportButton = page.getByRole("button", { name: "Export preview JSON" });
  await exportButton.scrollIntoViewIfNeeded();
  const buttonBox = await exportButton.boundingBox();
  expect(buttonBox!.x).toBeGreaterThanOrEqual(0); expect(buttonBox!.x + buttonBox!.width).toBeLessThanOrEqual(width);
  const actionBoxes = await page.locator(".preview-actions button").evaluateAll(buttons => buttons.map(button => ({ top: button.getBoundingClientRect().top, bottom: button.getBoundingClientRect().bottom })));
  expect(actionBoxes[0].bottom).toBeLessThanOrEqual(actionBoxes[1].top);
  const iconSizes = await page.locator(".product-icon").evaluateAll(icons => icons.map(icon => ({ width: icon.getBoundingClientRect().width, height: icon.getBoundingClientRect().height })));
  expect(iconSizes.every(size => size.width === 26 && size.height === 26)).toBe(true);
  await expect(page.locator('[data-package-id="git"] svg[data-icon="product"]')).toHaveCount(1);
  await expect(page.locator('[data-package-id="vscode"] svg[data-icon="neutral"]')).toHaveCount(1);
  await page.evaluate(() => { document.querySelector(".public-summary")!.scrollTop = 0; window.scrollTo({ top: 0, behavior: "instant" }); });
  await expect.poll(() => page.evaluate(() => window.scrollY)).toBe(0);
  if (width >= 1280) {
    const topCart = await page.locator(".public-summary").boundingBox();
    const topMain = await page.locator(".configuration-main").boundingBox();
    expect(Math.abs(topCart!.y - topMain!.y)).toBeLessThan(2);
  }
  await page.screenshot({ path: test.info().outputPath(`public-${width}-viewport.png`) });
  await page.screenshot({ path: test.info().outputPath(`public-${width}.png`), fullPage: true });
});

test("exports server-reviewed setup JSON as a separate native dry-run contract", async ({ page }) => {
  await open(page);
  await page.getByRole("button", { name: "Clear this selection" }).click();
  await page.locator("#windows-target").selectOption("windows-server-2022");
  await page.getByRole("checkbox", { name: "GitHub CLI", exact: true }).check();
  const responsePromise = page.waitForResponse(response => response.url().endsWith("/api/public/plan?export=setup-plan-v1"));
  const downloadPromise = page.waitForEvent("download");
  await page.getByRole("button", { name: "Export setup plan v1", exact: true }).click();
  const response = await responsePromise;
  expect(response.status()).toBe(200);
  const download = await downloadPromise;
  expect(download.suggestedFilename()).toBe("configureme-setup-plan.v1.json");
  const bytes = await readFile((await download.path())!);
  const plan = parseSetupPlan(bytes);
  expect(plan.authorization).toBe("none");
  expect(plan.packages.map(item => item.id)).toEqual(["git", "github-cli"]);
  expect(plan).toEqual(await response.json());
  await expect(page.getByRole("button", { name: "Export preview JSON", exact: true })).toBeEnabled();
});
