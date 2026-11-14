function Get-QuickSetupCopilotInstallerDefinition {
  # Verified official v1.1.34 bytes: Tauri NSIS 3.11, asInvoker, current-user installer.
  # NSIS /S is case sensitive. Tauri starts the app after silent setup only with /R; do not pass /R.
  return [pscustomobject]@{
    Automatic = $true; InstallerType = "exe"; ExpectedArchitecture = "x64"; AllowX86BootstrapForX64 = $true
    RequiresAdministrator = $false; Version = "1.1.34"
    Uri = [uri]"https://github.com/github/app/releases/download/v1.1.34/GitHub-Copilot-windows-x64-setup.exe"
    Sha256 = "4a8070a63b228895344a6c4f4536a01a62085e02821829b21786638234580e00"
    AllowedHosts = @("github.com", "release-assets.githubusercontent.com")
    Publisher = "GitHub, Inc."; ExpectedCommonName = "GitHub, Inc."
    Method = "Pinned official Tauri NSIS x64 package; current-user silent setup /S"
    Arguments = @("/S")
    Source = "https://github.com/github/app/releases/tag/v1.1.34"
    Notes = "Pinned reviewed 1.1.34 build; x86 NSIS bootstrap carries x64 payload. SHA-256 and exact trusted GitHub, Inc. signer are required. Existing installations are preserved. Windows Server compatibility still requires the real target test. Sign in interactively after installation."
  }
}

function Invoke-QuickSetupInstallerProcess {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string[]]$Arguments,
    [scriptblock]$ProcessRunner
  )

  if ($ProcessRunner) {
    return [int](& $ProcessRunner $Path $Arguments)
  }
  $process = Start-Process -FilePath $Path -ArgumentList $Arguments -Wait -PassThru -WindowStyle Hidden
  return [int]$process.ExitCode
}

function Get-QuickSetupInstallerCachePath {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)]$Definition
  )

  if ($Id -notmatch "^[a-z0-9]+(?:-[a-z0-9]+)*$" -or !$Definition.Uri -or $Definition.Uri.Scheme -ne "https") {
    throw "The installer cache request is invalid."
  }
  $extension = switch ($Definition.InstallerType) { "msi" { ".msi" } "msix" { ".msix" } "exe" { ".exe" } default { throw "The installer type cannot be cached." } }
  $keyText = "$Id|$($Definition.Version)|$($Definition.Uri.AbsoluteUri)"
  $sha256 = [Security.Cryptography.SHA256]::Create()
  try {
    $key = [BitConverter]::ToString($sha256.ComputeHash([Text.Encoding]::UTF8.GetBytes($keyText))).Replace("-", "").ToLowerInvariant()
  } finally { $sha256.Dispose() }
  $cacheDirectory = Join-Path $env:LOCALAPPDATA "configureMe\cache"
  Assert-QuickSetupSafePath -Path $cacheDirectory
  if (!(Test-Path -LiteralPath $cacheDirectory)) { New-Item -ItemType Directory -Path $cacheDirectory -Force | Out-Null }
  if ((Get-Item -LiteralPath $cacheDirectory -Force).Attributes -band [IO.FileAttributes]::ReparsePoint) {
    throw "The installer cache directory is a reparse point; refusing to use it."
  }
  return Join-Path $cacheDirectory "$Id-$key$extension"
}

function Get-QuickSetupGithubReleaseInstaller {
  param(
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$AssetPattern,
    [scriptblock]$ReleaseProvider
  )

  if ($Repository -notmatch "^[A-Za-z0-9_.-]+/[A-Za-z0-9_.-]+$") {
    throw "The GitHub release repository name is invalid."
  }
  $release = if ($ReleaseProvider) {
    & $ReleaseProvider $Repository
  } else {
    Get-QuickSetupOfficialMetadata -Uri "https://api.github.com/repos/$Repository/releases/latest" -AllowedHosts @("api.github.com") -Json
  }
  $asset = @($release.assets | Where-Object { $_.name -match $AssetPattern }) | Select-Object -First 1
  if (!$asset -or $asset.browser_download_url -notmatch "^https://github\.com/$([regex]::Escape($Repository))/releases/download/") {
    throw "No matching official Windows x64 release asset was found for $Repository."
  }
  $digest = $null
  if ($asset.digest -match "^sha256:([a-fA-F0-9]{64})$") { $digest = $Matches[1] }
  if (!$digest -and $release.body) {
    $escapedName = [regex]::Escape([string]$asset.name)
    $hashMatch = [regex]::Match([string]$release.body, "(?im)^\|\s*$escapedName\s*\|\s*([a-fA-F0-9]{64})\s*\|")
    if ($hashMatch.Success) { $digest = $hashMatch.Groups[1].Value }
  }
  [pscustomobject]@{
    Version = [string]$release.tag_name
    Uri = [uri]$asset.browser_download_url
    Sha256 = $digest
    Source = [string]$asset.browser_download_url
    AllowedHosts = @("github.com", "githubusercontent.com")
  }
}

