# configureMe Windows Server 2022 Developer Quick Setup

This self-contained package targets **Windows Server 2022 x64 with Desktop Experience** and Windows PowerShell 5.1. It does not need configureMe, Node.js, Git, GitHub CLI, or WinGet to run. Internet access is needed only for verified vendor metadata and installers.

The automated packages are Git, GitHub CLI, VS Code, Node.js LTS, Python, .NET 10 SDK, PowerShell 7, 7-Zip, Firefox, and GitHub Copilot Desktop. Git is installed only when missing, and its official x64 EXE requires the exact `Johannes Schindelin` Authenticode signer plus official release hash metadata when available. Copilot Desktop depends on Git and uses the pinned official v1.1.34 Windows installer with SHA-256 and exact `GitHub, Inc.` signer checks. The reviewed Tauri NSIS installer uses its case-sensitive `/S` silent switch for the current Windows user; sign-in remains interactive. Windows Server 2022 compatibility still requires a real target test. LibreOffice is optional and not included in the default profile. OpenSSH Client uses the Windows Capability API and requires an elevated session. Docker Desktop is never installed.

Open Windows PowerShell 5.1 in this extracted folder:

```powershell
.\bootstrap.ps1 -Profile windows-server-2022-developer -List
.\bootstrap.ps1 -Profile windows-server-2022-developer -DryRun -ReportPath .\setup-report.json
.\bootstrap.ps1 -Profile windows-server-2022-developer -ReportPath .\setup-report.json
```

The install run summarizes its actions and requires the exact response `YES` before starting an installer. Do not start PowerShell using **Run as different user**; the VS Code settings change is limited to the currently running user's profile. Nothing is upgraded when already detected. The script never disables execution policy, changes Git `safe.directory`, collects credentials, or initiates a reboot. If `RemoteSigned` blocks reviewed files marked as downloaded, inspect their origin and contents first, then use `Unblock-File` on the local `.ps1` and `.psm1` files; this does not change policy. Do not bypass an `AllSigned` or organization policy.

Automatic vendor installs are attempted only when the official source can be resolved and installer bytes match the explicitly declared MSI, EXE, or MSIX type and expected architecture. Downloads use HTTPS with TLS validation, hosts checked before each redirect, available official hashes, and the exact expected Authenticode signer common name. Git uses only `/VERYSILENT /NORESTART /NOCANCEL /SP-`; Copilot Desktop uses only `/S` and permits the reviewed x86 NSIS bootstrap carrying its x64 payload. If LibreOffice is selected in the local profile, its official stable x64 MSI is checked against the Document Foundation SHA-256 metadata, allowed mirror list, MSI architecture, and `The Document Foundation` Authenticode identity. Python on this Server 2022 profile uses the official signed CPython 3.14 x64 full EXE, with `/quiet /norestart InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_test=0 Include_launcher=0`, without AppX deployment or install-manager aliases. It detects a working supported x64 CPython (3.11+) and pip through PEP 514 registration even when PATH is stale. VS Code and .NET SDK allow an x86 bootstrapper only for their explicitly authorized x64 release metadata; installed executables must still be x64. 7-Zip uses the pinned official 25.01 x64 MSI and its reviewed SHA-256; only `NotSigned` without a certificate is allowed for those exact bytes, while invalid/untrusted signatures still fail. MSI packages are started with `msiexec.exe`; EXE packages use their package-specific arguments. A mismatch refuses execution. The bootstrap does not require WinGet. Some packages remain manual because a safe Server 2022 route is not established.

The end-of-run report is JSON plus a sibling text file. It records the OS, versions, source, method, result, errors, restart indication, and manual steps; it does not record tokens or environment variables. Review both reports and complete the listed manual steps.

The ZIP contains `manifest.json` with the bootstrap version, source commit, dirty-tree flag, and SHA-256/size for each packaged source file. The adjacent `.sha256` covers the ZIP only and is not a signature. The CI artifact is produced by the `Windows Quick Setup validation` workflow; no public GitHub Release is created.

See [SECURITY.md](SECURITY.md) for provenance limits. The German quick start and vendor references are in the configureMe repository at `docs/quickstart-windows-server-2022.md`.
