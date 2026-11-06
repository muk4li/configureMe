[CmdletBinding()]
param(
  [string]$Profile = "windows-server-2022-developer",
  [switch]$DryRun,
  [switch]$List,
  [switch]$GuiWorker,
  [switch]$SkipOptional,
  [string]$ReportPath = ".\setup-report.json"
)

$ErrorActionPreference = "Stop"
$bootstrapVersion = "0.3.0"
$root = $PSScriptRoot
$moduleDirectory = Join-Path $root "modules"
Import-Module (Join-Path $moduleDirectory "Logging.psm1") -Force
Import-Module (Join-Path $moduleDirectory "Detection.psm1") -Force
Import-Module (Join-Path $moduleDirectory "Downloads.psm1") -Force
Import-Module (Join-Path $moduleDirectory "Verification.psm1") -Force
Import-Module (Join-Path $moduleDirectory "Installation.psm1") -Force
Import-Module (Join-Path $moduleDirectory "GuiWorker.psm1") -Force

$knownPackageIds = @(Get-QuickSetupPackageCatalog | ForEach-Object { [string]$_.id })
$optionalPackageIds = @("libreoffice", "teams", "docker-desktop", "github-copilot-cli")
$requestedVersions = @{
  "git" = "latest stable"
  "github-cli" = "latest stable"
  "vscode" = "latest stable"
  "nodejs-lts" = "latest stable Active LTS"
  "python" = "latest supported stable Python 3.14 x64"
  "dotnet-10-sdk" = "latest stable .NET 10 SDK"
  "powershell-7" = "latest stable 7.x"
  "seven-zip" = "latest stable"
  "firefox" = "latest stable"
  "openssh-client" = "Windows Server capability"
  "github-copilot-desktop" = "Pinned official 1.1.34 release"
  "libreoffice" = "Latest stable x64 release; optional"
  "teams" = "Current desktop client; support not asserted"
  "docker-desktop" = "Existing installation only; no updates"
  "github-copilot-cli" = "Optional; user-selected"
}
if ($Profile -notmatch "^[a-z0-9]+(?:-[a-z0-9]+)*$") {
  throw "Profile must be a local profile ID, not a path or URL."
}
$profilePath = Join-Path (Join-Path $root "config") "$Profile.json"
if (!(Test-Path -LiteralPath $profilePath)) {
  throw "Profile '$Profile' was not found in the local package."
}
$profileData = Get-Content -LiteralPath $profilePath -Raw | ConvertFrom-Json
Test-QuickSetupProfile -Profile $profileData -AllowedPackageIds $knownPackageIds

if ($GuiWorker) {
  Set-QuickSetupGuiWorkerMode
  try {
    $workerExitCode = Invoke-QuickSetupGuiWorker
  } catch {
    Write-QuickSetupEvent -Type "worker-error" -Status "failed" -Message (ConvertTo-QuickSetupSafeDiagnostic $_.Exception.Message)
    $workerExitCode = 1
  }
  exit [int]$workerExitCode
}

if ($List) {
  Write-Host "Profile: $($profileData.id) - $($profileData.name)"
  Write-Host "Required and explicitly handled packages:"
  foreach ($id in $profileData.packages) {
    $definition = Get-QuickSetupInstallerDefinition -Id $id -OfflinePreview
    $name = Get-QuickSetupPackageName -Id $id
    $method = if ($definition) { $definition.Method } else { "Manual / support check" }
    Write-Host ("- {0} [{1}]" -f $name, $method)
  }
  exit 0
}

$startedAt = [DateTime]::UtcNow.ToString("o")
$os = Get-QuickSetupOperatingSystem
$report = [ordered]@{
  BootstrapVersion = $bootstrapVersion
  ProfileId = $profileData.id
  OperatingSystem = $os
  Architecture = $os.Architecture
  StartedAt = $startedAt
  FinishedAt = $null
  Summary = "In progress"
  Packages = @()
  Errors = @()
  ManualSteps = @()
}
$packageResults = New-Object System.Collections.Generic.List[object]
$plannedInstallations = New-Object System.Collections.Generic.List[object]
$manualSteps = New-Object System.Collections.Generic.List[string]
$errors = New-Object System.Collections.Generic.List[string]

Write-QuickSetupLog "Target: $($os.Caption), build $($os.Build), $($os.Architecture), installation type '$($os.InstallationType)'."
if (!$os.IsSupported) {
  foreach ($reason in $os.Reasons) { Write-QuickSetupLog -Level "ERROR" -Message $reason }
}

