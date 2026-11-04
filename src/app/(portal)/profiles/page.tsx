import Link from "next/link";
import { listProfiles } from "@/lib/profiles";

export default async function ProfilesPage() {
  const profiles = await listProfiles();
  return (
    <>
      <div className="page-heading">
        <div><div className="eyebrow-small">REUSABLE STARTING POINTS</div><h1>Setup profiles</h1><p>Starter configurations are validated against the trusted catalog. Edit and save are not enabled in this MVP.</p></div>
        <Link className="button button-primary button-small" href="/setup">Build a plan →</Link>
      </div>
      <section className="card-grid" aria-label="Available setup profiles">
        {profiles.map((profile) => (
          <Link className="profile-card" href={`/setup?profile=${profile.id}`} key={profile.id}>
            <div className="card-topline"><span>{profile.platform.toUpperCase()}</span><span className={profile.packages.length ? "badge" : "badge badge-warning"}>{profile.packages.length ? `${profile.packages.length} packages` : "Planning only"}</span></div>
            <h3>{profile.name}</h3>
            <p>{profile.description}</p>
            <div className="card-foot"><span>Local JSON · schema v1</span><span>{profile.packages.length ? "Configure →" : "Not installable"}</span></div>
          </Link>
        ))}
      </section>
      <p className="platform-notice">Profiles are currently read-only local JSON. The GitHub-backed configuration provider and browser editor are not configured in this release.</p>
    </>
  );
}
