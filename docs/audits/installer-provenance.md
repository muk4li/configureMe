# CM-010 narrow artifact provenance patch

Base: **d5c6a52** (`fix/installer-handoff-lock`), not plain main. Patch: `/tmp/configureme-provenance.patch` (29,225 bytes). No repository or Git changes performed by this agent.

## Additive contract

`Get-QuickSetupOfficialDownload` keeps returning only the destination string. Optional `[ref]$Provenance` captures source kind, configured URI and the final URI actually observed and already validated by its existing source checks. A shared URI sanitizer strips userinfo, query and fragment, accepts HTTPS only. Sanitization does not replace allowlist/TLS/redirect validation.

`Assert-QuickSetupInstallerSignature` keeps normal stdout unchanged. Optional `[ref]$Verification` captures the same successful signature call's status, policy, public signer subject and thumbprint; the provider is not invoked a second time. The pinned 7-Zip exception is explicitly NotSigned/pinned policy, never Valid. Invalid/untrusted signatures still throw without publishing successful verification metadata.

`Assert-QuickSetupDownloadedInstaller` keeps normal stdout unchanged. Optional verification output contains measured SHA256, length, expected SHA256/SHA512, installer file type/architecture and the successful signature result. On the installation path, the original path-based digest is retained and compared with the held-stream digest; any mismatch aborts before signer validation or process continuation. Expected hashes must still match. SHA256 stream/path binding is performed before signature checking even when no vendor digest is supplied, and the stream position is restored. Recorded SHA256/length come from the bound held stream. Existing file-type, architecture, source-specific bootstrap and signature checks remain. This does not solve mutable ancestor namespace risks from CM-006. MSIX records DeploymentValidationPending because manifest/signature presence is not Windows deployment trust.

`Invoke-QuickSetupPackageInstall` adds Provenance to its normal result and an optional ref sink populated only after successful verification. Cached files record cached + redacted configured URI + null observed final URI; no previous download provenance is invented. The sink survives a later runner/process exception so worker/standalone reports retain verified artifact evidence alongside failure status. Exit/reboot behavior remains unchanged. Windows capability operations have no fabricated artifact/hash record.

Both existing report producers receive additive Provenance. The native aggregate already clones complete worker data; its implementation need not change. A portable C# regression verifies that artifact metadata survives worker-error enrichment and serialization. Existing DetectedVersion remains a separate post-install result, not the artifact's metadata version.

## Tests actually executed in a staged copy

- Full patched installer-regressions.ps1 on PowerShell 7/Linux: **86 existing assertions + 25 provenance assertions passed**.
- Windows lock cases explicitly **NOT EXECUTED** on Linux; preserve existing PS5.1/PS7 CI checks.
- quicksetup-portable.ps1: passed.
- Patch apply-check against d5c6a52 file copies: passed.
- New provenance test on unchanged d5c6a52 fails because the new provenance URI helper is absent (feature not implemented); no claim this is a new security exploit reproduction.
- New C# aggregate test prepared, **not executed by this agent**; root must cross-build/run the full existing Windows/portable CI.

The new provenance script runs from the existing installer-regressions script, so both existing Windows shell CI invocations exercise it without workflow restructuring. Cases cover actual fixture SHA/size, unchanged return/stdout, exactly one signature provider call, source/final URI redaction, cached-no-invented-final URI, successful/reboot/failed result semantics, verified evidence retention after process failure, and no trusted evidence after hash/signature refusal. Existing mutation-denial fixtures remain intact.

## Remaining CM-010 and release work

This is artifact-level local verification evidence, **not independent publisher provenance** and not comprehensive CM-010 completion. No build source SHA/toolchain linkage is added; exact detected application architecture has no new dedicated report field; metadata version versus installed version remains distinguished; cache download history is unknown; failed verification does not currently emit partial untrusted artifact evidence. Text summary output stays unchanged; full additive provenance is in JSON/worker/aggregate reports. Dynamic vendor resolutions remain dynamic. Source commit binding, build provenance/attestation, actual Windows installer compatibility, redaction review for any future path-encoded secrets, independent signing/verification and real target-system acceptance remain separate work/gates. No real downloads, installers, signers or secrets were used.

## Files

- bootstrap/windows-server-2022-developer/modules/Downloads.psm1
- bootstrap/windows-server-2022-developer/modules/Installation.psm1
- bootstrap/windows-server-2022-developer/modules/Logging.psm1
- bootstrap/windows-server-2022-developer/modules/GuiWorker.psm1
- bootstrap/windows-server-2022-developer/bootstrap.ps1
- tests/installer-regressions.ps1
- tests/installer-provenance.ps1 (new)
- tests/worker-callback-fixture.ps1
- windows/ConfigureMe.Setup.Portable.Tests/SetupRunReportTests.cs

## Stream/path binding review correction

The first proposal replaced expected path hashing with stream hashing, which could authorize A's expected bytes while B was resolved by the path. This was rejected in root review and is not the delivered behavior. The revised helper always retains `Get-FileHash` of the path, computes the stream hash, and refuses divergence before signature validation. A deterministic two-file regression covers vendor-digest-present and no-vendor-digest cases; the earlier proposal fails with “A mismatched locked stream/path reached signer or process continuation.” Revised staged checks pass 86 existing + 25 provenance assertions. Residual *post-check* ancestor rebind risk remains CM-006 work; this correction does not claim an atomic anchored executable namespace.
