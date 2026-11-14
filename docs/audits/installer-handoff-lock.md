# CM-006 narrow handoff mitigation review

## Confirmed baseline and scope

On the verified configureMe checkout after PR #12, `Invoke-QuickSetupPackageInstall` validates an installer, emits progress callbacks, then starts the path. The existing out-of-repository reproduction changed a synthetic x64 PE after `verification-completed`; its mock ProcessRunner observed different bytes. Reproduced with PowerShell 7, no executable launched or actual signature bypassed. This is a confirmed mock-level handoff defect, not an elevated Windows exploit demonstration.

The prepared patch holds an `IO.FileStream` opened for Read with FileShare.Read before verification through the synchronous installer wait. On Windows this denies compatible writers and delete/replacement of that file. Existing hash, source, executable-type, architecture, narrowly authorized bootstrapper and signature checks all still run while locked. The handle is released in finally before removing only the invocation's own temporary directory. Shared cache files are not deleted by the new code. No retry/unlock fallback or changed signature policy.

## Validation

- `git apply --check /tmp/configureme-handoff.patch`: passes.
- Staged copy of existing installer-regressions with the patch: 86 existing portable assertions passed. New Windows sharing tests explicitly print NOT EXECUTED on Linux; POSIX advisory locks are not a Windows proof.
- Required Windows checks: the existing PS5.1 and PS7 installer-regressions CI invocations exercise successful read-only handoff and exit/reboot propagation, attempted callback writes at both post-verification stages (must throw before any runner call and retain original digest), preexisting writer refusal, and lock release on success/error. No third-party installer or administrator rights required.
- Real installer compatibility, ACL/integrity-level behavior, separate-process raw writes and genuine privileged target acceptance are not established by these fixtures.

## Remaining risk / status

Do not mark full CM-006 Done based on this file lock. FileShare.Read locks the opened file, not all ancestor directory identities. Mutable parent directories can still be renamed/rebound between path checks and process path resolution; current safe-path traversal is check-based rather than an atomic anchored namespace. A complete follow-up needs final-handle identity verification and deletion-blocking ancestor handles (or a reviewed private staging/ACL/integrity strategy), separate-process junction/replacement tests, and approved compatibility/privilege testing. Same-user process compromise and privileged adversaries are not solved. Existing TEMP/cache ownership/ACL assumptions and cleanup behavior remain relevant. Keep these residual risks explicit and public release trust blocked.

## CM-010 follow-up recommendation (not in patch)

The download helper validates the final redirect URI but discards it on returning Destination; the verified install result returns exit/restart only. Optional additive provenance sink can preserve compatibility while recording configured/observed final URI (query/fragment/userinfo stripped), expected metadata digests, measured locked-artifact SHA256/length and signature state/publisher/policy. Cached artifacts must say cached + configured source + measured digest, not invent a previously observed final URI. Add this record to install result, worker result, aggregate reports and mocked error-path tests; bind build/source metadata separately and never call a digest proof of publisher identity. This is a separate producer/consumer change, intentionally not mixed into the lock patch.

## Executed Windows acceptance (mock scope)

2026-11-14: [full Windows CI 43564614212](https://github.com/muk4li/configureMe/actions/runs/43564614212) for `d5c6a52` succeeded. Both PS5.1 and PS7 ran the new deny-write/delete mutation/writer/release fixtures; three complete GUI/controller/engine suites, portable suite, restrictive-policy single-file publication and embedded/self/layout startup checks all passed. No real installer ran. CM-036 narrow contents-lock scope Done; comprehensive CM-006 remains In Progress because ancestor namespace/ACL/privileged compatibility acceptance is still open. Final follow-up changes docs/task evidence and removes the temporary branch trigger only. Main/PR/manual triggers retained.
