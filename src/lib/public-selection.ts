import { publicCatalog, publicSnapshot, resolvePublicPlan, selectionSchema, modeFor, type OptionName, type PublicPlan, type PublicSelection, type WindowsTarget } from "./public-planning";

// UI actions derive dependencies from the same planner that validates the API payload.
// A required checked box cannot create a hidden negative override.
export function setPackageSelected(input: PublicSelection, id: string, selected: boolean): PublicSelection {
  const selection = selectionSchema.parse(input);
  const definition = publicCatalog.find(item => item.id === id);
  if (!definition) throw new Error("Unknown package selection.");
  const current = resolvePublicPlan(selection).packages.find(item => item.id === id);
  if (!selected && current?.requiredBy.length) return selection;
  if (selected && modeFor(definition, selection.target) === "unavailable") return selection;
  return selectionSchema.parse({ ...selection,
    addedPackageIds: selected ? [...new Set([...selection.addedPackageIds, id])].sort() : selection.addedPackageIds.filter(value => value !== id),
    removedPackageIds: selected ? selection.removedPackageIds.filter(value => value !== id) : [...new Set([...selection.removedPackageIds, id])].sort(),
  });
}
export function catalogGroupsFor(target: WindowsTarget) {
  const available = publicCatalog.filter(item => modeFor(item, target) !== "unavailable");
  return [...new Set(available.map(item => item.category))].map(category => ({ category, packages: available.filter(item => item.category === category) }));
}
const accountTools = new Set(["github-cli", "vscode", "github-copilot-desktop", "github-copilot-cli", "teams"]);
export function optionIsRelevant(key: OptionName, plan: PublicPlan): boolean {
  return plan.packages.some(item => item.mode !== "unavailable" && (key === "configureGit" ? item.id === "git" : accountTools.has(item.id)));
}
export function optionNeedsResolution(key: OptionName, selection: PublicSelection): boolean {
  if (selection.options[key] !== undefined) return false;
  return new Set(publicSnapshot.profiles.filter(profile => selection.profileIds.includes(profile.id))
    .map(profile => profile.options[key]).filter(value => value !== undefined)).size > 1;
}
export const preferenceHelp: Record<OptionName, { title: string; explanation: string }> = {
  configureGit: {
    title: "Review Git configuration after setup",
    explanation: "Add a reminder to review your Git settings later. No name, email or Git configuration is changed or saved here.",
  },
  interactiveAuthentication: {
    title: "Sign in to selected developer tools later",
    explanation: "Add a reminder to sign in to your selected tools yourself. This does not sign you in, open accounts or store passwords.",
  },
};
