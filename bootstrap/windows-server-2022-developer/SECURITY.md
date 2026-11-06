# Security notes

## Trust and provenance

This repository currently has no trusted release-signing certificate or independent release-signing key. A packaged ZIP is therefore **unsigned and not approved for public trust onboarding**. A SHA-256 sidecar detects accidental changes only; it does not prove who published the ZIP. Obtain the ZIP from a reviewed CI run or build it from a reviewed Git commit, then compare the source and artifact hash through a separately trusted channel. Do not treat HTTPS or a checksum distributed beside the ZIP as a publisher signature.

The bootstrap itself is local and version-controlled. It does not fetch or execute PowerShell code, use `Invoke-Expression`, accept installer URLs or commands from profile data, or depend on a configureMe server. Each package definition declares its installer type; MSI/EXE file type and declared architecture are validated before execution. The Server 2022 Python path uses the official signed CPython 3.14 amd64 full EXE, without AppX deployment. Installed applications are independently checked as x64; narrowly declared x86 installer bootstrappers do not relax that check. MSI packages are passed to `msiexec.exe`, not started as executables. Source hosts and redirects are allowlisted, available official SHA-256/SHA-512 metadata is checked, and Authenticode must be valid for the expected publisher for MSI/EXE installers, except that the exact reviewed official 7-Zip 25.01 x64 MSI may be NotSigned without a certificate if its pinned SHA-256 matches. Invalid/untrusted signatures are never accepted. See windows/ConfigureMe.Setup/SECURITY.md for the pin and trust boundaries. TLS certificate validation is not disabled. Any mismatch prevents execution.

## Scope and side effects

- The target is Windows Server 2022 x64 Desktop Experience only. Server Core, other releases, and other architectures are rejected for installation.
- Existing versions are detected and left unchanged; no automatic upgrade is performed.
- A typed `YES` is required before installer or Windows Optional Capability changes. No reboot is requested.
- System-wide installers and OpenSSH Client require an elevated session. The bootstrap does not elevate itself; rerun it under the same Windows account, not `Run as different user`.
- Python uses the official signed stable CPython 3.14 x64 full installer with pip, per-user, without MSIX or install-manager commands. PEP 514 paths and real executable/version/pip checks avoid stale PATH and Store aliases. Existing verified supported x64 Python versions and virtual environments are not removed.
- Git is installed only when missing, from the official Git for Windows x64 release asset. The official asset digest is checked when available, the Authenticode signature must be valid with the exact signer common name `Johannes Schindelin`, and only the documented Inno Setup switches `/VERYSILENT /NORESTART /NOCANCEL /SP-` are used. Existing Git is never updated.
- VS Code's Dark Modern setting is merged for the current Windows user after a backup. JSONC/invalid settings are left unchanged with a manual instruction.
- Docker Desktop is only inspected if present. It is not supported on Windows Server 2022 and is never installed or reconfigured here.
- Copilot Desktop is a separate app from editor extensions. The pinned official v1.1.34 installer is a Tauri NSIS package for the current user. Its reviewed x86 bootstrap carries the x64 payload; only this exact package has the architecture exception. SHA-256 `4a8070a63b228895344a6c4f4536a01a62085e02821829b21786638234580e00`, the exact trusted `GitHub, Inc.` signer, and the case-sensitive `/S` switch are required. No `/R` app launch is requested. Existing installs stay untouched; Windows Server 2022 compatibility remains unproven until a real target test. Authenticate interactively and never provide tokens to the bootstrap.
- LibreOffice is an optional profile package, not selected by default. When selected, the official stable x64 MSI's published SHA-256 and valid `The Document Foundation` Authenticode signer are required before execution.
- Teams uses the web fallback. Copilot CLI remains optional and user-installed.
- GitHub and Microsoft sign-in are interactive user actions after setup. Credentials and tokens are never put in the archive or reports.

## Package manifest and CI

The generated ZIP contains `manifest.json`: bootstrap version, source commit SHA, whether the source worktree was dirty, and SHA-256 plus size for every packaged file. A clean CI build records the checked-out commit and `workingTreeDirty: false`. A ZIP built from a modified checkout records `true`; do not treat it as a commit-only build. The adjacent ZIP SHA-256 is useful for accidental-corruption checks only. The package and manifest are unsigned, have no independent trust anchor, and are not authorized for public trusted-release use. CI artifacts are transient validation outputs, not stable releases.
