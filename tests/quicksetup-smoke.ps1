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

function Invoke-GuiWorkerTestRequest {
  param([Parameter(Mandatory = $true)]$Request)

  $startInfo = New-Object System.Diagnostics.ProcessStartInfo
  $startInfo.FileName = "powershell.exe"
  $startInfo.Arguments = '-NoLogo -NoProfile -NonInteractive -File "' + (Join-Path $packageRoot "bootstrap.ps1") + '" -GuiWorker'
  $startInfo.UseShellExecute = $false
  $startInfo.CreateNoWindow = $true
  $startInfo.RedirectStandardInput = $true
  $startInfo.RedirectStandardOutput = $true
  $startInfo.RedirectStandardError = $true
  $process = New-Object System.Diagnostics.Process
  $process.StartInfo = $startInfo
  if (!$process.Start()) { throw "The GUI worker process could not be started." }
  $requestJson = ConvertTo-Json -InputObject $Request -Compress -Depth 8
  $requestBytes = [System.Text.Encoding]::UTF8.GetBytes($requestJson + [Environment]::NewLine)
  $process.StandardInput.BaseStream.Write($requestBytes, 0, $requestBytes.Length)
  $process.StandardInput.BaseStream.Flush()
  $process.StandardInput.Close()
  $output = $process.StandardOutput.ReadToEnd()
  $errorOutput = $process.StandardError.ReadToEnd()
  $process.WaitForExit()
  [pscustomobject]@{
    ExitCode = $process.ExitCode
    Events = @($output -split "`r?`n" | Where-Object { $_ } | ForEach-Object { $_ | ConvertFrom-Json })
    StandardError = $errorOutput
    RequestJson = $requestJson
  }
}

function New-TestPeBytes {
  param([int]$Machine)
  $bytes = New-Object byte[] 256
  $bytes[0] = 0x4D
  $bytes[1] = 0x5A
  [Array]::Copy([BitConverter]::GetBytes([int]0x80), 0, $bytes, 0x3C, 4)
  $bytes[0x80] = 0x50
  $bytes[0x81] = 0x45
  [Array]::Copy([BitConverter]::GetBytes([int]0), 0, $bytes, 0x82, 2)
  [Array]::Copy([BitConverter]::GetBytes([int]$Machine), 0, $bytes, 0x84, 2)
  return ,$bytes
}

