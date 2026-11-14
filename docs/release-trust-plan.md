# Windows release trust: decision and acceptance plan

2026-11-14. Proposed signing/distribution design; **no release activation, signing-key access or publication**. Main f744d63 contains an unsigned development EXE, not an independently authenticated release. GitHub build success and a SHA256 shipped beside a file do not authenticate its publisher.

## Trust chain to approve

1. Owner chooses a durable publisher identity and Authenticode certificate/key custodian (recommended: protected managed signing service with nonexportable keys). Alternative hardware-backed certificate requires manual availability/backup/rotation procedures. Self-signed development certificates do not establish public trust; never label them public release signatures.
2. Protected release environment: reviewed immutable source SHA/tag, least privilege, pinned reviewed toolchain/action revisions, no secret access for untrusted PRs, human approval, separated build/sign/publish identities. Exact action/SDK pinning and upgrades remain reviewed changes, not security theatre from a floating 'latest'.
3. Build self-contained single-file EXE; record source/tree state, SDK/runtime/OS/action versions, dependency lock digest, engine manifest/catalog/plan-contract digests, unsigned input artifact digest. Compare independent builds where possible; record nondeterministic signing/timestamp fields separately instead of claiming byte reproduction of signed outputs.
4. Sign only an approved artifact digest, timestamp with a reviewed timestamp authority, verify publisher chain/EKU/revocation/timestamp and expected identity independently. Attach authenticated build provenance binding source/build inputs and signed artifact digest. SHA sidecars remain corruption checks only.
5. Consumer independently verifies the signed EXE against the approved publisher/trust policy **before privileged use**. Missing, wrong, expired-without-valid-timestamp, revoked or altered signatures fail closed. Unsigned development artifacts remain separate and visibly untrusted; no automatic silent fallback.
6. Publish only after clean target acceptance and human release approval. Rollback/revocation, compromised key, feed/package signer rotation and replacement artifact procedures require a documented owner. Retain immutable approval/verification evidence without credentials or raw private metadata.

## Pre-release gates and safe tests

| Gate | Negative/positive evidence required | Present status |
| --- | --- | --- |
| Publisher identity/key custody | Unavailable signing service, wrong identity, stolen/revoked key exercise; no exportable long-lived key in CI | Owner decision needed; no real secret operation authorized |
| Build/attestation | Wrong source SHA, dirty tree, substituted unsigned input/output, mismatching dependency/engine/catalog digest | Existing development manifests/CI; independent authenticated provenance not released |
| Signature policy | Altered payload, missing/untrusted/wrong publisher, certificate lifetime/revocation/timestamp cases; genuine correctly signed control | Prepare synthetic policy fixtures after signer policy acceptance; no mock success is publisher trust |
| Installer handoff | Contents/namespace identity, writable ancestors, reparse/ACL/integrity cases, cache concurrency and failure cleanup | Narrow deny-write/delete mitigation reviewed separately; complete CM-006 remains open |
| Target acceptance | Single-file cold start with no global .NET, CET updates, DPI, actual installed versions/architecture, restarts/idempotency/rights | Hosted CI != clean target/vendor acceptance; use [matrix](qa/windows-v1-acceptance.md) |
| Distribution | Authenticated artifact before download becomes executable authority, explicit local confirmation, no public unsigned ZIP/EXE endpoint | Public executable distribution remains blocked |

No signer implementation is activated by this document. CM-001 cannot be Done until its actual independently verified positive/negative trust criteria pass. Global source/identity/responsibility changes require Centrality review; no foreign repository changed.
