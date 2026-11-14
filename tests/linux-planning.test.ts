import { createHash } from "node:crypto";
import { readFileSync, readdirSync } from "node:fs";
import { describe, expect, it } from "vitest";
import { initialLinuxSelection, resolveLinuxSelection, parseLinuxPlanBytes } from "../src/lib/linux-planning";
const revision = createHash("sha256").update(readFileSync("linux/catalog.json")).digest("hex");
describe("shared Linux contract", () => {
  it("combines profiles deterministically and resolves only trusted dependencies", () => {
    const plan = resolveLinuxSelection(initialLinuxSelection, revision);
    expect(plan.steps).toEqual(["base-tools", "docker-apt-repository", "docker-engine", "unattended-upgrades"]);
    expect(plan.options.addInvokingUserToDockerGroup).toBe(false);
    expect(resolveLinuxSelection({ ...initialLinuxSelection, profileIds: [...initialLinuxSelection.profileIds].reverse() }, revision)).toEqual(plan);
    expect(() => resolveLinuxSelection({ ...initialLinuxSelection, removedStepIds: ["base-tools"] }, revision)).toThrow();
  });
  it("rejects unknown profiles, steps, targets and injected commands", () => {
    for (const change of [{ profileIds: ["unknown"] }, { addedStepIds: ["shell"] }, { command: "anything" }, { architecture: "arm64" }, { target: "ubuntu-22.04" }])
      expect(() => resolveLinuxSelection({ ...initialLinuxSelection, ...change }, revision)).toThrow();
  });
  // All the same byte fixtures as Python, including duplicate keys and malformed input.
  const fixtures = "tests/fixtures/linux-plan-v1";
  const catalogRevision = createHash("sha256").update(readFileSync(`${fixtures}/catalog.synthetic.json`)).digest("hex");
  for (const file of readdirSync(fixtures).filter(name => name.startsWith("valid-") || name.startsWith("invalid-"))) {
    it(`shared semantic fixture ${file}`, () => {
      const run = () => parseLinuxPlanBytes(readFileSync(`${fixtures}/${file}`), catalogRevision);
      if (file.startsWith("valid-")) expect(run).not.toThrow(); else expect(run).toThrow();
    });
  }
});
