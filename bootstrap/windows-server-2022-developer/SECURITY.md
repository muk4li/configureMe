# Security notes

## Trust and provenance

This repository currently has no trusted release-signing certificate or independent release-signing key. A packaged ZIP is therefore **unsigned and not approved for public trust onboarding**. A SHA-256 sidecar detects accidental changes only; it does not prove who published the ZIP. Obtain the ZIP from a reviewed CI run or build it from a reviewed Git commit, then compare the source and artifact hash through a separately trusted channel. Do not treat HTTPS or a checksum distributed beside the ZIP as a publisher signature.

The bootstrap itself is local and version-controlled. It does not fetch or execute PowerShell code, use `Invoke-Expression`, accept installer URLs or commands from profile data, or depend on a configureMe server. Each package definition declares its installer type; MSI/EXE file type and declared architecture are validated before execution. The Python install manager MSIX package identity and architecture are checked before deployment; Windows validates its package signature through `Add-AppxPackage`. MSI packages are passed to `msiexec.exe`, not started as executables. Source hosts and redirects are allowlisted, available official SHA-256/SHA-512 metadata is checked, and Authenticode must be valid for the expected publisher for MSI/EXE installers. TLS certificate validation is not disabled. Any mismatch prevents execution.

## Scope and side effects

- The target is Windows Server 2022 x64 Desktop Experience only. Server Core, other releases, and other architectures are rejected for installation.
- Existing versions are detected and left unchanged; no automatic upgrade is performed.
- A typed `YES` is required before installer or Windows Optional Capability changes. No reboot is requested.
- System-wide installers and OpenSSH Client require an elevated session. The bootstrap does not elevate itself; rerun it under the same Windows account, not `Run as different user`.
- Python uses the official x64 Python install manager MSIX and its documented per-user runtime installation command. The package publisher and architecture are checked before deployment; Windows validates the package signature. Existing Python versions and virtual environments are not removed.
- Git is installed only when missing, from the official Git for Windows x64 release asset. The official asset digest is checked when available, the Authenticode signature must be valid with the exact signer common name `Johannes Schindelin`, and only the documented Inno Setup switches `/VERYSILENT /NORESTART /NOCANCEL /SP-` are used. Existing Git is never updated.
- VS Code's Dark Modern setting is merged for the current Windows user after a backup. JSONC/invalid settings are left unchanged with a manual instruction.
- Docker Desktop is only inspected if present. It is not supported on Windows Server 2022 and is never installed or reconfigured here.
- Copilot Desktop is a separate app from editor extensions. The official Windows x64 release EXE has no verified documented silent switches or per-user installation behavior, so it remains interactive and manual. Windows Server 2022 compatibility is not asserted and requires explicit optional confirmation; authenticate interactively and never provide tokens to the bootstrap.
- LibreOffice is an optional profile package, not selected by default. When selected, the official stable x64 MSI's published SHA-256 and valid `The Document Foundation` Authenticode signer are required before execution.
- Teams uses the web fallback. Copilot CLI remains optional and user-installed.
- GitHub and Microsoft sign-in are interactive user actions after setup. Credentials and tokens are never put in the archive or reports.

## Package manifest and CI

The generated ZIP contains `manifest.json`: bootstrap version, source commit SHA, whether the source worktree was dirty, and SHA-256 plus size for every packaged file. A clean CI build records the checked-out commit and `workingTreeDirty: false`. A ZIP built from a modified checkout records `true`; do not treat it as a commit-only build. The adjacent ZIP SHA-256 is useful for accidental-corruption checks only. The package and manifest are unsigned, have no independent trust anchor, and are not authorized for public trusted-release use. CI artifacts are transient validation outputs, not stable releases.
