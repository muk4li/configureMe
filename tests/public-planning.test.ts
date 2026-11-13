import { describe, expect, it } from "vitest";
import { createPlanRateLimiter } from "../src/lib/public-rate-limit";
import { publicCatalog, publicSnapshot, resolvePublicPlan, selectionSchema, validatePublicSnapshot } from "../src/lib/public-planning";
import { freshSelection, maxSessionBytes, restorePublicSelection } from "../src/lib/public-session";

const selection = () => ({ ...freshSelection(), profileIds: [] as string[] });
describe("public fixture planning", () => {
  it("validates the complete fixture and rejects any invalid record, reference or action", () => {
    expect(publicSnapshot.sourceKind).toBe("local-fixture");
    const broken = structuredClone(publicSnapshot);
    broken.profiles[0].packages.push("untrusted-package");
    expect(() => validatePublicSnapshot(broken)).toThrow();
    expect(() => validatePublicSnapshot({ ...publicSnapshot, command: "run" })).toThrow();
    expect(() => validatePublicSnapshot({ ...publicSnapshot, profiles: [...publicSnapshot.profiles, publicSnapshot.profiles[0]] })).toThrow();
  });
  it("combines profiles independently of order, deduplicates and retains sources", () => {
    const input = { ...selection(), profileIds: ["essentials", "developer"] };
    const result = resolvePublicPlan(input);
    expect(result.valid).toBe(true);
    expect(result).toEqual(resolvePublicPlan({ ...input, profileIds: [...input.profileIds].reverse() }));
    expect(new Set(result.packages.map(item => item.id)).size).toBe(result.packages.length);
    expect(result.packages.find(item => item.id === "git")).toMatchObject({ requestedBy: ["essentials"], requiredBy: ["github-cli"] });
  });
  it("allows zero profiles and individual additions", () => {
    expect(resolvePublicPlan(selection()).packages).toEqual([]);
    expect(resolvePublicPlan({ ...selection(), addedPackageIds: ["github-cli"] }).packages.map(item => item.id)).toEqual(["git", "github-cli"]);
  });
  it("removes ordinary packages but refuses hidden dependency removal", () => {
    const result = resolvePublicPlan({ ...freshSelection(), removedPackageIds: ["vscode"] });
    expect(result.valid).toBe(true); expect(result.packages.some(item => item.id === "vscode")).toBe(false);
    expect(result.overrides.removedPackageIds).toEqual(["vscode"]);
    const blocked = resolvePublicPlan({ ...selection(), addedPackageIds: ["github-cli"], removedPackageIds: ["git"] });
    expect(blocked.issues.some(item => item.code === "REQUIRED_REMOVAL")).toBe(true);
    expect(blocked.packages.map(item => item.id)).toEqual(["git", "github-cli"]);
    expect(resolvePublicPlan({ ...selection(), profileIds: ["developer"], removedPackageIds: ["github-cli", "git"] }).valid).toBe(true);
  });
  it("reports profile option conflicts and lets explicit supported session values resolve them", () => {
    const input = { ...selection(), target: "windows-server-2022", profileIds: ["developer", "server-operations"] };
    expect(resolvePublicPlan(input).issues.map(item => item.code)).toContain("OPTIONS_CONFLICT");
    const resolved = resolvePublicPlan({ ...input, options: { interactiveAuthentication: false } });
    expect(resolved.valid).toBe(true);
    expect(resolved.options.interactiveAuthentication).toBe(false);
    expect(resolved.optionSources.interactiveAuthentication).toEqual(["session"]);
    expect(resolvePublicPlan(selection()).options).toEqual({});
  });
  it("never silently drops incompatible profiles or unavailable packages on target changes", () => {
    const input = { ...selection(), profileIds: ["server-operations"] };
    expect(resolvePublicPlan(input).issues.map(item => item.code)).toEqual(expect.arrayContaining(["PROFILE_TARGET", "PACKAGE_TARGET"]));
    expect(resolvePublicPlan({ ...input, target: "windows-server-2022" }).valid).toBe(true);
    expect(resolvePublicPlan({ ...selection(), addedPackageIds: ["docker-desktop"] }).valid).toBe(false);
  });
  it("separates manual/web/detection-only strategies from automatic installation", () => {
    const plan = resolvePublicPlan({ ...selection(), target: "windows-server-2022", profileIds: ["optional-tools"] });
    expect(plan.valid).toBe(true);
    expect(plan.packages.map(item => item.mode).sort()).toEqual(["detection-only", "manual", "web-fallback"]);
    expect(plan.executable).toBe(false); expect(plan.distribution.enabled).toBe(false);
    expect(plan.source.sourceCommit).toBeNull();
  });
  it("rejects unknown profile, addition and removal IDs", () => {
    for (const input of [{ ...selection(), profileIds: ["missing"] }, { ...selection(), addedPackageIds: ["missing"] }, { ...selection(), removedPackageIds: ["missing"] }])
      expect(resolvePublicPlan(input).valid).toBe(false);
  });
  it("detects cycles and resolves transitive dependencies from trusted catalog code", () => {
    const definitions = structuredClone(publicCatalog);
    definitions.find(item => item.id === "git")!.dependencies = ["vscode"];
    const input = { ...selection(), addedPackageIds: ["github-cli"] };
    expect(resolvePublicPlan(input, publicSnapshot.profiles, definitions).packages.map(item => item.id)).toEqual(["vscode", "git", "github-cli"]);
    definitions.find(item => item.id === "vscode")!.dependencies = ["github-cli"];
    expect(resolvePublicPlan(input, publicSnapshot.profiles, definitions).issues.map(item => item.code)).toContain("DEPENDENCY_CYCLE");
  });
  it("rejects injected actions, unknown options, wrong architecture/OS and duplicate inputs", () => {
    for (const extra of [{ command: "whoami" }, { installerUrl: "https://evil.invalid" }, { options: { vpnKey: "secret" } },
      { target: "linux" }, { architecture: "arm64" }, { snapshotId: "arbitrary-github-ref" }, { profileIds: ["developer", "developer"] },
      { addedPackageIds: ["git"], removedPackageIds: ["git"] }, { addedPackageIds: Array(51).fill("git") }])
      expect(selectionSchema.safeParse({ ...selection(), ...extra }).success).toBe(false);
  });
  it("does not mutate session inputs and produces a repeatable non-executable export", () => {
    const input = freshSelection(); const before = structuredClone(input);
    expect(resolvePublicPlan(input)).toEqual(resolvePublicPlan(input)); expect(input).toEqual(before);
    expect(resolvePublicPlan(input).kind).toBe("configureme-preview");
  });
});
describe("untrusted browser storage", () => {
  it("restores supported session changes, including visible conflicts", () => {
    const input = { ...selection(), target: "windows-server-2022", profileIds: ["developer", "server-operations"] };
    expect(restorePublicSelection(JSON.stringify(input))).toEqual(input);
  });
  it("discards corrupt, stale, unknown, oversized and injected storage", () => {
    for (const saved of [null, "{", "x".repeat(maxSessionBytes + 1), JSON.stringify({ ...selection(), schemaVersion: 2 }),
      JSON.stringify({ ...selection(), profileIds: ["missing"] }), JSON.stringify({ ...selection(), token: "synthetic" })])
      expect(restorePublicSelection(saved)).toBeUndefined();
  });
});

it("bounds anonymous work with a dedicated rolling bucket independent of identity", () => {
  const limited = createPlanRateLimiter();
  for (let i = 0; i < 60; i++) expect(limited(1000)).toBe(false);
  expect(limited(1000)).toBe(true);
  expect(limited(60_999)).toBe(true);
  expect(limited(61_000)).toBe(false);
});