foreach ($id in $profileData.packages) {
  $name = Get-QuickSetupPackageName -Id $id
  $result = New-QuickSetupPackageResult -Id $id -Name $name -RequestedVersion $requestedVersions[$id]
  $detectedVersion = Get-QuickSetupDetectedVersion -Id $id
  $result.DetectedVersion = $detectedVersion

  if (!$os.IsSupported) {
    $result.Status = "Not supported"
    $result.Method = "None"
    $result.Notes = $os.Reasons -join " "
    $packageResults.Add($result)
    continue
  }

  if ($id -eq "docker-desktop") {
    $docker = Get-QuickSetupDockerDiagnostics
    $result.DetectedVersion = $docker.Version
    $result.Source = "https://docs.docker.com/desktop/setup/install/windows-install/"
    $result.Method = "Detection only; no install or configuration"
    if ($docker.IsInstalled) {
      $result.Status = "Already installed"
      $result.Notes = "Context: $($docker.Context); container type: $($docker.ContainerType). $($docker.Notes) Docker Desktop is not officially supported on Windows Server 2022; this existing installation was not changed."
    } elseif ($SkipOptional) {
      $result.Status = "Skipped by user"
      $result.Notes = "Optional package skipped. Docker Desktop is not officially supported on Windows Server 2022."
    } else {
      $result.Status = "Not supported"
      $result.Notes = "Docker Desktop is not officially supported on Windows Server 2022. No installer was run. Consider a Linux VM and Docker Engine; virtualization changes require a separate decision."
    }
    if (!$docker.IsInstalled -and !$SkipOptional) {
      $manualSteps.Add("Docker Desktop is not installed and is unsupported on Windows Server 2022. Do not install it through this bootstrap: $($result.Source)")
    }
    $packageResults.Add($result)
    continue
  }

  if ($detectedVersion) {
    $result.Status = "Already installed"
    $result.Source = "Detected locally"
    $result.Method = "Detected locally; no update performed"
    $result.Notes = "The existing installation was preserved."
    if ($id -eq "teams") {
      $result.Notes += " The detected client is not an assertion of official Windows Server 2022 support; the web fallback remains available."
    }
    if ($id -eq "github-copilot-desktop") {
      $result.InstallerType = "exe"
      $result.Notes += " Existing app and user data were not modified. Practical use on Windows Server 2022 is not an official support guarantee."
    }
    $packageResults.Add($result)
    continue
  }

  if ($id -in $optionalPackageIds -and $SkipOptional) {
    $result.Status = "Skipped by user"
    $result.Method = "None"
    $result.Notes = "Optional package skipped by -SkipOptional."
    $packageResults.Add($result)
    continue
  }

  if ($id -eq "teams") {
    $result.Status = "Not supported"
    $result.Source = "https://teams.microsoft.com/v2"
    $result.Method = "Teams web application"
    $webView2Version = Get-QuickSetupWebView2Version
    $webView2State = if ($webView2Version) { "WebView2 Runtime $webView2Version detected" } else { "WebView2 Runtime not detected" }
    $result.Notes = "Windows Server build $($os.Build); $webView2State. Server/VDI support for the current desktop Teams client is not asserted, so the client is not installed. Use Teams on the web or validate Microsoft's current requirements for the actual VDI and runtime configuration."
    if (!$SkipOptional) { $manualSteps.Add("Open Microsoft Teams on the web and sign in interactively: $($result.Source)") }
    $packageResults.Add($result)
    continue
  }

  if ($id -eq "github-copilot-cli") {
    $result.Status = "Requires user action"
    $result.Source = "https://docs.github.com/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli"
    $result.Method = "Optional; install from a user-controlled npm session"
    $result.Notes = "Requires PowerShell 6+ or Node.js 22+ and an eligible Copilot subscription. The bootstrap does not install npm packages or handle authentication."
    $manualSteps.Add("If desired, install Copilot CLI manually following the official guide; authenticate interactively after installation: $($result.Source)")
    $packageResults.Add($result)
    continue
  }

  if ($id -eq "openssh-client" -and !$detectedVersion -and !$DryRun) {
    $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
    $principal = New-Object Security.Principal.WindowsPrincipal($identity)
    if (!$principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)) {
      $result.Status = "Requires user action"
      $result.Source = "https://learn.microsoft.com/windows-server/administration/openssh/openssh_install_firstuse"
      $result.InstallerType = "windows-capability"
      $result.RequiresAdministrator = $true
      $result.Method = "Windows Optional Capability (administrator required)"
      $result.Notes = "Open an elevated PowerShell session for the confirmed Windows capability step, or follow Microsoft's instructions."
      $manualSteps.Add("Install the OpenSSH Client capability from an elevated PowerShell session: $($result.Source)")
      $packageResults.Add($result)
      continue
    }
  }

  try {
    $definition = Get-QuickSetupInstallerDefinition -Id $id -OfflinePreview:$DryRun
    if (!$definition) {
      $result.Status = "Requires user action"
      $result.Method = "Manual"
      $result.Notes = "No verified automatic installation method is configured."
      $manualSteps.Add("${name}: install manually from the official vendor site.")
    } else {
      $result.RequestedVersion = $definition.Version
      $result.Source = $definition.Source
      $result.InstallerType = $definition.InstallerType
      $result.RequiresAdministrator = [bool]$definition.RequiresAdministrator
      $result.Method = $definition.Method
      $result.Notes = $definition.Notes
      if (!$definition.Automatic) {
        $result.Status = "Requires user action"
        $manualSteps.Add("${name}: $($definition.Notes) Source: $($definition.Source)")
      } elseif ($DryRun) {
        $result.Status = "Requires user action"
        $result.Notes = "Dry run only; no installer was downloaded or executed. $($definition.Notes)"
        $plannedInstallations.Add([pscustomobject]@{ Id = $id; Result = $result; Definition = $definition })
      } elseif ($definition.RequiresAdministrator -and !(Test-QuickSetupAdministratorRequirement -RequiresAdministrator $true -IsAdministrator ([Security.Principal.WindowsPrincipal]::new([Security.Principal.WindowsIdentity]::GetCurrent()).IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)))) {
        $result.Status = "Requires user action"
        $result.Notes = "This installation requires an elevated session. No installer was downloaded or started. $($definition.Notes)"
        $manualSteps.Add("$($result.Name) requires administrator rights. Re-run the reviewed bootstrap elevated using the same Windows account; do not use Run as different user.")
      } else {
        $plannedInstallations.Add([pscustomobject]@{ Id = $id; Result = $result; Definition = $definition })
      }
    }
  } catch {
    $result.Status = "Failed"
    $result.Method = "Official source metadata lookup"
    $result.ErrorCode = "metadata-error"
    $result.Notes = $_.Exception.Message
    $errors.Add("${name}: $($_.Exception.Message)")
    $manualSteps.Add("${name}: if it is still needed, install manually from its official source after checking the publisher: $($result.Source)")
    Write-QuickSetupLog -Level "ERROR" -Message "$name metadata could not be verified: $($_.Exception.Message)"
  }
  $packageResults.Add($result)
}

