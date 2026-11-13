# Setup-plan v1 implementation evidence

2026-11-14, base main `5f878a77146f40e9cd79eb784c1533388db301bc` with merged PRs #8/#9/#10/#11. Branch `feature/setup-plan-v1`. No main write, merge, real installation, privileged configuration, deployment or external-repository write.

## Phase A: confirmed ZIP failure

Actual JSZip entry inspection across a real 2.2-second wait found four implicit directory entries (`configureMe-QuickSetup/`, `assets/`, `config/`, `modules/`) stamped 2026-11-13T23:33:08Z versus 23:33:10Z. File entries stayed 1980-01-01. Archive offsets 10, 4684, 10323, 12353, 39177, 39404, 39660 and 39934 differed (36 versus 37): local/central DOS time fields for those directories. ZIP DOS times have two-second granularity; fast repeated calls had hidden the race with the clock.

Fix `96533c2`: createFolders=false for all entries, fixed UTC file dates, explicit DOS platform and DEFLATE level 6, existing sorted file traversal and unchanged manifest/hash/size checks. Regression controls only Date to cross known clock boundaries in UTC/Los Angeles/Kiritimati, checks all 13 entries and raw local/central DOS fields and full archive byte equality. Original complete Buffer equality assertion retained. Red test against original main: 17 rather than 13 entries (failed). Fixed: both bundle tests passed. No retry-until-green.

Old merged UX branch push trigger removed. CM-016 consolidated under its stable ID and marked merged based on main's PR #8 commit e4a9ebc; historical audit results are preserved. The current review branch temporarily triggers both existing workflows to obtain actual CI while the GitHub GraphQL API denies PR creation. It is not a release workflow or merge workaround.

## Phases B–E

[Contract, native safety model and limitations](../setup-plan-contract.md). Shared fixtures cover both platforms, versions, catalog binding, unknown IDs/actions/options, altered/missing/extra/duplicate/unsorted packages/dependencies, malformed/deep/large JSON and escaped duplicate keys. API tests independently resolve untrusted browser input; browser test exports saved bytes and validates the shared contract. Native tests cover importer atomicity, dependency display, manual mode, target checks, snapshot/source mutation, writer locking and junction refusal without symlink privilege. The existing worker supplies detection/offline plan; no second engine or imported install permission.

## Actual checks (in progress)

- Local Linux: typegen, typecheck, lint passed; 95 Unit/API tests passed with 1 explicit Linux skip of the Windows parser.
- Default Turbopack production build failed because the runtime denies local sockets (`EPERM`); an approved out-of-sandbox invocation had the same failure. Webpack diagnostic also failed in environment TypeScript config subprocess handling. Browser test server cannot start. Neither is counted as passed.
- Native Windows GUI and portable projects cross-build with zero warnings/errors. Standard local VSTest aborts on socket permission denial, not a passed run. A temporary out-of-repository in-process diagnostic invoked 43 shared native contract/target/dry-run assertions successfully; this is supplementary, not a full test-suite result.
- GitHub PR creation via `gh pr create`: `POST api.github.com/graphql: Forbidden`. Review branch pushed; [manual PR comparison](https://github.com/muk4li/configureMe/compare/main...feature/setup-plan-v1?expand=1). Web CI [43529661662](https://github.com/muk4li/configureMe/actions/runs/43529661662) for d20942d passed on Linux and Windows, including production builds and all 22 browser cases on Linux. Complete Windows workflow result still pending.

No physical Windows 11/Server VM, real monitor DPI, genuine vendor installation, or independently signed release acceptance performed in this task. Existing CET/update requirements and self-contained production model remain unchanged.
