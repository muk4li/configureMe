$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$moduleRoot = Join-Path $root "bootstrap/windows-server-2022-developer/modules"
Import-Module (Join-Path $moduleRoot "Downloads.psm1") -Force
Import-Module (Join-Path $moduleRoot "Verification.psm1") -Force
Import-Module (Join-Path $moduleRoot "Installation.psm1") -Force

$preview = Get-QuickSetupInstallerDefinition -Id "github-copilot-desktop" -OfflinePreview
if (!$preview.Automatic -or $preview.Version -ne "1.1.34" -or
    $preview.Sha256 -ne "4a8070a63b228895344a6c4f4536a01a62085e02821829b21786638234580e00" -or
    ($preview.Arguments -join " ") -cne "/S" -or !$preview.AllowX86BootstrapForX64) {
  throw "Copilot Desktop did not use its verified official NSIS release."
}

$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("configureme-portable-" + [guid]::NewGuid().ToString("N"))
$oldTemp = $env:TEMP
$oldLocalAppData = $env:LOCALAPPDATA
try {
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  $env:TEMP = $testRoot
  $env:LOCALAPPDATA = $testRoot
  $bytes = New-Object byte[] 256
  $bytes[0] = 0x4d; $bytes[1] = 0x5a
  [Array]::Copy([BitConverter]::GetBytes([int]0x80), 0, $bytes, 0x3c, 4)
  $bytes[0x80] = 0x50; $bytes[0x81] = 0x45
  [Array]::Copy([BitConverter]::GetBytes([int]0x014c), 0, $bytes, 0x84, 2)
  $definition = $preview.PSObject.Copy()
  $definition.Sha256 = [Convert]::ToHexString([Security.Cryptography.SHA256]::HashData($bytes)).ToLowerInvariant()
  $script:mockCalls = 0
  $result = Invoke-QuickSetupPackageInstall -Id "github-copilot-desktop" -Definition $definition -DownloadProvider {
    param($uri, $destination, $allowedHosts)
    [IO.File]::WriteAllBytes($destination, $bytes)
    return $uri
  } -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = 'CN="GitHub, Inc.", O="GitHub, Inc."' }
    }
  } -ProcessRunner {
    param($path, $arguments)
    $script:mockCalls++
    if (($arguments -join " ") -cne "/S" -or $path -notmatch "installer\.exe$") { throw "The reviewed silent installer arguments were changed." }
    return 0
  }
  if ($result.ExitCode -ne 0 -or $script:mockCalls -ne 1) { throw "The reviewed Copilot installer route did not run once." }

  $definition.Sha256 = "0" * 64
  $script:mockCalls = 0
  try {
    Invoke-QuickSetupPackageInstall -Id "github-copilot-desktop" -Definition $definition -DownloadProvider {
      param($uri, $destination, $allowedHosts)
      [IO.File]::WriteAllBytes($destination, $bytes)
      return $uri
    } -SignatureProvider { throw "Signature check should not run after a bad hash." } -ProcessRunner {
      $script:mockCalls++
      return 0
    } | Out-Null
    throw "A bad Copilot hash was accepted."
  } catch {
    if ($_.Exception.Message -eq "A bad Copilot hash was accepted.") { throw }
  }
  if ($script:mockCalls -ne 0) { throw "A bad Copilot hash started an installer." }
  "Portable PowerShell installer checks passed."
} finally {
  $env:TEMP = $oldTemp
  $env:LOCALAPPDATA = $oldLocalAppData
  Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
