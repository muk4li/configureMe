import Link from "next/link";

const authMessages: Record<string, string> = {
  unavailable: "GitHub sign-in is not configured. Set the OAuth environment variables to enable access.",
  forbidden: "This GitHub account is not on the configureMe allowlist.",
  "rate-limited": "Too many sign-in attempts. Please wait a moment and try again.",
  failed: "GitHub sign-in could not be completed. Please try again.",
};

export default async function Home({
  searchParams,
}: {
  searchParams: Promise<{ auth?: string }>;
}) {
  const { auth } = await searchParams;
  return (
    <main className="landing">
      <header className="public-header">
        <Link className="brand" href="/">
          <span className="brand-mark">c</span>
          <span>configure<span className="brand-muted">Me</span></span>
        </Link>
        <a className="button button-quiet" href="/api/auth/github">Sign in with GitHub <span aria-hidden="true">↗</span></a>
      </header>

      <section className="hero">
        <div className="hero-copy">
          <div className="eyebrow"><span className="status-dot" /> SELF-HOSTED SETUP, WITHOUT THE GUESSWORK</div>
          <h1>A fresh computer.<br /><span>Ready for your work.</span></h1>
          <p className="hero-lead">
            Choose a trusted setup profile, review every package, then run a local bootstrap you can inspect first.
            No remote agent. No hidden commands.
          </p>
          <div className="hero-actions">
            <a className="button button-primary" href="/api/auth/github">Continue with GitHub <span aria-hidden="true">→</span></a>
            <a className="button button-quiet" href="#how-it-works">See how it works</a>
          </div>
          {auth && authMessages[auth] && <p className="notice" role="status">{authMessages[auth]}</p>}
          <div className="hero-note"><span aria-hidden="true">◈</span> You stay in control. Nothing installs from your browser.</div>
        </div>
        <div className="preview-card" aria-label="Example installation plan preview">
          <div className="preview-top"><span className="traffic-lights"><i /><i /><i /></span><span>setup-plan.json</span><span className="preview-version">v1</span></div>
          <div className="preview-content">
            <div className="code-line"><span className="code-number">01</span><span className="code-brace">{`{`}</span></div>
            <div className="code-line"><span className="code-number">02</span><span className="code-key">&quot;platform&quot;</span><span>: </span><span className="code-string">&quot;windows&quot;</span><span>,</span></div>
            <div className="code-line"><span className="code-number">03</span><span className="code-key">&quot;architecture&quot;</span><span>: </span><span className="code-string">&quot;x64&quot;</span><span>,</span></div>
            <div className="code-line"><span className="code-number">04</span><span className="code-key">&quot;packages&quot;</span><span>: [</span></div>
            <div className="code-line"><span className="code-number">05</span><span className="code-string indent">&quot;git&quot;,</span></div>
            <div className="code-line"><span className="code-number">06</span><span className="code-string indent">&quot;github-cli&quot;,</span></div>
            <div className="code-line"><span className="code-number">07</span><span className="code-string indent">&quot;vscode&quot;</span></div>
            <div className="code-line"><span className="code-number">08</span><span>]</span></div>
            <div className="code-line"><span className="code-number">09</span><span className="code-brace">{`}`}</span></div>
          </div>
          <div className="preview-footer"><span className="status-dot" /> Validated against catalog v1 <span className="preview-footer-right">Local execution only</span></div>
          <div className="floating-badge"><span aria-hidden="true">✓</span> Review before running</div>
        </div>
      </section>

      <section className="trust-strip" aria-label="Product principles">
        <div><span className="trust-icon">⌘</span><span><strong>Reproducible by design</strong><small>Versioned profiles, predictable results</small></span></div>
        <div><span className="trust-icon">⌁</span><span><strong>Local-first execution</strong><small>Your machine, your confirmation</small></span></div>
        <div><span className="trust-icon">◇</span><span><strong>No secrets in bundles</strong><small>Sign in to developer tools yourself</small></span></div>
      </section>

      <section className="how-section" id="how-it-works">
        <div className="section-heading">
          <div className="eyebrow">A SAFER WAY TO GET STARTED</div>
          <h2>From blank screen to <span>your setup.</span></h2>
        </div>
        <div className="steps-grid">
          <article className="step-card"><div className="step-number">01</div><h3>Choose a profile</h3><p>Start from a curated setup and tailor the package list for this computer.</p></article>
          <article className="step-card"><div className="step-number">02</div><h3>Review the plan</h3><p>See exactly what is supported, what needs WinGet, and what remains manual.</p></article>
          <article className="step-card"><div className="step-number">03</div><h3>Run it locally</h3><p>Download the bundle, inspect it, and confirm before any installation starts.</p></article>
        </div>
      </section>
      <footer className="site-footer"><Link className="brand" href="/"><span className="brand-mark">c</span><span>configure<span className="brand-muted">Me</span></span></Link><span>Self-hosted. Transparent. Yours.</span><a href="https://github.com/muk4li/configureMe">GitHub <span aria-hidden="true">↗</span></a></footer>
    </main>
  );
}
