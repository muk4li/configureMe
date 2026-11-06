[CmdletBinding(SupportsShouldProcess = $true)]
param([switch]$DryRun, [switch]$VerifyOnly)

# The Windows route published by OpenAI's Codex CLI is the Microsoft Store web
# installer, not the Codex CLI binary and not an undocumented standalone EXE.
# Source: openai/codex, codex-rs/cli/src/desktop_app/windows.rs.
function Get-CodexDesktopInstallState {
  param([scriptblock]$PackageProvider, [scriptblock]$OsProvider)
  $os = if ($OsProvider) { & $OsProvider } else { (Get-CimInstance Win32_OperatingSystem -ErrorAction Stop).Caption }
  $query = if ($PackageProvider) { $PackageProvider } else {
    { param($name) if (Get-Command Get-AppxPackage -ErrorAction SilentlyContinue) { Get-AppxPackage -Name $name -ErrorAction Stop } }
  }
  $app = @(& $query 'OpenAI.Codex') | Where-Object {
    $_.Name -ceq 'OpenAI.Codex' -and [string]$_.Architecture -ieq 'X64' -and
    [string]$_.Status -ieq 'Ok' -and [string]$_.SignatureKind -ieq 'Store' -and
    [string]$_.Version -match '^\d+\.\d+\.\d+\.\d+$' -and $_.InstallLocation
  } | Select-Object -First 1
  $store = @(& $query 'Microsoft.WindowsStore') | Where-Object {
    $_.Name -ceq 'Microsoft.WindowsStore' -and [string]$_.Status -ieq 'Ok' -and [string]$_.SignatureKind -ieq 'Store'
  } | Select-Object -First 1
  [pscustomobject]@{
    PackageId = 'codex-desktop'
    OperatingSystem = [string]$os
    Installed = [bool]$app
    Version = if ($app) { [string]$app.Version } else { $null }
    StoreAvailable = [bool]$store
    InstallerUrl = 'https://get.microsoft.com/installer/download/9PLM9XGG6VKS?cid=website_cta_psi'
    Source = 'https://github.com/openai/codex/blob/main/codex-rs/cli/src/desktop_app/windows.rs'
    Status = if ($app) { 'Already installed' } else { 'Requires user action' }
    ErrorCode = if ($app) { $null } elseif (!$store) { 'codex-store-unavailable' } else { 'codex-installation-required' }
    Notes = if ($app) { 'Registered x64 Codex Desktop Store package verified for the current user; no reinstall.' }
      elseif (!$store) { 'OpenAI publishes a Microsoft Store installer for Codex Desktop. The Store is unavailable for this user; Windows Server 2022 does not include it. No supported unattended Server 2022 route was verified. No Store components, OS requirements or security checks were bypassed. Codex CLI is not a substitute installation.' }
      else { 'Finish the official interactive Windows installer, then rerun this script with -VerifyOnly. The Store enforces package signatures, OS requirements and dependencies.' }
  }
}

function Invoke-CodexDesktopSetup {
  [CmdletBinding(SupportsShouldProcess = $true)]
  param([switch]$DryRun, [switch]$VerifyOnly, [scriptblock]$PackageProvider, [scriptblock]$OsProvider, [scriptblock]$OpenInstaller)
  $state = Get-CodexDesktopInstallState -PackageProvider $PackageProvider -OsProvider $OsProvider
  if ($state.Installed -or $VerifyOnly -or !$state.StoreAvailable) { return $state }
  if ($DryRun -or !$PSCmdlet.ShouldProcess('Codex Desktop', 'Open the official Microsoft Store Windows installer')) {
    $state.Status = 'Dry run'
    return $state
  }
  if ($OpenInstaller) { & $OpenInstaller ([uri]$state.InstallerUrl) | Out-Null }
  else { Start-Process -FilePath $state.InstallerUrl -ErrorAction Stop }
  # Opening an installer is not proof of installation. Never return Installed here.
  $state.ErrorCode = 'codex-registration-pending'
  return $state
}

if ($MyInvocation.InvocationName -ne '.') {
  $ErrorActionPreference = 'Stop'
  try {
    $result = Invoke-CodexDesktopSetup -DryRun:$DryRun -VerifyOnly:$VerifyOnly -WhatIf:$WhatIfPreference
    $result | ConvertTo-Json -Depth 4
    if ($result.Installed -or $DryRun -or $WhatIfPreference) { exit 0 }
    exit 2
  } catch {
    [pscustomobject]@{ PackageId = 'codex-desktop'; Status = 'Failed'; ErrorCode = 'codex-setup-error'; Notes = $_.Exception.Message } | ConvertTo-Json
    exit 1
  }
}