function Get-QuickSetupLibreOfficeInstaller {
  param([scriptblock]$WebRequestProvider)

  $indexUri = [uri]"https://download.documentfoundation.org/libreoffice/stable/"
  $index = if ($WebRequestProvider) {
    & $WebRequestProvider $indexUri
  } else {
    Get-QuickSetupOfficialMetadata -Uri $indexUri -AllowedHosts @("download.documentfoundation.org")
  }
  $versions = @(
    [regex]::Matches([string]$index.Content, 'href="(?<version>\d+\.\d+\.\d+)/"') |
      ForEach-Object {
        $version = [version]$_.Groups["version"].Value
        [pscustomobject]@{ Version = $version; Text = $version.ToString() }
      } |
      Sort-Object Version -Descending
  )
  if ($versions.Count -eq 0) { throw "The official LibreOffice stable directory did not list a release version." }

  $version = $versions[0].Text
  $fileName = "LibreOffice_${version}_Win_x86-64.msi"
  $directory = "https://download.documentfoundation.org/libreoffice/stable/$version/win/x86_64/"
  $installerUri = [uri]($directory + $fileName)
  $mirrorListUri = [uri]($installerUri.AbsoluteUri + ".mirrorlist")
  $mirrorList = if ($WebRequestProvider) {
    & $WebRequestProvider $mirrorListUri
  } else {
    Get-QuickSetupOfficialMetadata -Uri $mirrorListUri -AllowedHosts @("download.documentfoundation.org")
  }
  $escapedName = [regex]::Escape($fileName)
  $pathMatch = [regex]::Match([string]$mirrorList.Content, "(?is)<li><span class=""mirrorbrain-label"">Path:</span>\s*(?<path>/[^<]+)</li>")
  $expectedPath = "/libreoffice/stable/$version/win/x86_64/$fileName"
  if (!$pathMatch.Success -or $pathMatch.Groups["path"].Value.Trim() -cne $expectedPath) {
    throw "The official LibreOffice mirror metadata did not match the selected x64 MSI path."
  }
  $hashMatch = [regex]::Match([string]$mirrorList.Content, "(?is)SHA-256 Hash</a>:</span>\s*<tt>(?<hash>[a-fA-F0-9]{64})</tt>")
  if (!$hashMatch.Success) { throw "The official LibreOffice mirror metadata did not publish the MSI SHA-256." }

  $allowedHosts = New-Object System.Collections.Generic.List[string]
  $allowedHosts.Add($installerUri.DnsSafeHost)
  $mirrorPattern = "(?is)<a\s+href=""(?<url>https://[^""]+/$escapedName)"">"
  foreach ($match in [regex]::Matches([string]$mirrorList.Content, $mirrorPattern)) {
    $mirrorUri = [uri]$match.Groups["url"].Value
    if (!$mirrorUri.AbsolutePath.EndsWith($expectedPath, [System.StringComparison]::Ordinal)) { continue }
    if (!$allowedHosts.Contains($mirrorUri.DnsSafeHost)) { $allowedHosts.Add($mirrorUri.DnsSafeHost) }
  }
  if ($allowedHosts.Count -eq 1) { throw "The official LibreOffice mirror metadata did not list any HTTPS MSI mirrors." }

  [pscustomobject]@{
    Version = $version
    FileName = $fileName
    Uri = $installerUri
    Sha256 = $hashMatch.Groups["hash"].Value
    AllowedHosts = $allowedHosts.ToArray()
    Source = "https://www.libreoffice.org/download/download-libreoffice/"
  }
}

function Get-QuickSetupPythonInstaller {
  # The classic signed full installer works without AppX services, Store, aliases or
  # deployment registration. Stay on the supported 3.14 line, not prereleases/embeddable ZIPs.
  param([scriptblock]$MetadataProvider)
  $index = if ($MetadataProvider) { & $MetadataProvider } else {
    Get-QuickSetupOfficialMetadata -Uri "https://www.python.org/ftp/python/" -AllowedHosts @("www.python.org")
  }
  $versions = @([regex]::Matches([string]$index.Content, 'href="(3\.14\.\d+)/"') |
    ForEach-Object { [version]$_.Groups[1].Value } | Sort-Object -Unique -Descending)
  if (!$versions.Count) { throw "The official Python directory did not list a stable Python 3.14 release." }
  $version = $versions[0].ToString()
  return [pscustomobject]@{
    Automatic = $true; InstallerType = "exe"; ExpectedArchitecture = "x64"; RequiresAdministrator = $false
    Version = $version; Uri = [uri]"https://www.python.org/ftp/python/$version/python-$version-amd64.exe"
    AllowedHosts = @("www.python.org"); Publisher = "Python Software Foundation"; ExpectedCommonName = "Python Software Foundation"
    BootstrapperKind = "python-burn-x86-for-x64"
    Arguments = @("/quiet", "/norestart", "InstallAllUsers=0", "PrependPath=1", "Include_pip=1", "Include_test=0", "Include_launcher=0")
    Source = "https://docs.python.org/3.14/using/windows.html#installing-without-ui"
    Method = "Official signed CPython 3.14 x64 full EXE; no MSIX deployment"
    Notes = "Server 2022 uses the classic per-user full installer, avoiding AppX deployment failures (0x80073CF0/0x80040154). Valid PSF Authenticode is required. Existing verified x64 Python 3 with pip is preserved. No Store alias or install manager is invoked."
  }
}

