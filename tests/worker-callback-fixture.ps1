[CmdletBinding()]
param([Parameter(Mandatory = $true)][string]$RepositoryRoot)

$ErrorActionPreference = "Stop"
$moduleRoot = Join-Path $RepositoryRoot "bootstrap/windows-server-2022-developer/modules"
foreach ($name in @("Logging", "Detection", "Downloads", "Verification", "Installation", "GuiWorker")) {
  Import-Module (Join-Path $moduleRoot "$name.psm1") -Force
}

# Run the real JSON-line GUI worker in a separate PowerShell process. Replace only
# OS detection and installer side effects; no network or application is changed.
$worker = Get-Module GuiWorker
& $worker {
  $script:fixtureInstalled = @{}
  if ($env:CONFIGUREME_TEST_INSTALLED_JSON) {
    $installed = $env:CONFIGUREME_TEST_INSTALLED_JSON | ConvertFrom-Json -ErrorAction Stop
    foreach ($entry in $installed.PSObject.Properties) { $script:fixtureInstalled[$entry.Name] = [string]$entry.Value }
  }
  function Get-QuickSetupOperatingSystem {
    [pscustomobject]@{ Caption = "Windows Server 2022 Datacenter Evaluation"; Version = "10.0.20348";
      Build = 20348; InstallationType = "Server"; Architecture = "x64"; IsSupported = $true; Reasons = @() }
  }
  function Get-QuickSetupGuiAdministratorStatus { return $false }
  function Get-QuickSetupDetectedVersion {
    param([string]$Id)
    return $script:fixtureInstalled[$Id]
  }
  function Get-QuickSetupDockerDiagnostics {
    $version = $script:fixtureInstalled["docker-desktop"]
    [pscustomobject]@{ IsInstalled = [bool]$version; Version = $version; Context = "fixture";
      ContainerType = "linux"; Notes = "Read-only fixture diagnostics." }
  }
  function Get-QuickSetupInstallerDefinition {
    param([string]$Id, [switch]$OfflinePreview)
    if (!$OfflinePreview -and $env:CONFIGUREME_TEST_FAIL_STAGE -eq "metadata" -and $env:CONFIGUREME_TEST_FAIL_ID -eq $Id) {
      throw "Mock official metadata endpoint failed for $Id; token=fixture-private; https://example.test/feed?sig=fixture-private"
    }
    [pscustomobject]@{
      Automatic = $true; InstallerType = $(if ($Id -eq "seven-zip") { "msi" } elseif ($Id -eq "openssh-client") { "windows-capability" } else { "exe" })
      RequiresAdministrator = ($Id -in @("github-cli", "openssh-client", "powershell-7")); Version = "fixture-version"
      Uri = [uri]"https://github.com/github/app/releases/download/v1.1.34/GitHub-Copilot-windows-x64-setup.exe"
      Method = "Mocked installer process"; Source = "local fixture"; Notes = "No installer launched."
    }
  }
  function Get-QuickSetupInstallerCachePath {
    param([string]$Id, $Definition)
    return (Join-Path $env:LOCALAPPDATA "$Id.fixture.exe")
  }
  function Assert-QuickSetupSafePath { param([string]$Path) }
  function Get-QuickSetupOfficialDownload {
    param($Uri, [string]$Destination, $AllowedHosts, $ExpectedSha256, $ExpectedSha512)
    if ($env:CONFIGUREME_TEST_FAIL_STAGE -eq "download") { throw "Mock official download failed." }
    Set-Content -LiteralPath $Destination -Value "fixture" -Encoding ASCII
    return $Destination
  }
  # Mock the shared boundary used by download preparation. Its real hash,
  # architecture and signature behavior is covered in installer-regressions.ps1.
  function Assert-QuickSetupDownloadedInstaller {
    param([string]$Id, $Definition, [string]$Path)
    if ($env:CONFIGUREME_TEST_FAIL_STAGE -eq "verification") { throw "Mock SHA-256 hash mismatch." }
  }
  function Invoke-QuickSetupPackageInstall {
    param([string]$Id, $Definition, [scriptblock]$ProgressCallback, [string]$CachedInstallerPath, [ref]$Provenance)
    foreach ($stage in @("download-started", "download-completed", "verification-started", "verification-completed", "installation-started")) {
      & $ProgressCallback $stage
      if ($env:CONFIGUREME_TEST_FAIL_STAGE -eq "verification" -and $env:CONFIGUREME_TEST_FAIL_ID -eq $Id -and $stage -eq "verification-started") {
        throw "Mock SHA-256 hash mismatch."
      }
    }
    if ($env:CONFIGUREME_TEST_FAIL_ID -eq $Id) { throw "Mock installer failed for $Id after progress events." }
    & $ProgressCallback "installation-completed"
    $script:fixtureInstalled[$Id] = switch ($Id) { "python" { "3.13.0" } "dotnet-10-sdk" { "10.0.403" } "seven-zip" { "26.00" } default { "1.0.0" } }
    [pscustomobject]@{ ExitCode = 0; RestartRequired = $false }
  }
  function Sync-QuickSetupProcessPath { }
  try { exit [int](Invoke-QuickSetupGuiWorker) }
  catch {
    Write-QuickSetupEvent -Type "worker-error" -Status "failed" -Message $_.Exception.Message
    exit 1
  }
}
