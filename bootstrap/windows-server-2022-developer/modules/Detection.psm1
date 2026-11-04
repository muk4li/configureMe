$script:PackageCatalogPath = Join-Path (Split-Path -Parent $PSScriptRoot) "config\catalog.json"
$script:PackageCatalog = $null

function Get-QuickSetupPackageCatalog {
  if (!$script:PackageCatalog) {
    $catalog = Get-Content -LiteralPath $script:PackageCatalogPath -Raw -ErrorAction Stop | ConvertFrom-Json -ErrorAction Stop
    if ($catalog.schemaVersion -ne 1 -or !$catalog.packages -or $catalog.packages.Count -gt 100) {
      throw "The local configureMe package catalog is invalid."
    }
    $ids = @($catalog.packages | ForEach-Object { [string]$_.id })
    if (@($ids | Select-Object -Unique).Count -ne $ids.Count) {
      throw "The local configureMe package catalog contains duplicate IDs."
    }
    foreach ($package in $catalog.packages) {
      if ([string]$package.id -notmatch "^[a-z0-9]+(?:-[a-z0-9]+)*$" -or
        !$package.name -or
        $package.windowsMode -notin @("automatic", "manual", "detection-only", "web-fallback", "catalog-only")) {
        throw "The local configureMe package catalog contains invalid package metadata."
      }
    }
    $script:PackageCatalog = $catalog
  }
  return @($script:PackageCatalog.packages | Where-Object { $_.platforms.windows -and $_.windowsMode -ne "catalog-only" })
}

function Get-QuickSetupPackageDefinition {
  param([Parameter(Mandatory = $true)][string]$Id)
  return (Get-QuickSetupPackageCatalog | Where-Object { $_.id -ceq $Id } | Select-Object -First 1)
}

function Get-QuickSetupOperatingSystem {
  $os = Get-CimInstance -ClassName Win32_OperatingSystem
  $processor = Get-CimInstance -ClassName Win32_Processor | Select-Object -First 1
  $currentVersion = Get-ItemProperty -LiteralPath "HKLM:\SOFTWARE\Microsoft\Windows NT\CurrentVersion"
  $installationType = [string]$currentVersion.InstallationType
  $build = [int]$currentVersion.CurrentBuild
  $target = Test-QuickSetupTargetContext -Caption ([string]$os.Caption) -Build $build -InstallationType $installationType -ProcessorArchitecture ([int]$processor.Architecture) -Is64Bit ([Environment]::Is64BitOperatingSystem)

  [pscustomobject]@{
    Caption = [string]$os.Caption
    Version = [string]$os.Version
    Build = $build
    InstallationType = $installationType
    Architecture = $target.Architecture
    IsSupported = $target.IsSupported
    Reasons = $target.Reasons
  }
}

function Test-QuickSetupTargetContext {
  param(
    [Parameter(Mandatory = $true)][string]$Caption,
    [Parameter(Mandatory = $true)][int]$Build,
    [Parameter(Mandatory = $true)][string]$InstallationType,
    [Parameter(Mandatory = $true)][int]$ProcessorArchitecture,
    [Parameter(Mandatory = $true)][bool]$Is64Bit
  )

  $isServer2022 = ($Caption -match "Windows Server 2022") -and $Build -eq 20348
  $isDesktopExperience = $InstallationType -notmatch "Core"
  $isX64 = $Is64Bit -and $ProcessorArchitecture -eq 9
  $reasons = @()
  if (!$isServer2022) { $reasons += "Windows Server 2022 build 20348 is required." }
  if (!$isDesktopExperience) { $reasons += "Server Core is not supported; Desktop Experience is required." }
  if (!$isX64) { $reasons += "A 64-bit x64 operating system is required." }

  [pscustomobject]@{
    Architecture = if ($isX64) { "x64" } else { "unsupported" }
    IsSupported = ($reasons.Count -eq 0)
    Reasons = $reasons
  }
}

function Get-QuickSetupPackageName {
  param([Parameter(Mandatory = $true)][string]$Id)
  $definition = Get-QuickSetupPackageDefinition -Id $Id
  if ($definition) { return [string]$definition.name }
  return $Id
}

