import { catalog, platforms } from "@/lib/catalog";

export default function CatalogPage() {
  return (
    <>
      <div className="page-heading">
        <div><div className="eyebrow-small">TRUSTED PACKAGE DEFINITIONS</div><h1>Software catalog</h1><p>Only packages with an explicit, reviewed installation strategy are marked as installable.</p></div>
        <span className="badge badge-muted">Catalog v1</span>
      </div>
      <section className="catalog-grid" aria-label="Software catalog">
        {catalog.map((item) => {
          const windows = item.platforms.windows;
          return (
            <article className="catalog-card" key={item.id}>
              <div>
                <div className="card-topline"><span>{item.category}</span><span className={windows?.supported ? "badge badge-warning" : "badge badge-muted"}>{windows?.supported ? "Windows · WinGet preview" : "Manual / planned"}</span></div>
                <h3>{item.name}</h3>
                <p>{item.description}</p>
                <div className="card-foot"><span>{platforms.filter((platform) => item.platforms[platform]?.supported).join(", ") || "No automated platform yet"}</span><span>{item.elevated ? "Administrator required" : "User scope"}</span></div>
              </div>
              <a href={item.website} target="_blank" rel="noreferrer">Official site ↗</a>
            </article>
          );
        })}
      </section>
      <p className="platform-notice">Linux and macOS package adapters are not enabled in v1. Catalog entries without a verified installer cannot be added to an automated installation plan.</p>
    </>
  );
}
