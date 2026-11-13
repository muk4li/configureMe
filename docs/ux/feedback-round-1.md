# Public configurator: UI/UX feedback round 1

2026-11-13. Base `main@3442f9fbaabb2ce1602681449df6955e6d57b758`, containing merged PRs #8, #9 and #10. No open PRs found in the public list at start; API/GraphQL reads remain Forbidden. Branch: `feature/configurator-ux-round-1`. Scope is UI/selection/tests/docs only; no installer, auth, release, deployment, data-provider or system-configuration changes.

## Dependency cause and correction

Previously the checkbox read the *effective* package list while its handler always treated an uncheck as an explicit exclusion. GitHub CLI required Git, so the resolver correctly kept Git and rejected the new `removedPackageIds: [git]`. The checked UI and negative intent consequently contradicted each other.

`setPackageSelected` now derives required-by state from the same `resolvePublicPlan` used for rendering and API validation. An active dependency cannot create a negative override. Its checked checkbox is disabled with a visible “Required for …” explanation. “Also keep … separately” explicitly records direct intent; removing the parent later retains only direct/profile/other-parent requests. Existing explicit malformed/legacy exclusions are not silently normalized away: warnings/export blocking remain until Undo or another explicit repair. Server-side rejection of injected exclusions remains unchanged and has a route regression test.

Intent remains in the existing contract: addedPackageIds = direct choices, selected profile packages = profile requests, resolver requiredBy = automatic dependencies, removedPackageIds = explicit exclusions. No session-key/schema migration or relaxation of API validation.

## Target catalog and counts

Only packages with an existing approved target strategy enter the normal catalog; empty categories disappear. The count is the actual number of visible choices. Manual/web/detection-only strategies remain explicit existing planning modes, not promises of installation. The application does not invent Windows 11 strategies for Server-only packages.

On target change, selected incompatible tools and overrides remain in state and in an explicit warning list; they are absent from the normal tool grid. The plan stays invalid and cannot export successfully. Profile-target conflicts also remain visible; removing an individual tool does not silently remove its source profile. The API revalidates all choices regardless of the UI filter.

## Existing plan preferences, without new settings

| Stored flag | New explanation / scope | Context and effect |
| --- | --- | --- |
| configureGit | “Review Git configuration after setup”; reminder to review Git settings later, no name/email stored or Git command run | Global plan hint shown when Git is resolved; changes only options.configureGit and optionSources in the preview |
| interactiveAuthentication | “Sign in to selected developer tools later”; user signs in themselves, no account/session/password created | Global plan hint shown for selected GitHub CLI/Copilot, VS Code or Teams with a valid target strategy; changes only the corresponding preview fields |

“Use profile preference”, “Include this reminder” and “Do not include this reminder” replace raw booleans. The visible result distinguishes profile defaults, the user's choice, an unspecified value and a conflicting profile default. These options do **not** currently drive a local installer adapter. Labels stay in the existing English interface language rather than introducing a partial translation.

Unrelated controls are hidden. A still-blocking profile-option conflict keeps its resolution control visible even if the corresponding tools were removed, because hiding it would make existing server validation impossible to satisfy. Explicit choices that become irrelevant are retained in sessionStorage, mentioned read-only in the summary and restored when their context returns; no silent reset. No new option or auth bypass.

## Layout and icons

The existing dark palette, typography, header/private-portal button and cards remain. The public wrapper uses a responsive rem/vw clamp: at 1920px the inner grid is about 76% of the viewport, leaving roughly one quarter for side space. The summary now starts next to the introduction, not below it. Its desktop sticky panel is height-bounded/scrollable; mobile remains normal document flow. Each category is one fieldset with a two-column tool grid; a container query reduces it to one column when the actual main-column width is narrow.

Locally embedded 26px icons have no runtime image request or layout shift. Licensed Git/.NET/Copilot assets and neutral fallbacks: [sources, licenses and attribution](../../third_party/simple-icons/README.md). No unreviewed brand asset or CDN introduced, no npm dependency change.

Representative captures: [desktop 1920](../screenshots/ux-round-1/desktop-1920.png), [mobile 375](../screenshots/ux-round-1/mobile-375.png). Tests also capture 768, 1280 and 1440px and verify no horizontal overflow, two/one-column geometry, no overlapping action buttons, fixed icon dimensions and sticky/cart accessibility. These are real headless Chromium CSS-viewport tests, not physical monitor/DPI or native WinForms tests.

## Executed validation

Host: Debian 13 x64, Node 24.22.1, npm 11.9.0, existing Chromium 155.0.8059.79. No installs or system changes; npm pack downloaded only an icon source archive to /tmp. Backend installer/auth/Engine/Windows-workflow files and dependency lockfile remain unchanged.

| Command | Actual result / limit |
| --- | --- |
| `npx next typegen`; `npm run typecheck`; `npm run lint` | passed |
| `npm test` | 50 passed, 1 explicit Linux skip of Windows parser, 8 files |
| `NEXT_TELEMETRY_DISABLED=1 npm run build` | production build passed, no deployment |
| `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium npm run test:browser` | 20 passed at 375/768/1280/1440/1920; browser/API checks, no external browser requests allowed |
| Source archive SHA-512, path SHA-256/license tests | passed; provenance is a source record, not independent release authentication |
| Documentation links/status/IDs and `git diff --check` | 93 local links/anchors and 26 stable task IDs/statuses/fields passed; original installer/Engine/auth/API/schema/lock/framework rules unchanged |

The first browser run correctly refused to click an intentionally disabled label. The regression now asserts disabled state, then forces only the physical click attempt through Playwright's guard and verifies that the browser does not create an exclusion and the real API accepts the unchanged valid selection. No assertion removed. Screenshot capture uses instant scroll reset and checks geometry before capture, preventing CSS smooth-scroll from recording a transient sticky position.

The existing web workflow targets this review branch instead of the already merged public-first branch so tests can run while PR API access is blocked. CI and final review status are recorded after actual execution; a workflow definition alone is not a passing result. Existing security/release/real-Windows-acceptance gates remain open. No automatic merge.
