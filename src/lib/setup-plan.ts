import { z } from "zod";
import schema from "../../schemas/setup-plan-v1.schema.json";
import policy from "../../contracts/setup-plan-v1.policy.json";
import { publicCatalog, publicSnapshot, modeFor, resolvePublicPlan, selectionSchema, type PublicSelection, type WindowsTarget } from "./public-planning";

// Structural constraints have one source; C# reads this same embedded schema.
const structuralSchema = z.fromJSONSchema(schema as z.core.JSONSchema.JSONSchema);
export type SetupPlan = {
  formatId: "configureme/setup-plan"; schemaVersion: 1; catalogRevision: string;
  status: "validated-plan"; authorization: "none";
  target: { os: WindowsTarget; architecture: "x64" };
  planning: { requestedPackageIds: string[]; profileIds: string[] };
  packages: { id: string; mode: string; dependsOn: string[] }[];
  options: { configureGit?: boolean; interactiveAuthentication?: boolean };
};
const sorted = (values: string[]) => [...new Set(values)].sort();
function equal(a: unknown, b: unknown) { return JSON.stringify(a) === JSON.stringify(b); }

export function validateSetupPlan(input: unknown): SetupPlan {
  const plan = structuralSchema.parse(input) as SetupPlan;
  if (!equal(plan.planning.requestedPackageIds, sorted(plan.planning.requestedPackageIds)) ||
      !equal(plan.planning.profileIds, sorted(plan.planning.profileIds))) throw new Error("Plan IDs must be sorted and unique.");
  const byId = new Map(publicCatalog.map(item => [item.id, item]));
  const effective = new Map<string, SetupPlan["packages"][number]>();
  const visiting = new Set<string>();
  function visit(id: string) {
    if (effective.has(id)) return;
    if (visiting.has(id)) throw new Error("Dependency cycle.");
    const item = byId.get(id);
    if (!item || modeFor(item, plan.target.os) === "unavailable") throw new Error("Unknown or incompatible package.");
    visiting.add(id);
    const dependsOn = sorted(item.dependencies ?? []);
    for (const dependency of dependsOn) visit(dependency);
    visiting.delete(id);
    effective.set(id, { id, mode: modeFor(item, plan.target.os), dependsOn });
  }
  for (const id of plan.planning.requestedPackageIds) visit(id);
  const expected = [...effective.values()].sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0);
  // Ignore object property order, but never array order, missing deps, extra actions or modes.
  if (plan.packages.length !== expected.length || plan.packages.some((item, i) =>
    item.id !== expected[i].id || item.mode !== expected[i].mode || !equal(item.dependsOn, expected[i].dependsOn)))
    throw new Error("The effective package list does not match the trusted catalog.");
  return plan;
}

export function createSetupPlan(input: unknown): SetupPlan {
  const selection: PublicSelection = selectionSchema.parse(input);
  const preview = resolvePublicPlan(selection);
  if (!preview.valid || !preview.packages.length) throw new Error("Resolve the selection before exporting a setup plan.");
  const removed = new Set(selection.removedPackageIds);
  const requested = sorted([
    ...publicSnapshot.profiles.filter(profile => selection.profileIds.includes(profile.id)).flatMap(profile => profile.packages),
    ...selection.addedPackageIds,
  ].filter(id => !removed.has(id)));
  return validateSetupPlan({
    formatId: "configureme/setup-plan", schemaVersion: 1,
    catalogRevision: schema.properties.catalogRevision.const, status: "validated-plan", authorization: "none",
    target: { os: selection.target, architecture: "x64" },
    planning: { requestedPackageIds: requested, profileIds: sorted(selection.profileIds) },
    packages: [...preview.packages].sort((a, b) => a.id < b.id ? -1 : a.id > b.id ? 1 : 0).map(item => ({
      id: item.id, mode: item.mode, dependsOn: sorted(publicCatalog.find(def => def.id === item.id)!.dependencies ?? []),
    })),
    options: Object.fromEntries(Object.entries(preview.options).sort(([a], [b]) => a < b ? -1 : 1)),
  });
}

export function parseSetupPlan(bytes: Uint8Array): SetupPlan {
  if (bytes.byteLength > policy.maxBytes) throw new Error("Setup plan is too large.");
  const text = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);
  const value: unknown = JSON.parse(text); // Reject malformed syntax first.
  // A lexical pass preserves duplicate keys lost by JSON.parse, including escaped keys.
  const tokens = text.match(/"(?:[^"\\]|\\.)*"|[{}\[\]:,]|[^\s{}\[\]:,]+/g) ?? [];
  const stack: ({ keys: Set<string>; expectsKey: boolean } | null)[] = [];
  for (const token of tokens) {
    const current = stack.at(-1);
    if (token === "{" || token === "[") {
      stack.push(token === "{" ? { keys: new Set(), expectsKey: true } : null);
      if (stack.length > policy.maxDepth) throw new Error("Setup plan is too deep.");
    } else if (token === "}" || token === "]") stack.pop();
    else if (token === "," && current) current.expectsKey = true;
    else if (token.startsWith('"') && current?.expectsKey) {
      const key: string = JSON.parse(token);
      if (current.keys.has(key)) throw new Error("Duplicate JSON key.");
      current.keys.add(key); current.expectsKey = false;
    }
  }
  return validateSetupPlan(value);
}
