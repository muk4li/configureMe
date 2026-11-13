import { z } from "zod";
import fixture from "../../fixtures/public/profiles.v1.json";
import { catalog, type PackageDefinition } from "./catalog";

export const targets = ["windows-11", "windows-server-2022"] as const;
export type WindowsTarget = (typeof targets)[number];
export const targetNames: Record<WindowsTarget, string> = {
  "windows-11": "Windows 11 x64",
  "windows-server-2022": "Windows Server 2022 x64 · Desktop Experience",
};
const id = z.string().min(1).max(64).regex(/^[a-z][a-z0-9]*(?:-[a-z0-9]+)*$/);
export const optionNames = ["configureGit", "interactiveAuthentication"] as const;
export type OptionName = (typeof optionNames)[number];
export const optionLabels: Record<OptionName, string> = {
  configureGit: "Configure Git after local review",
  interactiveAuthentication: "Offer interactive tool sign-in",
};
const optionsSchema = z.object({ configureGit: z.boolean().optional(), interactiveAuthentication: z.boolean().optional() }).strict();
const uniqueIds = (max: number) => z.array(id).max(max).refine(values => new Set(values).size === values.length, "Duplicate IDs are not allowed.");
const publicProfileSchema = z.object({
  id, name: z.string().min(1).max(80), description: z.string().min(1).max(240),
  targets: z.array(z.enum(targets)).min(1).max(2).refine(values => new Set(values).size === values.length),
  packages: uniqueIds(50), options: optionsSchema,
}).strict();
const snapshotSchema = z.object({
  schemaVersion: z.literal(1), snapshotId: z.literal("local-fixture-v1"), sourceKind: z.literal("local-fixture"),
  profiles: z.array(publicProfileSchema).min(1).max(8),
}).strict().superRefine((snapshot, ctx) => {
  if (new Set(snapshot.profiles.map(profile => profile.id)).size !== snapshot.profiles.length)
    ctx.addIssue({ code: "custom", message: "Duplicate profile IDs." });
  for (const profile of snapshot.profiles) for (const packageId of profile.packages)
    if (!catalog.some(item => item.id === packageId && item.windowsMode !== "catalog-only"))
      ctx.addIssue({ code: "custom", message: "Unknown fixture package." });
});
export function validatePublicSnapshot(input: unknown) { return snapshotSchema.parse(input); }
export const publicSnapshot = validatePublicSnapshot(fixture);
export type PublicProfile = z.infer<typeof publicProfileSchema>;

export const selectionSchema = z.object({
  schemaVersion: z.literal(1), snapshotId: z.literal("local-fixture-v1"), target: z.enum(targets),
  architecture: z.literal("x64"), profileIds: uniqueIds(8),
  addedPackageIds: uniqueIds(50), removedPackageIds: uniqueIds(50), options: optionsSchema,
}).strict().refine(selection => !selection.addedPackageIds.some(value => selection.removedPackageIds.includes(value)),
  "An addition cannot also be a removal.");
export type PublicSelection = z.infer<typeof selectionSchema>;
export const initialSelection: PublicSelection = {
  schemaVersion: 1, snapshotId: "local-fixture-v1", target: "windows-11", architecture: "x64",
  profileIds: ["essentials"], addedPackageIds: [], removedPackageIds: [], options: {},
};

// Keep legacy aliases out of this new public namespace. No ID rewriting.
export const publicCatalog = catalog.filter(item => item.windowsMode !== "catalog-only");
export function modeFor(item: PackageDefinition, target: WindowsTarget): string {
  if (item.platforms.windows?.supported !== true) return "unavailable";
  if (target === "windows-11") return item.windowsPackageId ? "winget" : "unavailable";
  return ["automatic", "manual", "web-fallback", "detection-only"].includes(item.windowsMode) ? item.windowsMode : "unavailable";
}
export const modeLabels: Record<string, string> = {
  winget: "WinGet · local installation", automatic: "Official installer / Windows capability",
  manual: "Manual step", "web-fallback": "Web fallback · no desktop install",
  "detection-only": "Detection only · installation unsupported", unavailable: "No approved strategy for this target",
};
export type PlanIssue = { code: string; message: string };
export type ResolvedPackage = { id: string; name: string; mode: string; requestedBy: string[]; requiredBy: string[] };