function Get-QuickSetupDetectedVersion {
  param(
    [Parameter(Mandatory = $true)][string]$Id,
    [scriptblock]$RegistryProvider,
    [scriptblock]$PathExistsProvider,
    [scriptblock]$ExecutableVersionProvider,
    [scriptblock]$GitVersionProvider
  )

  if ($Id -eq "git" -and $GitVersionProvider) {
    $gitCommandResult = & $GitVersionProvider
    return Get-QuickSetupGitVersion -Output ([string]$gitCommandResult.Output) -ExitCode ([int]$gitCommandResult.ExitCode)
  }

  if ($Id -eq "github-copilot-desktop") {
    $registryPaths = @(
      "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($registryPath in $registryPaths) {
      $entries = if ($RegistryProvider) {
        & $RegistryProvider $registryPath
      } else {
        Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
      }
      $entry = $entries |
        Where-Object { $_.DisplayName -and $_.DisplayName -match "^GitHub Copilot(?: Desktop)?$" } |
        Select-Object -First 1
      if ($entry) {
        if ($entry.DisplayVersion) { return [string]$entry.DisplayVersion }
        return "detected (version unavailable)"
      }
    }

    $executablePath = Join-Path $env:LOCALAPPDATA "Programs\GitHub Copilot\GitHub Copilot.exe"
    if (!$PathExistsProvider) {
      foreach ($candidate in @("Programs\GitHub Copilot\github.exe", "GitHub Copilot\github.exe")) {
        $candidatePath = Join-Path $env:LOCALAPPDATA $candidate
        if (Test-Path -LiteralPath $candidatePath -PathType Leaf) { $executablePath = $candidatePath; break }
      }
    }
    $executableExists = if ($PathExistsProvider) {
      [bool](& $PathExistsProvider $executablePath)
    } else {
      Test-Path -LiteralPath $executablePath
    }
    if ($executableExists) {
      $version = if ($ExecutableVersionProvider) {
        [string](& $ExecutableVersionProvider $executablePath)
      } else {
        [string](Get-Item -LiteralPath $executablePath).VersionInfo.ProductVersion
      }
      if ($version) { return $version }
      return "detected (version unavailable)"
    }
    return $null
  }

  if ($Id -eq "libreoffice") {
    $registryPaths = @(
      "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($registryPath in $registryPaths) {
      $entries = if ($RegistryProvider) {
        & $RegistryProvider $registryPath
      } else {
        Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue
      }
      $entry = $entries |
        Where-Object { $_.DisplayName -and $_.DisplayName -match "^LibreOffice(?:\s+\d+(?:\.\d+){1,3})?$" } |
        Select-Object -First 1
      if ($entry) {
        if ($entry.DisplayVersion) { return [string]$entry.DisplayVersion }
        return "detected (version unavailable)"
      }
    }

    $executablePaths = @(
      (Join-Path $env:ProgramFiles "LibreOffice\program\soffice.exe"),
      (Join-Path ${env:ProgramFiles(x86)} "LibreOffice\program\soffice.exe")
    )
    foreach ($executablePath in $executablePaths) {
      $executableExists = if ($PathExistsProvider) {
        [bool](& $PathExistsProvider $executablePath)
      } else {
        Test-Path -LiteralPath $executablePath
      }
      if ($executableExists) {
        $version = if ($ExecutableVersionProvider) {
          [string](& $ExecutableVersionProvider $executablePath)
        } else {
          [string](Get-Item -LiteralPath $executablePath).VersionInfo.ProductVersion
        }
        if ($version) { return $version }
        return "detected (version unavailable)"
      }
    }
    return $null
  }

  if ($Id -eq "docker-desktop") {
    $registryPaths = @(
      "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
      "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
    )
    foreach ($registryPath in $registryPaths) {
      $entry = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue |
        Where-Object { $_.DisplayName -and $_.DisplayName -like "Docker Desktop*" } |
        Select-Object -First 1
      if ($entry) {
        if ($entry.DisplayVersion) { return [string]$entry.DisplayVersion }
        return "detected (version unavailable)"
      }
    }
    $desktopExecutable = Join-Path $env:ProgramFiles "Docker\Docker\Docker Desktop.exe"
    if (Test-Path -LiteralPath $desktopExecutable) { return "detected (version unavailable)" }
    return $null
  }

  $commandName = switch ($Id) {
    "git" { "git" }
    "github-cli" { "gh" }
    "vscode" { "code" }
    "nodejs-lts" { "node" }
    "python" { "python" }
    "dotnet-10-sdk" { "dotnet" }
    "powershell-7" { "pwsh" }
    "seven-zip" { "7z" }
    "firefox" { "firefox" }
    "github-copilot-cli" { "copilot" }
    default { $null }
  }

  if ($Id -eq "openssh-client") {
    try {
      $capability = Get-WindowsCapability -Online -Name "OpenSSH.Client*" -ErrorAction Stop |
        Select-Object -First 1
      if ($capability.State -eq "Installed") { return [string]$capability.Name }
    } catch { }
  }

  if ($commandName) {
    $command = Get-Command $commandName -ErrorAction SilentlyContinue | Select-Object -First 1
    if ($Id -eq "python" -and $command -and $command.Source -like (Join-Path $env:LOCALAPPDATA "Microsoft\WindowsApps\*")) {
      $command = $null
    }
    if (!$command) {
      $candidatePaths = switch ($Id) {
        "python" {
          # Python Install Manager registers real runtimes using PEP 514. Probe those
          # executables rather than invoking a WindowsApps alias that could install a runtime.
          @(Get-ChildItem "HKCU:\Software\Python\PythonCore", "HKLM:\Software\Python\PythonCore" -ErrorAction SilentlyContinue | ForEach-Object {
            $entry = Get-ItemProperty -LiteralPath (Join-Path $_.PSPath "InstallPath") -ErrorAction SilentlyContinue
            if ($entry.ExecutablePath) { [string]$entry.ExecutablePath }
          })
        }
        "git" { @((Join-Path $env:ProgramFiles "Git\cmd\git.exe")) }
        "github-cli" { @((Join-Path $env:ProgramFiles "GitHub CLI\gh.exe")) }
        "vscode" { @((Join-Path $env:LOCALAPPDATA "Programs\Microsoft VS Code\bin\code.cmd")) }
        "nodejs-lts" { @((Join-Path $env:ProgramFiles "nodejs\node.exe")) }
        "dotnet-10-sdk" { @((Join-Path $env:ProgramFiles "dotnet\dotnet.exe")) }
        "powershell-7" { @((Join-Path $env:ProgramFiles "PowerShell\7\pwsh.exe")) }
        "seven-zip" { @((Join-Path $env:ProgramFiles "7-Zip\7z.exe")) }
        "firefox" { @((Join-Path $env:ProgramFiles "Mozilla Firefox\firefox.exe")) }
        default { @() }
      }
      $candidate = @($candidatePaths | Where-Object { Test-Path -LiteralPath $_ }) | Select-Object -First 1
      if ($candidate) { $command = [pscustomobject]@{ Source = $candidate } }
    }
    if ($command) {
      try {
        switch ($Id) {
          "git" {
            $output = & $command.Source --version 2>$null | Out-String
            $version = Get-QuickSetupGitVersion -Output $output -ExitCode $LASTEXITCODE
            if ($version) { return $version }
          }
          "github-cli" {
            $output = & $command.Source --version 2>$null | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "(\d+\.\d+(?:\.\d+)?)") { return $Matches[1] }
          }
          "vscode" {
            $output = & $command.Source --version 2>$null | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
          }
          "nodejs-lts" {
            $output = & $command.Source --version 2>$null | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "v?(\d+\.\d+\.\d+)") {
              $nodeVersion = $Matches[1]
              $npmCommand = Get-Command npm -ErrorAction SilentlyContinue | Select-Object -First 1
              if (!$npmCommand) {
                $npmPath = Join-Path (Split-Path -Parent $command.Source) "npm.cmd"
                if (Test-Path -LiteralPath $npmPath) { $npmCommand = [pscustomobject]@{ Source = $npmPath } }
              }
              if (!$npmCommand) { return "$nodeVersion (npm not found)" }
              $npmOutput = & $npmCommand.Source --version 2>$null | Out-String
              if ($LASTEXITCODE -eq 0 -and $npmOutput -match "(\d+\.\d+\.\d+)") { return "$nodeVersion (npm $($Matches[1]))" }
              return "$nodeVersion (npm version unavailable)"
            }
          }
          "python" {
            $output = & $command.Source --version 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "Python\s+(\d+\.\d+\.\d+)") {
              $pythonVersion = $Matches[1]
              $pyCommand = Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1
              $pipOutput = & $command.Source -m pip --version 2>&1 | Out-String
              $pyState = if ($pyCommand) { "py available" } else { "py not found" }
              $pipState = if ($pipOutput -match "pip\s+(\d+)") { "pip available" } else { "pip not verified" }
              return "$pythonVersion ($pyState; $pipState)"
            }
          }
          "dotnet-10-sdk" {
            $output = & $command.Source --list-sdks 2>$null | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "(?m)^(10\.\d+\.\d+)\s+") { return $Matches[1] }
          }
          "powershell-7" {
            $output = & $command.Source -NoLogo -NoProfile -Command '$PSVersionTable.PSVersion.ToString()' 2>$null | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "(\d+\.\d+\.\d+)") { return $Matches[1] }
          }
          "seven-zip" {
            $output = & $command.Source 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "(\d+\.\d+)") { return $Matches[1] }
          }
          "firefox" {
            $output = & $command.Source --version 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "(\d+\.\d+(?:\.\d+)?)") { return $Matches[1] }
          }
          "github-copilot-cli" {
            $output = & $command.Source --version 2>&1 | Out-String
            if ($LASTEXITCODE -eq 0 -and $output -match "(\d+\.\d+(?:\.\d+)?)") { return $Matches[1] }
          }
        }
      } catch { }
      # A command stub or an unrelated SDK/runtime is not an installed requested package.
      return $null
    }
  }

  if ($Id -in @("git", "dotnet-10-sdk")) { return $null }
  $name = Get-QuickSetupPackageName -Id $Id
  $registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  foreach ($registryPath in $registryPaths) {
    $entry = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue |
      Where-Object {
        if (!$_.DisplayName) { $false }
        elseif ($Id -eq "git") { $_.DisplayName -match "^Git(?:$| for Windows(?:\s+[\w.-]+)?$| version\s+[\w.-]+$|\s+[\d][\w.-]*$)" }
        else { $_.DisplayName -like "$name*" }
      } |
      Select-Object -First 1
    if ($entry) {
      if ($entry.DisplayVersion) { return [string]$entry.DisplayVersion }
      return "detected (version unavailable)"
    }
  }

  return $null
}

