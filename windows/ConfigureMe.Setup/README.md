# configureMe Setup

`configureMe-Setup.exe` is a native Windows Forms application for Windows Server 2022 x64 with Desktop Experience. It is published self-contained for `win-x64`; no .NET runtime, Git, WinGet, Node.js, or configureMe web server is required to open the GUI. Windows PowerShell 5.1 is included with the supported target and remains the installer worker.

The GUI detects the operating system and installed packages, supports a Developer profile and individual selections, shows a reviewed plan before changes, downloads up to two installers at a time, and processes installations serially. Detection and package status are reported as structured JSON-line events from the local PowerShell worker. A unique JSON and text report for each GUI run includes all selected packages, failed downloads, cancellations, and manual steps; it can be exported from the UI. Dry runs also produce a report.

The app and its trusted PowerShell modules/catalog are embedded in the EXE. The app extracts those resources under `%LOCALAPPDATA%\configureMe\engine\<manifest-hash>` and verifies each resource's SHA-256 and length before launching the worker. A changed extracted file or reparse-point directory is refused. The EXE is a single-file publish; the .NET host may extract native runtime components to its temporary directory at startup. The embedded PowerShell engine is extracted to the per-user location above, so the complete runtime footprint is not a single file.

Run the app as the intended Windows user. VS Code and Python runtime setup remain per-user. A system-wide installer or OpenSSH Client requires administrator rights; close the app and run it elevated using the **same account**. Do not use **Run as different user**, which would switch the user profile used by per-user installers. The app does not elevate itself or change ExecutionPolicy, Defender, or other security settings. An active installer is allowed to finish; cancel removes only packages still waiting in the queue.

Docker Desktop is detection-only and is not installed on Windows Server. Teams opens its web app. Copilot Desktop installs automatically after Git when missing, using a pinned verified current-user installer; Copilot CLI remains manual. GitHub sign-in is interactive.

## Build and tests

From the repository root on Windows with the .NET 10 SDK:

```powershell
dotnet test windows\ConfigureMe.Setup.Tests\ConfigureMe.Setup.Tests.csproj --configuration Release
dotnet publish windows\ConfigureMe.Setup\ConfigureMe.Setup.csproj --configuration Release -p:PublishProfile=win-x64 -o dist\configureMe-Setup
powershell.exe -NoProfile -NonInteractive -File scripts\New-SetupReleasePackage.ps1 -PublishDirectory dist\configureMe-Setup -OutputPath dist\configureMe-Setup-win-x64.zip
```

CI packages the EXE, this README, `SECURITY.md`, version metadata, a per-file SHA-256 manifest, and an archive checksum as an unsigned development artifact. The metadata records whether the source checkout had uncommitted changes. The checksum detects accidental corruption only; it is not publisher authentication. No stable GitHub Release is published.

The Windows CI runner validates the build, worker contract, queue/controller tests, and package contents. It does not install third-party applications or prove an interactive GUI run on a clean Windows Server 2022 Desktop Experience host. That platform-specific GUI/E2E check remains outstanding until performed on the target system.

The published EXE also runs `--layout-self-test` in CI. This checks the native package rows, category bounds, vertical scrolling, resize, and simulated scale without installing software. Follow the [Windows Server 2022 GUI retest](../../docs/windows-setup-0.3.0-retest.md) for visual inspection and a real installer run on the target machine.

On Linux, the non-UI engine, queue, and report tests can run with .NET 10 SDK and PowerShell 7 using `dotnet test windows/ConfigureMe.Setup.Portable.Tests/ConfigureMe.Setup.Portable.Tests.csproj`; the WinForms app can be cross-compiled but not executed there.

## Server 2022 updates and early startup diagnostics

Install **all available Windows Server 2022 cumulative updates**, reboot the VM, and complete any pending restart before launching the self-contained .NET 10 EXE. Keep Hyper-V host updates/CPU compatibility current. There is no verified minimum KB/UBR or reliable managed preflight for this CET issue; do not disable CET or exploit protections. The reported `0x80131506`/`coreclr.dll` crash occurred before `Main`, so a WinForms catch block cannot intercept it. A successful non-single-file launch after updating Windows does **not** validate the production single-file apphost. That production artifact still requires the clean-VM test below.