// Pure and shared for guidance. The server always reruns this with its own snapshot/catalog.
export function resolvePublicPlan(input: unknown, profiles: readonly PublicProfile[] = publicSnapshot.profiles,
  definitions: readonly PackageDefinition[] = publicCatalog) {
  const selection = selectionSchema.parse(input);
  const issues: PlanIssue[] = [];
  const issue = (code: string, message: string) => issues.push({ code, message });
  const byId = new Map(definitions.map(item => [item.id, item]));
  const requested = new Map<string, Set<string>>();
  const chosenProfiles = [...selection.profileIds].sort().map(profileId => {
    const profile = profiles.find(item => item.id === profileId);
    if (!profile) issue("UNKNOWN_PROFILE", `Unknown public profile: ${profileId}.`);
    else if (!profile.targets.includes(selection.target)) issue("PROFILE_TARGET", `${profile.name} is unavailable for this target.`);
    return profile;
  }).filter((profile): profile is PublicProfile => Boolean(profile));
  function request(packageId: string, source: string) {
    if (!requested.has(packageId)) requested.set(packageId, new Set());
    requested.get(packageId)!.add(source);
  }
  for (const profile of chosenProfiles) for (const packageId of profile.packages) request(packageId, profile.id);
  for (const packageId of selection.addedPackageIds) request(packageId, "session");
  const removed = new Set(selection.removedPackageIds);
  for (const packageId of removed) {
    if (!byId.has(packageId)) issue("UNKNOWN_PACKAGE", `Unknown package removal: ${packageId}.`);
  }
  const requiredBy = new Map<string, Set<string>>();
  const ordered: string[] = [];
  const visiting = new Set<string>();
  const visited = new Set<string>();
  function visit(packageId: string) {
    if (visited.has(packageId)) return;
    if (visiting.has(packageId)) { issue("DEPENDENCY_CYCLE", `Dependency cycle includes ${packageId}.`); return; }
    const definition = byId.get(packageId);
    if (!definition) { issue("UNKNOWN_PACKAGE", `Unknown package: ${packageId}.`); visited.add(packageId); return; }
    if (modeFor(definition, selection.target) === "unavailable") issue("PACKAGE_TARGET", `${definition.name} has no approved strategy for this target.`);
    visiting.add(packageId);
    for (const dependency of [...(definition.dependencies ?? [])].sort()) {
      if (!requiredBy.has(dependency)) requiredBy.set(dependency, new Set());
      requiredBy.get(dependency)!.add(packageId);
      if (removed.has(dependency)) issue("REQUIRED_REMOVAL", `${dependency} is required by ${packageId}; restore it or remove its requester.`);
      visit(dependency);
    }
    visiting.delete(packageId); visited.add(packageId); ordered.push(packageId);
  }
  for (const packageId of [...requested.keys()].sort()) if (!removed.has(packageId)) visit(packageId);
  const options: Partial<Record<OptionName, boolean>> = {};
  const optionSources: Partial<Record<OptionName, string[]>> = {};
  for (const key of optionNames) {
    if (selection.options[key] !== undefined) { options[key] = selection.options[key]; optionSources[key] = ["session"]; continue; }
    const values = chosenProfiles.filter(profile => profile.options[key] !== undefined);
    if (new Set(values.map(profile => profile.options[key])).size > 1) issue("OPTIONS_CONFLICT", `Profiles disagree on ${key}; choose an explicit session value.`);
    else if (values.length) { options[key] = values[0].options[key]; optionSources[key] = values.map(profile => profile.id); }
  }
  const packages: ResolvedPackage[] = ordered.map(packageId => ({
    id: packageId, name: byId.get(packageId)!.name, mode: modeFor(byId.get(packageId)!, selection.target),
    requestedBy: [...(requested.get(packageId) ?? [])].filter(() => !removed.has(packageId)).sort(),
    requiredBy: [...(requiredBy.get(packageId) ?? [])].sort(),
  }));
  return {
    kind: "configureme-preview" as const, schemaVersion: 1 as const, executable: false as const,
    valid: issues.length === 0, target: selection.target, architecture: selection.architecture,
    source: { kind: publicSnapshot.sourceKind, snapshotId: publicSnapshot.snapshotId, sourceCommit: null },
    profileIds: [...selection.profileIds].sort(),
    overrides: { addedPackageIds: [...selection.addedPackageIds].sort(), removedPackageIds: [...selection.removedPackageIds].sort(), options: { ...selection.options } },
    packages, options, optionSources, issues,
    distribution: { enabled: false as const, reason: "Executable setup downloads await independent release and target-system approval." },
  };
}
export type PublicPlan = ReturnType<typeof resolvePublicPlan>;
