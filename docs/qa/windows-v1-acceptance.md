# Windows-v1 target acceptance matrix

2026-11-14; instructions, **not executed clean-VM acceptance**. Existing CI exercises mocks, Windows GUI/PowerShell and embedded single-file startup. Real vendor installation and isolated target provisioning require explicit separate owner authorization. No production device, signing key or secrets in test data.

## Capture before execution

Create a fresh isolated VM snapshot per scenario. Record OS caption/build/UBR/install type/architecture/updates, desktop scaling/resolution, account and elevation context, artifact/source/engine/catalog/plan digests, independent signature status, global .NET/SDK/WinGet presence, installed application inventory and time. Keep system/private identifiers out of committed evidence. Use Hyper-V console/desktop, not just headless task success.

```powershell
# Read-only host evidence (save locally in the isolated test evidence directory).
Get-CimInstance Win32_OperatingSystem | Select-Object Caption,Version,BuildNumber,OSArchitecture
Get-ItemProperty 'HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion' | Select-Object CurrentBuildNumber,UBR,InstallationType
Get-FileHash -Algorithm SHA256 -LiteralPath .\configureMe-Setup.exe
Get-AuthenticodeSignature -LiteralPath .\configureMe-Setup.exe | Select-Object Status,StatusMessage
```

## Non-installing acceptance

| Scenario | Server 2022 x64 Desktop Experience | Windows 11 x64 | Evidence / expected result |
| --- | --- | --- | --- |
| Fully updated single-file cold startup, no global .NET/SDK/Node/Git | Required | Runtime start can be tested, does not authorize adapter | Explorer double-click and terminal from unrelated working directory, no CET/security bypass |
| GUI at 100/125/150/200%, 900x700/1280x720/1920x1080 | Required | Required before adapter registration | All labels/actions reachable; screenshots and physical scaling record |
| Public multi-profile JSON export → local fixed-drive import | Required | Current native import must refuse | Exact retained selection/dependencies, no installer/network process from import |
| Invalid version/target/arch/catalog/dependencies/duplicates/oversize/reparse/writer | Required | Required before registration | Atomic refusal, previous valid selection preserved, no privilege/installation |
| detect + offline plan with installed/missing/failed/manual/rights cases | Required | Candidate preparations only; actual host acceptance still blocked | Errors retained; detection is not proven architecture unless actual binary checked; no download/install |
| Cancel/replace/review again/manual mode | Required | After native adapter approval | Stale late results cannot authorize anything, existing manual selection confirmation unchanged |

After verifying the development EXE's origin manually, existing non-installing self-tests can be run on an isolated target (they create and clean temporary application files):

```powershell
.\configureMe-Setup.exe --self-test
if ($LASTEXITCODE -ne 0) { throw 'Embedded worker failed' }
.\configureMe-Setup.exe --layout-self-test
if ($LASTEXITCODE -ne 0) { throw 'Layout self-test failed' }
.\configureMe-Setup.exe --startup-layout-self-test
if ($LASTEXITCODE -ne 0) { throw 'Shell/message-loop startup failed' }
```

These commands are existing fixed self-test modes; they do not activate imported installation. No `--plan` CLI or Windows-11 registration is implied. GUI Dry-Run writes local cache/reports; distinguish those from system configuration changes.

## Separately authorized real installation matrix

For each approved package and target, restore the snapshot, perform one confirmed manual/approved imported installation, verify actual version/x64 binary, and rerun to prove skip behavior. VS Code per-user path, .NET SDK `Program Files\dotnet\dotnet.exe --list-sdks` with stale PATH, Python version/64-bit/pip and 7-Zip x64 are mandatory. Test non-admin/per-user versus administrator-required packages, reboot-required exit codes, source/hash/signature refusals, offline/network failure, cancelled queue versus active installer completion, partial failure, and repeat with accurate reports. Windows 11 strategies need their own evidence; generic Windows support or Server results do not substitute.

Do not automatically uninstall, downgrade, restart, elevate or weaken OS protections. Capture sanitized reports and final observed application architecture; hash alone is not provenance. A clean-VM result with unsigned development EXE is not a signed public release. CM-005 remains Blocked until environment, explicit real-install authorization and complete evidence exist.