function Get-QuickSetupDockerDiagnostics {
  $docker = Get-Command docker -ErrorAction SilentlyContinue | Select-Object -First 1
  $desktopVersion = Get-QuickSetupDetectedVersion -Id "docker-desktop"
  if (!$docker) {
    return [pscustomobject]@{
      IsInstalled = [bool]$desktopVersion
      Version = $desktopVersion
      Context = $null
      ContainerType = $null
      Notes = if ($desktopVersion) { "Docker Desktop is installed, but the Docker CLI was not found in PATH." } else { "Docker Desktop and the Docker CLI were not found." }
    }
  }

  $version = $null
  $context = $null
  $containerType = $null
  $notes = @()
  try {
    $output = & $docker.Source version 2>&1 | Out-String
    $client = [regex]::Match($output, "(?s)Client:.*?Version:\s*(\d+\.\d+\.\d+)")
    $server = [regex]::Match($output, "(?s)Server:.*?Version:\s*(\d+\.\d+\.\d+)")
    if ($client.Success -and $server.Success) {
      $version = "Client $($client.Groups[1].Value); Server $($server.Groups[1].Value)"
    } elseif ($client.Success) {
      $version = "Client $($client.Groups[1].Value)"
      $notes += "Docker Engine did not return server version details."
    } else {
      $notes += "docker version output could not be parsed."
    }
  } catch { $notes += "docker version could not be read." }
  try {
    $context = (& $docker.Source context show 2>&1 | Out-String).Trim()
    if ($LASTEXITCODE -ne 0) { $context = $null; $notes += "Docker context could not be queried." }
  } catch { $notes += "Docker context could not be queried." }
  try {
    $info = & $docker.Source info 2>&1 | Out-String
    if ($LASTEXITCODE -ne 0) {
      $notes += "Docker Engine is not reachable."
    } elseif ($info -match "(?m)^\s*OSType:\s*(\S+)") {
      $containerType = $Matches[1]
    } else {
      $notes += "Docker info did not report its container type."
    }
  } catch { $notes += "Docker Engine is not reachable." }
  if (!$containerType) { $notes += "No daemon diagnostics were changed or repaired." }

  [pscustomobject]@{
    IsInstalled = [bool]$desktopVersion
    Version = if ($desktopVersion -and $desktopVersion -ne "detected (version unavailable)") { $desktopVersion } else { $version }
    Context = $context
    ContainerType = $containerType
    Notes = if ($desktopVersion) { ($notes -join " ") } else { ("A Docker CLI was found, but Docker Desktop itself was not detected. " + ($notes -join " ")) }
  }
}

