# Setup-plan v1 implementation evidence

2026-11-14, base main `5f878a77146f40e9cd79eb784c1533388db301bc` with merged PRs #8/#9/#10/#11. Branch `feature/setup-plan-v1`. No main write, merge, real installation, privileged configuration, deployment or external-repository write.

## Phase A: confirmed ZIP failure

Actual JSZip entry inspection across a real 2.2-second wait found four implicit directory entries (`configureMe-QuickSetup/`, `assets/`, `config/`, `modules/`) stamped 2026-11-13T23:33:08Z versus 23:33:10Z. File entries stayed 1980-01-01. Archive offsets 10, 4684, 10323, 12353, 39177, 39404, 39660 and 39934 differed (36 versus 37): local/central DOS time fields for those directories. ZIP DOS times have two-second granularity; fast repeated calls had hidden the race with the clock.

Fix `96533c2`: createFolders=false for all entries, fixed UTC file dates, explicit DOS platform and DEFLATE level 6, existing sorted file traversal and unchanged manifest/hash/size checks. Regression controls only Date to cross known clock boundaries in UTC/Los Angeles/Kiritimati, checks all 13 entries and raw local/central DOS fields and full archive byte equality. Original complete Buffer equality assertion retained. Red test against original main: 17 rather than 13 entries (failed). Fixed: both bundle tests passed. No retry-until-green.

Old merged UX branch push trigger removed. CM-016 consolidated under its stable ID and marked merged based on main's PR #8 commit e4a9ebc; historical audit results are preserved. The current review branch temporarily triggered both existing workflows to obtain actual CI while the GitHub GraphQL API denied PR creation; both temporary triggers were removed after final code CI passed. It is not a release workflow or merge workaround.

## Phases B–E

[Contract, native safety model and limitations](../setup-plan-contract.md). Shared fixtures cover both platforms, versions, catalog binding, unknown IDs/actions/options, altered/missing/extra/duplicate/unsorted packages/dependencies, malformed/deep/large JSON and escaped duplicate keys. API tests independently resolve untrusted browser input; browser test exports saved bytes and validates the shared contract. Native tests cover importer atomicity, dependency display, manual mode, target checks, snapshot/source mutation, writer locking and junction refusal without symlink privilege. The existing worker supplies detection/offline plan; no second engine or imported install permission.

## Actual checks

