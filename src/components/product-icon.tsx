import icons from "@/assets/product-icons.json";
export function ProductIcon({ id }: { id: string }) {
  const icon = Object.hasOwn(icons, id) ? (icons as Record<string, { path: string; hex: string }>)[id] : undefined;
  return <svg className={`product-icon ${icon ? "" : "product-icon-fallback"}`} viewBox="0 0 24 24" width="26" height="26"
    aria-hidden="true" focusable="false" data-icon={icon ? "product" : "neutral"}>
    {icon ? <path fill={icon.hex === "000000" ? "currentColor" : `#${icon.hex}`} d={icon.path} />
      : <g fill="none" stroke="currentColor" strokeWidth="1.5" strokeLinejoin="round"><path d="m12 2 9 5v10l-9 5-9-5V7z M3 7l9 5 9-5 M12 12v10 M7.5 4.5l9 5" /></g>}
  </svg>;
}