The packaged optional `Start-SetupWithDiagnostics.ps1` runs before .NET 10 using Windows PowerShell 5.1, warns about known pending-reboot markers and, after a failed launch, shows an actionable message for `0x80131506`. That exit code can have other causes; inspect Application event logs too. It does not install .NET or updates, change CET, elevate, or alter policy. Launch the EXE directly normally; for diagnosis run `powershell.exe -NoProfile -File .\Start-SetupWithDiagnostics.ps1`. Follow your organization's script policy; do not permanently relax it.

The manifest build target now quotes the PowerShell executable and script/output paths and adds process-scoped `-ExecutionPolicy Bypass` itself. The standard publish command above needs no execution-policy property workaround. To select PowerShell 7, pass only its executable path, e.g. `-p:PowerShellExecutable="C:\Program Files\PowerShell\7\pwsh.exe"`, **not** a string containing command-line options. Group-policy-enforced MachinePolicy/UserPolicy may still block unsigned build scripts and must be handled through your administrator.

Package corrections: VS Code uses its official stable `win32-x64-user` metadata and mandatory SHA-256; the .NET 10 SDK uses `win-x64` SDK metadata and mandatory SHA-512. Both retain trusted Microsoft Authenticode verification while explicitly allowing their x86 installer bootstrappers. Python uses the official signed stable CPython 3.14 amd64 full installer rather than MSIX, installing pip per-user without the optional launcher. 7-Zip uses a reviewed pinned x64 MSI; see SECURITY.md for the exact narrowly scoped unsigned-artifact policy. Success requires installed executable architecture and version checks, plus pip for Python and `--list-sdks` for .NET; PATH is not the source of truth.

Run `powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests\installer-regressions.ps1` for mocked package security regressions. Layout tests and `--layout-self-test` check button text dimensions/overlaps at simulated 100/125/150/200% and multiple viewport sizes; real DPI/desktop tests remain necessary. See [target VM acceptance steps](../../docs/windows-setup-0.3.0-retest.md).

## .NET signer and VS Code post-install verification

The official .NET SDK 10.0.403 Windows x64 installer is signed with **CN=.NET, O=Microsoft Corporation** (verified against the downloaded official release SHA-512). This exact CN and organization are required for the .NET package, in addition to Windows' valid Authenticode trust result and the official SHA-512. This does not permit `.NET` certificates from other organizations or change signers for other packages.

VS Code detection reads the installed x64 `Code.exe` product name/version and requires an identical stable version in `resources\app\package.json`. It does not launch Electron or `code.cmd` in the hidden worker. Default user/system paths and Microsoft VS Code uninstall registrations are supported. Post-install detection retries up to ten times at two-second intervals to allow final file/registration writes; failed verification remains a failure, and no installer is re-run by these retries.

## Optional Codex Desktop helper

The release ZIP also includes `Install-CodexDesktop.ps1`. From that extracted directory:

```powershell
powershell.exe -NoProfile -File .\Install-CodexDesktop.ps1 -DryRun
powershell.exe -NoProfile -File .\Install-CodexDesktop.ps1
powershell.exe -NoProfile -File .\Install-CodexDesktop.ps1 -VerifyOnly
```

From a repository checkout use `scripts\Install-CodexDesktop.ps1` instead. The helper emits JSON and uses the same official [Windows Store installer/product](https://github.com/openai/codex/blob/main/codex-rs/cli/src/desktop_app/windows.rs) as OpenAI's `codex app`: product `9PLM9XGG6VKS`, package `OpenAI.Codex`. It never installs Codex CLI as a substitute.

**Windows Server 2022 does not include Microsoft Store. A supported unattended Codex Desktop installation on that target has not been established.** When the Store is absent, the helper returns `codex-store-unavailable`, exit code **2**, and runs no installer. It does not add Store components, fetch unofficial MSIX packages or bypass OS requirements. If a working Store is already present, it can open the official interactive installation route; complete that installation and rerun `-VerifyOnly`. Opening the installer is still exit code 2, not success. Only a registered, healthy, Store-signed x64 `OpenAI.Codex` package counts as already installed (exit 0). Actual script errors return 1; dry runs/WhatIf return 0 without an installation claim. Existing installs are preserved. This helper is optional and independent of the self-contained EXE.