function Get-QuickSetupPythonDiagnostics {
  $python = Get-Command python -ErrorAction SilentlyContinue | Select-Object -First 1
  $py = Get-Command py -ErrorAction SilentlyContinue | Select-Object -First 1
  $version = $null
  $launcherVersion = $null
  $pipAvailable = $false
  if ($python) {
    try {
      $output = & $python.Source --version 2>&1 | Out-String
      if ($output -match "Python\s+(\d+\.\d+\.\d+)") { $version = $Matches[1] }
      $pipOutput = & $python.Source -m pip --version 2>&1 | Out-String
      $pipAvailable = ($LASTEXITCODE -eq 0 -and $pipOutput -match "pip\s+\d+")
    } catch { }
  }
  if ($py) {
    try {
      $output = & $py.Source --version 2>&1 | Out-String
      if ($LASTEXITCODE -eq 0 -and $output -match "Python\s+(\d+\.\d+\.\d+)") {
        $launcherVersion = $Matches[1]
      }
    } catch { }
  }
  [pscustomobject]@{
    Version = $version
    LauncherVersion = $launcherVersion
    PythonCommand = [bool]$python
    PyLauncher = [bool]$py
    Pip = $pipAvailable
    Complete = [bool]($python -and $version -and $py -and $launcherVersion -and $pipAvailable)
  }
}

