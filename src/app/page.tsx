import Link from "next/link";
import { PublicConfigurator } from "@/components/public-configurator";

const authMessages: Record<string, string> = {
  unavailable: "Private sign-in is not configured. The public configurator works without it.",
  forbidden: "This account is not on the private portal allowlist. Public planning remains available.",
  "rate-limited": "Please wait before trying private sign-in again.",
  failed: "Private sign-in could not be completed. You can continue planning without signing in.",
};
export default async function Home({ searchParams }: { searchParams: Promise<{ auth?: string }> }) {
  const { auth } = await searchParams;
  return <main className="landing public-landing">
    <header className="public-header">
      <Link className="brand" href="/"><span className="brand-mark">c</span><span>configure<span className="brand-muted">Me</span></span></Link>
      <a className="button button-quiet" href="/api/auth/github">Private portal · optional sign-in</a>
    </header>
    {auth && authMessages[auth] && <p className="notice" role="status">{authMessages[auth]}</p>}
    <PublicConfigurator />
    <footer className="site-footer"><span>Plan in your browser. Review and run locally, when released.</span><a href="https://github.com/muk4li/configureMe">Source on GitHub</a></footer>
  </main>;
}
