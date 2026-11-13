import { describe, expect, it } from "vitest";
import { freshSelection } from "../src/lib/public-session";
import { publicCatalog, resolvePublicPlan } from "../src/lib/public-planning";
import { catalogGroupsFor, optionIsRelevant, optionNeedsResolution, setPackageSelected } from "../src/lib/public-selection";
const empty = () => ({ ...freshSelection(), profileIds: [] as string[] });
describe("direct, profile and dependency intent", () => {
  it("cannot turn a required Git checkbox into a hidden exclusion", () => {
    const selected = setPackageSelected(empty(), "github-cli", true);
    const clickedGit = setPackageSelected(selected, "git", false);
    expect(clickedGit).toEqual(selected);
    expect(clickedGit.removedPackageIds).not.toContain("git");
    expect(resolvePublicPlan(clickedGit)).toMatchObject({ valid: true, packages: [{ id: "git", requiredBy: ["github-cli"] }, { id: "github-cli" }] });
    expect(resolvePublicPlan(setPackageSelected(clickedGit, "github-cli", false)).packages).toEqual([]);
  });
  it("keeps Git when directly selected before or after its parent", () => {
    for (const order of [["git", "github-cli"], ["github-cli", "git"]]) {
      let state = empty();
      for (const id of order) state = setPackageSelected(state, id, true);
      state = setPackageSelected(state, "github-cli", false);
      expect(resolvePublicPlan(state).packages.map(item => item.id)).toEqual(["git"]);
      expect(state.addedPackageIds).toEqual(["git"]);
    }
  });
  it("retains another profile's request after removing the parent", () => {
    const state = setPackageSelected(freshSelection(), "github-cli", true);
    const plan = resolvePublicPlan(setPackageSelected(state, "github-cli", false));
    expect(plan.valid).toBe(true);
    expect(plan.packages.find(item => item.id === "git")?.requestedBy).toEqual(["essentials"]);
  });
  it("tracks multiple parents until the last request disappears", () => {
    let state: ReturnType<typeof freshSelection> = { ...empty(), target: "windows-server-2022" };
    state = setPackageSelected(state, "github-cli", true);
    state = setPackageSelected(state, "github-copilot-desktop", true);
    expect(resolvePublicPlan(state).packages.find(item => item.id === "git")?.requiredBy).toEqual(["github-cli", "github-copilot-desktop"]);
    state = setPackageSelected(state, "github-cli", false);
    expect(resolvePublicPlan(state).packages.find(item => item.id === "git")?.requiredBy).toEqual(["github-copilot-desktop"]);
    state = setPackageSelected(state, "github-copilot-desktop", false);
    expect(resolvePublicPlan(state).packages).toEqual([]);
  });
  it("preserves server rejection for old or injected dependency exclusions", () => {
    const state = { ...empty(), addedPackageIds: ["github-cli"], removedPackageIds: ["git"] };
    expect(resolvePublicPlan(state).valid).toBe(false);
    expect(resolvePublicPlan(setPackageSelected(state, "git", false)).valid).toBe(false);
    expect(resolvePublicPlan(setPackageSelected(state, "git", true)).valid).toBe(true);
  });
  it("does not silently discard changes when a target makes them incompatible", () => {
    const state = setPackageSelected({ ...empty(), target: "windows-server-2022" }, "dotnet-10-sdk", true);
    const switched = { ...state, target: "windows-11" as const };
    expect(resolvePublicPlan(switched).valid).toBe(false);
    expect(setPackageSelected(switched, "dotnet-10-sdk", true)).toEqual(switched);
    expect(resolvePublicPlan(setPackageSelected(switched, "dotnet-10-sdk", false)).valid).toBe(true);
  });
});
describe("target catalog and existing preference context", () => {
  it("hides unavailable entries and empty categories for Windows 11", () => {
    const groups = catalogGroupsFor("windows-11");
    expect(groups.every(group => group.packages.length > 0)).toBe(true);
    expect(groups.flatMap(group => group.packages.map(item => item.id))).toEqual(expect.arrayContaining(["git", "github-cli", "vscode"]));
    expect(groups.flatMap(group => group.packages).some(item => item.id === "dotnet-10-sdk")).toBe(false);
    expect(groups.map(group => group.category)).not.toContain("Browsers");
  });
  it("retains all declared Server strategies including clearly labelled manual and detection modes", () => {
    expect(catalogGroupsFor("windows-server-2022").flatMap(group => group.packages).length).toBe(publicCatalog.length);
  });
  it("shows only relevant hints, but never hides a conflict that must be resolved", () => {
    const plan = resolvePublicPlan(empty());
    expect(optionIsRelevant("configureGit", plan)).toBe(false);
    expect(optionIsRelevant("interactiveAuthentication", plan)).toBe(false);
    expect(optionIsRelevant("configureGit", resolvePublicPlan(setPackageSelected(empty(), "git", true)))).toBe(true);
    expect(optionIsRelevant("interactiveAuthentication", resolvePublicPlan(setPackageSelected(empty(), "github-cli", true)))).toBe(true);
    const state = { ...empty(), target: "windows-server-2022" as const, profileIds: ["developer", "server-operations"] };
    expect(optionNeedsResolution("interactiveAuthentication", state)).toBe(true);
    const noAccountTools = { ...state, removedPackageIds: ["github-cli"] };
    expect(optionIsRelevant("interactiveAuthentication", resolvePublicPlan(noAccountTools))).toBe(false);
    expect(optionNeedsResolution("interactiveAuthentication", noAccountTools)).toBe(true);
    expect(optionNeedsResolution("interactiveAuthentication", { ...state, options: { interactiveAuthentication: false } })).toBe(false);
  });
});
