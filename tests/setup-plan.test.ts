import { createHash } from "node:crypto";
import { readFileSync } from "node:fs";
import { describe, expect, it } from "vitest";
import cases from "./fixtures/setup-plan-v1/cases.json";
import schema from "../schemas/setup-plan-v1.schema.json";
import { createSetupPlan, parseSetupPlan, validateSetupPlan } from "../src/lib/setup-plan";
import { freshSelection } from "../src/lib/public-session";
const selection = { ...freshSelection(), target: "windows-server-2022" as const, profileIds: [], addedPackageIds: ["github-cli"] };
describe("setup-plan v1", () => {
  for (const fixture of cases) it(`shared fixture ${fixture.file}: ${fixture.valid}`, () => {
    const bytes = readFileSync(`tests/fixtures/setup-plan-v1/${fixture.file}`);
    if (fixture.valid) expect(() => parseSetupPlan(bytes)).not.toThrow();
    else expect(() => parseSetupPlan(bytes)).toThrow();
  });
  it("exports exactly the shared native end-to-end fixture", () => {
    expect(createSetupPlan(selection)).toEqual(JSON.parse(readFileSync("tests/fixtures/setup-plan-v1/valid-server.json", "utf8")));
  });
  it("binds the contract to the exact trusted catalog bytes", () => {
    expect(createHash("sha256").update(readFileSync("bootstrap/windows-server-2022-developer/config/catalog.json")).digest("hex"))
      .toBe(schema.properties.catalogRevision.const);
  });
  it("emits sorted dependencies, distinguishes provenance and grants no authority", () => {
    const plan = createSetupPlan(selection);
    expect(plan.planning.requestedPackageIds).toEqual(["github-cli"]);
    expect(plan.packages).toEqual([{ id: "git", mode: "automatic", dependsOn: [] }, { id: "github-cli", mode: "automatic", dependsOn: ["git"] }]);
    expect(plan.authorization).toBe("none");
    expect(parseSetupPlan(Buffer.from(JSON.stringify(plan)))).toEqual(plan);
  });
  it("is byte reproducible for profile order, repeated requests and option insertion order", () => {
    const a = { ...selection, profileIds: ["essentials", "developer"], options: { configureGit: true, interactiveAuthentication: false } };
    const b = { ...a, profileIds: [...a.profileIds].reverse(), options: { interactiveAuthentication: false, configureGit: true } };
    expect(JSON.stringify(createSetupPlan(a))).toBe(JSON.stringify(createSetupPlan(b)));
  });
  it("rejects empty or invalid input and never accepts hidden execution fields", () => {
    expect(() => createSetupPlan({ ...selection, addedPackageIds: [] })).toThrow();
    expect(() => createSetupPlan({ ...selection, removedPackageIds: ["git"] })).toThrow();
    expect(() => validateSetupPlan({ ...createSetupPlan(selection), command: "arbitrary" })).toThrow();
  });
});