function New-TestMsixPackage {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [string]$Publisher = "CN=Python Software Foundation, O=Python Software Foundation, L=Beaverton, S=Oregon, C=US",
    [string]$Architecture = "x64"
  )

  Add-Type -AssemblyName System.IO.Compression
  $stream = [System.IO.File]::Open($Path, [System.IO.FileMode]::Create)
  $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
  try {
    $manifest = '<Package xmlns="http://schemas.microsoft.com/appx/manifest/foundation/windows10"><Identity Name="PythonSoftwareFoundation.PythonManager" Publisher="' + $Publisher + '" Version="26.4.240.0" ProcessorArchitecture="' + $Architecture + '" /></Package>'
    foreach ($entryName in @("AppxManifest.xml", "AppxSignature.p7x")) {
      $entry = $archive.CreateEntry($entryName)
      $entryStream = $entry.Open()
      try {
        $bytes = if ($entryName -eq "AppxManifest.xml") { [System.Text.Encoding]::UTF8.GetBytes($manifest) } else { [byte[]](1, 2, 3) }
        $entryStream.Write($bytes, 0, $bytes.Length)
      } finally { $entryStream.Dispose() }
    }
  } finally {
    $archive.Dispose()
    $stream.Dispose()
  }
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

  Import-Module (Join-Path $moduleRoot "Logging.psm1") -Force
  Import-Module (Join-Path $moduleRoot "Verification.psm1") -Force
  Import-Module (Join-Path $moduleRoot "Downloads.psm1") -Force
  Import-Module (Join-Path $moduleRoot "Detection.psm1") -Force
  Import-Module (Join-Path $moduleRoot "Installation.psm1") -Force
  Import-Module (Join-Path $moduleRoot "GuiWorker.psm1") -Force
  $progressState = @{ Phase = "preparation" }
  $callback = New-QuickSetupGuiProgressCallback -Id "python" -ProgressState $progressState
  & $callback "installation-started"
  Assert-True ($progressState.Phase -eq "installation-started") "The Python progress callback could not update its phase across module scope."
  $profile = Get-Content -LiteralPath (Join-Path $packageRoot "config\windows-server-2022-developer.json") -Raw | ConvertFrom-Json
  $expectedIds = @("git", "github-cli", "vscode", "nodejs-lts", "python", "dotnet-10-sdk", "powershell-7", "seven-zip", "firefox", "openssh-client")
  Assert-True (@($profile.packages | Where-Object { $_ -in $expectedIds }).Count -eq $expectedIds.Count) "The profile is missing a required P0 package."
  Test-QuickSetupProfile -Profile $profile -AllowedPackageIds @($profile.packages)
  $expectedInstallerTypes = @{
    "git" = "exe"; "github-cli" = "msi"; "vscode" = "exe"; "nodejs-lts" = "msi"
    "python" = "msix"; "dotnet-10-sdk" = "exe"; "powershell-7" = "msi"; "seven-zip" = "exe"
    "firefox" = "msi"; "openssh-client" = "windows-capability"
  }
  foreach ($id in $expectedInstallerTypes.Keys) {
    $definition = Get-QuickSetupInstallerDefinition -Id $id -OfflinePreview
    Assert-True ($definition.InstallerType -eq $expectedInstallerTypes[$id]) "The $id package did not declare its installer type."
  }
  $gitPreview = Get-QuickSetupInstallerDefinition -Id "git" -OfflinePreview
  Assert-True ($gitPreview.Automatic -and (($gitPreview.Arguments -join " ") -ceq "/VERYSILENT /NORESTART /NOCANCEL /SP-")) "Git did not use only the approved documented Inno Setup switches."
  Assert-True ($gitPreview.Publisher -ceq "Johannes Schindelin" -and $gitPreview.ExpectedCommonName -ceq "Johannes Schindelin") "Git did not pin the exact approved signer identity."
  $copilotPreview = Get-QuickSetupInstallerDefinition -Id "github-copilot-desktop" -OfflinePreview
  Assert-True ($copilotPreview.Automatic -and $copilotPreview.InstallerType -eq "exe" -and ($copilotPreview.Arguments -join " ") -ceq "/S") "Copilot Desktop does not use the reviewed NSIS silent install switch."
  Assert-True ($copilotPreview.Version -eq "1.1.34" -and $copilotPreview.Sha256 -eq "4a8070a63b228895344a6c4f4536a01a62085e02821829b21786638234580e00") "Copilot Desktop release was not pinned to the reviewed official bytes."
  Assert-True ($copilotPreview.AllowX86BootstrapForX64 -and $copilotPreview.ExpectedCommonName -ceq "GitHub, Inc." -and !$copilotPreview.RequiresAdministrator) "Copilot Desktop did not declare the verified bootstrap architecture, signer, and current-user install."
  $libreOfficePreview = Get-QuickSetupInstallerDefinition -Id "libreoffice" -OfflinePreview
  Assert-True ($libreOfficePreview.Automatic -and $libreOfficePreview.InstallerType -eq "msi" -and $libreOfficePreview.Publisher -eq "The Document Foundation" -and $libreOfficePreview.ExpectedCommonName -eq "The Document Foundation") "LibreOffice did not declare its optional MSI and exact signer."
  Assert-True (@($profile.packages | Where-Object { $_ -eq "libreoffice" }).Count -eq 0) "LibreOffice was selected in the default profile."
  Assert-True ((Get-QuickSetupGitVersion -Output "git version 2.56.0.windows.4" -ExitCode 0) -eq "2.56.0.windows.4") "The Git version parser did not read the exact git --version output."
  Assert-True ($null -eq (Get-QuickSetupGitVersion -Output "git version 2.56.0.windows.4" -ExitCode 1)) "A failing git --version command was treated as successful."
  Assert-True ($null -eq (Get-QuickSetupGitVersion -Output "not git output" -ExitCode 0)) "Malformed git --version output was accepted."
  $mockGitInstalledVersion = Get-QuickSetupDetectedVersion -Id "git" -GitVersionProvider {
    [pscustomobject]@{ Output = "git version 2.56.0.windows.4"; ExitCode = 0 }
  }
  $mockGitMissingVersion = Get-QuickSetupDetectedVersion -Id "git" -GitVersionProvider {
    [pscustomobject]@{ Output = ""; ExitCode = 1 }
  }
  Assert-True ($mockGitInstalledVersion -eq "2.56.0.windows.4" -and $null -eq $mockGitMissingVersion) "Git installed/missing detection did not use git --version success and failure correctly."
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
  $wrongPublisher = Test-QuickSetupAuthenticodePublisher -Path $fakeInstaller -ExpectedPublisher "Microsoft Corporation" -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = "CN=Unrelated Publisher" }
    }
  }
  Assert-True (!$wrongPublisher.IsValid) "A valid signature from the wrong publisher was accepted."
  $approvedGitSigner = Test-QuickSetupAuthenticodePublisher -Path $fakeInstaller -ExpectedPublisher "Johannes Schindelin" -ExpectedCommonName "Johannes Schindelin" -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = "CN=Johannes Schindelin, O=Git for Windows" }
    }
  }
  Assert-True $approvedGitSigner.IsValid "The exact approved Git signer identity was rejected."
  $quotedLibreOfficeSigner = Test-QuickSetupAuthenticodePublisher -Path $fakeInstaller -ExpectedPublisher "The Document Foundation" -ExpectedCommonName "The Document Foundation" -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = 'CN="The Document Foundation", O="The Document Foundation", L=Berlin, C=DE' }
    }
  }
  Assert-True $quotedLibreOfficeSigner.IsValid "The exact quoted LibreOffice signer common name was rejected."
  $wrongGitSigner = Test-QuickSetupAuthenticodePublisher -Path $fakeInstaller -ExpectedPublisher "Johannes Schindelin" -ExpectedCommonName "Johannes Schindelin" -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = "CN=Johannes Schindelin Backup, O=Git for Windows" }
    }
  }
  Assert-True (!$wrongGitSigner.IsValid) "A similarly named Git signer passed the exact common-name check."
  $trustedCopilotSigner = Test-QuickSetupAuthenticodePublisher -Path $fakeInstaller -ExpectedPublisher "GitHub, Inc." -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = 'CN="GitHub, Inc.", O="GitHub, Inc.", L=San Francisco, S=California, C=US' }
    }
  }
  Assert-True $trustedCopilotSigner.IsValid "The official GitHub, Inc. Copilot signer was rejected."
  $untrustedCopilotSigner = Test-QuickSetupAuthenticodePublisher -Path $fakeInstaller -ExpectedPublisher "GitHub, Inc." -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = "CN=Unrelated Publisher" }
    }
  }
  Assert-True (!$untrustedCopilotSigner.IsValid) "A Copilot installer from an unrelated signer was accepted."
  $invalidSignature = Test-QuickSetupAuthenticodePublisher -Path $fakeInstaller -ExpectedPublisher "Johannes Schindelin" -ExpectedCommonName "Johannes Schindelin" -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::NotSigned
      SignerCertificate = $null
    }
  }
  Assert-True (!$invalidSignature.IsValid) "An installer with no Authenticode signature was accepted."
  $copilotInstallMarker = Join-Path $temporaryDirectory "copilot-user-data.json"
  Set-Content -LiteralPath $copilotInstallMarker -Value '{"userData":"keep"}' -Encoding UTF8
  $copilotDataHash = (Get-FileHash -LiteralPath $copilotInstallMarker -Algorithm SHA256).Hash
  $copilotDetectedVersion = Get-QuickSetupDetectedVersion -Id "github-copilot-desktop" -RegistryProvider {
    param($registryPath)
    if ($registryPath -like "HKCU:*") {
      return [pscustomobject]@{ DisplayName = "GitHub Copilot"; DisplayVersion = "1.1.34" }
    }
    return @()
  } -PathExistsProvider { param($path) $false }
  Assert-True ($copilotDetectedVersion -eq "1.1.34") "The existing GitHub Copilot Desktop 1.1.34 install was not detected."
  Assert-True ((Get-FileHash -LiteralPath $copilotInstallMarker -Algorithm SHA256).Hash -eq $copilotDataHash) "Copilot detection modified user data."
  $copilotCliOnly = Get-QuickSetupDetectedVersion -Id "github-copilot-desktop" -RegistryProvider {
    param($registryPath)
    if ($registryPath -like "HKCU:*") {
      return [pscustomobject]@{ DisplayName = "GitHub Copilot CLI"; DisplayVersion = "0.1.0" }
    }
    return @()
  } -PathExistsProvider { param($path) $false }
  Assert-True ($null -eq $copilotCliOnly) "Copilot CLI was incorrectly detected as the Desktop app."
  $libreOfficeDetectedVersion = Get-QuickSetupDetectedVersion -Id "libreoffice" -RegistryProvider {
    param($registryPath)
    if ($registryPath -like "HKLM:*") {
      return [pscustomobject]@{ DisplayName = "LibreOffice 26.8"; DisplayVersion = "26.8.2.1" }
    }
    return @()
  }
  Assert-True ($libreOfficeDetectedVersion -eq "26.8.2.1") "The existing LibreOffice installation was not detected."
  $script:releaseRepository = $null
  $gitDigest = "A" * 64
  $gitRelease = Get-QuickSetupGithubReleaseInstaller -Repository "git-for-windows/git" -AssetPattern "^Git-[0-9.]+-64-bit\.exe$" -ReleaseProvider {
    param($repository)
    $script:releaseRepository = $repository
    [pscustomobject]@{
      tag_name = "v2.56.0.windows.4"
      body = "| Git-2.56.0.4-64-bit.exe | $gitDigest |"
      assets = @(
        [pscustomobject]@{
          name = "Git-2.56.0.4-64-bit.exe"
          browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/Git-2.56.0.4-64-bit.exe"
          digest = "sha256:$gitDigest"
        }
      )
    }
  }
  Assert-True ($script:releaseRepository -eq "git-for-windows/git" -and $gitRelease.Version -eq "v2.56.0.windows.4" -and $gitRelease.Sha256 -eq $gitDigest) "Git did not resolve its official release asset digest."
  $gitReleaseFallback = Get-QuickSetupGithubReleaseInstaller -Repository "git-for-windows/git" -AssetPattern "^Git-[0-9.]+-64-bit\.exe$" -ReleaseProvider {
    param($repository)
    [pscustomobject]@{
      tag_name = "v2.56.0.windows.4"
      body = "| Git-2.56.0.4-64-bit.exe | $gitDigest |"
      assets = @(
        [pscustomobject]@{
          name = "Git-2.56.0.4-64-bit.exe"
          browser_download_url = "https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/Git-2.56.0.4-64-bit.exe"
          digest = $null
        }
      )
    }
  }
  Assert-True ($gitReleaseFallback.Sha256 -eq $gitDigest) "Git's official release-body SHA-256 fallback was not read."
  $libreOfficeMirrorlist = '<li><span class="mirrorbrain-label">Path:</span> /libreoffice/stable/26.8.2/win/x86_64/LibreOffice_26.8.2_Win_x86-64.msi</li><li><span class="mirrorbrain-label"><a href="/libreoffice/stable/26.8.2/win/x86_64/LibreOffice_26.8.2_Win_x86-64.msi.sha256">SHA-256 Hash</a>:</span> <tt>' + ("B" * 64) + '</tt></li><li><a href="https://mirror.example.org/tdf/libreoffice/stable/26.8.2/win/x86_64/LibreOffice_26.8.2_Win_x86-64.msi">mirror</a></li>'
  $libreOfficeMetadata = Get-QuickSetupLibreOfficeInstaller -WebRequestProvider {
    param($uri)
    if ($uri.AbsoluteUri -eq "https://download.documentfoundation.org/libreoffice/stable/") {
      return [pscustomobject]@{ Content = '<a href="25.8.7/"></a><a href="26.8.2/"></a>' }
    }
    return [pscustomobject]@{ Content = $libreOfficeMirrorlist }
  }
  Assert-True ($libreOfficeMetadata.Version -eq "26.8.2" -and $libreOfficeMetadata.Sha256 -eq ("B" * 64) -and $libreOfficeMetadata.AllowedHosts -contains "mirror.example.org") "LibreOffice did not verify the official MSI metadata and mirror list."
  Assert-True (!(Test-QuickSetupAdministratorRequirement -RequiresAdministrator $true -IsAdministrator $false)) "A system installer was allowed without administrator rights."
  Assert-True (Test-QuickSetupAdministratorRequirement -RequiresAdministrator $false -IsAdministrator $false) "A per-user installer incorrectly required administrator rights."
  $originalProcessPath = $env:Path
  try {
    $env:Path = "C:\quicksetup-current"
    Sync-QuickSetupProcessPath -MachinePath "C:\quicksetup-machine;C:\quicksetup-current" -UserPath "C:\quicksetup-user"
    Assert-True (($env:Path -split ";") -contains "C:\quicksetup-machine" -and ($env:Path -split ";") -contains "C:\quicksetup-user") "Persisted installer PATH changes were not applied to the current process."
    Assert-True (@($env:Path -split ";" | Where-Object { $_ -eq "C:\quicksetup-current" }).Count -eq 1) "PATH refresh duplicated an existing entry."
  } finally { $env:Path = $originalProcessPath }

  $msiPath = Join-Path $temporaryDirectory "mock-installer.msi"
  [IO.File]::WriteAllBytes($msiPath, [byte[]](0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1))
  $msiCheck = Test-QuickSetupInstallerFile -Path $msiPath -InstallerType "msi" -ExpectedArchitecture "x64" -MsiPlatformReader { param($path) "x64;1033" }
  Assert-True ($msiCheck.InstallerType -eq "msi" -and $msiCheck.Architecture -eq "x64") "The MSI signature and mocked x64 template were not validated."
  $wrongMsiArchitecture = $false
  try { Test-QuickSetupInstallerFile -Path $msiPath -InstallerType "msi" -ExpectedArchitecture "x64" -MsiPlatformReader { param($path) "Intel;1033" } | Out-Null } catch { $wrongMsiArchitecture = $true }
  Assert-True $wrongMsiArchitecture "An x86 MSI was accepted as x64."

  $exePath = Join-Path $temporaryDirectory "mock-installer.exe"
  [IO.File]::WriteAllBytes($exePath, (New-TestPeBytes -Machine 0x8664))
  $exeCheck = Test-QuickSetupInstallerFile -Path $exePath -InstallerType "exe" -ExpectedArchitecture "x64"
  Assert-True ($exeCheck.InstallerType -eq "exe" -and $exeCheck.Architecture -eq "x64") "A valid x64 PE installer was rejected."
  [IO.File]::WriteAllBytes($exePath, (New-TestPeBytes -Machine 0x014c))
  $wrongExeArchitecture = $false
  try { Test-QuickSetupInstallerFile -Path $exePath -InstallerType "exe" -ExpectedArchitecture "x64" | Out-Null } catch { $wrongExeArchitecture = $true }
  Assert-True $wrongExeArchitecture "An x86 EXE was accepted as x64."
  $pythonBootstrapCheck = Test-QuickSetupInstallerFile -Path $exePath -InstallerType "exe" -ExpectedArchitecture "x64" -AllowX86BootstrapForX64
  Assert-True ($pythonBootstrapCheck.Architecture -eq "x64 payload (x86 bootstrap)") "The explicit x86-bootstrap/x64-payload exception was not recorded."
  Set-Content -LiteralPath $exePath -Value "<html>download error</html>" -Encoding ASCII
  $htmlRefused = $false
  try { Test-QuickSetupInstallerFile -Path $exePath -InstallerType "exe" -ExpectedArchitecture "x64" | Out-Null } catch { $htmlRefused = $true }
  Assert-True $htmlRefused "An HTML response was accepted as an installer."

  $msixPath = Join-Path $temporaryDirectory "python-manager.msix"
  New-TestMsixPackage -Path $msixPath
  $msixCheck = Test-QuickSetupInstallerFile -Path $msixPath -InstallerType "msix" -ExpectedArchitecture "x64" -ExpectedPackageName "PythonSoftwareFoundation.PythonManager" -ExpectedPackagePublisher "CN=Python Software Foundation, O=Python Software Foundation, L=Beaverton, S=Oregon, C=US"
  Assert-True ($msixCheck.InstallerType -eq "msix" -and $msixCheck.PackageName -eq "PythonSoftwareFoundation.PythonManager") "A valid Python manager MSIX identity was rejected."
  $wrongMsixPublisher = $false
  try {
    Test-QuickSetupInstallerFile -Path $msixPath -InstallerType "msix" -ExpectedArchitecture "x64" -ExpectedPackageName "PythonSoftwareFoundation.PythonManager" -ExpectedPackagePublisher "CN=Unrelated Publisher" | Out-Null
  } catch { $wrongMsixPublisher = $true }
  Assert-True $wrongMsixPublisher "An MSIX package from the wrong publisher was accepted."
  $wrongMsixArchitecturePath = Join-Path $temporaryDirectory "python-manager-x86.msix"
  New-TestMsixPackage -Path $wrongMsixArchitecturePath -Architecture "x86"
  $wrongMsixArchitecture = $false
  try {
    Test-QuickSetupInstallerFile -Path $wrongMsixArchitecturePath -InstallerType "msix" -ExpectedArchitecture "x64" -ExpectedPackageName "PythonSoftwareFoundation.PythonManager" -ExpectedPackagePublisher "CN=Python Software Foundation, O=Python Software Foundation, L=Beaverton, S=Oregon, C=US" | Out-Null
  } catch { $wrongMsixArchitecture = $true }
  Assert-True $wrongMsixArchitecture "An x86 Python manager MSIX was accepted as x64."

  $installTemp = Join-Path $temporaryDirectory "installer path with spaces"
  New-Item -ItemType Directory -Path $installTemp -Force | Out-Null
  $originalTemp = $env:TEMP
  $env:TEMP = $installTemp
  $script:mockInstallerCalls = 0
  $script:mockExitCode = 0
  $signatureProvider = {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = "CN=Mozilla Corporation" }
    }
  }
  $msiDefinition = [pscustomobject]@{
    Automatic = $true; InstallerType = "msi"; ExpectedArchitecture = "x64"
    Uri = [uri]"https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64"
    AllowedHosts = @("mozilla.org"); Sha256 = $null; Sha512 = $null
    Publisher = "Mozilla Corporation"; Arguments = @("/qn", "/norestart")
  }
  $msiDownloadProvider = {
    param($uri, $destination, $allowedHosts)
    [IO.File]::WriteAllBytes($destination, [byte[]](0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1))
    return [uri]"https://download.mozilla.org/"
  }
  $msiProcessRunner = {
    param($path, $arguments)
    $script:mockInstallerCalls++
    if ($path -ne "msiexec.exe") { throw "MSI was not launched through msiexec.exe." }
    if ($arguments.Count -ne 4 -or $arguments[0] -ne "/i" -or $arguments[1] -notmatch '^".*installer\.msi"$') {
      throw "MSI arguments did not safely quote the installer path: $($arguments -join '|')"
    }
    if ($arguments[1] -notmatch "installer path with spaces") { throw "The MSI path with spaces was not preserved." }
    return $script:mockExitCode
  }
  foreach ($expectedExitCode in @(0, 3010, 1603)) {
    $script:mockExitCode = $expectedExitCode
    $installResult = Invoke-QuickSetupPackageInstall -Id "firefox" -Definition $msiDefinition -DownloadProvider $msiDownloadProvider -MsiPlatformReader { param($path) "x64;1033" } -SignatureProvider $signatureProvider -ProcessRunner $msiProcessRunner
    Assert-True ($installResult.ExitCode -eq $expectedExitCode -and $installResult.RestartRequired -eq ($expectedExitCode -eq 3010)) "MSI exit code $expectedExitCode was not interpreted correctly."
  }
  Assert-True ($script:mockInstallerCalls -eq 3) "The MSI process runner was not called once per installation attempt."

  $script:mockInstallerCalls = 0
  $script:mockExitCode = 0
  $exeDefinition = [pscustomobject]@{
    Automatic = $true; InstallerType = "exe"; ExpectedArchitecture = "x64"
    Uri = [uri]"https://download.microsoft.com/installer?channel=stable"
    AllowedHosts = @("microsoft.com"); Sha256 = $null; Sha512 = $null
    Publisher = "Microsoft Corporation"; Arguments = @("/quiet", "/norestart")
  }
  $exeDownloadProvider = {
    param($uri, $destination, $allowedHosts)
    [IO.File]::WriteAllBytes($destination, (New-TestPeBytes -Machine 0x8664))
    return [uri]"https://download.microsoft.com/"
  }
  $exeProcessRunner = {
    param($path, $arguments)
    $script:mockInstallerCalls++
    if ($path -notmatch "\\installer\.exe$" -or $path -eq "msiexec.exe") { throw "EXE installer was not launched directly." }
    if ($arguments -join " " -ne "/quiet /norestart") { throw "The EXE installer arguments changed." }
    return $script:mockExitCode
  }
  $exeInstallResult = Invoke-QuickSetupPackageInstall -Id "vscode" -Definition $exeDefinition -DownloadProvider $exeDownloadProvider -SignatureProvider {
    param($path)
    [pscustomobject]@{ Status = [System.Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = "CN=Microsoft Corporation" } }
  } -ProcessRunner $exeProcessRunner
  Assert-True ($exeInstallResult.ExitCode -eq 0 -and $script:mockInstallerCalls -eq 1) "EXE installation was not executed directly."

  $gitInstallDefinition = $gitPreview.PSObject.Copy()
  $gitInstallDefinition | Add-Member -NotePropertyName Uri -NotePropertyValue ([uri]"https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/Git-2.56.0.4-64-bit.exe")
  $gitInstallDefinition | Add-Member -NotePropertyName AllowedHosts -NotePropertyValue @("github.com", "githubusercontent.com")
  $gitInstallDefinition | Add-Member -NotePropertyName Sha256 -NotePropertyValue $null
  $script:gitInstallCalls = 0
  $gitProcessRunner = {
    param($path, $arguments)
    $script:gitInstallCalls++
    if ($path -notmatch "\\installer\.exe$") { throw "Git did not start its downloaded x64 EXE." }
    if (($arguments -join " ") -cne "/VERYSILENT /NORESTART /NOCANCEL /SP-") { throw "Git was launched with unapproved installer switches." }
    return 0
  }
  $gitSignatureProvider = {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = "CN=Johannes Schindelin, O=Git for Windows" }
    }
  }
  $gitDownloadProvider = {
    param($uri, $destination, $allowedHosts)
    [IO.File]::WriteAllBytes($destination, (New-TestPeBytes -Machine 0x8664))
    return [uri]"https://github.com/git-for-windows/git/releases/download/v2.56.0.windows.4/Git-2.56.0.4-64-bit.exe"
  }
  $gitInstallResult = Invoke-QuickSetupPackageInstall -Id "git" -Definition $gitInstallDefinition -DownloadProvider $gitDownloadProvider -SignatureProvider $gitSignatureProvider -ProcessRunner $gitProcessRunner
  Assert-True ($gitInstallResult.ExitCode -eq 0 -and !$gitInstallResult.RestartRequired -and $script:gitInstallCalls -eq 1) "Git installation did not complete without a restart."
  $copilotMockDefinition = $copilotPreview.PSObject.Copy()
  $copilotMockBytes = New-TestPeBytes -Machine 0x014c
  $copilotMockDefinition.Sha256 = (Get-FileHash -InputStream ([IO.MemoryStream]::new($copilotMockBytes)) -Algorithm SHA256).Hash
  $script:copilotInstallCalls = 0
  $copilotMockResult = Invoke-QuickSetupPackageInstall -Id "github-copilot-desktop" -Definition $copilotMockDefinition -DownloadProvider {
    param($uri, $destination, $allowedHosts)
    [IO.File]::WriteAllBytes($destination, $copilotMockBytes)
    return $uri
  } -SignatureProvider {
    param($path)
    [pscustomobject]@{ Status = [Management.Automation.SignatureStatus]::Valid; SignerCertificate = [pscustomobject]@{ Subject = 'CN="GitHub, Inc.", O="GitHub, Inc."' } }
  } -ProcessRunner {
    param($path, $arguments)
    $script:copilotInstallCalls++
    Assert-True (($arguments -join " ") -ceq "/S" -and $path -match "installer\.exe$") "Copilot Desktop did not start its verified NSIS installer silently."
    return 0
  }
  Assert-True ($copilotMockResult.ExitCode -eq 0 -and $script:copilotInstallCalls -eq 1) "The mock Copilot Desktop installer did not run exactly once."
  $script:gitInstallCalls = 0
  $gitWrongSignerRefused = $false
  try {
    Invoke-QuickSetupPackageInstall -Id "git" -Definition $gitInstallDefinition -DownloadProvider $gitDownloadProvider -ProcessRunner $gitProcessRunner -SignatureProvider {
      param($path)
      [pscustomobject]@{
        Status = [System.Management.Automation.SignatureStatus]::Valid
        SignerCertificate = [pscustomobject]@{ Subject = "CN=Other Publisher, O=Git for Windows" }
      }
    } | Out-Null
  } catch { $gitWrongSignerRefused = $true }
  Assert-True ($gitWrongSignerRefused -and $script:gitInstallCalls -eq 0) "Git executed an installer signed by an unapproved identity."
  $gitBadDigestRefused = $false
  $gitBadDigestDefinition = $gitInstallDefinition.PSObject.Copy()
  $gitBadDigestDefinition.Sha256 = "0" * 64
  try {
    Invoke-QuickSetupPackageInstall -Id "git" -Definition $gitBadDigestDefinition -DownloadProvider $gitDownloadProvider -ProcessRunner $gitProcessRunner -SignatureProvider $gitSignatureProvider | Out-Null
  } catch { $gitBadDigestRefused = $true }
  Assert-True ($gitBadDigestRefused -and $script:gitInstallCalls -eq 0) "Git executed an installer whose official release digest did not match."
  $script:mockExitCode = 1603
  $gitInstallerError = Invoke-QuickSetupPackageInstall -Id "git" -Definition $gitInstallDefinition -DownloadProvider $gitDownloadProvider -SignatureProvider $gitSignatureProvider -ProcessRunner {
    param($path, $arguments)
    return $script:mockExitCode
  }
  Assert-True ($gitInstallerError.ExitCode -eq 1603 -and !$gitInstallerError.RestartRequired) "A Git installer error was not propagated."

  $libreOfficeInstallDefinition = $msiDefinition.PSObject.Copy()
  $libreOfficeInstallDefinition.Uri = [uri]"https://download.documentfoundation.org/libreoffice/stable/26.8.2/win/x86_64/LibreOffice_26.8.2_Win_x86-64.msi"
  $libreOfficeInstallDefinition.AllowedHosts = @("download.documentfoundation.org", "mirror.example.org")
  $libreOfficeInstallDefinition.Sha256 = $null
  $libreOfficeInstallDefinition.Publisher = "The Document Foundation"
  $libreOfficeInstallDefinition | Add-Member -NotePropertyName ExpectedCommonName -NotePropertyValue "The Document Foundation"
  $libreOfficeInstallDefinition.Arguments = @("/qn", "/norestart")
  $script:libreOfficeInstallCalls = 0
  $libreOfficeInstallResult = Invoke-QuickSetupPackageInstall -Id "libreoffice" -Definition $libreOfficeInstallDefinition -DownloadProvider {
    param($uri, $destination, $allowedHosts)
    [IO.File]::WriteAllBytes($destination, [byte[]](0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1))
    return [uri]"https://download.documentfoundation.org/libreoffice/stable/26.8.2/win/x86_64/LibreOffice_26.8.2_Win_x86-64.msi"
  } -MsiPlatformReader { param($path) "x64;1033" } -SignatureProvider {
    param($path)
    [pscustomobject]@{
      Status = [System.Management.Automation.SignatureStatus]::Valid
      SignerCertificate = [pscustomobject]@{ Subject = "CN=The Document Foundation, O=The Document Foundation, L=Berlin, C=DE" }
    }
  } -ProcessRunner {
    param($path, $arguments)
    $script:libreOfficeInstallCalls++
    if ($path -ne "msiexec.exe" -or $arguments[-2] -ne "/qn" -or $arguments[-1] -ne "/norestart") {
      throw "LibreOffice did not use the approved MSI switches."
    }
    return 0
  }
  Assert-True ($libreOfficeInstallResult.ExitCode -eq 0 -and $script:libreOfficeInstallCalls -eq 1) "Selected LibreOffice did not install through its validated MSI route."

  $script:mockInstallerCalls = 0
  $script:mockAppxDeployments = 0
  $pythonManagerDefinition = [pscustomobject]@{
    Automatic = $true; InstallerType = "msix"; ExpectedArchitecture = "x64"
    Uri = [uri]"https://python.org/ftp/python/pymanager/python-manager-26.4.msix"
    AllowedHosts = @("python.org"); PackageName = "PythonSoftwareFoundation.PythonManager"
    PackagePublisher = "CN=Python Software Foundation, O=Python Software Foundation, L=Beaverton, S=Oregon, C=US"
    RuntimeArguments = @("install", "default")
  }
  $pythonManagerResult = Invoke-QuickSetupPackageInstall -Id "python" -Definition $pythonManagerDefinition -DownloadProvider {
    param($uri, $destination, $allowedHosts)
    New-TestMsixPackage -Path $destination
    return [uri]"https://python.org/ftp/python/pymanager/python-manager-26.4.msix"
  } -AppxPackageProvider {
    param($path)
    $script:mockAppxDeployments++
    if (!(Test-Path -LiteralPath $path)) { throw "The MSIX package was not downloaded before deployment." }
  } -ProcessRunner {
    param($path, $arguments)
    $script:mockInstallerCalls++
    if ($path -ne "pymanager.exe" -or ($arguments -join " ") -ne "install default") { throw "The documented Python runtime installation command was not used." }
    return 0
  }
  Assert-True ($pythonManagerResult.ExitCode -eq 0 -and $script:mockAppxDeployments -eq 1 -and $script:mockInstallerCalls -eq 1) "Python manager deployment or its documented per-user runtime command failed."

  $script:mockInstallerCalls = 0
  $mismatchedDefinition = $msiDefinition.PSObject.Copy()
  $mismatchedDefinition.Uri = [uri]"https://download.mozilla.org/?file=installer.exe"
  $mismatchedDownloadProvider = {
    param($uri, $destination, $allowedHosts)
    [IO.File]::WriteAllBytes($destination, (New-TestPeBytes -Machine 0x8664))
    return [uri]"https://download.mozilla.org/"
  }
  $mismatchedTypeRefused = $false
  try {
    Invoke-QuickSetupPackageInstall -Id "firefox" -Definition $mismatchedDefinition -DownloadProvider $mismatchedDownloadProvider -MsiPlatformReader { param($path) "x64;1033" } -SignatureProvider $signatureProvider -ProcessRunner $msiProcessRunner | Out-Null
  } catch { $mismatchedTypeRefused = $true }
  Assert-True ($mismatchedTypeRefused -and $script:mockInstallerCalls -eq 0) "Installer type was inferred from the URL or a mismatched file was executed (refused=$mismatchedTypeRefused; calls=$script:mockInstallerCalls)."
  $env:TEMP = $originalTemp

  $downloadRefused = $false
  try {
    Get-QuickSetupOfficialDownload -Uri ([uri]"http://example.invalid/installer.msi") -Destination (Join-Path $temporaryDirectory "refused.msi") -AllowedHosts @("example.invalid")
  } catch { $downloadRefused = $true }
  Assert-True ($downloadRefused) "An insecure HTTP installer source was not rejected."
  Assert-True (!(Test-QuickSetupAllowedHost -HostName "github.com.attacker.test" -AllowedHosts @("github.com")) ) "A suffix-spoofed download host was accepted."
  $redirectRefused = $false
  try {
    Get-QuickSetupOfficialDownload -Uri ([uri]"https://download.mozilla.org/?product=firefox-msi-latest-ssl") -Destination (Join-Path $temporaryDirectory "redirect.msi") -AllowedHosts @("mozilla.org") -DownloadProvider {
      param($uri, $destination, $allowedHosts)
      [IO.File]::WriteAllBytes($destination, [byte[]](0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1))
      return [uri]"https://evil.example/installer.msi"
    }
  } catch { $redirectRefused = $true }
  Assert-True $redirectRefused "An HTTPS redirect to a non-allowlisted host was accepted."
  $badHashRefused = $false
  try {
    Get-QuickSetupOfficialDownload -Uri ([uri]"https://python.org/installer.exe") -Destination (Join-Path $temporaryDirectory "bad-hash.exe") -AllowedHosts @("python.org") -ExpectedSha256 ("0" * 64) -DownloadProvider {
      param($uri, $destination, $allowedHosts)
      [IO.File]::WriteAllBytes($destination, (New-TestPeBytes -Machine 0x8664))
      return [uri]"https://python.org/installer.exe"
    }
  } catch { $badHashRefused = $true }
  Assert-True $badHashRefused "An installer with a mismatched trusted SHA-256 was accepted."
  $script:timeoutAttempts = 0
  $timeoutRefused = $false
  try {
    Get-QuickSetupOfficialDownload -Uri ([uri]"https://python.org/installer.exe") -Destination (Join-Path $temporaryDirectory "timeout.exe") -AllowedHosts @("python.org") -DownloadProvider {
      param($uri, $destination, $allowedHosts)
      $script:timeoutAttempts++
      throw (New-Object System.Net.WebException("mock timeout"))
    }
  } catch { $timeoutRefused = $true }
  Assert-True ($timeoutRefused -and $script:timeoutAttempts -eq 3) "A download timeout did not fail after the bounded retry limit."

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
  $catalog = Get-QuickSetupPackageCatalog
  Assert-True (@($catalog | Where-Object { $_.id -eq "github-copilot-desktop" -and $_.windowsMode -eq "automatic" -and "git" -in $_.dependencies }).Count -eq 1) "The canonical catalog did not identify Copilot Desktop as automatic with Git dependency."
  Assert-True (@($catalog | Where-Object { $_.id -eq "docker-desktop" -and $_.windowsMode -eq "detection-only" }).Count -eq 1) "The canonical catalog did not mark Docker Desktop as detection-only."
  $guiList = Invoke-GuiWorkerTestRequest -Request @{ schemaVersion = 1; action = "list" }
  $guiListEvents = $guiList.Events | ConvertTo-Json -Compress -Depth 12
  Assert-True ($guiList.ExitCode -eq 0 -and $guiList.Events.Count -eq 1 -and $guiList.Events[0].type -eq "catalog") "The GUI worker list action did not return one structured catalog event (exit $($guiList.ExitCode); request: $($guiList.RequestJson); stderr: $($guiList.StandardError); events: $guiListEvents)"
  Assert-True (@($guiList.Events[0].data | Where-Object { $_.id -eq "github-copilot-desktop" }).Count -eq 1) "The GUI worker catalog omitted Copilot Desktop."
  $guiPlan = Invoke-GuiWorkerTestRequest -Request @{ schemaVersion = 1; action = "plan"; packageIds = @("github-cli") }
  Assert-True ($guiPlan.ExitCode -eq 0 -and @($guiPlan.Events | Where-Object { $_.type -eq "install-plan" }).Count -eq 1) "The GUI worker did not return a structured install plan: $($guiPlan.StandardError)"
  $installPlanEvent = @($guiPlan.Events | Where-Object { $_.type -eq "install-plan" })[0]
  Assert-True (($installPlanEvent.data.id -join ",") -eq "git,github-cli") "The GUI worker did not expand GitHub CLI's Git dependency in order."
  $untrustedPlan = Invoke-GuiWorkerTestRequest -Request @{ schemaVersion = 1; action = "plan"; packageIds = @("untrusted-command") }
  Assert-True ($untrustedPlan.ExitCode -ne 0 -and @($untrustedPlan.Events | Where-Object { $_.type -eq "worker-error" }).Count -eq 1) "An untrusted GUI package ID was accepted."
  $unconfirmedInstall = Invoke-GuiWorkerTestRequest -Request @{ schemaVersion = 1; action = "install"; packageIds = @("git"); confirmed = $false }
  Assert-True ($unconfirmedInstall.ExitCode -ne 0 -and @($unconfirmedInstall.Events | Where-Object { $_.type -eq "worker-error" }).Count -eq 1) "The GUI worker accepted an install request without confirmation."

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
  $copilotReport = @($report.Packages | Where-Object { $_.Id -eq "github-copilot-desktop" }) | Select-Object -First 1
  if ($copilotReport.Status -eq "Already installed") {
    Assert-True ($copilotReport.DetectedVersion -eq "1.1.34" -and $copilotReport.Notes -match "user data were not modified") "An existing Copilot Desktop install or its user data was not preserved."
  } else {
    Assert-True ($copilotReport.Status -eq "Requires user action" -and $copilotReport.InstallerType -eq "exe" -and $copilotReport.RequestedVersion -eq "1.1.34") "Copilot Desktop dry-run did not report its pinned automatic installation plan."
    Assert-True ($copilotReport.Notes -match "x86 NSIS bootstrap" -and $copilotReport.Notes -match "Windows Server compatibility") "Copilot Desktop dry-run omitted reviewed installer or platform limits."
  }
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
    Assert-True ($entryNames -contains "configureMe-QuickSetup/modules/GuiWorker.psm1") "The ZIP omitted the GUI worker module."
    Assert-True ($entryNames -contains "configureMe-QuickSetup/config/catalog.json") "The ZIP omitted the canonical package catalog."
    Assert-True ($entryNames -contains "configureMe-QuickSetup/assets/firefox-bookmarks.html") "The ZIP omitted Firefox bookmarks."
    Assert-True ($entryNames -contains "configureMe-QuickSetup/manifest.json") "The ZIP omitted its provenance manifest."
    $manifestEntry = $zip.GetEntry("configureMe-QuickSetup/manifest.json")
    $manifestReader = New-Object System.IO.StreamReader($manifestEntry.Open())
    try { $packageManifest = $manifestReader.ReadToEnd() | ConvertFrom-Json } finally { $manifestReader.Dispose() }
    Assert-True ($packageManifest.bootstrapVersion -eq "0.3.0") "The ZIP manifest does not record the bootstrap version."
    Assert-True ($packageManifest.sourceCommitSha -match "^[a-f0-9]{40,64}$" -and $packageManifest.files.Count -ge 10) "The ZIP manifest does not record source provenance and file hashes."
    $headCommit = (& git -C $repositoryRoot rev-parse --verify HEAD).Trim()
    Assert-True ($packageManifest.sourceCommitSha -eq $headCommit.ToLowerInvariant()) "The ZIP manifest source SHA does not match the checked-out commit."
    $sha256 = [Security.Cryptography.SHA256]::Create()
    try {
      foreach ($manifestFile in $packageManifest.files) {
        $entry = $zip.GetEntry("configureMe-QuickSetup/$($manifestFile.path)")
        Assert-True ($null -ne $entry) "The ZIP omitted manifest file '$($manifestFile.path)'."
        $entryStream = $entry.Open()
        try {
          $entryHash = [BitConverter]::ToString($sha256.ComputeHash($entryStream)).Replace("-", "").ToLowerInvariant()
        } finally { $entryStream.Dispose() }
        Assert-True ($entryHash -eq $manifestFile.sha256) "The ZIP manifest hash does not match '$($manifestFile.path)'."
      }
    } finally { $sha256.Dispose() }
    Assert-True ((Get-Content -LiteralPath "$zipPath.sha256" -Raw) -match $secondHash.ToLowerInvariant()) "The ZIP sidecar checksum does not match the archive."
  } finally { $zip.Dispose() }

  Write-Host "Quick Setup smoke tests passed."
} finally {
  Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
}
