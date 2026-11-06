# configureMe Setup security

## Trust and provenance

The setup EXE and CI ZIP are unsigned development artifacts. A SHA-256 manifest or sidecar detects accidental changes but does not authenticate a publisher. Obtain builds only from a reviewed source commit and CI run; compare provenance through a separately trusted channel. Do not use these artifacts for public trust onboarding until a release-signing identity and verified release process exist.

The app embeds the catalog, bootstrap, and PowerShell modules. At startup it validates the embedded manifest, each resource hash and length, the extraction path, and existing extracted files. It checks the extracted resources again before each Windows PowerShell 5.1 worker run. Modified files and reparse-point paths are refused. This protects the runtime extraction against accidental or local file tampering; it does not create an independent trust anchor for an unsigned EXE.

The GUI sends only a bounded JSON request on the PowerShell worker's standard input. Package IDs are checked against the local catalog by both the app and worker. The worker starts from the bundled local script path with fixed arguments; package input is never composed into a shell command or evaluated as PowerShell. No runtime scripts are downloaded. The worker emits structured JSON-line events and writes the existing JSON and text reports.

## Installation boundaries

- The app starts as the current user (`asInvoker`) and never launches itself elevated. If a reviewed package needs administrator rights, restart the app elevated as the same Windows account. UAC credential entry for a different account changes the profile and can send per-user VS Code/Python setup to the wrong account; do not use **Run as different user**.
- Existing installs are detected and not automatically upgraded. Installations run one at a time. Cancel removes packages waiting in the queue; an active installer is allowed to finish.
- The GUI prepares at most two downloads at once, then installs packages one at a time. The PowerShell engine validates each HTTPS redirect before following it, hashes, installer type/architecture, and exact Authenticode signer. VS Code and .NET SDK require official SHA-256/SHA-512 metadata respectively before their package-specific x86-bootstrap/x64-payload authorization applies. Python requires the exact official stable 3.14 amd64 EXE URL and trusted PSF signer. Installed applications are independently verified as x64. The only unsigned-artifact policy is the exact official 7-Zip 25.01 x64 MSI with SHA-256 `e7eb0b7ed5efa4e087b7b17f191797f7af5b7f442d1290c66f3a21777005ef57`: `NotSigned` without a certificate is permitted only for that pin. Invalid/untrusted signatures always fail, including on 7-Zip. A failed hash never falls back to execution. Cache files undergo the same checks in both download preparation and installation.
- Docker Desktop is only inspected and never installed on Windows Server 2022. Teams uses a web fallback. Copilot Desktop uses the pinned signed official v1.1.34 Tauri NSIS installer silently for the current user; Copilot CLI remains manual. A real Windows Server 2022 installation test remains outstanding.
- The app does not change ExecutionPolicy, Defender, Git safe-directory settings, user credentials, or reboot state.

CI uses read-only repository permissions and mocks installer/process execution. It does not install Git, Docker, or other applications and does not replace a real Windows Server 2022 Desktop Experience GUI test.

## Build and startup boundaries

Manifest generation uses `-ExecutionPolicy Bypass` only on its noninteractive PowerShell build subprocess. This does not persist any policy change and does not affect installer verification or the runtime worker. Enforced organization MachinePolicy/UserPolicy can still prohibit unsigned scripts; do not attempt to bypass those controls.

Keep CET and Windows exploit protections enabled. Fully update Server 2022 and reboot before running .NET 10. The optional `Start-SetupWithDiagnostics.ps1` launcher runs on the built-in Windows PowerShell 5.1 runtime and can report a CoreCLR startup exit code; it cannot conclusively detect CET support or prove that the single-file apphost will initialize. It is included in package hashes but, like the EXE, is an unsigned development artifact. The EXE remains directly launchable without the wrapper.
