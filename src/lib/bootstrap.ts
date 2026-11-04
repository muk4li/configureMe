import { catalog, type PackageDefinition } from "./catalog";

function hasWindowsPackageId(item: PackageDefinition): item is PackageDefinition & { windowsPackageId: string } {
  return item.platforms.windows?.supported === true && typeof item.windowsPackageId === "string";
}

const windowsBootstrapTemplate = String.raw`param(
  [switch]$DryRun
)
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $MyInvocation.MyCommand.Path
$planPath = Join-Path $root "plan.json"
$hashPath = Join-Path $root "plan.sha256"
if (!(Test-Path $planPath) -or !(Test-Path $hashPath)) {
  throw "The plan or its integrity file is missing."
}
$actualHash = (Get-FileHash -Path $planPath -Algorithm SHA256).Hash.ToLowerInvariant()
$expectedHash = (Get-Content -Path $hashPath -Raw).Trim().ToLowerInvariant()
if ($actualHash -ne $expectedHash) {
  throw "Plan integrity check failed. Do not run this package."
}
$plan = Get-Content -Path $planPath -Raw | ConvertFrom-Json
if ($plan.schemaVersion -ne 1 -or $plan.catalogVersion -ne "1" -or $plan.platform -ne "windows") {
  throw "Unsupported or invalid installation plan."
}
if ($plan.architecture -ne "x64") {
  throw "Unsupported target architecture in plan."
}
$architecture = (Get-CimInstance Win32_Processor | Select-Object -First 1).Architecture
$actualArchitecture = if ($architecture -eq 9) { "x64" } else { "unsupported" }
if ($actualArchitecture -ne $plan.architecture) {
  throw "This plan targets $($plan.architecture), but this computer is $actualArchitecture."
}
$os = Get-CimInstance Win32_OperatingSystem
if ($os.Caption -notmatch "Windows 10|Windows 11|Windows Server") {
  throw "This Windows version is not supported by the bootstrap."
}
if ($os.Caption -match "Server" -and $plan.packages -contains "vscode") {
  throw "Visual Studio Code is not supported on Windows Server by this bootstrap."
}
if ($os.Caption -match "Server") {
  $serverAllowed = @("git", "github-cli", "powershell")
  foreach ($package in $plan.packages) {
    if ($package -notin $serverAllowed) {
      throw "Package '$package' is not allowlisted for Windows Server."
    }
  }
}
$allowedPackages = @{
__PACKAGE_ALLOWLIST__
}
if (!$plan.packages -or $plan.packages.Count -gt 50) {
  throw "Plan package list is empty or too large."
}
$install = @()
foreach ($package in $plan.packages) {
  if (!$allowedPackages.ContainsKey([string]$package)) {
    throw "Package '$package' is not in the trusted package allowlist."
  }
  $install += $allowedPackages[[string]$package]
}
Write-Host "Target: $($os.Caption) / $actualArchitecture"
Write-Host "Packages to check: $($install -join ', ')"
Write-Host "Dry run: $DryRun"
if ($DryRun) {
  foreach ($id in $install) { Write-Host "[DRY RUN] Would check/install $id" }
  exit 0
}
if (Get-Command winget -ErrorAction SilentlyContinue) {
  $winget = (Get-Command winget).Source
} else {
  throw "WinGet is unavailable. No software was installed. Use the official links in README.txt for manual installation."
}
$confirmation = Read-Host "Continue with this installation? Type YES"
if ($confirmation -cne "YES") {
  Write-Host "Cancelled. No changes were made."
  exit 0
}
$failed = @()
foreach ($id in $install) {
  Write-Host "Checking $id ..."
  $listing = & $winget list --id $id --exact --accept-source-agreements 2>$null | Out-String
  if ($LASTEXITCODE -eq 0 -and $listing -match [regex]::Escape($id)) {
    Write-Host "$id appears to be installed; skipping."
    continue
  }
  Write-Host "Installing $id from the configured WinGet source ..."
  & $winget install --id $id --exact --source winget --accept-source-agreements --accept-package-agreements --silent
  if ($LASTEXITCODE -ne 0) {
    Write-Host "Installation failed for $id (exit code $LASTEXITCODE)."
    $failed += $id
  } else {
    $verification = & $winget list --id $id --exact --accept-source-agreements 2>$null | Out-String
    if ($LASTEXITCODE -eq 0 -and $verification -match [regex]::Escape($id)) {
      Write-Host "Verified $id."
    } else {
      Write-Host "Could not verify $id after installation."
      $failed += $id
    }
  }
}
if ($failed.Count -gt 0) {
  Write-Host "Some installations failed: $($failed -join ', '). Rerunning is safe."
  exit 1
}
Write-Host "All requested package operations completed. Verify each application before use."
`;

export function createWindowsBootstrapScript(): string {
  return windowsBootstrapTemplate.replace(
    "__PACKAGE_ALLOWLIST__",
    catalog
      .filter(hasWindowsPackageId)
      .map((item) => `  "${item.id}" = "${item.windowsPackageId}"`)
      .join("\r\n"),
  );
}
