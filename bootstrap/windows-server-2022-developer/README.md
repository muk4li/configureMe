# configureMe Windows Server 2022 Developer Quick Setup

This self-contained package targets **Windows Server 2022 x64 with Desktop Experience** and Windows PowerShell 5.1. It does not need configureMe, Node.js, Git, GitHub CLI, or WinGet to run. Internet access is needed only for verified vendor metadata and installers.

Open PowerShell in this extracted folder:

```powershell
.\bootstrap.ps1 -Profile windows-server-2022-developer -List
.\bootstrap.ps1 -Profile windows-server-2022-developer -DryRun -ReportPath .\setup-report.json
.\bootstrap.ps1 -Profile windows-server-2022-developer -ReportPath .\setup-report.json
```

The install run summarizes its actions and requires the exact response `YES` before starting an installer. Do not start PowerShell using **Run as different user**; the VS Code settings change is limited to the currently running user's profile. Nothing is upgraded when already detected. The script never disables execution policy, changes Git `safe.directory`, collects credentials, or initiates a reboot. If `RemoteSigned` blocks reviewed files marked as downloaded, inspect their origin and contents first, then use `Unblock-File` on the local `.ps1` and `.psm1` files; this does not change policy. Do not bypass an `AllSigned` or organization policy.

Automatic vendor installs are attempted only when the official source can be resolved, the file is HTTPS-downloaded with TLS validation, and its Authenticode signature is valid for the expected publisher. A source, signature, or publisher check failure refuses execution. The bootstrap does not require WinGet. Some packages have a manual fallback because a suitable Server 2022 route is not established.

The end-of-run report is JSON plus a sibling text file. It records the OS, versions, source, method, result, errors, restart indication, and manual steps; it does not record tokens or environment variables. Review both reports and complete the listed manual steps.

See [SECURITY.md](SECURITY.md) for provenance limits. The German quick start and vendor references are in the configureMe repository at `docs/quickstart-windows-server-2022.md`.
