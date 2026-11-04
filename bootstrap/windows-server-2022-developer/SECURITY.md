# Security notes

## Trust and provenance

This repository currently has no trusted release-signing certificate or independent release-signing key. A packaged ZIP is therefore **unsigned and not approved for public trust onboarding**. A SHA-256 sidecar detects accidental changes only; it does not prove who published the ZIP. Obtain the ZIP from the reviewed repository release or build it from a reviewed Git commit, then compare the source and artifact hash through a separately trusted channel. Do not treat HTTPS or a checksum distributed beside the ZIP as a publisher signature.

The bootstrap itself is local and version-controlled. It does not fetch or execute PowerShell code, use `Invoke-Expression`, accept installer URLs or commands from profile data, or depend on a configureMe server. For packages it does install, source locations are fixed in the reviewed module, redirect hosts are allowlisted, downloaded files are checked for a valid Windows Authenticode signature and expected publisher, and available official SHA-256 metadata is checked. TLS certificate validation is not disabled. Any mismatch prevents execution.

## Scope and side effects

- The target is Windows Server 2022 x64 Desktop Experience only. Server Core, other releases, and other architectures are rejected for installation.
- Existing versions are detected and left unchanged; no automatic upgrade is performed.
- A typed `YES` is required before installer or Windows Optional Capability changes. No reboot is requested.
- OpenSSH Client is installed only through the Windows-serviced capability after confirmation and requires an elevated session.
- VS Code's Dark Modern setting is merged for the current Windows user after a backup. JSONC/invalid settings are left unchanged with a manual instruction.
- Docker Desktop is only inspected if present. It is not supported on Windows Server 2022 and is never installed or reconfigured here.
- Copilot Desktop is a separate app from editor extensions. Its installer/support status must be reviewed manually. Teams uses the web fallback. Copilot CLI remains optional and user-installed.
- Git and Python remain manual. This release does not rely on an undocumented silent switch or install the Python Install Manager/MSIX on Server 2022.
- GitHub and Microsoft sign-in are interactive user actions after setup. Credentials and tokens are never put in the archive or reports.