function Get-QuickSetupSevenZipInstaller {
  # Reviewed official artifact, SHA-256 independently cross-checked with Microsoft's
  # winget-pkgs 7zip.7zip 25.01 manifest. Unsigned is NOT an invalid signature.
  return [pscustomobject]@{
    Automatic = $true; InstallerType = "msi"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true
    Version = "25.01"; Uri = [uri]"https://github.com/ip7z/7zip/releases/download/25.01/7z2501-x64.msi"
    Sha256 = "e7eb0b7ed5efa4e087b7b17f191797f7af5b7f442d1290c66f3a21777005ef57"
    AllowedHosts = @("github.com", "release-assets.githubusercontent.com")
    Publisher = "Igor Pavlov"; ExpectedCommonName = "Igor Pavlov"
    VerificationPolicy = "seven-zip-25.01-pinned-unsigned"
    Arguments = @("/qn", "/norestart")
    Source = "https://www.7-zip.org/"
    Method = "Pinned official x64 MSI, SHA-256 and Windows Installer x64 template"
    Notes = "Only the exact reviewed 25.01 MSI may be unsigned; invalid/untrusted signatures are rejected. Update URL, version and reviewed hash together when upgrading this pin."
  }
}

function Test-QuickSetupBootstrapAuthorization {
  param([string]$Id, $Definition)
  if ($Id -eq "github-copilot-desktop") {
    $pin = Get-QuickSetupCopilotInstallerDefinition
    return ($Definition.Uri -eq $pin.Uri -and $Definition.Version -ceq $pin.Version -and $Definition.AllowX86BootstrapForX64 -and $Definition.Sha256 -match "^[A-Fa-f0-9]{64}$" -and $Definition.Publisher -ceq $pin.Publisher)
  }
  if ($Definition.ExpectedArchitecture -ne "x64" -or $Definition.InstallerType -ne "exe") { return $false }
  switch ($Id) {
    "vscode" {
      return ($Definition.BootstrapperKind -ceq "vscode-inno-x86-for-x64" -and
        $Definition.Publisher -ceq "Microsoft Corporation" -and $Definition.Version -match '^\d+\.\d+\.\d+$' -and
        $Definition.Sha256 -match '^[a-fA-F0-9]{64}$' -and
        $Definition.Uri.AbsoluteUri -cmatch '^https://[^/]+/.*VSCodeUserSetup-x64-[0-9.]+\.exe$' -and
        (Test-QuickSetupAllowedHost $Definition.Uri.DnsSafeHost @("visualstudio.com", "microsoft.com")))
    }
    "dotnet-10-sdk" {
      return ($Definition.BootstrapperKind -ceq "dotnet-burn-x86-for-x64" -and
        $Definition.Publisher -ceq "Microsoft Corporation" -and $Definition.Version -match '^10\.\d+\.\d+$' -and
        $Definition.Sha512 -match '^[a-fA-F0-9]{128}$' -and
        $Definition.Uri.AbsolutePath -cmatch '/dotnet-sdk-10\.\d+\.\d+-win-x64\.exe$' -and
        $Definition.Uri.Scheme -eq "https" -and
        (Test-QuickSetupAllowedHost $Definition.Uri.DnsSafeHost @("builds.dotnet.microsoft.com", "download.visualstudio.microsoft.com")))
    }
    "python" {
      return ($Definition.BootstrapperKind -ceq "python-burn-x86-for-x64" -and
        $Definition.Publisher -ceq "Python Software Foundation" -and $Definition.Version -match '^3\.14\.\d+$' -and
        $Definition.Uri.AbsoluteUri -ceq "https://www.python.org/ftp/python/$($Definition.Version)/python-$($Definition.Version)-amd64.exe")
    }
  }
  return $false
}

function Assert-QuickSetupInstallerSignature {
  param([string]$Id, $Definition, [string]$Path, [scriptblock]$SignatureProvider, [scriptblock]$FileHashProvider, [ref]$Verification)
  if ($Verification) { $Verification.Value = $null }
  $signature = if ($SignatureProvider) { & $SignatureProvider $Path } else { Get-AuthenticodeSignature -LiteralPath $Path }
  if ($Id -eq "seven-zip" -and $Definition.VerificationPolicy -ceq "seven-zip-25.01-pinned-unsigned") {
    $pin = Get-QuickSetupSevenZipInstaller
    $actualHash = if ($FileHashProvider) { & $FileHashProvider $Path } else { (Get-FileHash -LiteralPath $Path -Algorithm SHA256).Hash }
    if ($Definition.Uri -ne $pin.Uri -or $Definition.Version -cne $pin.Version -or
        $Definition.InstallerType -ne "msi" -or $Definition.ExpectedArchitecture -ne "x64" -or
        $Definition.Sha256 -cne $pin.Sha256 -or
        $actualHash -ine $pin.Sha256) {
      throw "The unsigned 7-Zip exception requires the exact reviewed official x64 MSI and SHA-256."
    }
    if ($signature.Status -eq [System.Management.Automation.SignatureStatus]::NotSigned -and !$signature.SignerCertificate) {
      if ($Verification) { $Verification.Value = [pscustomobject]@{ Status = "NotSigned"; Policy = "seven-zip-25.01-pinned-unsigned"; SignerSubject = $null; SignerThumbprint = $null } }
      return
    }
  }
  $result = Test-QuickSetupAuthenticodePublisher -Path $Path -ExpectedPublisher $Definition.Publisher -ExpectedCommonName $Definition.ExpectedCommonName -ExpectedOrganization $Definition.ExpectedOrganization -SignatureProvider { param($ignored) $signature }
  if (!$result.IsValid) { throw $result.Message }
  if ($Verification) {
    $Verification.Value = [pscustomobject]@{
      Status = [string]$signature.Status; Policy = "authenticode"
      SignerSubject = [string]$signature.SignerCertificate.Subject
      SignerThumbprint = [string]$signature.SignerCertificate.Thumbprint
    }
  }
}

