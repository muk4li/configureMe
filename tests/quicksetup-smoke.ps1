$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$packageRoot = Join-Path $repositoryRoot "bootstrap\windows-server-2022-developer"
$moduleRoot = Join-Path $packageRoot "modules"
$temporaryDirectory = Join-Path $env:TEMP ("configureMe-smoke-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null

function Assert-True {
  param([bool]$Condition, [string]$Message)
  if (!$Condition) { throw $Message }
}

try {
  $filesToParse = @(
    (Join-Path $packageRoot "bootstrap.ps1"),
    (Join-Path $repositoryRoot "scripts\New-WindowsServer2022QuickSetup.ps1"),
    $PSCommandPath
  ) + @(Get-ChildItem -LiteralPath $moduleRoot -Filter "*.psm1" | ForEach-Object { $_.FullName })
  foreach ($file in $filesToParse) {
    $tokens = $null
    $parseErrors = $null
    [void][System.Management.Automation.Language.Parser]::ParseFile($file, [ref]$tokens, [ref]$parseErrors)
    Assert-True ($parseErrors.Count -eq 0) "PowerShell parse failed in $file`: $($parseErrors -join '; ')"
  }

  Import-Module (Join-Path $moduleRoot "Verification.psm1") -Force
  Import-Module (Join-Path $moduleRoot "Downloads.psm1") -Force
  Import-Module (Join-Path $moduleRoot "Detection.psm1") -Force
  Import-Module (Join-Path $moduleRoot "Installation.psm1") -Force
  $profile = Get-Content -LiteralPath (Join-Path $packageRoot "config\windows-server-2022-developer.json") -Raw | ConvertFrom-Json
  $expectedIds = @("git", "github-cli", "vscode", "nodejs-lts", "python", "dotnet-10-sdk", "powershell-7", "seven-zip", "firefox", "openssh-client")
  Assert-True (@($profile.packages | Where-Object { $_ -in $expectedIds }).Count -eq $expectedIds.Count) "The profile is missing a required P0 package."
  Test-QuickSetupProfile -Profile $profile -AllowedPackageIds @($profile.packages)
  $supportedTarget = Test-QuickSetupTargetContext -Caption "Microsoft Windows Server 2022" -Build 20348 -InstallationType "Server" -ProcessorArchitecture 9 -Is64Bit $true
  $coreTarget = Test-QuickSetupTargetContext -Caption "Microsoft Windows Server 2022" -Build 20348 -InstallationType "Server Core" -ProcessorArchitecture 9 -Is64Bit $true
  $x86Target = Test-QuickSetupTargetContext -Caption "Microsoft Windows Server 2022" -Build 20348 -InstallationType "Server" -ProcessorArchitecture 0 -Is64Bit $false
  Assert-True ($supportedTarget.IsSupported) "A mocked Server 2022 Desktop Experience x64 host was rejected."
  Assert-True (!$coreTarget.IsSupported -and ($coreTarget.Reasons -join " ") -match "Server Core") "Mocked Server Core was not rejected."
  Assert-True (!$x86Target.IsSupported -and $x86Target.Architecture -eq "unsupported") "Mocked x86 architecture was not rejected."

  $sha = Test-QuickSetupSha256Text -Text ("A" * 64 + "  sample.msi") -FileName "sample.msi"
  Assert-True ($sha -eq ("A" * 64)) "The SHA-256 manifest parser did not return the expected hash."
  Assert-True ($null -eq (Test-QuickSetupSha256Text -Text "invalid sample.msi" -FileName "sample.msi")) "The SHA-256 manifest parser accepted malformed input."
  $fakeInstaller = Join-Path $temporaryDirectory "unsigned-installer.txt"
  Set-Content -LiteralPath $fakeInstaller -Value "not an installer" -Encoding ASCII
  $signatureCheck = Test-QuickSetupAuthenticodePublisher -Path $fakeInstaller -ExpectedPublisher "Microsoft Corporation"
  Assert-True (!$signatureCheck.IsValid) "An unsigned mock installer passed Authenticode verification."
  $downloadRefused = $false
  try {
    Get-QuickSetupOfficialDownload -Uri ([uri]"http://example.invalid/installer.msi") -Destination (Join-Path $temporaryDirectory "refused.msi") -AllowedHosts @("example.invalid")
  } catch { $downloadRefused = $true }
  Assert-True ($downloadRefused) "An insecure HTTP installer source was not rejected."

  $originalAppData = $env:APPDATA
  $env:APPDATA = Join-Path $temporaryDirectory "appdata"
  $settingsDirectory = Join-Path $env:APPDATA "Code\User"
  New-Item -ItemType Directory -Path $settingsDirectory -Force | Out-Null
  $settingsPath = Join-Path $settingsDirectory "settings.json"
  Set-Content -LiteralPath $settingsPath -Value '{"editor.fontSize":16}' -Encoding UTF8
  $themeResult = Set-QuickSetupVsCodeDarkTheme
  $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json
  Assert-True ($themeResult.Success -and $settings."editor.fontSize" -eq 16 -and $settings."workbench.colorTheme" -eq "Default Dark Modern") "VS Code settings were not merged as expected."
  Assert-True (@(Get-ChildItem -LiteralPath $settingsDirectory -Filter "*.bak").Count -eq 1) "Existing VS Code settings were not backed up."
  Set-Content -LiteralPath $settingsPath -Value "{`n  // JSONC is not rewritten`n  `"editor.fontSize`": 16`n}" -Encoding UTF8
  $themeResult = Set-QuickSetupVsCodeDarkTheme
  Assert-True (!$themeResult.Success -and (Get-Content -LiteralPath $settingsPath -Raw) -match "JSONC") "A JSONC settings file was not preserved."
  if ($null -eq $originalAppData) { Remove-Item Env:\APPDATA -ErrorAction SilentlyContinue } else { $env:APPDATA = $originalAppData }

  $script:mockInstallerCalls = 0
  $mockExitCode = Invoke-QuickSetupInstallerProcess -Path "mock-installer.exe" -Arguments @("/quiet") -ProcessRunner {
    param($path, $arguments)
    $script:mockInstallerCalls++
    if ($path -ne "mock-installer.exe" -or $arguments[0] -ne "/quiet") { return 81 }
    return 0
  }
  Assert-True ($mockExitCode -eq 0 -and $script:mockInstallerCalls -eq 1) "The mock installer runner did not capture the expected process call."
  $mockFailureCode = Invoke-QuickSetupInstallerProcess -Path "mock-installer.exe" -Arguments @("/quiet") -ProcessRunner {
    param($path, $arguments)
    return 1603
  }
  Assert-True ($mockFailureCode -eq 1603) "A mocked installer failure code was not propagated."

  $listOutput = & powershell.exe -NoProfile -NonInteractive -File (Join-Path $packageRoot "bootstrap.ps1") -List 2>&1
  Assert-True ($LASTEXITCODE -eq 0) "The bootstrap list mode failed: $($listOutput -join "`n")"
  Assert-True (($listOutput -join "`n") -match "OpenSSH Client") "List mode omitted OpenSSH Client."

  $reportPath = Join-Path $temporaryDirectory "dry-run-report.json"
  $dryRunOutput = & powershell.exe -NoProfile -NonInteractive -File (Join-Path $packageRoot "bootstrap.ps1") -DryRun -ReportPath $reportPath 2>&1
  Assert-True ($LASTEXITCODE -eq 0) "The bootstrap dry-run failed: $($dryRunOutput -join "`n")"
  Assert-True (Test-Path -LiteralPath $reportPath) "Dry-run did not create its JSON report."
  Assert-True (Test-Path -LiteralPath ([System.IO.Path]::ChangeExtension($reportPath, ".txt"))) "Dry-run did not create its text report."
  $report = Get-Content -LiteralPath $reportPath -Raw | ConvertFrom-Json
  Assert-True ($report.Architecture -eq "x64") "The report did not record x64 architecture."
  Assert-True ($report.OperatingSystem.Caption -match "Windows Server 2022" -and $report.OperatingSystem.IsSupported) "The Server 2022 x64 Desktop Experience preflight did not pass on this host."
  Assert-True ($report.Summary -eq "Dry run complete") "Dry-run report summary was unexpected."
  Assert-True (@($report.Packages | Where-Object { $_.Status -eq "Failed" }).Count -eq 0) "Dry-run reported installation failures."
  Assert-True (@($report.Packages | Where-Object { $_.Id -eq "docker-desktop" }).Count -eq 1) "Docker Desktop was not explicitly reported."
  if (Get-Command git -ErrorAction SilentlyContinue) {
    Assert-True (@($report.Packages | Where-Object { $_.Id -eq "git" -and $_.Status -eq "Already installed" }).Count -eq 1) "The existing Git installation was not detected."
  }
  $bootstrapSources = Get-Content -LiteralPath (Join-Path $packageRoot "bootstrap.ps1") -Raw
  Assert-True ($bootstrapSources -notmatch "(?i)winget") "The standalone entry point must not depend on WinGet."
  $optionalReportPath = Join-Path $temporaryDirectory "optional-report.json"
  $optionalOutput = & powershell.exe -NoProfile -NonInteractive -File (Join-Path $packageRoot "bootstrap.ps1") -DryRun -SkipOptional -ReportPath $optionalReportPath 2>&1
  Assert-True ($LASTEXITCODE -eq 0) "Dry-run with -SkipOptional failed: $($optionalOutput -join "`n")"
  $optionalReport = Get-Content -LiteralPath $optionalReportPath -Raw | ConvertFrom-Json
  Assert-True (@($optionalReport.Packages | Where-Object { $_.Id -eq "github-copilot-cli" -and $_.Status -eq "Skipped by user" }).Count -eq 1) "-SkipOptional did not report the Copilot CLI as skipped."

  $zipPath = Join-Path $temporaryDirectory "configureMe-WindowsServer2022-Developer-QuickSetup.zip"
  $packagingScript = Join-Path $repositoryRoot "scripts\New-WindowsServer2022QuickSetup.ps1"
  & powershell.exe -NoProfile -NonInteractive -File $packagingScript -OutputPath $zipPath
  Assert-True ($LASTEXITCODE -eq 0) "The ZIP packaging routine failed."
  $firstHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
  & powershell.exe -NoProfile -NonInteractive -File $packagingScript -OutputPath $zipPath -Force
  Assert-True ($LASTEXITCODE -eq 0) "The repeat ZIP packaging routine failed."
  $secondHash = (Get-FileHash -LiteralPath $zipPath -Algorithm SHA256).Hash
  Assert-True ($firstHash -eq $secondHash) "ZIP packaging is not deterministic for identical source files."
  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $zip = [System.IO.Compression.ZipFile]::OpenRead($zipPath)
  try {
    $entryNames = @($zip.Entries | ForEach-Object { $_.FullName })
    Assert-True ($entryNames -contains "configureMe-QuickSetup/bootstrap.ps1") "The ZIP omitted its entry point."
    Assert-True ($entryNames -contains "configureMe-QuickSetup/modules/Downloads.psm1") "The ZIP omitted a required module."
    Assert-True ($entryNames -contains "configureMe-QuickSetup/assets/firefox-bookmarks.html") "The ZIP omitted Firefox bookmarks."
  } finally { $zip.Dispose() }

  Write-Host "Quick Setup smoke tests passed."
} finally {
  Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
