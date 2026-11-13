import { getPackage, type PackageDefinition } from "@/lib/catalog";
import { modeLabels, type ResolvedPackage } from "@/lib/public-planning";
import { ProductIcon } from "./product-icon";

export function PublicPackageCard({ item, resolved, mode, directlySelected, sources, onSelect, onKeep }: {
  item: PackageDefinition; resolved?: ResolvedPackage; mode: string; directlySelected: boolean; sources: string[];
  onSelect: (selected: boolean) => void; onKeep: () => void;
}) {
  const required = Boolean(resolved?.requiredBy.length);
  const reasonId = `package-reason-${item.id}`;
  return <div className="choice-row public-package" data-package-id={item.id}>
    <label className="package-selection">
      <input type="checkbox" aria-label={item.name} aria-describedby={required ? reasonId : undefined}
        checked={Boolean(resolved)} disabled={required} onChange={event => onSelect(event.target.checked)} />
      <ProductIcon id={item.id} />
      <span className="package-copy"><strong>{item.name}</strong><small>{modeLabels[mode]}</small>
        {sources.length > 0 && <small className="package-origin">{sources.join(", ")}</small>}
        {required && <small className="dependency-reason" id={reasonId}>Required for {resolved!.requiredBy.map(id =>
          // Display names are supplied by the same trusted catalog as the planner.
          getPackage(id)?.name ?? id).join(", ")}. Remove those tools first to remove {item.name}.</small>}
      </span>
    </label>
    <div className="package-meta"><span className={`badge ${["manual", "web-fallback", "detection-only"].includes(mode) ? "badge-warning" : ""}`}>{mode}</span>
      {required && !directlySelected && <button className="text-link keep-package" type="button" onClick={onKeep}>Also keep {item.name} separately</button>}
    </div>
  </div>;
}