Write-Host ""
$changesConfirmed = $false
Write-Host "Planned package actions:"
foreach ($result in $packageResults) {
  Write-Host ("- {0}: {1}; type: {2}; administrator required: {3}; requested: {4}; detected: {5}; {6}" -f $result.Name, $result.Status, $result.InstallerType, $result.RequiresAdministrator, $result.RequestedVersion, $(if ($result.DetectedVersion) { $result.DetectedVersion } else { "not installed" }), $result.Method)
}
if ($DryRun) {
  if ($plannedInstallations.Count -gt 0) {
    $manualSteps.Add("Dry run only: after reviewing both reports, rerun without -DryRun to start the confirmed installers.")
  }
  Write-QuickSetupLog "Dry run complete. No downloads or software installations were performed."
} elseif ($plannedInstallations.Count -gt 0) {
  $confirmation = Read-Host "Continue with the listed system changes? Type YES"
  if ($confirmation -cne "YES") {
    foreach ($planned in $plannedInstallations) {
      $planned.Result.Status = "Skipped by user"
      $planned.Result.Notes = "Installation was not started because the confirmation was not YES."
    }
    Write-QuickSetupLog -Level "WARN" -Message "Cancelled. No planned installers were started."
  } else {
    $changesConfirmed = $true
    foreach ($planned in $plannedInstallations) {
      $result = $planned.Result
      $id = $planned.Id
      try {
        $definition = $planned.Definition
        $result.RequestedVersion = $definition.Version
        $result.Source = $definition.Source
        $result.InstallerType = $definition.InstallerType
        $result.RequiresAdministrator = [bool]$definition.RequiresAdministrator
        $result.Method = $definition.Method
        $installResult = Invoke-QuickSetupPackageInstall -Id $id -Definition $definition
        $result.InstallerExitCode = [int]$installResult.ExitCode
        if ($installResult.ExitCode -notin @(0, 3010, 1641)) {
          $result.Status = "Failed"
          $result.ErrorCode = [string]$installResult.ExitCode
          $result.Notes = "$($definition.Notes) Installer exited with code $($installResult.ExitCode)."
          $errors.Add("$($result.Name) installer exit code $($installResult.ExitCode).")
        } else {
          $result.RestartRequired = [bool]$installResult.RestartRequired
          Sync-QuickSetupProcessPath
          $result.DetectedVersion = Wait-QuickSetupInstalledVersion -Id $id -VersionProvider { param($packageId) Get-QuickSetupDetectedVersion -Id $packageId }
          $verifiedVersion = $result.DetectedVersion
          $versionVerified = $verifiedVersion -and (
            $id -ne "git" -or $verifiedVersion -match "^\d+\.\d+(?:\.\d+)?(?:\.windows\.\d+)?$"
          )
          if ($versionVerified) {
            $result.Status = "Installed"
            $result.Notes = $definition.Notes
          } else {
            $result.Status = "Failed"
            $result.ErrorCode = if ($id -eq "git") { "git-version-verification-failed" } else { "verification-failed" }
            $result.Notes = if ($id -eq "git") { "The installer returned success, but git --version did not return a verified version." } else { "The installer returned success, but the installed package could not be verified with its expected command or registry entry." }
            $errors.Add("$($result.Name) could not be verified after installation.")
          }
        }
      } catch {
        $message = $_.Exception.Message
        if ($message -match "signature|publisher|SHA-256|redirected outside|not an allowed official") {
          $result.Status = "Requires user action"
          $result.Method = "Manual fallback after verification refusal"
          $manualSteps.Add("$($result.Name): automatic execution was refused: $message Review the official vendor source '$($result.Source)' manually.")
        } else {
          $result.Status = "Failed"
          $errors.Add("$($result.Name): $message")
        }
        $result.ErrorCode = if ($result.Status -eq "Requires user action") { "verification-refused" } else { "install-error" }
        $result.Notes = $message
        Write-QuickSetupLog -Level "ERROR" -Message "$($result.Name): $message"
      }
    }
  }
}