function Get-QuickSetupInstallerDefinition {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [switch]$OfflinePreview,
    [scriptblock]$MetadataProvider
  )

  if ($OfflinePreview) {
    switch ($Id) {
      "git" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "exe"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true; Version = "latest stable Git for Windows x64"; Source = "https://github.com/git-for-windows/git/releases/latest"; Publisher = "Johannes Schindelin"; ExpectedCommonName = "Johannes Schindelin"; Method = "Official release x64 EXE; exact Johannes Schindelin signer; Inno Setup documented silent switches"; Arguments = @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-"); Notes = "The release digest is checked when official metadata provides it. Authenticode must be valid and the signer common name must exactly equal Johannes Schindelin. Existing Git is detected first and is never updated." }
      }
      "github-copilot-desktop" {
        return Get-QuickSetupCopilotInstallerDefinition
      }
      "libreoffice" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "msi"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true; Version = "latest stable x64"; Source = "https://www.libreoffice.org/download/download-libreoffice/"; Method = "Official Document Foundation x64 MSI via msiexec /qn"; Arguments = @("/qn", "/norestart"); Publisher = "The Document Foundation"; ExpectedCommonName = "The Document Foundation"; Notes = "Optional package; resolves the current stable x64 MSI from the official Document Foundation directory, validates its official SHA-256 and exact Authenticode signer common name, and installs only when selected in the local profile." }
      }
      "github-cli" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "msi"; RequiresAdministrator = $true; Version = "latest stable"; Source = "https://github.com/cli/cli/releases"; Method = "Official x64 MSI via msiexec /qn"; Notes = "The CLI resolves official release metadata while preparing the plan; installer bytes require confirmation." }
      }
      "vscode" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "exe"; RequiresAdministrator = $false; Version = "latest stable"; Source = "https://code.visualstudio.com/docs/setup/windows"; Method = "Current-user VS Code setup"; Notes = "Official user installer and documented silent options; applies only to the current Windows user." }
      }
      "nodejs-lts" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "msi"; RequiresAdministrator = $true; Version = "latest stable Active LTS"; Source = "https://nodejs.org/en/download/"; Method = "Official x64 MSI via msiexec /qn"; Notes = "The CLI resolves the official Node.js index while preparing the plan; installer bytes require confirmation." }
      }
      "python" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "exe"; RequiresAdministrator = $false; Version = "latest supported stable Python 3.14 x64"; Source = "https://www.python.org/downloads/windows/"; Method = "Official signed CPython full EXE /quiet, no AppX required"; Notes = "Per-user x64 Python with pip; does not depend on MSIX deployment or install-manager aliases." }
      }
      "dotnet-10-sdk" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "exe"; RequiresAdministrator = $true; Version = "latest stable .NET 10 SDK"; Source = "https://learn.microsoft.com/dotnet/core/install/windows"; Method = "Official .NET SDK installer /quiet"; Notes = "The CLI resolves Microsoft's .NET 10 feed while preparing the plan; installer bytes require confirmation." }
      }
      "powershell-7" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "msi"; RequiresAdministrator = $true; Version = "latest stable"; Source = "https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows"; Method = "Official x64 MSI via msiexec /qn"; Notes = "The CLI resolves official PowerShell release metadata while preparing the plan; installer bytes require confirmation." }
      }
      "seven-zip" { return Get-QuickSetupSevenZipInstaller }
      "firefox" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "msi"; RequiresAdministrator = $true; Version = "latest stable"; Source = "https://www.mozilla.org/firefox/enterprise/"; Method = "Official Firefox Enterprise MSI via msiexec /qn"; Notes = "The CLI prepares the stable MSI source before confirmation; installer bytes and publisher signature are checked after confirmation." }
      }
      "openssh-client" {
        return [pscustomobject]@{ Automatic = $true; InstallerType = "windows-capability"; RequiresAdministrator = $true; Version = "Windows Server capability"; Source = "Windows Optional Capability: OpenSSH.Client"; Method = "Add-WindowsCapability (after confirmation)"; Notes = "Uses the Windows-serviced OpenSSH Client capability." }
      }
      default { return $null }
    }
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  switch ($Id) {
    "github-copilot-desktop" { return Get-QuickSetupCopilotInstallerDefinition }
    "git" {
      $release = Get-QuickSetupGithubReleaseInstaller -Repository "git-for-windows/git" -AssetPattern "^Git-[0-9.]+-64-bit\.exe$"
      return [pscustomobject]@{
        Automatic = $true; InstallerType = "exe"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true
        Version = $release.Version; Uri = $release.Uri; Sha256 = $release.Sha256; AllowedHosts = $release.AllowedHosts
        Publisher = "Johannes Schindelin"; ExpectedCommonName = "Johannes Schindelin"
        Method = "Official Git for Windows x64 EXE (Inno Setup)"
        Arguments = @("/VERYSILENT", "/NORESTART", "/NOCANCEL", "/SP-")
        Source = "https://github.com/git-for-windows/git/releases/latest"
        Notes = "The official GitHub release's asset digest or exact-asset SHA-256 table is used when available. Authenticode must be valid and its signer common name must exactly equal Johannes Schindelin. The Inno Setup switches are documented; no restart is requested."
      }
    }
    "libreoffice" {
      $release = Get-QuickSetupLibreOfficeInstaller
      return [pscustomobject]@{
        Automatic = $true; InstallerType = "msi"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true
        Version = $release.Version; Uri = $release.Uri; Sha256 = $release.Sha256; AllowedHosts = $release.AllowedHosts
        Publisher = "The Document Foundation"; ExpectedCommonName = "The Document Foundation"; Method = "Official x64 MSI /qn /norestart"
        Arguments = @("/qn", "/norestart")
        Source = $release.Source
        Notes = "Optional selected package; official Document Foundation MSI SHA-256 and Authenticode signer are checked before execution."
      }
    }
    "github-cli" {
      $release = Get-QuickSetupGithubReleaseInstaller -Repository "cli/cli" -AssetPattern "^gh_[0-9.]+_windows_amd64\.msi$"
      return [pscustomobject]@{
        Automatic = $true; InstallerType = "msi"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true; Version = $release.Version; Uri = $release.Uri; Sha256 = $release.Sha256
        AllowedHosts = $release.AllowedHosts; Publisher = "GitHub, Inc."; Method = "MSI /qn"
        Arguments = @("/qn", "/norestart")
        Source = "https://github.com/cli/cli/releases"
        Notes = "Official GitHub CLI x64 MSI; MSI exit code 3010 means a restart is required."
      }
    }
    "vscode" {
      $metadataUri = "https://update.code.visualstudio.com/api/update/win32-x64-user/stable/latest"
      $release = if ($MetadataProvider) { & $MetadataProvider $metadataUri } else { Get-QuickSetupOfficialMetadata -Uri $metadataUri -AllowedHosts @("update.code.visualstudio.com") -Json }
      if ($release.productVersion -notmatch '^\d+\.\d+\.\d+$' -or $release.sha256hash -notmatch '^[A-Fa-f0-9]{64}$') {
        throw "The official VS Code x64 user feed did not provide a stable version and SHA-256."
      }
      return [pscustomobject]@{
        Automatic = $true; InstallerType = "exe"; ExpectedArchitecture = "x64"; RequiresAdministrator = $false; Version = [string]$release.productVersion; Uri = [uri]$release.url
        BootstrapperKind = "vscode-inno-x86-for-x64"
        Sha256 = [string]$release.sha256hash; AllowedHosts = @("microsoft.com", "visualstudio.com")
        Publisher = "Microsoft Corporation"; Method = "VS Code user setup (Inno Setup)"
        Arguments = @("/VERYSILENT", "/NORESTART", "/MERGETASKS=!runcode", "/COPILOTCLI=none")
        Source = "https://code.visualstudio.com/docs/setup/windows"
        Notes = "Installs only for the current Windows user. Do not start PowerShell using different credentials."
      }
    }
    "nodejs-lts" {
      $index = Get-QuickSetupOfficialMetadata -Uri "https://nodejs.org/dist/index.json" -AllowedHosts @("nodejs.org") -Json
      $release = @($index | Where-Object { $_.lts -and $_.version -match "^v\d+\.\d+\.\d+$" -and $_.files -contains "win-x64-msi" }) |
        Select-Object -First 1
      if (!$release) { throw "The official Node.js feed did not report a stable Windows x64 LTS MSI." }
      $fileName = "node-$($release.version)-x64.msi"
      $sumText = (Get-QuickSetupOfficialMetadata -Uri "https://nodejs.org/dist/$($release.version)/SHASUMS256.txt" -AllowedHosts @("nodejs.org")).Content
      $hash = Test-QuickSetupSha256Text -Text $sumText -FileName $fileName
      if (!$hash) { throw "The official Node.js SHA-256 manifest did not contain the selected MSI." }
      return [pscustomobject]@{
        Automatic = $true; InstallerType = "msi"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true; Version = [string]$release.version; Uri = [uri]"https://nodejs.org/dist/$($release.version)/$fileName"
        Sha256 = $hash; AllowedHosts = @("nodejs.org"); Publisher = "OpenJS Foundation"; Method = "MSI /qn"
        Arguments = @("/qn", "/norestart")
        Source = "https://nodejs.org/en/download/"
        Notes = "Newest stable Active LTS release reported by the official Node.js distribution index."
      }
    }
    "python" { return Get-QuickSetupPythonInstaller }
    "dotnet-10-sdk" {
      $metadataUri = "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/10.0/releases.json"
      $feed = if ($MetadataProvider) { & $MetadataProvider $metadataUri } else { Get-QuickSetupOfficialMetadata -Uri $metadataUri -AllowedHosts @("dotnetcli.blob.core.windows.net") -Json }
      $release = @($feed.releases | Where-Object { $_.sdk.version -and $_.sdk.files }) | Select-Object -First 1
      if (!$release) { throw "The official .NET 10 release feed did not report an SDK installer." }
      $file = @($release.sdk.files | Where-Object { $_.rid -eq "win-x64" -and $_.name -eq "dotnet-sdk-win-x64.exe" }) |
        Select-Object -First 1
      if (!$file -or $release.sdk.version -notmatch "^10\.\d+\.\d+$" -or $file.hash -notmatch "^[A-Fa-f0-9]{128}$" -or $file.url -notmatch "^https://") { throw "The official .NET 10 feed has no Windows x64 SDK executable." }
      return [pscustomobject]@{
        Automatic = $true; InstallerType = "exe"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true; Version = [string]$release.sdk.version; Uri = [uri]$file.url
        Sha256 = $null; Sha512 = if ($file.hash -match "^[A-Fa-f0-9]{128}$") { [string]$file.hash } else { $null }
        AllowedHosts = @("microsoft.com", "dotnetcli.azureedge.net", "blob.core.windows.net")
        Publisher = "Microsoft Corporation"; ExpectedCommonName = ".NET"; ExpectedOrganization = "Microsoft Corporation"; BootstrapperKind = "dotnet-burn-x86-for-x64"; Method = ".NET SDK installer /quiet"
        Arguments = @("/install", "/quiet", "/norestart")
        Source = "https://learn.microsoft.com/dotnet/core/install/windows"
        Notes = "Installs the SDK, not only a runtime. The official SHA-512 and trusted signer CN=.NET, O=Microsoft Corporation are required. Exit codes 3010/1641 retain restart status; the installed x64 SDK is verified at its actual path."
      }
    }
    "powershell-7" {
      $release = Get-QuickSetupGithubReleaseInstaller -Repository "PowerShell/PowerShell" -AssetPattern "^PowerShell-7\.[0-9.]+-win-x64\.msi$"
      return [pscustomobject]@{
        Automatic = $true; InstallerType = "msi"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true; Version = $release.Version; Uri = $release.Uri; Sha256 = $release.Sha256
        AllowedHosts = $release.AllowedHosts; Publisher = "Microsoft Corporation"; Method = "MSI /qn"
        Arguments = @("/qn", "/norestart")
        Source = "https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows"
        Notes = "Official stable x64 MSI; PowerShell 7 installs side-by-side with Windows PowerShell 5.1."
      }
    }
    "seven-zip" { return Get-QuickSetupSevenZipInstaller }
    "firefox" {
      return [pscustomobject]@{
        Automatic = $true; InstallerType = "msi"; ExpectedArchitecture = "x64"; RequiresAdministrator = $true; Version = "latest stable"; Uri = [uri]"https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US"
        Sha256 = $null; AllowedHosts = @("mozilla.org", "mozilla.net")
        Publisher = "Mozilla Corporation"; Method = "Mozilla Enterprise MSI /qn"
        Arguments = @("/qn", "/norestart")
        Source = "https://www.mozilla.org/firefox/enterprise/"
        Notes = "Official Firefox x64 MSI channel; existing Firefox profiles are not edited."
      }
    }
    "openssh-client" {
      return [pscustomobject]@{
        Automatic = $true
        InstallerType = "windows-capability"
        RequiresAdministrator = $true
        Version = "Windows Server capability"
        Source = "Windows Optional Capability: OpenSSH.Client"
        Method = "Add-WindowsCapability (after confirmation)"
        Notes = "Uses the Windows-serviced OpenSSH Client capability. No downloaded installer or reboot is requested."
      }
    }
    default { return $null }
  }
}

