# Local synthetic bytes and mocked signatures/processes only. No installers/network.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
foreach ($name in @("Downloads", "Verification", "Installation")) {
  Import-Module (Join-Path $root "bootstrap/windows-server-2022-developer/modules/$name.psm1") -Force
}
$script:provenanceChecks = 0
function Assert-Provenance($condition, [string]$message) {
  $script:provenanceChecks++; if (!$condition) { throw $message }
}
$directory = Join-Path ([IO.Path]::GetTempPath()) ("configureme provenance fixture " + [guid]::NewGuid().ToString("N"))
$oldTemp = $env:TEMP
try {
  New-Item -ItemType Directory -Path $directory | Out-Null
  $env:TEMP = $directory
  $bytes = New-Object byte[] 256; $bytes[0] = 0x4d; $bytes[1] = 0x5a
  [Array]::Copy([BitConverter]::GetBytes([int]128), 0, $bytes, 60, 4)
  $bytes[128] = 0x50; $bytes[129] = 0x45
  [Array]::Copy([BitConverter]::GetBytes([int]0x8664), 0, $bytes, 132, 2)
  $cached = Join-Path $directory "cached fixture.exe"; [IO.File]::WriteAllBytes($cached, $bytes)
  $hash = (Get-FileHash -LiteralPath $cached -Algorithm SHA256).Hash.ToLowerInvariant()
  $definition = [pscustomobject]@{
    Automatic = $true; InstallerType = "exe"; ExpectedArchitecture = "x64"; Version = "1.2.3"
    Uri = [uri]"https://download.microsoft.com/fixture.exe?token=fixture-secret#private-fragment"
    AllowedHosts = @("microsoft.com"); Sha256 = $hash; Sha512 = $null
    Publisher = "Microsoft Corporation"; Arguments = @("/quiet")
  }
  $download = {
    param($uri, $destination, $allowedHosts)
    [IO.File]::WriteAllBytes($destination, $bytes)
    return [uri]"https://download.microsoft.com/final.exe?sig=fixture-secret#private-fragment"
  }
  $script:signatureCalls = 0
  $signature = {
    $script:signatureCalls++
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid;
      SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation'; Thumbprint = 'fixture-thumbprint' } }
  }
  $redacted = ConvertTo-QuickSetupProvenanceUri ([uri]"https://fixture-user:fixture-password@download.microsoft.com/a.exe?token=fixture-secret#private-fragment")
  Assert-Provenance ($redacted -ceq 'https://download.microsoft.com/a.exe') 'Provenance URI retained userinfo/query/fragment.'
  $rawSource = $null
  $rawPath = Join-Path $directory 'direct.exe'
  $returned = Get-QuickSetupOfficialDownload -Uri $definition.Uri -Destination $rawPath -AllowedHosts $definition.AllowedHosts -ExpectedSha256 $hash -DownloadProvider $download -Provenance ([ref]$rawSource)
  Assert-Provenance ($returned -is [string] -and $returned -ceq $rawPath) 'Existing download return/stdout contract changed.'
  Assert-Provenance ($rawSource.ObservedFinalUri -ceq 'https://download.microsoft.com/final.exe') 'Observed validated final URI was not recorded safely.'
  $captured = $null
  $installed = Invoke-QuickSetupPackageInstall vscode $definition -DownloadProvider $download -SignatureProvider $signature -ProcessRunner { return 3010 } -Provenance ([ref]$captured)
  Assert-Provenance ($script:signatureCalls -eq 1) 'Provenance called the signature provider a second time.'
  Assert-Provenance ($installed.ExitCode -eq 3010 -and $installed.RestartRequired) 'Provenance changed installer exit semantics.'
  Assert-Provenance ($captured.PackageId -ceq 'vscode' -and $captured.ResolvedVersion -ceq '1.2.3') 'Package identity/metadata version lost.'
  Assert-Provenance ($captured.Artifact.Sha256 -ceq $hash -and $captured.Artifact.SizeBytes -eq 256) 'Verified locked artifact digest/length was not measured.'
  Assert-Provenance ($captured.Artifact.ExpectedSha256 -ceq $hash) 'Expected metadata digest lost.'
  Assert-Provenance ($captured.Artifact.InstallerArchitecture -ceq 'x64' -and $captured.Artifact.InstallerType -ceq 'exe') 'Installer validation result lost.'
  Assert-Provenance ($captured.Artifact.Signature.Status -ceq 'Valid' -and $captured.Artifact.Signature.Policy -ceq 'authenticode') 'Actual successful signature state/policy lost.'
  Assert-Provenance ($captured.Artifact.Signature.SignerSubject -ceq 'CN=Microsoft Corporation' -and $captured.Artifact.Signature.SignerThumbprint -ceq 'fixture-thumbprint') 'Same verified signer metadata lost.'
  Assert-Provenance ($captured.SourceKind -ceq 'downloaded' -and $captured.ObservedFinalUri -ceq 'https://download.microsoft.com/final.exe') 'Download provenance was not bound to the observed response.'
  Assert-Provenance ($captured.ConfiguredUri -ceq 'https://download.microsoft.com/fixture.exe') 'Configured URI query or fragment leaked.'
  $json = ConvertTo-Json -InputObject $installed.Provenance -Depth 8 -Compress
  Assert-Provenance ($json -notmatch 'fixture-secret|private-fragment|fixture-user|fixture-password') 'Provenance serialized credentials or URI parameters.'
  $script:signatureCalls = 0
  $cachedResult = Invoke-QuickSetupPackageInstall vscode $definition -CachedInstallerPath $cached -SignatureProvider $signature -DownloadProvider { throw 'Cached route must not download.' } -ProcessRunner { return 1603 }
  Assert-Provenance ($cachedResult.ExitCode -eq 1603 -and !$cachedResult.RestartRequired) 'Failed installer result was silently converted to success.'
  Assert-Provenance ($cachedResult.Provenance.SourceKind -ceq 'cached' -and $null -eq $cachedResult.Provenance.ObservedFinalUri) 'Cached artifact invented a previously observed final URI.'
  Assert-Provenance ($cachedResult.Provenance.Artifact.Sha256 -ceq $hash -and $script:signatureCalls -eq 1) 'Cached artifact lacked current successful verification evidence.'
  $afterFailure = $null; $thrown = $false
  try {
    Invoke-QuickSetupPackageInstall vscode $definition -CachedInstallerPath $cached -SignatureProvider $signature -ProcessRunner { throw 'Mock process launch failed.' } -Provenance ([ref]$afterFailure) | Out-Null
  } catch { $thrown = $true }
  Assert-Provenance ($thrown -and $afterFailure.Artifact.Sha256 -ceq $hash) 'A process failure erased already verified artifact evidence.'
  $bad = $definition.PSObject.Copy(); $bad.Sha256 = '0' * 64
  $refused = 'stale'; $thrown = $false; $script:signatureCalls = 0
  try {
    Invoke-QuickSetupPackageInstall vscode $bad -CachedInstallerPath $cached -SignatureProvider $signature -ProcessRunner { throw 'Hash refusal reached runner.' } -Provenance ([ref]$refused) | Out-Null
  } catch { $thrown = $true }
  Assert-Provenance ($thrown -and $null -eq $refused -and $script:signatureCalls -eq 0) 'Failed hash validation emitted trusted provenance or reached signature validation.'
  $refused = 'stale'; $thrown = $false
  try {
    Invoke-QuickSetupPackageInstall vscode $definition -CachedInstallerPath $cached -SignatureProvider {
      [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::NotTrusted; SignerCertificate = $null }
    } -ProcessRunner { throw 'Signature refusal reached runner.' } -Provenance ([ref]$refused) | Out-Null
  } catch { $thrown = $true }
  Assert-Provenance ($thrown -and $null -eq $refused) 'Invalid signature emitted trusted provenance.'
  # Model an ancestor/path rebind deterministically: hold file A but present
  # path B. Both files are valid PE fixtures; only their content differs.
  $differentPath = Join-Path $directory 'different fixture.exe'
  $differentBytes = [byte[]]$bytes.Clone(); $differentBytes[255] = 42
  [IO.File]::WriteAllBytes($differentPath, $differentBytes)
  $held = [IO.File]::Open($cached, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
  try {
    foreach ($vendorHashAvailable in @($true, $false)) {
      $differentDefinition = $definition.PSObject.Copy()
      $differentDefinition.Sha256 = if ($vendorHashAvailable) { $hash } else { $null }
      $script:signatureCalls = 0; $continuedToRunner = $false; $thrown = $false; $refused = 'stale'
      try {
        Assert-QuickSetupDownloadedInstaller vscode $differentDefinition $differentPath -ArtifactStream $held -SignatureProvider $signature -Verification ([ref]$refused)
        $continuedToRunner = $true # No executable is launched even if the guard regresses.
      } catch { $thrown = $true }
      Assert-Provenance ($thrown -and !$continuedToRunner -and $script:signatureCalls -eq 0 -and $null -eq $refused) 'A mismatched locked stream/path reached signer or process continuation.'
      Assert-Provenance ($held.Position -eq 0) 'Mismatch rejection did not restore the held stream position.'
    }
  } finally { $held.Dispose() }
  $unsigned = $null; $seven = Get-QuickSetupSevenZipInstaller
  Assert-QuickSetupInstallerSignature seven-zip $seven $cached -FileHashProvider { $seven.Sha256 } -SignatureProvider {
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::NotSigned; SignerCertificate = $null }
  } -Verification ([ref]$unsigned)
  Assert-Provenance ($unsigned.Status -ceq 'NotSigned' -and $unsigned.Policy -ceq 'seven-zip-25.01-pinned-unsigned' -and $null -eq $unsigned.SignerSubject) 'Pinned unsigned artifact was mislabeled as signed.'
  "Installer provenance: $script:provenanceChecks assertions passed (mocked signatures/processes, no network)."
} finally {
  $env:TEMP = $oldTemp
  Remove-Item -LiteralPath $directory -Recurse -Force -ErrorAction SilentlyContinue
}