$vscodeResult = @($packageResults | Where-Object { $_.Id -eq "vscode" }) | Select-Object -First 1
if (!$DryRun -and $changesConfirmed -and $vscodeResult -and $vscodeResult.Status -in @("Installed", "Already installed")) {
  try {
    $themeResult = Set-QuickSetupVsCodeDarkTheme
    if (!$themeResult.Success) {
      $vscodeResult.Notes += " $($themeResult.Notes)"
      $manualSteps.Add("Set the VS Code Dark Modern theme manually. $($themeResult.Notes)")
    } else {
      $vscodeResult.Notes += " $($themeResult.Notes)"
    }
  } catch {
    $vscodeResult.Notes += " VS Code theme configuration failed: $($_.Exception.Message)"
    $manualSteps.Add("Set the VS Code Dark Modern theme manually: $($_.Exception.Message)")
  }
}

foreach ($result in $packageResults) {
  if ($result.Id -eq "github-cli" -and $result.Status -in @("Installed", "Already installed")) {
    $manualSteps.Add("Sign in to GitHub interactively when ready: gh auth login. No credentials were collected or stored by the bootstrap.")
  }
  if ($result.Id -eq "firefox" -and $result.Status -in @("Installed", "Already installed")) {
    $manualSteps.Add("Import assets/firefox-bookmarks.html from Firefox's Bookmark Manager; the bootstrap does not edit existing browser profiles.")
  }
  if ($result.Id -eq "python" -and $result.Status -in @("Installed", "Already installed")) {
    $pythonDiagnostics = Get-QuickSetupPythonDiagnostics
    $result.Notes += " Python: $($pythonDiagnostics.Version); py: $($pythonDiagnostics.LauncherVersion); pip: $($pythonDiagnostics.Pip)."
    if (!$pythonDiagnostics.Complete) {
      $manualSteps.Add("Verify or complete Python command setup with python --version, py --version, and python -m pip --version.")
    }
  }
  if ($result.Id -eq "github-copilot-desktop" -and $result.Status -in @("Installed", "Already installed")) {
    $manualSteps.Add("Open GitHub Copilot Desktop and sign in interactively. No credentials were collected by the bootstrap.")
  }
  if ($result.Id -eq "git") {
    $manualSteps.Add("Set git config --global user.name and user.email yourself if needed; configureMe does not invent Git identity values.")
  }
}

$failedCount = @($packageResults | Where-Object { $_.Status -eq "Failed" }).Count
$summary = if (!$os.IsSupported) {
  "Not supported"
} elseif ($failedCount -gt 0) {
  "Completed with failures"
} elseif ($DryRun) {
  "Dry run complete"
} elseif ($manualSteps.Count -gt 0) {
  "Completed with manual steps"
} else {
  "Completed"
}
$report.FinishedAt = [DateTime]::UtcNow.ToString("o")
$report.Summary = $summary
$report.Packages = $packageResults.ToArray()
$report.Errors = $errors.ToArray()
$report.ManualSteps = @($manualSteps | Select-Object -Unique)

$resolvedReportPath = if ([System.IO.Path]::IsPathRooted($ReportPath)) { $ReportPath } else { Join-Path (Get-Location).Path $ReportPath }
Write-QuickSetupReport -Report ([pscustomobject]$report) -Path $resolvedReportPath
if ($errors.Count -gt 0 -or !$os.IsSupported) { exit 1 }
exit 0