function Get-QuickSetupVerifiedArtifactHash {
  param([string]$Path, [string]$Algorithm, [IO.Stream]$ArtifactStream)
  # Retain the original path-based digest check. A locked stream alone must
  # never authorize a different file now resolved by the executable path.
  $pathHash = (Get-FileHash -LiteralPath $Path -Algorithm $Algorithm).Hash.ToLowerInvariant()
  if (!$ArtifactStream) { return $pathHash }
  $position = $ArtifactStream.Position
  $hasher = [Security.Cryptography.HashAlgorithm]::Create($Algorithm)
  try {
    $ArtifactStream.Position = 0
    $streamHash = [BitConverter]::ToString($hasher.ComputeHash($ArtifactStream)).Replace("-", "").ToLowerInvariant()
    if ($streamHash -cne $pathHash) { throw "The installer path $Algorithm hash does not match the locked artifact; refusing verification." }
    return $streamHash
  } finally { $ArtifactStream.Position = $position; $hasher.Dispose() }
}

function Assert-QuickSetupDownloadedInstaller {
  param([string]$Id, $Definition, [string]$Path, [scriptblock]$SignatureProvider, [scriptblock]$MsiPlatformReader,
    [ref]$Verification, [IO.Stream]$ArtifactStream)
  if ($Verification) { $Verification.Value = $null }
  Assert-QuickSetupSafePath -Path $Path
  $measured = @{}
  foreach ($algorithm in @("SHA256", "SHA512")) {
    $expected = $Definition.$algorithm
    $length = if ($algorithm -eq "SHA256") { 64 } else { 128 }
    if ($expected) {
      if ($expected -notmatch "^[A-Fa-f0-9]{$length}$") { throw "The cached/downloaded installer $algorithm does not match the official metadata." }
      $measured[$algorithm] = Get-QuickSetupVerifiedArtifactHash -Path $Path -Algorithm $algorithm -ArtifactStream $ArtifactStream
      if ($measured[$algorithm] -ine $expected) { throw "The cached/downloaded installer $algorithm does not match the official metadata." }
    }
  }
  # Also bind stream/path before signature checking when the vendor supplies
  # only SHA512 or no digest; later provenance must not describe another file.
  if (!$measured.ContainsKey("SHA256")) { $measured["SHA256"] = Get-QuickSetupVerifiedArtifactHash -Path $Path -Algorithm SHA256 -ArtifactStream $ArtifactStream }
  $allowBootstrap = Test-QuickSetupBootstrapAuthorization -Id $Id -Definition $Definition
  if (($Definition.BootstrapperKind -or $Definition.AllowX86BootstrapForX64) -and !$allowBootstrap) {
    throw "The package-specific bootstrapper authorization metadata is invalid."
  }
  $fileCheck = Test-QuickSetupInstallerFile -Path $Path -InstallerType $Definition.InstallerType -ExpectedArchitecture $Definition.ExpectedArchitecture -AllowX86BootstrapForX64:$allowBootstrap -MsiPlatformReader $MsiPlatformReader -ExpectedPackageName $Definition.PackageName -ExpectedPackagePublisher $Definition.PackagePublisher
  $signatureCheck = $null
  if ($Definition.InstallerType -ne "msix") {
    Assert-QuickSetupInstallerSignature -Id $Id -Definition $Definition -Path $Path -SignatureProvider $SignatureProvider -Verification ([ref]$signatureCheck)
  } else {
    # Manifest/signature presence is not Windows deployment trust validation.
    $signatureCheck = [pscustomobject]@{ Status = "DeploymentValidationPending"; Policy = "msix-platform-deployment"; SignerSubject = $null; SignerThumbprint = $null }
  }
  if ($Verification) {
    $Verification.Value = [pscustomobject]@{
      Sha256 = $measured["SHA256"]
      SizeBytes = if ($ArtifactStream) { $ArtifactStream.Length } else { (Get-Item -LiteralPath $Path).Length }
      ExpectedSha256 = $Definition.Sha256; ExpectedSha512 = $Definition.Sha512
      InstallerType = [string]$fileCheck.InstallerType; InstallerArchitecture = [string]$fileCheck.Architecture
      Signature = $signatureCheck
    }
  }
}

