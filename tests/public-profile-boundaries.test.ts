import { describe, expect, it } from "vitest";
import sourceProfile from "./fixtures/public-profile-boundaries/source-profile.synthetic.json";
import sourceCatalog from "./fixtures/public-profile-boundaries/source-catalog.synthetic.json";
import overLimit from "./fixtures/public-profile-boundaries/source-over-limit.synthetic.json";
import { profileSchema } from "../src/lib/profiles";
import { publicSnapshot, resolvePublicPlan, selectionSchema, validatePublicSnapshot } from "../src/lib/public-planning";
import { freshSelection, restorePublicSelection } from "../src/lib/public-session";
import { createSetupPlan } from "../src/lib/setup-plan";

const localControl = {
  schemaVersion: 1, id: "synthetic-local-control", name: "Synthetic local control",
  description: "Local format only", platform: "windows", packages: ["git"], options: {},
};

// These are compatibility/rejection probes against actual consumers, not an adapter.
// Every source-shaped object is invented; no private profile or live source is read.
describe("proposed public source boundary stays inactive", () => {
  it("accepts a known local control while refusing source-shaped profiles/catalogs despite schemaVersion 1", () => {
    expect(profileSchema.safeParse(localControl).success).toBe(true);
    expect(profileSchema.safeParse(sourceProfile).success).toBe(false);
    expect(() => validatePublicSnapshot(sourceCatalog)).toThrow();
    expect(selectionSchema.safeParse(sourceProfile).success).toBe(false);
  });

  it("rejects unknown source schema versions without a migration or partial import", () => {
    for (const schemaVersion of [0, 2, "1"]) {
      // Change only the version of otherwise known-valid consumer controls.
      expect(profileSchema.safeParse({ ...localControl, schemaVersion }).success).toBe(false);
      expect(() => validatePublicSnapshot({ ...publicSnapshot, schemaVersion })).toThrow();
      expect(profileSchema.safeParse({ ...sourceProfile, schemaVersion }).success).toBe(false);
      expect(() => validatePublicSnapshot({ ...sourceCatalog, schemaVersion })).toThrow();
    }
    expect(() => validatePublicSnapshot({
      ...publicSnapshot, profiles: [publicSnapshot.profiles[0], sourceProfile],
    })).toThrow();
    expect(publicSnapshot.profiles.some(profile => profile.id === sourceProfile.id)).toBe(false);
  });

  it("cannot convert an external source by merely renaming platforms or silently truncating limits", () => {
    // Deliberately supply the other consumer fields to isolate the actual limits.
    // This local probe is not a producer-to-consumer transformation implementation.
    const result = profileSchema.safeParse({
      schemaVersion: overLimit.schemaVersion, id: overLimit.id, name: overLimit.name,
      description: overLimit.description, platform: "windows", packages: overLimit.packages,
      options: overLimit.options,
    });
    expect(result.success).toBe(false);
    if (result.success) throw new Error("Over-limit source data was accepted.");
    const limitPaths = result.error.issues.filter(issue => issue.code === "too_big").map(issue => issue.path.join("."));
    expect(limitPaths).toEqual(expect.arrayContaining(["name", "description", "packages"]));
    expect(overLimit.name).toHaveLength(81);
    expect(overLimit.description).toHaveLength(241);
    expect(overLimit.packages).toHaveLength(51);
  });

  it("does not mistake source catalog revision or commit for a supported public snapshot", () => {
    for (const snapshotId of [String(sourceCatalog.catalogVersion), "a".repeat(40), "external-snapshot-v1"]) {
      const selection = { ...freshSelection(), snapshotId };
      expect(selectionSchema.safeParse(selection).success).toBe(false);
      expect(restorePublicSelection(JSON.stringify(selection))).toBeUndefined();
      expect(() => createSetupPlan(selection)).toThrow();
    }
    expect(() => validatePublicSnapshot({ ...publicSnapshot, sourceKind: "myconfigs-data" })).toThrow();
  });

  it("does not map legacy package aliases or infer a Server workflow from generic windows", () => {
    const empty = { ...freshSelection(), profileIds: [], target: "windows-server-2022" };
    expect(selectionSchema.safeParse({ ...empty, addedPackageIds: ["7zip"] }).success).toBe(false);
    expect(resolvePublicPlan({ ...empty, addedPackageIds: ["powershell"] }).issues.map(issue => issue.code)).toContain("UNKNOWN_PACKAGE");
    const sourceWithServerOnlyPackage = { ...sourceProfile, packages: ["dotnet-10-sdk"] };
    expect(profileSchema.safeParse(sourceWithServerOnlyPackage).success).toBe(false);
    const explicitServer = createSetupPlan({ ...empty, addedPackageIds: ["dotnet-10-sdk"] });
    expect(explicitServer.target.os).toBe("windows-server-2022");
    expect(() => createSetupPlan({ ...empty, target: "windows-11", addedPackageIds: ["dotnet-10-sdk"] })).toThrow();
  });
});
