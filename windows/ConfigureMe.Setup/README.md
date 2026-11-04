# configureMe Setup

`configureMe-Setup.exe` is a native Windows Forms application for Windows Server 2022 x64 with Desktop Experience. It is published self-contained for `win-x64`; no .NET runtime, Git, WinGet, Node.js, or configureMe web server is required to open the GUI. Windows PowerShell 5.1 is included with the supported target and remains the installer worker.

The GUI detects the operating system and installed packages, supports a Developer profile and individual selections, shows a reviewed plan before changes, and processes package installations serially. Detection and package status are reported as structured JSON-line events from the local PowerShell worker. Existing JSON and text installation reports remain available and can be exported from the UI.

The app and its trusted PowerShell modules/catalog are embedded in the EXE. The app extracts those resources under `%LOCALAPPDATA%\configureMe\engine\<manifest-hash>` and verifies each resource's SHA-256 and length before launching the worker. A changed extracted file or reparse-point directory is refused. The EXE is a single-file publish; the .NET host may extract native runtime components to its temporary directory at startup. The embedded PowerShell engine is extracted to the per-user location above, so the complete runtime footprint is not a single file.

Run the app as the intended Windows user. VS Code and Python runtime setup remain per-user. A system-wide installer or OpenSSH Client requires administrator rights; close the app and run it elevated using the **same account**. Do not use **Run as different user**, which would switch the user profile used by per-user installers. The app does not elevate itself or change ExecutionPolicy, Defender, or other security settings. An active installer is allowed to finish; cancel removes only packages still waiting in the queue.

Docker Desktop is detection-only and is not installed on Windows Server. Teams opens its web app. Copilot Desktop and Copilot CLI remain manual actions. GitHub sign-in is interactive.

## Build and tests

From the repository root on Windows with the .NET 10 SDK:

```powershell
dotnet test windows\ConfigureMe.Setup.Tests\ConfigureMe.Setup.Tests.csproj --configuration Release
dotnet publish windows\ConfigureMe.Setup\ConfigureMe.Setup.csproj --configuration Release -p:PublishProfile=win-x64 -o dist\configureMe-Setup
powershell.exe -NoProfile -NonInteractive -File scripts\New-SetupReleasePackage.ps1 -PublishDirectory dist\configureMe-Setup -OutputPath dist\configureMe-Setup-win-x64.zip
```

CI packages the EXE, this README, `SECURITY.md`, version metadata, a per-file SHA-256 manifest, and an archive checksum as an unsigned development artifact. The checksum detects accidental corruption only; it is not publisher authentication. No stable GitHub Release is published.

The Windows CI runner validates the build, worker contract, queue/controller tests, and package contents. It does not install third-party applications or prove an interactive GUI run on a clean Windows Server 2022 Desktop Experience host. That platform-specific GUI/E2E check remains outstanding until performed on the target system.
