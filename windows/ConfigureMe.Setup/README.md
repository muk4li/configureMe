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
