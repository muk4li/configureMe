# Imported-plan execution contract: review preparation

Status 2026-11-14: **Proposed execution contract; implemented testable review preparation, unregistered in the GUI**. The existing v1 importer remains review/Dry-Run only. No installation permission, installer activation or public release is authorized by this work.

## Inputs and state

The setup-plan v1 JSON remains `authorization: none`. It supplies desired trusted package IDs and reminders, never URLs, shell commands, executable paths, arguments, security flags, elevation or local consent. `ImportedPlanExecutionReview` copies the validated file snapshot and exact trusted catalog bytes; binds target and hashes; and revalidates the existing `SetupPlanContract` before every review. The hashes identify reviewed bytes, not publisher authenticity or authorization.

Allowed preparatory states: Validated → Reviewing → Reviewed. Reviewed may refresh its read-only observations. Any changed catalog/target or malformed worker result makes the review Invalid; the user must create a new import/review. Cancellation is terminal for that instance, clears review rows and prevents late detection results from issuing the subsequent plan request or restoring Reviewed. A concurrent review attempt is refused. No Executing/Authorized transition or install/download method exists.

The preparation invokes only the existing `SetupPlanDryRun`: `detect` then offline `plan`, both with confirmed=false. It is not a second engine. It accepts exactly one detection and one plan entry per independently resolved effective package, one offline plan event, bounded version text and explicit boolean rights. Missing, duplicate, unexpected IDs/events, unknown actions or malformed strategies are refused. Existing catalog modes prevent a manual/unsupported package being promoted to automatic by a malformed worker response.

Review dispositions:

- DetectedPresent: existing detection reports a version; preserve/skip it in a future execution proposal. This is not a new architecture/signature assurance: existing package-specific detection limitations remain.
- Candidate: detection explicitly says missing and the trusted offline plan offers automatic installation with available rights. This is a proposal only, never permission.
- RightsRequired: missing automatic package requires administrator context that is not available. No self-elevation.
- Manual / Unsupported: retain every requested package and explain its nonautomatic mode; never silently remove it.
- DetectionUnclear: failed/unknown/inconsistent/absent detection evidence; never infer “missing”, never offer automatic execution based on uncertainty.

All package rows are read-only snapshots. Raw logs, arbitrary worker text and untrusted URI parameters are not propagated through this preparatory review result.

## Proposed future execution acceptance

Before activation, the owner must accept this execution contract and separately authorize implementation/activation of imported-plan installation. Future consent belongs to a local UI action bound to the exact reviewed snapshot/catalog/OS, effective dependency order, detection observations, rights and proposed actions. It cannot be read from JSON, persisted as a reusable authorization bit, inherited from a prior run, supplied by a profile or fabricated by switching modes. Decline/cancel/catalog/target/selection changes invalidate it. Fresh detection and a new local review are required for retries.

Revalidate the stored snapshot, trusted embedded engine and catalog immediately before preparing execution. Existing dependency resolution determines dependency-first order. Respect already present software; uncertain detection blocks the affected automatic changes. Determine rights from the trusted resolved installer strategy, distinguishing per-user packages from system-wide requirements; never convert a missing right into automatic elevation. Do not introduce automatic uninstall, downgrade, reboot or unrelated reconfiguration.

Actual execution, after a later approval, must call the existing verified download/serial install/report path. Preserve HTTPS, redirect allowlist, expected/measured digests, installer format, architecture, package-specific bootstrapper rules and Authenticode distinctions. The independent handoff/ACL/TOCTOU gate remains relevant; this review contract does not close it. User cancellation may stop waiting work/downloads, never kill an active installer. Partial failures remain per-package failures; reports must retain previous detected/final versions and error phases. A repeat is a fresh review, not a replay of consent.

## Integration points and explicit gates

The existing `SetupForm.ImportPlanSnapshot`, imported branch of `ShowPlanAsync`, `SetupPlanDryRun`, `PowerShellWorkerClient`, `InstallPlanResolver`, `PackageDownloadPlan`, install queue and `SetupRunReport` are the intended seams. This preparation does not register a new execution button or remove the existing imported-mode guard. Returning to manual mode keeps the preexisting manual confirmation flow and grants no imported authorization.

Before work package C: accept execution semantics and authorize its implementation phase; review package capability/rights and handoff fixes; then implement consent/invalidations with mocks. Before real target tests: authorize isolated Windows VM resets and real vendor installations. Before public executable distribution: independent release provenance/trust, signing and verification, protected keys/workflows, clean target acceptance and human release approval. Windows 11 adapter registration and execution have separate platform gates. No external data provider, private configuration, secrets, VPN or permanent agent is added.

Tests cover copied snapshot ownership, catalog/target changes, read-only actions, no confirmation propagation, existing/missing/unclear detection, incomplete/duplicate/forged protocol observations, rights, terminal cancellation and retry/new-review behavior. These are preparation tests, not a proof of real installation or Windows target acceptance.
