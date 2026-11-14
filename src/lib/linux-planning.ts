import { z } from "zod";
import catalog from "../../linux/catalog.json";
import profiles from "../../linux/profiles.v1.json";
import schema from "../../schemas/linux-plan-v1.schema.json";
export const linuxCatalog = catalog;
export const linuxProfiles = profiles.profiles;
export const linuxStepIds = catalog.steps.map(step => step.id);
const uniqueIds = (max: number) => z.array(z.string().min(1).max(64)).max(max).refine(ids => new Set(ids).size === ids.length);
export const linuxSelectionSchema = z.object({
  schemaVersion: z.literal(1), target: z.literal("ubuntu-24.04"), architecture: z.literal("amd64"),
  profileIds: uniqueIds(3), addedStepIds: uniqueIds(4), removedStepIds: uniqueIds(4),
  addInvokingUserToDockerGroup: z.boolean(),
}).strict().refine(value => !value.addedStepIds.some(id => value.removedStepIds.includes(id)));
export type LinuxSelection = z.infer<typeof linuxSelectionSchema>;
export const initialLinuxSelection: LinuxSelection = { schemaVersion: 1, target: "ubuntu-24.04", architecture: "amd64",
  profileIds: linuxProfiles.map(profile => profile.id), addedStepIds: [], removedStepIds: [], addInvokingUserToDockerGroup: false };
const planSchema = z.fromJSONSchema(schema as z.core.JSONSchema.JSONSchema);
export type LinuxPlan = { formatId: "configureme/linux-plan"; schemaVersion: 1; catalogRevision: string; authorization: "none";
  target: { os: "ubuntu-24.04"; architecture: "amd64" }; steps: string[]; options: { addInvokingUserToDockerGroup: boolean } };
export function validateLinuxPlan(input: unknown, revision: string): LinuxPlan {
  const plan = planSchema.parse(input) as LinuxPlan;
  if (plan.catalogRevision !== revision) throw new Error("Linux catalog revision does not match.");
  if (new Set(plan.steps).size !== plan.steps.length || JSON.stringify(plan.steps) !== JSON.stringify(linuxStepIds.filter(id => plan.steps.includes(id))))
    throw new Error("Linux steps must be unique and follow the trusted catalog order.");
  for (const id of plan.steps) {
    const definition = catalog.steps.find(step => step.id === id)!;
    for (const dependency of definition.dependsOn)
      if (!plan.steps.includes(dependency)) throw new Error(`${id} requires ${dependency}.`);
  }
  if (plan.options.addInvokingUserToDockerGroup && !plan.steps.includes("docker-engine")) throw new Error("Docker group requires Docker Engine.");
  return plan;
}
export function resolveLinuxSelection(input: unknown, revision: string): LinuxPlan {
  const selection = linuxSelectionSchema.parse(input);
  if (selection.profileIds.some(id => !linuxProfiles.some(profile => profile.id === id))) throw new Error("Unknown Linux profile.");
  if ([...selection.addedStepIds, ...selection.removedStepIds].some(id => !linuxStepIds.includes(id))) throw new Error("Unknown Linux step.");
  const requested = new Set([...linuxProfiles.filter(profile => selection.profileIds.includes(profile.id)).flatMap(profile => profile.steps), ...selection.addedStepIds]);
  const removed = new Set(selection.removedStepIds), effective = new Set<string>();
  function visit(id: string) {
    if (effective.has(id)) return;
    if (removed.has(id)) throw new Error(`${id} is required; restore it or remove its requester.`);
    effective.add(id);
    for (const dependency of catalog.steps.find(step => step.id === id)!.dependsOn) visit(dependency);
  }
  for (const id of [...requested].sort()) if (!removed.has(id)) visit(id);
  return validateLinuxPlan({ formatId: "configureme/linux-plan", schemaVersion: 1, catalogRevision: revision, authorization: "none",
    target: { os: selection.target, architecture: selection.architecture }, steps: linuxStepIds.filter(id => effective.has(id)),
    options: { addInvokingUserToDockerGroup: selection.addInvokingUserToDockerGroup } }, revision);
}

// Byte-level rules shared with the independent Python reader (no BOM/duplicates/oversize/deep JSON).
export function parseLinuxPlanBytes(bytes: Uint8Array, revision: string): LinuxPlan {
  if (bytes.length > 16384) throw new Error("Linux plan exceeds 16 KiB.");
  const text = new TextDecoder("utf-8", { fatal: true, ignoreBOM: true }).decode(bytes);
  const value: unknown = JSON.parse(text);
  const tokens = text.match(/"(?:[^"\\]|\\.)*"|[{}\[\]:,]|[^\s{}\[\]:,]+/g) ?? [];
  const stack: ({ keys: Set<string>; key: boolean } | null)[] = [];
  for (const token of tokens) {
    const current = stack.at(-1);
    if (token === "{" || token === "[") {
      stack.push(token === "{" ? { keys: new Set(), key: true } : null);
      if (stack.length > 4) throw new Error("Linux plan is too deep.");
    } else if (token === "}" || token === "]") stack.pop();
    else if (token === "," && current) current.key = true;
    else if (token.startsWith('"') && current?.key) {
      const key: string = JSON.parse(token);
      if (current.keys.has(key)) throw new Error("Duplicate Linux JSON key.");
      current.keys.add(key); current.key = false;
    }
  }
  return validateLinuxPlan(value, revision);
}
