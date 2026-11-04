import Link from "next/link";
import type { ReactNode } from "react";
import type { Session } from "@/lib/auth";

const navigation = [
  { href: "/dashboard", label: "Overview" },
  { href: "/catalog", label: "Catalog" },
  { href: "/profiles", label: "Profiles" },
  { href: "/setup", label: "New setup" },
];

export function PortalShell({ session, children }: { session: Session; children: ReactNode }) {
  return (
    <div className="portal">
      <header className="portal-header">
        <Link className="brand" href="/dashboard" aria-label="configureMe dashboard">
          <span className="brand-mark">c</span>
          <span>configure<span className="brand-muted">Me</span></span>
        </Link>
        <nav className="portal-nav" aria-label="Main navigation">
          {navigation.map((item) => (
            <Link key={item.href} href={item.href}>{item.label}</Link>
          ))}
        </nav>
        <div className="user-actions">
          <span>{session.username} · {session.role}</span>
          <form action="/api/auth/logout" method="post">
            <button className="logout-button" type="submit">Sign out</button>
          </form>
        </div>
      </header>
      <main className="portal-main">{children}</main>
      <footer className="site-footer" style={{ maxWidth: 1052, margin: "0 auto", padding: "0 0" }}>
        <Link className="brand" href="/dashboard"><span className="brand-mark">c</span><span>configure<span className="brand-muted">Me</span></span></Link>
        <span>Profiles are data, never scripts.</span>
        <a href="https://github.com/muk4li/configureMe">Documentation <span aria-hidden="true">↗</span></a>
      </footer>
    </div>
  );
}
