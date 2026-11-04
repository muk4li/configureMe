# configureMe Setup security

## Trust and provenance

The setup EXE and CI ZIP are unsigned development artifacts. A SHA-256 manifest or sidecar detects accidental changes but does not authenticate a publisher. Obtain builds only from a reviewed source commit and CI run; compare provenance through a separately trusted channel. Do not use these artifacts for public trust onboarding until a release-signing identity and verified release process exist.

The app embeds the catalog, bootstrap, and PowerShell modules. At startup it validates the embedded manifest, each resource hash and length, the extraction path, and existing extracted files. It checks the extracted resources again before each Windows PowerShell 5.1 worker run. Modified files and reparse-point paths are refused. This protects the runtime extraction against accidental or local file tampering; it does not create an independent trust anchor for an unsigned EXE.

The GUI sends only a bounded JSON request on the PowerShell worker's standard input. Package IDs are checked against the local catalog by both the app and worker. The worker starts from the bundled local script path with fixed arguments; package input is never composed into a shell command or evaluated as PowerShell. No runtime scripts are downloaded. The worker emits structured JSON-line events and writes the existing JSON and text reports.

## Installation boundaries

- The app starts as the current user (`asInvoker`) and never launches itself elevated. If a reviewed package needs administrator rights, restart the app elevated as the same Windows account. UAC credential entry for a different account changes the profile and can send per-user VS Code/Python setup to the wrong account; do not use **Run as different user**.
- Existing installs are detected and not automatically upgraded. Installations run one at a time. Cancel removes packages waiting in the queue; an active installer is allowed to finish.
- The GUI prepares at most two downloads at once, then installs packages one at a time. The PowerShell engine validates each HTTPS redirect before following it, hashes, installer type/architecture, and exact Authenticode signer. A failed hash or signature never falls back to execution.
- Docker Desktop is only inspected and never installed on Windows Server 2022. Teams uses a web fallback. Copilot Desktop uses the pinned signed official v1.1.34 Tauri NSIS installer silently for the current user; Copilot CLI remains manual. A real Windows Server 2022 installation test remains outstanding.
- The app does not change ExecutionPolicy, Defender, Git safe-directory settings, user credentials, or reboot state.

CI uses read-only repository permissions and mocks installer/process execution. It does not install Git, Docker, or other applications and does not replace a real Windows Server 2022 Desktop Experience GUI test.
