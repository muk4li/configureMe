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

function Get-QuickSetupGithubReleaseInstaller {
  param(
    [Parameter(Mandatory = $true)][string]$Repository,
    [Parameter(Mandatory = $true)][string]$AssetPattern
  )

  $headers = @{ "User-Agent" = "configureMe-Windows-QuickSetup"; "Accept" = "application/vnd.github+json" }
  $release = Invoke-RestMethod -Uri "https://api.github.com/repos/$Repository/releases/latest" -Headers $headers -TimeoutSec 60 -ErrorAction Stop
  $asset = @($release.assets | Where-Object { $_.name -match $AssetPattern }) | Select-Object -First 1
  if (!$asset -or $asset.browser_download_url -notmatch "^https://github\.com/$([regex]::Escape($Repository))/releases/download/") {
    throw "No matching official Windows x64 release asset was found for $Repository."
  }
  $digest = $null
  if ($asset.digest -match "^sha256:([a-fA-F0-9]{64})$") { $digest = $Matches[1] }
  [pscustomobject]@{
    Version = [string]$release.tag_name
    Uri = [uri]$asset.browser_download_url
    Sha256 = $digest
    Source = [string]$asset.browser_download_url
    AllowedHosts = @("github.com", "githubusercontent.com")
  }
}

function Get-QuickSetupInstallerDefinition {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [switch]$OfflinePreview
  )

  if ($OfflinePreview) {
    switch ($Id) {
      "git" {
        return [pscustomobject]@{ Automatic = $false; Version = "latest stable"; Source = "https://git-scm.com/download/win"; Method = "Manual"; Notes = "Manual install; no product-specific silent command is used." }
      }
      "github-cli" {
        return [pscustomobject]@{ Automatic = $true; Version = "latest stable"; Source = "https://github.com/cli/cli/releases"; Method = "Official x64 MSI /qn"; Notes = "Version is resolved from the official GitHub release feed only after confirmation." }
      }
      "vscode" {
        return [pscustomobject]@{ Automatic = $true; Version = "latest stable"; Source = "https://code.visualstudio.com/docs/setup/windows"; Method = "Current-user VS Code setup"; Notes = "Official user installer and documented silent options; applies only to the current Windows user." }
      }
      "nodejs-lts" {
        return [pscustomobject]@{ Automatic = $true; Version = "latest stable Active LTS"; Source = "https://nodejs.org/en/download/"; Method = "Official x64 MSI /qn"; Notes = "Version is resolved from the official Node.js distribution index only after confirmation." }
      }
      "python" {
        return [pscustomobject]@{ Automatic = $false; Version = "latest stable"; Source = "https://www.python.org/downloads/windows/"; Method = "Manual"; Notes = "The current Python Install Manager/MSIX path is not automatically applied on Server 2022." }
      }
      "dotnet-10-sdk" {
        return [pscustomobject]@{ Automatic = $true; Version = "latest stable .NET 10 SDK"; Source = "https://learn.microsoft.com/dotnet/core/install/windows"; Method = "Official .NET SDK installer /quiet"; Notes = "Version is resolved from Microsoft's .NET 10 release feed only after confirmation." }
      }
      "powershell-7" {
        return [pscustomobject]@{ Automatic = $true; Version = "latest stable"; Source = "https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows"; Method = "Official x64 MSI /qn"; Notes = "Version is resolved from Microsoft's official PowerShell release feed only after confirmation." }
      }
      "seven-zip" {
        return [pscustomobject]@{ Automatic = $true; Version = "latest stable"; Source = "https://www.7-zip.org/"; Method = "Official x64 EXE /S"; Notes = "The vendor's FAQ documents /S; the signed installer is resolved from the official site only after confirmation." }
      }
      "firefox" {
        return [pscustomobject]@{ Automatic = $true; Version = "latest stable"; Source = "https://www.mozilla.org/firefox/enterprise/"; Method = "Official Firefox Enterprise MSI /qn"; Notes = "The stable MSI source is resolved only after confirmation and publisher signature validation." }
      }
      "openssh-client" {
        return [pscustomobject]@{ Automatic = $true; Version = "Windows Server capability"; Source = "Windows Optional Capability: OpenSSH.Client"; Method = "Add-WindowsCapability (after confirmation)"; Notes = "Uses the Windows-serviced OpenSSH Client capability." }
      }
      default { return $null }
    }
  }

  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  switch ($Id) {
    "git" {
      return [pscustomobject]@{
        Automatic = $false
        Version = "latest stable"
        Source = "https://git-scm.com/download/win"
        Method = "Manual"
        Notes = "No product-specific silent installer command is used by this bootstrap; install from the official Git for Windows page."
      }
    }
    "github-cli" {
      $release = Get-QuickSetupGithubReleaseInstaller -Repository "cli/cli" -AssetPattern "^gh_[0-9.]+_windows_amd64\.msi$"
      return [pscustomobject]@{
        Automatic = $true; Version = $release.Version; Uri = $release.Uri; Sha256 = $release.Sha256
        AllowedHosts = $release.AllowedHosts; Publisher = "GitHub, Inc."; Method = "MSI /qn"
        Arguments = @("/i", "{installer}", "/qn", "/norestart")
        Source = "https://github.com/cli/cli/releases"
        Notes = "Official GitHub CLI x64 MSI; MSI exit code 3010 means a restart is required."
      }
    }
    "vscode" {
      return [pscustomobject]@{
        Automatic = $true; Version = "latest stable"; Uri = [uri]"https://update.code.visualstudio.com/latest/win32-x64-user/stable"
        Sha256 = $null; AllowedHosts = @("microsoft.com", "visualstudio.com")
        Publisher = "Microsoft Corporation"; Method = "VS Code user setup (Inno Setup)"
        Arguments = @("/VERYSILENT", "/NORESTART", "/MERGETASKS=!runcode", "/COPILOTCLI=none")
        Source = "https://code.visualstudio.com/docs/setup/windows"
        Notes = "Installs only for the current Windows user. Do not start PowerShell using different credentials."
      }
    }
    "nodejs-lts" {
      $index = Invoke-RestMethod -Uri "https://nodejs.org/dist/index.json" -TimeoutSec 60 -ErrorAction Stop
      $release = @($index | Where-Object { $_.lts -and $_.version -match "^v\d+\.\d+\.\d+$" -and $_.files -contains "win-x64-msi" }) |
        Select-Object -First 1
      if (!$release) { throw "The official Node.js feed did not report a stable Windows x64 LTS MSI." }
      $fileName = "node-$($release.version)-x64.msi"
      $sumText = (Invoke-WebRequest -Uri "https://nodejs.org/dist/$($release.version)/SHASUMS256.txt" -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop).Content
      $hash = Test-QuickSetupSha256Text -Text $sumText -FileName $fileName
      if (!$hash) { throw "The official Node.js SHA-256 manifest did not contain the selected MSI." }
      return [pscustomobject]@{
        Automatic = $true; Version = [string]$release.version; Uri = [uri]"https://nodejs.org/dist/$($release.version)/$fileName"
        Sha256 = $hash; AllowedHosts = @("nodejs.org"); Publisher = "OpenJS Foundation"; Method = "MSI /qn"
        Arguments = @("/i", "{installer}", "/qn", "/norestart")
        Source = "https://nodejs.org/en/download/"
        Notes = "Newest stable Active LTS release reported by the official Node.js distribution index."
      }
    }
    "python" {
      return [pscustomobject]@{
        Automatic = $false
        Version = "latest stable"
        Source = "https://www.python.org/downloads/windows/"
        Method = "Manual"
        Notes = "The current Python Install Manager/MSIX path is not automatically applied on Server 2022; use the official Python downloads and confirm the supported installer for this host."
      }
    }
    "dotnet-10-sdk" {
      $feed = Invoke-RestMethod -Uri "https://dotnetcli.blob.core.windows.net/dotnet/release-metadata/10.0/releases.json" -TimeoutSec 60 -ErrorAction Stop
      $release = @($feed.releases | Where-Object { $_.sdk.version -and $_.sdk.files }) | Select-Object -First 1
      if (!$release) { throw "The official .NET 10 release feed did not report an SDK installer." }
      $file = @($release.sdk.files | Where-Object { $_.rid -eq "win-x64" -and $_.name -eq "dotnet-sdk-win-x64.exe" }) |
        Select-Object -First 1
      if (!$file -or $file.url -notmatch "^https://") { throw "The official .NET 10 feed has no Windows x64 SDK executable." }
      return [pscustomobject]@{
        Automatic = $true; Version = [string]$release.sdk.version; Uri = [uri]$file.url
        Sha256 = $null; Sha512 = if ($file.hash -match "^[A-Fa-f0-9]{128}$") { [string]$file.hash } else { $null }
        AllowedHosts = @("microsoft.com", "dotnetcli.azureedge.net", "blob.core.windows.net")
        Publisher = "Microsoft Corporation"; Method = ".NET SDK installer /quiet"
        Arguments = @("/install", "/quiet", "/norestart")
        Source = "https://learn.microsoft.com/dotnet/core/install/windows"
        Notes = "Installs the SDK, not only a runtime. The feed is constrained to the .NET 10 release channel."
      }
    }
    "powershell-7" {
      $release = Get-QuickSetupGithubReleaseInstaller -Repository "PowerShell/PowerShell" -AssetPattern "^PowerShell-7\.[0-9.]+-win-x64\.msi$"
      return [pscustomobject]@{
        Automatic = $true; Version = $release.Version; Uri = $release.Uri; Sha256 = $release.Sha256
        AllowedHosts = $release.AllowedHosts; Publisher = "Microsoft Corporation"; Method = "MSI /qn"
        Arguments = @("/i", "{installer}", "/qn", "/norestart")
        Source = "https://learn.microsoft.com/powershell/scripting/install/install-powershell-on-windows"
        Notes = "Official stable x64 MSI; PowerShell 7 installs side-by-side with Windows PowerShell 5.1."
      }
    }
    "seven-zip" {
      $page = Invoke-WebRequest -Uri "https://www.7-zip.org/" -UseBasicParsing -TimeoutSec 60 -ErrorAction Stop
      $match = [regex]::Match([string]$page.Content, 'https://github\.com/ip7z/7zip/releases/download/[^"''<> ]+/7z\d+-x64\.exe')
      if (!$match.Success) { throw "The official 7-Zip page did not identify an x64 installer." }
      $versionMatch = [regex]::Match($match.Value, "/download/([^/]+)/")
      $version = if ($versionMatch.Success) { $versionMatch.Groups[1].Value } else { "latest stable from the official 7-Zip page" }
      return [pscustomobject]@{
        Automatic = $true; Version = $version; Uri = [uri]$match.Value
        Sha256 = $null; AllowedHosts = @("github.com", "githubusercontent.com")
        Publisher = "Igor Pavlov"; Method = "7-Zip EXE /S"
        Arguments = @("/S")
        Source = "https://www.7-zip.org/"
        Notes = "The vendor FAQ documents /S as the EXE installer's case-sensitive silent switch."
      }
    }
    "firefox" {
      return [pscustomobject]@{
        Automatic = $true; Version = "latest stable"; Uri = [uri]"https://download.mozilla.org/?product=firefox-msi-latest-ssl&os=win64&lang=en-US"
        Sha256 = $null; AllowedHosts = @("mozilla.org", "mozilla.net")
        Publisher = "Mozilla Corporation"; Method = "Mozilla Enterprise MSI /qn"
        Arguments = @("/i", "{installer}", "/qn", "/norestart")
        Source = "https://www.mozilla.org/firefox/enterprise/"
        Notes = "Official Firefox x64 MSI channel; existing Firefox profiles are not edited."
      }
    }
    "openssh-client" {
      return [pscustomobject]@{
        Automatic = $true
        Version = "Windows Server capability"
        Source = "Windows Optional Capability: OpenSSH.Client"
        Method = "Add-WindowsCapability (after confirmation)"
        Notes = "Uses the Windows-serviced OpenSSH Client capability. No downloaded installer or reboot is requested."
      }
    }
    default { return $null }
  }
}

