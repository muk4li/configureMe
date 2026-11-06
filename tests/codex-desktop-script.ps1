$ErrorActionPreference = 'Stop'
. (Join-Path (Split-Path -Parent $PSScriptRoot) 'scripts/Install-CodexDesktop.ps1')
$script:opens = 0
$server = { 'Microsoft Windows Server 2022 Datacenter Evaluation' }
$missing = Invoke-CodexDesktopSetup -OsProvider $server -PackageProvider { @() } -OpenInstaller { $script:opens++ }
if ($missing.Installed -or $missing.ErrorCode -ne 'codex-store-unavailable' -or $script:opens -ne 0) { throw 'Server without Store was incorrectly installed or launched.' }
$attempt = Invoke-CodexDesktopSetup -OpenOfficialInstaller -OsProvider $server -PackageProvider { @() } -OpenInstaller {
  param($uri)
  if ($uri.Host -cne 'get.microsoft.com') { throw 'Not the official web installer' }
  $script:opens++
}
if ($attempt.Installed -or $attempt.ErrorCode -ne 'codex-registration-pending' -or $script:opens -ne 1) { throw 'An explicit official installer attempt was blocked or claimed success.' }
$script:opens = 0
$store = [pscustomobject]@{ Name = 'Microsoft.WindowsStore'; Status = 'Ok'; SignatureKind = 'Store' }
$packages = { param($name) if ($name -eq 'Microsoft.WindowsStore') { $store } }
$dry = Invoke-CodexDesktopSetup -DryRun -OsProvider $server -PackageProvider $packages -OpenInstaller { $script:opens++ }
if ($dry.Status -ne 'Dry run' -or $script:opens -ne 0) { throw 'Dry run started an installer.' }
$verify = Invoke-CodexDesktopSetup -VerifyOnly -OsProvider $server -PackageProvider $packages -OpenInstaller { $script:opens++ }
if ($verify.Installed -or $script:opens -ne 0) { throw 'VerifyOnly started an installer or accepted a missing package.' }
$pending = Invoke-CodexDesktopSetup -OsProvider $server -PackageProvider $packages -OpenInstaller {
  param($uri)
  if ($uri.AbsoluteUri -cne 'https://get.microsoft.com/installer/download/9PLM9XGG6VKS?cid=website_cta_psi') { throw 'Wrong official Desktop source/product.' }
  $script:opens++
}
if ($pending.Installed -or $pending.ErrorCode -ne 'codex-registration-pending' -or $script:opens -ne 1) { throw 'Opening the installer was treated as success.' }
$app = [pscustomobject]@{ Name = 'OpenAI.Codex'; Architecture = 'X64'; Status = 'Ok'; SignatureKind = 'Store'; Version = '1.0.0.0'; InstallLocation = 'C:\Program Files\WindowsApps\fixture' }
$installed = Invoke-CodexDesktopSetup -OsProvider $server -PackageProvider { param($name) if ($name -eq 'OpenAI.Codex') { $app } } -OpenInstaller { throw 'Must not reinstall an existing app' }
if (!$installed.Installed -or $installed.Status -ne 'Already installed') { throw 'Existing verified Desktop app was not preserved.' }
foreach ($field in @('SignatureKind', 'Architecture', 'Status', 'Name')) {
  $wrong = $app.PSObject.Copy(); $wrong.$field = 'unapproved'
  $result = Invoke-CodexDesktopSetup -OsProvider $server -PackageProvider { param($name) if ($name -eq 'OpenAI.Codex') { $wrong } } -OpenInstaller { throw 'No installer is authorized' }
  if ($result.Installed) { throw "Invalid Desktop identity accepted: $field" }
}
'Codex Desktop helper: 10 scenarios passed (no network, no installer processes).'