function Sync-QuickSetupProcessPath {
  param(
    [string]$MachinePath = [Environment]::GetEnvironmentVariable("Path", "Machine"),
    [string]$UserPath = [Environment]::GetEnvironmentVariable("Path", "User")
  )

  $pathEntries = @($env:Path -split ";" | Where-Object { $_ })
  $pathEntries += @($MachinePath -split ";" | Where-Object { $_ })
  $pathEntries += @($UserPath -split ";" | Where-Object { $_ })
  $env:Path = (@($pathEntries | Select-Object -Unique) -join ";")
}

function Get-QuickSetupWebView2Version {
  $registryPaths = @(
    "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKLM:\SOFTWARE\WOW6432Node\Microsoft\Windows\CurrentVersion\Uninstall\*",
    "HKCU:\SOFTWARE\Microsoft\Windows\CurrentVersion\Uninstall\*"
  )
  foreach ($registryPath in $registryPaths) {
    $entry = Get-ItemProperty -Path $registryPath -ErrorAction SilentlyContinue |
      Where-Object { $_.DisplayName -and $_.DisplayName -like "Microsoft Edge WebView2 Runtime*" } |
      Select-Object -First 1
    if ($entry) { return [string]$entry.DisplayVersion }
  }
  return $null
}

function Set-QuickSetupVsCodeDarkTheme {
  param()

  $settingsPath = Join-Path $env:APPDATA "Code\User\settings.json"
  $directory = Split-Path -Parent $settingsPath
  if (!(Test-Path -LiteralPath $directory)) {
    New-Item -ItemType Directory -Path $directory -Force | Out-Null
  }
  $settings = [pscustomobject]@{}
  if (Test-Path -LiteralPath $settingsPath) {
    try {
      $settings = Get-Content -LiteralPath $settingsPath -Raw | ConvertFrom-Json -ErrorAction Stop
    } catch {
      return [pscustomobject]@{
        Success = $false
        Notes = "Existing settings.json is JSONC or invalid JSON; it was not changed. Set the theme manually."
      }
    }
    if ($null -eq $settings -or $settings -isnot [pscustomobject]) {
      return [pscustomobject]@{
        Success = $false
        Notes = "Existing settings.json is not a JSON object; it was not changed. Set the theme manually."
      }
    }
    $backupPath = "$settingsPath.configureMe-$(Get-Date -Format 'yyyyMMdd-HHmmss').bak"
    Copy-Item -LiteralPath $settingsPath -Destination $backupPath -ErrorAction Stop
  }

  if ($settings.PSObject.Properties["workbench.colorTheme"]) {
    $settings."workbench.colorTheme" = "Default Dark Modern"
  } else {
    $settings | Add-Member -NotePropertyName "workbench.colorTheme" -NotePropertyValue "Default Dark Modern"
  }
  $json = ConvertTo-Json -InputObject $settings -Depth 100
  Set-Content -LiteralPath $settingsPath -Value $json -Encoding UTF8
  [pscustomobject]@{ Success = $true; Notes = "Dark theme set for the current Windows user only." }
}

function Get-QuickSetupGitVersion {
  param(
    [Parameter(Mandatory = $true)][AllowEmptyString()][string]$Output,
    [int]$ExitCode = 0
  )

  if ($ExitCode -ne 0) { return $null }
  if ($Output -match "(?m)^\s*git version (\d+\.\d+(?:\.\d+)?(?:\.windows\.\d+)?)\s*$") {
    return $Matches[1]
  }
  return $null
}

Export-ModuleMember -Function Get-QuickSetupOperatingSystem, Test-QuickSetupTargetContext, Get-QuickSetupPackageCatalog, Get-QuickSetupPackageDefinition, Get-QuickSetupPackageName, Get-QuickSetupDetectedVersion, Get-QuickSetupGitVersion, Get-QuickSetupDockerDiagnostics, Get-QuickSetupPythonDiagnostics, Sync-QuickSetupProcessPath, Get-QuickSetupWebView2Version, Set-QuickSetupVsCodeDarkTheme