function Invoke-QuickSetupPackageInstall {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [Parameter(Mandatory = $true)]$Definition,
    [scriptblock]$ProcessRunner
  )

  if ($Id -eq "openssh-client") {
    $result = Add-WindowsCapability -Online -Name "OpenSSH.Client~~~~0.0.1.0" -ErrorAction Stop
    if ($result.RestartNeeded) { return [pscustomobject]@{ ExitCode = 3010; RestartRequired = $true } }
    return [pscustomobject]@{ ExitCode = 0; RestartRequired = $false }
  }

  $temporaryDirectory = Join-Path $env:TEMP ("configureMe-" + [guid]::NewGuid().ToString("N"))
  New-Item -ItemType Directory -Path $temporaryDirectory -Force | Out-Null
  try {
    $extension = if ($Definition.Uri.AbsoluteUri -match "\.msi(?:\?|$)") { ".msi" } else { ".exe" }
    $installerPath = Join-Path $temporaryDirectory ("installer" + $extension)
    Get-QuickSetupOfficialDownload -Uri $Definition.Uri -Destination $installerPath -AllowedHosts $Definition.AllowedHosts -ExpectedSha256 $Definition.Sha256 -ExpectedSha512 $Definition.Sha512 | Out-Null
    $signature = Test-QuickSetupAuthenticodePublisher -Path $installerPath -ExpectedPublisher $Definition.Publisher
    if (!$signature.IsValid) { throw $signature.Message }
    $quotedInstallerPath = '"' + $installerPath + '"'
    $arguments = @($Definition.Arguments | ForEach-Object { $_.Replace("{installer}", $quotedInstallerPath) })
    $exitCode = Invoke-QuickSetupInstallerProcess -Path $installerPath -Arguments $arguments -ProcessRunner $ProcessRunner
    [pscustomobject]@{ ExitCode = $exitCode; RestartRequired = ($exitCode -eq 3010) }
  } finally {
    Remove-Item -LiteralPath $temporaryDirectory -Recurse -Force -ErrorAction SilentlyContinue
  }
}

Export-ModuleMember -Function Get-QuickSetupInstallerDefinition, Invoke-QuickSetupInstallerProcess, Invoke-QuickSetupPackageInstall
