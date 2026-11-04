function Write-QuickSetupLog {
  param(
    [Parameter(Mandatory = $true)][string]$Message,
    [ValidateSet("INFO", "WARN", "ERROR")][string]$Level = "INFO"
  )

  $color = switch ($Level) {
    "WARN" { "Yellow" }
    "ERROR" { "Red" }
    default { "Gray" }
  }
  Write-Host "[$Level] $Message" -ForegroundColor $color
}

function New-QuickSetupPackageResult {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)][string]$Name,
    [Parameter(Mandatory = $true)][string]$RequestedVersion
  )

  [pscustomobject]@{
    Id = $Id
    Name = $Name
    RequestedVersion = $RequestedVersion
    DetectedVersion = $null
    InstallerType = "manual"
    RequiresAdministrator = $false
    Source = $null
    Method = $null
    Status = "Requires user action"
    ErrorCode = $null
    Notes = $null
    RestartRequired = $false
  }
}

function Write-QuickSetupReport {
  param(
    [Parameter(Mandatory = $true)]$Report,
    [Parameter(Mandatory = $true)][string]$Path
  )

  $directory = Split-Path -Parent $Path
  if ($directory -and !(Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $json = ConvertTo-Json -InputObject $Report -Depth 8
  Set-Content -LiteralPath $Path -Value $json -Encoding UTF8

  $textPath = [System.IO.Path]::ChangeExtension($Path, ".txt")
  $lines = @(
    "configureMe Windows Server 2022 Developer Quick Setup",
    "Bootstrap version: $($Report.BootstrapVersion)",
    "Status: $($Report.Summary)",
    "Operating system: $($Report.OperatingSystem.Caption)",
    "Architecture: $($Report.Architecture)",
    "Started: $($Report.StartedAt)",
    "Finished: $($Report.FinishedAt)",
    "",
    "Package results:"
  )
  foreach ($package in $Report.Packages) {
    $version = if ($package.DetectedVersion) { $package.DetectedVersion } else { "not detected" }
    $requested = if ($package.RequestedVersion) { $package.RequestedVersion } else { "unspecified" }
    $source = if ($package.Source) { $package.Source } else { "none" }
    $errorCode = if ($package.ErrorCode) { $package.ErrorCode } else { "none" }
    $lines += "- $($package.Name): $($package.Status); installer type: $($package.InstallerType); administrator required: $($package.RequiresAdministrator); requested: $requested; detected: $version; source: $source; method: $($package.Method); error: $errorCode; restart required: $($package.RestartRequired); $($package.Notes)"
  }
  if ($Report.ManualSteps.Count -gt 0) {
    $lines += ""
    $lines += "Manual steps:"
    foreach ($step in $Report.ManualSteps) { $lines += "- $step" }
  }
  if ($Report.Errors.Count -gt 0) {
    $lines += ""
    $lines += "Errors:"
    foreach ($errorMessage in $Report.Errors) { $lines += "- $errorMessage" }
  }
  Set-Content -LiteralPath $textPath -Value $lines -Encoding UTF8
  Write-QuickSetupLog "Reports written to '$Path' and '$textPath'."
}

Export-ModuleMember -Function Write-QuickSetupLog, New-QuickSetupPackageResult, Write-QuickSetupReport