- Local Linux: typegen, typecheck, lint passed; 95 Unit/API tests passed with 1 explicit Linux skip of the Windows parser.
- Default Turbopack production build failed because the runtime denies local sockets (`EPERM`); an approved out-of-sandbox invocation had the same failure. Webpack diagnostic also failed in environment TypeScript config subprocess handling. Browser test server cannot start. Neither is counted as passed.
- Native Windows GUI and portable projects cross-build with zero warnings/errors. Standard local VSTest aborts on socket permission denial, not a passed run. A temporary out-of-repository in-process diagnostic invoked 43 shared native contract/target/dry-run assertions successfully; this is supplementary, not a full test-suite result.
- GitHub PR creation via `gh pr create`: `POST api.github.com/graphql: Forbidden`. Review branch pushed; [manual PR comparison](https://github.com/muk4li/configureMe/compare/main...feature/setup-plan-v1?expand=1). Web CI [43529661662](https://github.com/muk4li/configureMe/actions/runs/43529661662) for d20942d passed on Linux and Windows, including production builds and all 22 browser cases on Linux. Complete Windows workflow [43529661650](https://github.com/muk4li/configureMe/actions/runs/43529661650) for d20942d also passed (3m55s): PS5.1/PS7 fixtures, three full GUI/controller/engine suites, portable suite, restrictive-policy single-file publication, embedded engine/startup/layout self-tests and development ZIP packaging. Subsequent saved-file integration, fail-closed detection and package-action refinements passed the final runs recorded below.

No manual acceptance on a clean Windows 11/Server target VM, real monitor DPI, genuine vendor installation, or independently signed release acceptance performed in this task. Hosted Windows CI is recorded separately. Existing CET/update requirements and self-contained production model remain unchanged.

Local additional checks: `dotnet publish windows/ConfigureMe.Setup/ConfigureMe.Setup.csproj --configuration Release -p:PublishProfile=win-x64 --output /tmp/configureme-plan-publish --no-restore` succeeded; 50-MiB EXE, no external DLLs (cross-publication, not a Windows launch). `pwsh -NoProfile -NonInteractive -File tests/installer-regressions.ps1` passed 86 assertions; `tests/codex-desktop-script.ps1` passed 10 mocked scenarios; `tests/quicksetup-portable.ps1` passed. No network/installer/system side effects in these fixtures. Local CLI/XDG/cache roots were explicitly workspace-scoped because host home directories are read-only.

Follow-up CI finding: the strengthened byte-exact export fixture failed on Windows in 9885b3c/b956983 because Git autocrlf changed committed fixture LF to CRLF. The exported JSON remained LF. Fix: explicit LF attributes for shared contract byte fixtures; byte equality is retained without normalization in the assertion. Native Windows CI for b956983 [43530466987](https://github.com/muk4li/configureMe/actions/runs/43530466987) passed completely; failed web run [43530467008](https://github.com/muk4li/configureMe/actions/runs/43530467008) is recorded rather than counted as success.

## Review scope and remaining work

Implemented: distinct local contract, complete server revalidation/export, safe atomic import, dependency display, persisted snapshot revalidation, existing-engine detection/offline plan, explicit manual-mode return and accurate detection-failure reporting. Shared fixtures: 37 (4 positive, 33 negative); TypeScript export bytes equal the native saved-plan fixture. Browser export and native file/GUI/worker integration checks compose the transition without third-party installation.

Not implemented/released: native Windows-11 adapter, CLI/file association, real execution of imported plans, production external profile source, private templates/secret provisioning, signed public executable distribution, independent publisher provenance, and clean target-VM acceptance. No global architecture/repository/data-source decision changed. The PR-creation API blocker remains external to the implementation; no merge substitutes for review.

Production build on a development machine with .NET 10 SDK (not needed to run the published EXE):

```powershell
dotnet publish windows\ConfigureMe.Setup\ConfigureMe.Setup.csproj --configuration Release -p:PublishProfile=win-x64 --output .\publish
```

Manual non-installing validation: on fully updated Server 2022 x64 Desktop Experience, open the existing self-contained EXE, import the saved v1 JSON, inspect exact roots/dependencies/reminders, run Dry-Run, inspect existing/missing/manual/failed statuses and report, reject a changed version/dependency/unknown action, then explicitly return to manual selection. Do not press real installation controls in this review. Windows 11 native import must refuse. This checklist is an instruction, not a claim of completed interactive VM acceptance.

## Final verified code and handoff

Final implementation commit: `79bf3e18e8e4ff3ecfd4149b1c1ccf404c91c983`.

| Actual gate | Result |
| --- | --- |
| [Web CI 43561655099](https://github.com/muk4li/configureMe/actions/runs/43561655099) | Success, 2m05s; Linux + Windows typegen/typecheck/lint/unit/API/production builds, 22 Linux browser cases |
| [Windows CI 43561655089](https://github.com/muk4li/configureMe/actions/runs/43561655089) | Success, 3m07s; PS5.1/7 security fixtures, three full GUI/controller/embedded-engine suites, portable suite, restricted-process-policy single-file publish, embedded-worker/layout/shell-startup self-tests, development ZIPs |
| Shared fixtures | 37 files: 4 accepted contracts, 33 refused inputs, exercised by TS and C#; Windows-11 contract accepted structurally but refused by native adapter |
| Local final web checks | `npx next typegen`, `npm run typecheck`, `npm run lint`, `npm test`: passed; 95 tests plus 1 explicit Linux skip |
| Documentation/scope | 143 local links/anchors and 31 stable unique task IDs/table rows/statuses/required fields; `git diff --check` passed; legacy schema, engine, installer/security definitions, auth and package lock unchanged |

Final follow-up commit changes only documentation/task evidence and removes the temporary feature-branch triggers. The complete code was tested at the SHA above; do not mislabel those runs as tests of a later documentation-only SHA. PR/main/manual CI triggers remain; no workflow security gate was removed. Existing @v4 action Node-runtime deprecation annotations remain nonblocking and were not addressed by an unrelated dependency upgrade.

Main remains `5f878a77146f40e9cd79eb784c1533388db301bc`. No PR was created: GraphQL POST is Forbidden in this environment. Prepared review description: `/tmp/configureme-plan-pr.md`; [open the branch comparison](https://github.com/muk4li/configureMe/compare/main...feature/setup-plan-v1?expand=1). CM-027..030 are Implemented/Tested in their local scope, not Released. CM-031 remains Blocked only on actual PR creation; all code/CI integration criteria passed. No automatic merge.

Changed production modules: `src/lib/server-bundle.ts` (ZIP metadata); `schemas/setup-plan-v1.schema.json`, `contracts/setup-plan-v1.policy.json`, `src/lib/setup-plan.ts` (shared contract/server projection); public route/component (separate JSON download); `SetupPlanContract.cs`, `SetupPlanFile.cs`, `SetupPlanDryRun.cs`, `SetupForm.cs` and catalog model/resource project entries (independent native validation and existing-engine preview). Shared fixtures, API/browser/native regression tests, LF attributes, architecture/security/plan/integration/backlog documentation accompany them. No production installer function was changed.

## Status nach Eigentümermerge (2026-11-14)

PR [#12](https://github.com/muk4li/configureMe/pull/12) ist in main `f744d63c5d245f113e3104161abf04d9f5e900e1` gemergt. Die damalige PR-Erstellungsblockade oben ist historisch, CM-031 jetzt Done. [Main-Web-CI](https://github.com/muk4li/configureMe/actions/runs/43562422332) und [Main-Windows-CI](https://github.com/muk4li/configureMe/actions/runs/43562422337) erfolgreich. Folgeauftrag: [aktuelle Baseline](windows-v1-baseline.md). Keine Installations-/Releasefreigabe aus dem Merge ableiten.
