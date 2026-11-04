import Link from "next/link";
import { catalog } from "@/lib/catalog";
import { listProfiles } from "@/lib/profiles";

export default async function DashboardPage() {
  const profiles = await listProfiles();
  return (
    <>
      <div className="page-heading">
        <div><div className="eyebrow-small">YOUR WORKSPACE</div><h1>Overview</h1><p>Your setup plans start from trusted package definitions and run only on your computer.</p></div>
      </div>
      <section className="welcome-grid" aria-label="Quick start and configuration status">
        <div className="welcome-panel">
          <div className="eyebrow-small">READY WHEN YOU ARE</div>
          <h2>Make the next setup feel familiar.</h2>
          <p>Pick a starting profile, make it yours, and download a local Windows bootstrap bundle.</p>
          <Link className="button button-primary button-small" href="/setup">Start a new setup <span aria-hidden="true">→</span></Link>
          <div className="welcome-meta"><span>◈ {catalog.length} catalog entries</span><span>◈ {profiles.length} starter profiles</span></div>
        </div>
        <aside className="panel side-panel">
          <h3>Configuration source</h3>
          <div className="source-status"><span>Provider</span><strong>Local JSON · active</strong></div>
          <div className="source-status"><span>GitHub repository</span><span>Not configured</span></div>
          <div className="source-status"><span>Artifact signing</span><span>Not configured</span></div>
        </aside>
      </section>
      <div className="section-title-row"><h2>Starter profiles</h2><Link className="text-link" href="/profiles">View all →</Link></div>
      <section className="card-grid" aria-label="Starter profiles">
        {profiles.slice(0, 3).map((profile) => (
          <Link className="profile-card" href={`/setup?profile=${profile.id}`} key={profile.id}>
            <div className="card-topline"><span>{profile.platform.toUpperCase()}</span><span className="badge">{profile.packages.length} packages</span></div>
            <h3>{profile.name}</h3>
            <p>{profile.description}</p>
            <div className="card-foot"><span>Local configuration</span><span>Configure →</span></div>
          </Link>
        ))}
      </section>
    </>
  );
}
