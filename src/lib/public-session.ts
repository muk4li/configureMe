import { initialSelection, resolvePublicPlan, selectionSchema, type PublicSelection } from "./public-planning";
export const publicSessionKey = "configureme:public-selection:v1";
export const maxSessionBytes = 8_192;
export function restorePublicSelection(value: string | null): PublicSelection | undefined {
  if (!value || new TextEncoder().encode(value).byteLength > maxSessionBytes) return undefined;
  try {
    const parsed = selectionSchema.safeParse(JSON.parse(value));
    if (!parsed.success) return undefined;
    const plan = resolvePublicPlan(parsed.data);
    return plan.issues.some(issue => ["UNKNOWN_PROFILE", "UNKNOWN_PACKAGE"].includes(issue.code)) ? undefined : parsed.data;
  } catch { return undefined; }
}
export function freshSelection(): PublicSelection { return structuredClone(initialSelection); }