function Invoke-QuickSetupPackageInstall {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)]$Definition,
    [scriptblock]$ProcessRunner,
    [scriptblock]$DownloadProvider,
    [scriptblock]$SignatureProvider,
    [scriptblock]$MsiPlatformReader,
    [scriptblock]$AppxPackageProvider,
    [scriptblock]$ProgressCallback,
    [string]$CachedInstallerPath,
    [ref]$Provenance
  )

  if ($Provenance) { $Provenance.Value = $null }
  if ($Id -eq "openssh-client") {
    if ($Definition.InstallerType -ne "windows-capability") { throw "OpenSSH Client has an invalid installer type." }
    if ($ProgressCallback) { $null = & $ProgressCallback "installation-started" }
    $result = Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0" -ErrorAction Stop
    if ($ProgressCallback) { $null = & $ProgressCallback "installation-completed" }
    if ($result.RestartNeeded) { return [pscustomobject]@{ ExitCode = 3010; RestartRequired = $true } }
    return [pscustomobject]@{ ExitCode = 0; RestartRequired = $false }
  }

  if (!$Definition.Automatic -or $Definition.InstallerType -notin @("msi", "exe", "msix")) {
    throw "Package '$Id' does not have a verified automatic installer."
  }
  $allowBootstrap = Test-QuickSetupBootstrapAuthorization -Id $Id -Definition $Definition
  if (($Definition.BootstrapperKind -or $Definition.AllowX86BootstrapForX64) -and !$allowBootstrap) {
    throw "The package-specific bootstrapper authorization metadata is invalid."
  }
  $temporaryDirectory = Join-Path $env:TEMP ("configureMe-" + [guid]::NewGuid().ToString("N"))
  Assert-QuickSetupSafePath -Path $temporaryDirectory
  New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
  $installerLock = $null
  $artifactProvenance = $null
  $sourceProvenance = [pscustomobject]@{
    SourceKind = "cached"; ConfiguredUri = ConvertTo-QuickSetupProvenanceUri $Definition.Uri; ObservedFinalUri = $null
  }
  try {
    $extension = switch ($Definition.InstallerType) { "msi" { ".msi" } "msix" { ".msix" } default { ".exe" } }
    $installerPath = if ($CachedInstallerPath) { $CachedInstallerPath } else { Join-Path $temporaryDirectory ("installer" + $extension) }
    if ($CachedInstallerPath) {
      Assert-QuickSetupSafePath -Path $installerPath
      if (!(Test-Path -LiteralPath $installerPath -PathType Leaf)) { throw "The verified installer cache file is missing." }
    } else {
      if ($ProgressCallback) { $null = & $ProgressCallback "download-started" }
      Get-QuickSetupOfficialDownload -Uri $Definition.Uri -Destination $installerPath -AllowedHosts $Definition.AllowedHosts -ExpectedSha256 $Definition.Sha256 -ExpectedSha512 $Definition.Sha512 -DownloadProvider $DownloadProvider -Provenance ([ref]$sourceProvenance) | Out-Null
      if ($ProgressCallback) { $null = & $ProgressCallback "download-completed" }
    }
    # Keep the exact file read-locked before verification until the installer has
    # exited. Windows denies concurrent writers and deletion/replacement while
    # this handle is held. A repeated hash alone would leave another TOCTOU gap.
    # This does not claim to protect mutable ancestor directories or same-user ACLs.
    Assert-QuickSetupSafePath -Path $installerPath
    $installerLock = [IO.File]::Open($installerPath, [IO.FileMode]::Open, [IO.FileAccess]::Read, [IO.FileShare]::Read)
    Assert-QuickSetupSafePath -Path $installerPath
    if ($ProgressCallback) { $null = & $ProgressCallback "verification-started" }
    $verification = $null
    Assert-QuickSetupDownloadedInstaller -Id $Id -Definition $Definition -Path $installerPath -SignatureProvider $SignatureProvider -MsiPlatformReader $MsiPlatformReader -ArtifactStream $installerLock -Verification ([ref]$verification)
    $artifactProvenance = [pscustomobject]@{
      SchemaVersion = 1; EvidenceKind = "local-installer-verification"
      PackageId = $Id; ResolvedVersion = [string]$Definition.Version
      SourceKind = $sourceProvenance.SourceKind; ConfiguredUri = $sourceProvenance.ConfiguredUri; ObservedFinalUri = $sourceProvenance.ObservedFinalUri
      Artifact = $verification
    }
    if ($Provenance) { $Provenance.Value = $artifactProvenance }
    if ($Definition.InstallerType -eq "msix") {
      if ($ProgressCallback) { $null = & $ProgressCallback "verification-completed" }
      if ($ProgressCallback) { $null = & $ProgressCallback "installation-started" }
      if ($AppxPackageProvider) {
        & $AppxPackageProvider $installerPath
      } else {
        Add-AppxPackage -Path $installerPath -ErrorAction Stop
      }
      $exitCode = Invoke-QuickSetupInstallerProcess -Path "pymanager.exe" -Arguments @($Definition.RuntimeArguments) -ProcessRunner $ProcessRunner
    } elseif ($Definition.InstallerType -eq "msi") {
      if ($ProgressCallback) { $null = & $ProgressCallback "verification-completed" }
      if ($ProgressCallback) { $null = & $ProgressCallback "installation-started" }
      $arguments = @("/i", ('"' + $installerPath + '"')) + @($Definition.Arguments)
      $exitCode = Invoke-QuickSetupInstallerProcess -Path "msiexec.exe" -Arguments $arguments -ProcessRunner $ProcessRunner
    } else {
      if ($ProgressCallback) { $null = & $ProgressCallback "verification-completed" }
      if ($ProgressCallback) { $null = & $ProgressCallback "installation-started" }
      $exitCode = Invoke-QuickSetupInstallerProcess -Path $installerPath -Arguments @($Definition.Arguments) -ProcessRunner $ProcessRunner
    }
    if ($ProgressCallback) { $null = & $ProgressCallback "installation-completed" }
    [pscustomobject]@{ ExitCode = $exitCode; RestartRequired = ($exitCode -in @(3010, 1641)); Provenance = $artifactProvenance }
  } finally {
    if ($installerLock) { $installerLock.Dispose() }
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Export-ModuleMember -Function Get-QuickSetupInstallerDefinition, Get-QuickSetupInstallerCachePath, Get-QuickSetupGithubReleaseInstaller, Get-QuickSetupLibreOfficeInstaller, Get-QuickSetupPythonInstaller, Get-QuickSetupSevenZipInstaller, Test-QuickSetupBootstrapAuthorization, Assert-QuickSetupInstallerSignature, Assert-QuickSetupDownloadedInstaller, Invoke-QuickSetupPackageInstall, Invoke-QuickSetupInstallerProcess
