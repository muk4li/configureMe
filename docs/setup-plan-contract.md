# Setup-plan contract v1

Status 2026-11-14: implemented/tested, merged in PR #12 (main f744d63); validation evidence in [the audit](audits/setup-plan-v1.md). Not a release/distribution approval. The native runner remains the existing EXE in this repository, not a new engine or per-user build.

## Formats and authority

| Format | Consumer | Meaning |
| --- | --- | --- |
| `schemas/install-plan.schema.json` | legacy WinGet/bootstrap | Existing behavior unchanged; no implicit migration |
| `configureme-preview` | public browser preview | Informational; cannot be imported as setup-plan v1 |
| `configureme/setup-plan`, schemaVersion 1 | public JSON exporter + native importer | Declarative desired packages; review and local Dry-Run only |

The authoritative structural definition is [setup-plan-v1.schema.json](../schemas/setup-plan-v1.schema.json). [Policy](../contracts/setup-plan-v1.policy.json) defines a 65,536-byte snapshot and 12-container depth limit, native target and reminders-only semantics. TypeScript uses existing Zod's JSON-Schema importer. C# interprets the bounded schema vocabulary, rejecting unsupported keywords; both consumers run the same positive/negative byte fixtures. No new dependency or remote schema lookup.

`catalogRevision` pins the SHA-256 of the exact trusted catalog file. `.gitattributes` fixes LF for this file on Windows too. A catalog edit requires an explicit revision/schema/fixture review; there is no automatic acceptance of an arbitrary newer catalog. The digest binds compatibility, not publisher identity. No runtime download source or installer policy comes from JSON.

## Fields and deterministic semantics

- `formatId`, `schemaVersion`, `catalogRevision`: exact supported identity/version/catalog; unknown versions fail closed. Future migrations must be explicit reviewed adapters, not aliases for legacy/preview JSON.
- `status: validated-plan`, `authorization: none`: producer-resolved data, never execution rights or proof of authenticity. Import validates independently.
- `target.os`: Windows 11 or Windows Server 2022; architecture exclusively x64.
- `planning.requestedPackageIds`: effective direct/profile roots after explicit exclusions, sorted and unique. These are desired selections, not uninstall requests.
- `planning.profileIds`: sorted public profile identifiers retained as advisory provenance only. Native code does not fetch profiles or treat these names as verified provenance/authority; root IDs are independently checked.
- `packages`: ID-sorted exact dependency closure. Each entry contains only id, approved mode and sorted direct dependsOn IDs. Native and server recompute this from the bundled trusted catalog and reject extras, omissions, wrong modes/dependencies/order or unknown IDs. The existing engine independently resolves execution order.
- `options`: only optional configureGit/interactiveAuthentication booleans. Both are reminders; no identity, configuration change, sign-in, secret, arbitrary action, URL, path, script or argument. Their values are shown in the import log.

Server export recomputes the complete existing PublicSelection (profiles, direct requests, exclusions, conflicts and option defaults) before projection. Input order does not change exported JSON. No timestamp/random run ID is in the contract. A new explicit exclusion still cannot defeat a required dependency. Public fixture profiles remain synthetic; this contract does not authorize external data import.

## Export and local import

1. Configure publicly without login; resolve all conflicts and choose at least one package.
2. `Export setup plan v1` posts the selection to `/api/public/plan?export=setup-plan-v1`. Existing Origin, 8-KiB request, timeout, rate/concurrency and no-store rules apply. No anonymous ZIP/EXE generation.
3. Save `configureme-setup-plan.v1.json` on a local fixed Windows drive.
4. Start the development EXE on fully updated Windows Server 2022 x64 Desktop Experience. Use `Setup-Plan importieren`. No global .NET/Node/Git required by the existing self-contained EXE.
5. Review checked packages, dependency marks and reminder log. Import itself starts no worker, download or installation. Unknown fields, duplicate/escaped duplicate keys, malformed UTF-8/JSON, incompatible catalog/OS/architecture or altered effective lists are refused atomically.
6. `Dry-Run` revalidates the stored snapshot and catalog, then calls only the existing worker's `detect` and offline `plan`, both unconfirmed. Installed detection is reported separately; detection failures do not prove a change is safe. Manual/web/detection-only modes remain explicit. Reports/cache are local application writes, not system configuration changes.
7. Imported mode locks package changes and real installation actions. `Manuelle Auswahl` deliberately exits imported mode and restores the preexisting developer selection and its normal detection/confirmation checks; it is not permission supplied by the JSON.

The source file is read once through Win32 no-follow open, sharing only reads (excluding concurrent writers/deleters), final handle path/attributes and ancestor reparse checks. Relative/UNC/device/network-drive/alternate-stream/noncanonical paths are refused. The file is bounded before allocation and read into owned snapshot bytes; subsequent edits to the original file cannot affect review/Dry-Run. These protections do not establish an independently trusted publisher or protect a compromised same-user process/OS.

No CLI plan switch or file association is added. Windows 11 can be represented/exported and structurally validated, but native import/Dry-Run explicitly refuses it: a tested native WinGet adapter is not implemented. Existing manual Server GUI behavior remains available without any imported file.

## Architecture boundaries and release gates

Public profiles and nonsecret basis choices are unauthenticated planning data. Private templates are a later authorized feature; private data must not be fetched or delivered before authentication. VPN/device enrollment, certificates, SSH secrets, browser passwords and vault integration require separate contracts; no permanent agent or private infrastructure is needed for basic setup.

The current data decision remains an explicitly approved versioned snapshot from `myConfigs-data`; its concrete adapter contract is still Proposed. A separate public profile repository is an alternative, not a decision. [Comparison and unresolved schema issues](integrations/public-snapshot-v1-proposal.md). No other repository changed. Global responsibility/repository changes require Centrality review.

Before public executable distribution: independent publisher provenance/trust anchor, protected build/release workflow, signing and independent verification, secured signing keys/rotation, installer-handoff review, actual clean Windows target acceptance and human release approval. SHA-256 alone is not provenance. CI artifacts remain unsigned development artifacts; no public executable route or distribution switch was enabled. Future real execution of imported plans needs separately reviewed confirmation/permissions, not changing `authorization` in JSON.
