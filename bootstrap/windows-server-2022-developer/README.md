# configureMe Windows Server 2022 Developer Quick Setup

This self-contained package targets **Windows Server 2022 x64 with Desktop Experience** and Windows PowerShell 5.1. It does not need configureMe, Node.js, Git, GitHub CLI, or WinGet to run. Internet access is needed only for verified vendor metadata and installers.

The automated packages are GitHub CLI, VS Code, Node.js LTS, Python, .NET 10 SDK, PowerShell 7, 7-Zip, and Firefox. Git remains a manual install because this bootstrap has not verified an authoritative supported silent command line and pinned signer identity for its official x64 EXE. OpenSSH Client uses the Windows Capability API and requires an elevated session. Docker Desktop is never installed.

Open Windows PowerShell 5.1 in this extracted folder:

```powershell
.\bootstrap.ps1 -Profile windows-server-2022-developer -List
.\bootstrap.ps1 -Profile windows-server-2022-developer -DryRun -ReportPath .\setup-report.json
.\bootstrap.ps1 -Profile windows-server-2022-developer -ReportPath .\setup-report.json
```

The install run summarizes its actions and requires the exact response `YES` before starting an installer. Do not start PowerShell using **Run as different user**; the VS Code settings change is limited to the currently running user's profile. Nothing is upgraded when already detected. The script never disables execution policy, changes Git `safe.directory`, collects credentials, or initiates a reboot. If `RemoteSigned` blocks reviewed files marked as downloaded, inspect their origin and contents first, then use `Unblock-File` on the local `.ps1` and `.psm1` files; this does not change policy. Do not bypass an `AllSigned` or organization policy.

Automatic vendor installs are attempted only when the official source can be resolved and installer bytes match the explicitly declared MSI, EXE, or MSIX type and expected architecture. Downloads use HTTPS with TLS validation, allowlisted redirect hosts, available official hashes, and the expected Authenticode publisher. The Python install manager MSIX identity is checked before Windows validates its package signature through `Add-AppxPackage`; its documented `pymanager install default` command then installs the current stable Python runtime per-user. MSI packages are started with `msiexec.exe`; EXE packages use their package-specific arguments. A mismatch refuses execution. The bootstrap does not require WinGet. Some packages remain manual because a safe Server 2022 route is not established.

The end-of-run report is JSON plus a sibling text file. It records the OS, versions, source, method, result, errors, restart indication, and manual steps; it does not record tokens or environment variables. Review both reports and complete the listed manual steps.

The ZIP contains `manifest.json` with the bootstrap version, source commit, dirty-tree flag, and SHA-256/size for each packaged source file. The adjacent `.sha256` covers the ZIP only and is not a signature. The CI artifact is produced by the `Windows Quick Setup validation` workflow; no public GitHub Release is created.

See [SECURITY.md](SECURITY.md) for provenance limits. The German quick start and vendor references are in the configureMe repository at `docs/quickstart-windows-server-2022.md`.
