# Deterministic fixtures only: no network, AppX deployment or real installer processes.
$ErrorActionPreference = "Stop"
$root = Split-Path -Parent $PSScriptRoot
$modules = Join-Path $root "bootstrap/windows-server-2022-developer/modules"
foreach ($name in @("Downloads", "Verification", "Installation", "Detection")) { Import-Module (Join-Path $modules "$name.psm1") -Force }
$script:checks = 0
function Assert($condition, [string]$message) { $script:checks++; if (!$condition) { throw $message } }
function Reject([scriptblock]$operation, [string]$message) {
  $rejected = $false
  try { & $operation | Out-Null } catch { $rejected = $true }
  Assert $rejected $message
}
$testRoot = Join-Path ([IO.Path]::GetTempPath()) ("configureme regression tests " + [guid]::NewGuid().ToString("N"))
$oldTemp = $env:TEMP
$oldLocal = $env:LOCALAPPDATA
try {
  New-Item -ItemType Directory -Path $testRoot | Out-Null
  $env:TEMP = $testRoot; $env:LOCALAPPDATA = $testRoot
  # Parse the complete engine with the current shell (also run by CI on PowerShell 5.1).
  foreach ($file in Get-ChildItem $modules -Filter *.psm1) {
    $tokens = $null; $errors = $null
    [void][Management.Automation.Language.Parser]::ParseFile($file.FullName, [ref]$tokens, [ref]$errors)
    Assert ($errors.Count -eq 0) "Parse errors: $($file.Name): $errors"
  }
  $bytes = New-Object byte[] 256
  $bytes[0] = 0x4d; $bytes[1] = 0x5a
  [Array]::Copy([BitConverter]::GetBytes([int]0x80), 0, $bytes, 0x3c, 4)
  $bytes[0x80] = 0x50; $bytes[0x81] = 0x45
  [Array]::Copy([BitConverter]::GetBytes([int]0x014c), 0, $bytes, 0x84, 2)
  $pe = Join-Path $testRoot "bootstrap.exe"; [IO.File]::WriteAllBytes($pe, $bytes)
  $hash256 = (Get-FileHash $pe -Algorithm SHA256).Hash
  $hash512 = (Get-FileHash $pe -Algorithm SHA512).Hash
  $vs = Get-QuickSetupInstallerDefinition vscode -MetadataProvider {
    param($uri)
    Assert ($uri -ceq "https://update.code.visualstudio.com/api/update/win32-x64-user/stable/latest") "Wrong VS Code architecture channel."
    [pscustomobject]@{ productVersion = "1.100.0"; sha256hash = $hash256; url = "https://vscode.download.prss.microsoft.com/dbazure/download/stable/fixture/VSCodeUserSetup-x64-1.100.0.exe" }
  }
  $sdk = Get-QuickSetupInstallerDefinition dotnet-10-sdk -MetadataProvider {
    param($uri)
    Assert ($uri -match '/10.0/releases.json$') "Wrong SDK channel."
    [pscustomobject]@{ releases = @([pscustomobject]@{ sdk = [pscustomobject]@{ version = "10.0.100"; files = @(
      [pscustomobject]@{ rid = "win-x86"; name = "dotnet-sdk-win-x86.exe"; url = "https://builds.dotnet.microsoft.com/bad.exe"; hash = $hash512 },
      [pscustomobject]@{ rid = "win-x64"; name = "dotnet-sdk-win-x64.exe"; url = "https://builds.dotnet.microsoft.com/dotnet/Sdk/10.0.100/dotnet-sdk-10.0.100-win-x64.exe"; hash = $hash512 }
    ) } }) }
  }
  Assert ($sdk.Version -eq "10.0.100" -and $sdk.Uri.AbsolutePath.EndsWith("win-x64.exe")) "Did not select x64 SDK."
  Assert (($sdk.Arguments -join ' ') -ceq '/install /quiet /norestart') "SDK silent arguments changed."
  $python = Get-QuickSetupPythonInstaller -MetadataProvider { [pscustomobject]@{ Content = '<a href="3.14.0/">a</a><a href="3.14.2/">b</a><a href="3.15.0b1/">preview</a>' } }
  Assert ($python.Version -eq '3.14.2' -and $python.InstallerType -eq 'exe' -and $python.Uri.AbsolutePath.EndsWith('-amd64.exe')) "Wrong stable Python x64 selection."
  Assert ($python.Arguments -contains 'Include_pip=1' -and $python.Arguments -contains 'InstallAllUsers=0') "Python must include pip and retain per-user scope."
  Assert ((Get-QuickSetupInstallerDefinition python -OfflinePreview).InstallerType -ne 'msix') "Server Python still depends on AppX deployment."
  foreach ($pair in @(@('vscode', $vs), @('dotnet-10-sdk', $sdk), @('python', $python))) {
    $id = $pair[0]; $definition = $pair[1]
    Assert (Test-QuickSetupBootstrapAuthorization $id $definition) "Missing explicit bootstrap authorization for $id."
    Reject { Test-QuickSetupInstallerFile $pe exe -ExpectedArchitecture x64 } "x86 was globally accepted."
    $check = Test-QuickSetupInstallerFile $pe exe -ExpectedArchitecture x64 -AllowX86BootstrapForX64:(Test-QuickSetupBootstrapAuthorization $id $definition)
    Assert ($check.Architecture -eq 'x64 payload (x86 bootstrap)') "Bootstrap distinction was not recorded."
    $bad = $definition.PSObject.Copy(); $bad.Uri = [uri]'https://attacker.invalid/installer-x64.exe'
    Assert (!(Test-QuickSetupBootstrapAuthorization $id $bad)) "Unauthorized source accepted for $id."
    $bad = $definition.PSObject.Copy(); $bad.Publisher = 'Unrelated Publisher'
    Assert (!(Test-QuickSetupBootstrapAuthorization $id $bad)) "Unauthorized publisher accepted."
  }
  $script:processCalls = 0
  foreach ($pair in @(@('vscode', $vs), @('dotnet-10-sdk', $sdk), @('python', $python))) {
    $id = $pair[0]; $definition = $pair[1]
    $exit = if ($id -eq 'dotnet-10-sdk') { 3010 } else { 0 }
    $install = Invoke-QuickSetupPackageInstall $id $definition -DownloadProvider {
      param($uri, $destination, $hosts) [IO.File]::WriteAllBytes($destination, $bytes); return $uri
    } -SignatureProvider {
      [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = $(if ($id -eq "dotnet-10-sdk") { "CN=.NET, O=Microsoft Corporation" } else { "CN=$($definition.Publisher)" }) } }
    } -AppxPackageProvider { throw 'AppX deployment unavailable: 0x80073CF0/0x80040154' } -ProcessRunner {
      param($path, $arguments) $script:processCalls++; return $exit
    }
    Assert ($install.ExitCode -eq $exit) "Installer exit code lost."
    if ($id -eq 'dotnet-10-sdk') { Assert $install.RestartRequired "Reboot-required SDK exit code lost." }
  }
  Assert ($script:processCalls -eq 3) "Expected one process per package, no AppX or manager command."
  foreach ($code in @(1641,1603)) {
    $result = Invoke-QuickSetupPackageInstall dotnet-10-sdk $sdk -DownloadProvider {
      param($uri,$destination,$hosts) [IO.File]::WriteAllBytes($destination,$bytes); $uri
    } -SignatureProvider {
      [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = 'CN=.NET, O=Microsoft Corporation' } }
    } -ProcessRunner { return $code }
    Assert ($result.ExitCode -eq $code -and $result.RestartRequired -eq ($code -eq 1641)) "Installer exit/reboot status $code was lost."
  }
  # Only the exact pinned 7-Zip MSI can be unsigned. An invalid signature is never unsigned.
  $seven = Get-QuickSetupSevenZipInstaller
  Assert ($seven.InstallerType -eq 'msi' -and $seven.ExpectedArchitecture -eq 'x64') "7-Zip must use the x64 MSI template."
  Assert-QuickSetupInstallerSignature seven-zip $seven $pe -FileHashProvider { $seven.Sha256 } -SignatureProvider {
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::NotSigned; SignerCertificate = $null }
  }
  foreach ($status in @('HashMismatch', 'NotTrusted', 'UnknownError', 'NotSupportedFileFormat')) {
    Reject { Assert-QuickSetupInstallerSignature seven-zip $seven $pe -FileHashProvider { $seven.Sha256 } -SignatureProvider {
      [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::$status; SignerCertificate = $null }
    } } "Invalid/untrusted 7-Zip signature accepted: $status."
  }
  Reject { Assert-QuickSetupInstallerSignature seven-zip $seven $pe -FileHashProvider { '0' * 64 } -SignatureProvider {
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::NotSigned; SignerCertificate = $null }
  } } 'Wrong 7-Zip digest accepted.'
  $wrong = $seven.PSObject.Copy(); $wrong.Uri = [uri]'https://github.com/unrelated/repo/release.msi'
  Reject { Assert-QuickSetupInstallerSignature seven-zip $wrong $pe -FileHashProvider { $seven.Sha256 } -SignatureProvider {
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::NotSigned; SignerCertificate = $null }
  } } 'Unsigned exception escaped pinned URL.'
  foreach ($status in @('NotSigned','NotTrusted','HashMismatch')) {
    Reject { Assert-QuickSetupInstallerSignature vscode $vs $pe -SignatureProvider {
      [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::$status; SignerCertificate = $null }
    } } "Strict signed policy changed: $status."
  }
  Assert-QuickSetupInstallerSignature vscode $vs $pe -SignatureProvider {
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation' } }
  }
  # Actual official .NET SDK 10.0.403 signer: CN=.NET, O=Microsoft Corporation.
  Assert ($sdk.ExpectedCommonName -ceq '.NET' -and $sdk.ExpectedOrganization -ceq 'Microsoft Corporation') 'Wrong SDK signer identity.'
  Assert-QuickSetupInstallerSignature dotnet-10-sdk $sdk $pe -SignatureProvider {
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = 'CN=.NET, O=Microsoft Corporation, C=US' } }
  }
  foreach ($subject in @('CN=.NET, O=Other Microsoft Corporation', 'CN=Other, O=Microsoft Corporation', 'CN=.NET, OU=Microsoft Corporation, O=Other', 'CN=.NET, OU="Fake, O=Microsoft Corporation, X=Fake", O=Other', 'CN=.NET, O=Microsoft Corporation, O=Other')) {
    Reject { Assert-QuickSetupInstallerSignature dotnet-10-sdk $sdk $pe -SignatureProvider {
      [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = $subject } }
    } } "Unapproved SDK signer accepted: $subject"
  }
  foreach ($status in @('NotSigned', 'HashMismatch', 'NotTrusted')) {
    Reject { Assert-QuickSetupInstallerSignature dotnet-10-sdk $sdk $pe -SignatureProvider {
      [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::$status; SignerCertificate = [pscustomobject]@{ Subject = 'CN=.NET, O=Microsoft Corporation' } }
    } } 'SDK accepted an invalid signature.'
  }
  # Installed VS Code can be verified without launching code.cmd/Electron in the worker.
  $vsMetadata = { [pscustomobject]@{ ProductName = 'Visual Studio Code'; ProductVersion = '1.100.0'; PackageVersion = '1.100.0' } }
  $version = Get-QuickSetupVerifiedApplicationVersion vscode -CandidatePaths @($pe) -ArchitectureVerifier { $true } -VsCodeMetadataProvider $vsMetadata -CommandRunner { throw 'Must not launch code.cmd' }
  Assert ($version -ceq '1.100.0') 'Installed VS Code was not verified from matching binary/package versions.'
  Assert ((Get-QuickSetupVerifiedApplicationVersion vscode -CandidatePaths @($pe) -ArchitectureVerifier { $true } -VsCodeMetadataProvider $vsMetadata) -eq $version) 'Existing VS Code was not detected again.'
  Assert (!(Get-QuickSetupVerifiedApplicationVersion vscode -CandidatePaths @($pe) -ArchitectureVerifier { $false } -VsCodeMetadataProvider $vsMetadata)) 'Installed x86 VS Code accepted.'
  Assert (!(Get-QuickSetupVerifiedApplicationVersion vscode -CandidatePaths @($pe) -ArchitectureVerifier { $true } -VsCodeMetadataProvider { throw 'Manifest missing' })) 'Missing VS Code manifest accepted.'
  foreach ($metadata in @(
    [pscustomobject]@{ ProductName = 'Other Editor'; ProductVersion = '1.100.0'; PackageVersion = '1.100.0' },
    [pscustomobject]@{ ProductName = 'Visual Studio Code'; ProductVersion = '1.100.0'; PackageVersion = '1.99.0' },
    [pscustomobject]@{ ProductName = 'Visual Studio Code'; ProductVersion = '1.100.0'; PackageVersion = 'invalid' }
  )) {
    Assert (!(Get-QuickSetupVerifiedApplicationVersion vscode -CandidatePaths @($pe) -ArchitectureVerifier { $true } -VsCodeMetadataProvider { $metadata })) 'Unverified VS Code metadata accepted.'
  }
  $script:probes = 0; $script:delays = 0
  $ready = Wait-QuickSetupInstalledVersion vscode -Attempts 3 -VersionProvider { $script:probes++; if ($script:probes -eq 3) { '1.100.0' } } -DelayProvider { $script:delays++ }
  Assert ($ready -eq '1.100.0' -and $script:probes -eq 3 -and $script:delays -eq 2) 'Post-install registration/file delay was not handled.'
  $script:probes = 0; $script:delays = 0
  $missing = Wait-QuickSetupInstalledVersion vscode -Attempts 3 -VersionProvider { $script:probes++; return $null } -DelayProvider { $script:delays++ }
  Assert (!$missing -and $script:probes -eq 3 -and $script:delays -eq 2) 'Missing installation was marked successful or retries were unbounded.'
  # Installed-app detection: explicit full paths, no dependency on current PATH.
  $script:detectedCommands = @()
  foreach ($id in @('dotnet-10-sdk', 'python', 'seven-zip')) {
    $runner = {
      param($path, $arguments)
      $script:detectedCommands += $path
      $output = switch ($id) {
        'vscode' { "1.100.0`ncommit`nx64`n" }
        'dotnet-10-sdk' { "10.0.100 [C:\\Program Files\\dotnet\\sdk]" }
        'seven-zip' { "7-Zip 25.01 (x64) : Copyright" }
        'python' { if ($arguments -contains 'pip') { 'pip 25.0 from installed runtime (python 3.14)' } else { '{"version":"3.14.2","bits":64,"implementation":"CPython"}' } }
      }
      [pscustomobject]@{ ExitCode = 0; Output = $output }
    }
    $version = Get-QuickSetupVerifiedApplicationVersion $id -CandidatePaths @($pe) -ArchitectureVerifier { $true } -CommandRunner $runner
    Assert ([bool]$version) "Installed $id was not verified."
    Assert ((Get-QuickSetupVerifiedApplicationVersion $id -CandidatePaths @($pe) -ArchitectureVerifier { $true } -CommandRunner $runner) -eq $version) "Repeat detection changed."
    Assert (!(Get-QuickSetupVerifiedApplicationVersion $id -CandidatePaths @($pe) -ArchitectureVerifier { $false } -CommandRunner $runner)) "Installed x86 $id passed x64 verification."
    Assert (!(Get-QuickSetupVerifiedApplicationVersion $id -CandidatePaths @($pe) -ArchitectureVerifier { $true } -CommandRunner { [pscustomobject]@{ ExitCode = 1; Output = '10.0.100 [sdk]' } })) "Failed installed application command accepted."
  }
  Assert (!(Get-QuickSetupVerifiedApplicationVersion dotnet-10-sdk -CandidatePaths @($pe) -ArchitectureVerifier { $true } -CommandRunner { [pscustomobject]@{ ExitCode = 0; Output = 'Microsoft.NETCore.App 10.0.0 [shared]' } })) 'Runtime-only install counted as SDK.'
  Assert (!(Get-QuickSetupVerifiedApplicationVersion python -CandidatePaths @($pe) -ArchitectureVerifier { $true } -CommandRunner {
    param($path,$arguments)
    if ($arguments -contains 'pip') { [pscustomobject]@{ ExitCode = 1; Output = 'pip 25.0 stale text' } } else { [pscustomobject]@{ ExitCode = 0; Output = '{"version":"3.14.2","bits":64,"implementation":"CPython"}' } }
  })) 'Python without working pip counted as successful.'
  Assert (!(Get-QuickSetupVerifiedApplicationVersion python -CandidatePaths @($pe) -ArchitectureVerifier { $true } -CommandRunner { [pscustomobject]@{ ExitCode = 0; Output = '{"version":"3.14.2","bits":32,"implementation":"CPython"}' } })) 'Python reported x86 accepted.'
  Assert (!(Get-QuickSetupVerifiedApplicationVersion python -CandidatePaths @($pe) -ArchitectureVerifier { $true } -CommandRunner { [pscustomobject]@{ ExitCode = 0; Output = '{"version":"3.9.0","bits":64,"implementation":"CPython"}' } })) 'Unsupported Python version counted as successful.'
  # Actual PE reader, not the architecture test seam, must reject these x86 fixture applications.
  Assert (!(Get-QuickSetupVerifiedApplicationVersion dotnet-10-sdk -CandidatePaths @($pe) -CommandRunner { throw 'Must not execute x86 app' })) 'Installed PE check was bypassed.'
  # The GUI download stage and the install stage share this validation entry point.
  Assert-QuickSetupDownloadedInstaller vscode $vs $pe -SignatureProvider {
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation' } }
  }
  $badCache = $vs.PSObject.Copy(); $badCache.Sha256 = '0' * 64
  Reject { Assert-QuickSetupDownloadedInstaller vscode $badCache $pe -SignatureProvider { throw 'Hash must fail first' } } 'Tampered cached installer accepted.'
  $unsignedOther = $vs.PSObject.Copy(); $unsignedOther | Add-Member -NotePropertyName VerificationPolicy -NotePropertyValue 'seven-zip-25.01-pinned-unsigned'
  Reject { Assert-QuickSetupInstallerSignature vscode $unsignedOther $pe -SignatureProvider {
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::NotSigned; SignerCertificate = $null }
  } } '7-Zip exception authorized another package.'
  Reject { Get-QuickSetupInstallerDefinition dotnet-10-sdk -MetadataProvider {
    [pscustomobject]@{ releases = @([pscustomobject]@{ sdk = [pscustomobject]@{ version = '10.0.100'; files = @(
      [pscustomobject]@{ rid = 'win-x64'; name = 'dotnet-sdk-win-x64.exe'; url = 'https://builds.dotnet.microsoft.com/dotnet-sdk-10.0.100-win-x64.exe'; hash = '' }
    ) } }) }
  } } 'SDK without official SHA512 accepted.'
  Assert (!(Test-QuickSetupBootstrapAuthorization unrelated $vs)) 'Bootstrap exception authorized another package.'
  . (Join-Path $root 'scripts/Start-SetupWithDiagnostics.ps1')
  Assert ((Get-SetupStartupFailureMessage -ExitCode -2146233082) -match 'CET' ) 'CoreCLR startup diagnostic lost.'
  Assert ((Get-SetupStartupFailureMessage -ExitCode 1) -notmatch 'CET-Inkompatibilitaet') 'Unrelated exit code misdiagnosed as CET.'
  # Kernel sharing semantics are a Windows-only acceptance check. POSIX .NET
  # advisory locks are not evidence of protection against arbitrary writers.
  if ([Environment]::OSVersion.Platform -eq [PlatformID]::Win32NT) {
    $handoffPath = Join-Path $testRoot 'handoff fixture.exe'
    [IO.File]::WriteAllBytes($handoffPath, $bytes)
    $mutated = [byte[]]$bytes.Clone(); $mutated[255] = 42
    $script:handoffProcessCalls = 0
    $handoffSignature = {
      [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = 'CN=Microsoft Corporation' } }
    }
    # A reader remains compatible, and the existing exit/reboot result is kept.
    $handoff = Invoke-QuickSetupPackageInstall vscode $vs -CachedInstallerPath $handoffPath -SignatureProvider $handoffSignature -ProcessRunner {
      param($path, $arguments)
      $script:handoffProcessCalls++
      Assert ((Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash -eq $hash256) 'Process handoff did not retain verified fixture bytes.'
      return 3010
    }
    Assert ($handoff.ExitCode -eq 3010 -and $handoff.RestartRequired -and $script:handoffProcessCalls -eq 1) 'Locked unchanged installer did not preserve normal execution/reboot reporting.'
    # A callback mutation must abort before the runner, never be ignored.
    foreach ($blockedStage in @('verification-completed', 'installation-started')) {
      [IO.File]::WriteAllBytes($handoffPath, $bytes)
      $script:handoffProcessCalls = 0; $script:handoffMutationAttempted = $false
      Reject {
        Invoke-QuickSetupPackageInstall vscode $vs -CachedInstallerPath $handoffPath -SignatureProvider $handoffSignature -ProgressCallback {
          param($stage)
          if ($stage -eq $blockedStage) {
            $script:handoffMutationAttempted = $true
            [IO.File]::WriteAllBytes($handoffPath, $mutated)
          }
        } -ProcessRunner { $script:handoffProcessCalls++; return 0 }
      } "A mutation at $blockedStage was not refused."
      Assert $script:handoffMutationAttempted "Mutation stage $blockedStage was not exercised."
      Assert ($script:handoffProcessCalls -eq 0) "An installer runner was called after attempted mutation at $blockedStage."
      Assert ((Get-FileHash -LiteralPath $handoffPath -Algorithm SHA256).Hash -eq $hash256) 'The locked fixture was modified.'
    }
    # Existing writers prevent validation/start, rather than getting trusted later.
    $script:handoffProcessCalls = 0
    $writer = [IO.File]::Open($handoffPath, [IO.FileMode]::Open, [IO.FileAccess]::ReadWrite, [IO.FileShare]::ReadWrite)
    try {
      Reject {
        Invoke-QuickSetupPackageInstall vscode $vs -CachedInstallerPath $handoffPath -SignatureProvider { throw 'Must not validate a writable handoff.' } -ProcessRunner { $script:handoffProcessCalls++; return 0 }
      } 'An existing writer was accepted during installer handoff.'
      Assert ($script:handoffProcessCalls -eq 0) 'Existing writer still reached the installer runner.'
    } finally { $writer.Dispose() }
    # Error and successful exits must both release the lock. Never delete a shared cache file.
    Reject {
      Invoke-QuickSetupPackageInstall vscode $badCache -CachedInstallerPath $handoffPath -SignatureProvider $handoffSignature -ProcessRunner { throw 'Hash failure reached process execution.' }
    } 'The locked installer did not retain official metadata hash rejection.'
    [IO.File]::WriteAllBytes($handoffPath, $mutated)
    Assert ((Get-FileHash -LiteralPath $handoffPath -Algorithm SHA256).Hash -ne $hash256) 'Verification failure leaked the handoff lock.'
    [IO.File]::WriteAllBytes($handoffPath, $bytes)
    $handoff = Invoke-QuickSetupPackageInstall vscode $vs -CachedInstallerPath $handoffPath -SignatureProvider $handoffSignature -ProcessRunner { return 0 }
    [IO.File]::WriteAllBytes($handoffPath, $mutated)
    Assert ($handoff.ExitCode -eq 0 -and (Get-FileHash -LiteralPath $handoffPath -Algorithm SHA256).Hash -ne $hash256) 'Successful process exit leaked the handoff lock.'
  } else {
    Write-Host 'NOT EXECUTED: installer deny-write/delete handoff assertions require Windows kernel sharing semantics (run in Windows PS5.1 and PS7 CI).'
  }
  "Installer regressions: $script:checks assertions passed."
} finally {
  $env:TEMP = $oldTemp; $env:LOCALAPPDATA = $oldLocal
  Remove-Item -LiteralPath $testRoot -Recurse -Force -ErrorAction SilentlyContinue
}
