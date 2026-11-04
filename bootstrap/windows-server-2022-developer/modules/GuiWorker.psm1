function Resolve-QuickSetupGuiDependencies {
  param([Parameter(Mandatory = $true)][string[]]$PackageIds)

  $resolved = New-Object System.Collections.Generic.List[string]
  $visiting = New-Object System.Collections.Generic.HashSet[string]
  $added = New-Object System.Collections.Generic.HashSet[string]

  function Add-PackageDependency {
    param([string]$Id)
    if ($added.Contains($Id)) { return }
    if (!$visiting.Add($Id)) { throw "Package dependency cycle includes '$Id'." }
    $definition = Get-QuickSetupPackageDefinition -Id $Id
    if (!$definition) { throw "Package '$Id' is not in the local trusted catalog." }
    foreach ($dependency in @($definition.dependencies)) {
      if ($dependency) { Add-PackageDependency -Id ([string]$dependency) }
    }
    $visiting.Remove($Id) | Out-Null
    $added.Add($Id) | Out-Null
    $resolved.Add($Id)
  }

  foreach ($packageId in $PackageIds) { Add-PackageDependency -Id $packageId }
  return $resolved.ToArray()
}

function Get-QuickSetupGuiAdministratorStatus {
  $identity = [Security.Principal.WindowsIdentity]::GetCurrent()
  $principal = New-Object Security.Principal.WindowsPrincipal($identity)
  return $principal.IsInRole([Security.Principal.WindowsBuiltInRole]::Administrator)
}

function Write-QuickSetupGuiPackageEvent {
  param(
    [Parameter(Mandatory = $true)][string]$Type,
    [Parameter(Mandatory = $true)][string]$Id,
    [string]$Status,
    [string]$Message,
    $Data
  )
  Write-QuickSetupEvent -Type $Type -PackageId $Id -Status $Status -Message $Message -Data $Data
}

function Invoke-QuickSetupGuiWorker {
  Set-QuickSetupGuiWorkerMode
  $requestLine = [Console]::In.ReadLine()
  if (!$requestLine -or $requestLine.Length -gt 65536) {
    throw "The GUI worker request is missing or exceeds the size limit."
  }
  $request = $requestLine | ConvertFrom-Json -ErrorAction Stop
  if ($request.schemaVersion -ne 1 -or $request.action -notin @("list", "detect", "plan", "download", "install")) {
    throw "The GUI worker request schema or action is unsupported."
  }

  $catalog = @(Get-QuickSetupPackageCatalog)
  $catalogIds = @($catalog | ForEach-Object { [string]$_.id })
  if ($request.action -eq "list") {
    Write-QuickSetupEvent -Type "catalog" -Data $catalog
    return 0
  }
  if (!$request.packageIds -or $request.packageIds.Count -gt 50) {
    throw "The GUI worker request must contain between one and 50 package IDs."
  }
  $packageIds = @($request.packageIds | ForEach-Object { [string]$_ })
  foreach ($packageId in $packageIds) {
    if ($packageId -notmatch "^[a-z0-9]+(?:-[a-z0-9]+)*$" -or $packageId -notin $catalogIds) {
      throw "Package '$packageId' is not in the local trusted Windows catalog."
    }
  }
  $packageIds = @($packageIds | Select-Object -Unique)
  $operatingSystem = Get-QuickSetupOperatingSystem
  $isAdministrator = Get-QuickSetupGuiAdministratorStatus
  Write-QuickSetupEvent -Type "system-detected" -Status $(if ($operatingSystem.IsSupported) { "supported" } else { "unsupported" }) -Data @{
    operatingSystem = $operatingSystem
    isAdministrator = $isAdministrator
  }

  if ($request.action -eq "detect") {
    foreach ($id in $packageIds) {
      $version = Get-QuickSetupDetectedVersion -Id $id
      $details = if ($id -eq "docker-desktop") { Get-QuickSetupDockerDiagnostics } else { $null }
      Write-QuickSetupGuiPackageEvent -Type "package-detected" -Id $id -Status $(if ($version) { "installed" } else { "missing" }) -Data @{
        detectedVersion = $version
        details = $details
      }
    }
    return 0
  }

  $orderedIds = Resolve-QuickSetupGuiDependencies -PackageIds $packageIds
  if ($request.action -eq "plan") {
    $plan = foreach ($id in $orderedIds) {
      $catalogPackage = Get-QuickSetupPackageDefinition -Id $id
      $installer = Get-QuickSetupInstallerDefinition -Id $id -OfflinePreview
      $requiresAdministrator = if ($installer) { [bool]$installer.RequiresAdministrator } else { [bool]$catalogPackage.elevated }
      $action = if ($catalogPackage.windowsMode -eq "detection-only") { "detection-only" }
        elseif ($catalogPackage.windowsMode -eq "web-fallback") { "manual-action" }
        elseif ($catalogPackage.windowsMode -eq "manual" -or !$installer -or !$installer.Automatic) { "manual-action" }
        else { "install" }
      [pscustomobject]@{
        id = $id
        name = [string]$catalogPackage.name
        action = $action
        requiresAdministrator = $requiresAdministrator
        administratorAvailable = (!$requiresAdministrator -or $isAdministrator)
        installerType = if ($installer) { [string]$installer.InstallerType } else { "manual" }
        method = if ($installer) { [string]$installer.Method } else { [string]$catalogPackage.platforms.windows.label }
        notes = if ($installer) { [string]$installer.Notes } else { [string]$catalogPackage.description }
      }
    }
    Write-QuickSetupEvent -Type "install-plan" -Data @($plan)
    return 0
  }

  if ($request.action -eq "download") {
    if ($request.confirmed -ne $true) {
      throw "The GUI worker will not download packages before explicit user confirmation."
    }
    if (!$operatingSystem.IsSupported) {
      throw "The setup target is not supported; no installer was downloaded."
    }
    if ($packageIds.Count -ne 1) {
      throw "The GUI download action accepts exactly one package at a time."
    }
    $id = $packageIds[0]
    $catalogPackage = Get-QuickSetupPackageDefinition -Id $id
    if ($catalogPackage.windowsMode -ne "automatic") {
      throw "Package '$id' does not have a supported automatic download route."
    }
    if (Get-QuickSetupDetectedVersion -Id $id) {
      Write-QuickSetupGuiPackageEvent -Type "package-status" -Id $id -Status "already-installed" -Message "Existing installation preserved; no download was started."
      return 0
    }
    $definition = Get-QuickSetupInstallerDefinition -Id $id
    if (!$definition -or !$definition.Automatic -or $definition.InstallerType -notin @("msi", "exe", "msix")) {
      throw "Package '$id' has no verified automatic installer."
    }
    $cachePath = Get-QuickSetupInstallerCachePath -Id $id -Definition $definition
    $temporaryPath = $cachePath + "." + [guid]::NewGuid().ToString("N") + ".download"
    Write-QuickSetupGuiPackageEvent -Type "download-started" -Id $id -Status "downloading" -Message "Downloading from the configured official source."
    if (Test-Path -LiteralPath $cachePath -PathType Leaf) {
      $temporaryPath = $cachePath
    } else {
      Get-QuickSetupOfficialDownload -Uri $definition.Uri -Destination $temporaryPath -AllowedHosts $definition.AllowedHosts -ExpectedSha256 $definition.Sha256 -ExpectedSha512 $definition.Sha512 | Out-Null
    }
    Write-QuickSetupGuiPackageEvent -Type "download-completed" -Id $id -Status "downloaded"
    Write-QuickSetupGuiPackageEvent -Type "verification-started" -Id $id -Status "verifying"
    if ($definition.InstallerType -eq "msix") {
      Test-QuickSetupInstallerFile -Path $temporaryPath -InstallerType "msix" -ExpectedArchitecture $definition.ExpectedArchitecture -ExpectedPackageName $definition.PackageName -ExpectedPackagePublisher $definition.PackagePublisher | Out-Null
    } else {
      Test-QuickSetupInstallerFile -Path $temporaryPath -InstallerType $definition.InstallerType -ExpectedArchitecture $definition.ExpectedArchitecture -AllowX86BootstrapForX64:([bool]$definition.AllowX86BootstrapForX64) | Out-Null
      $signature = Test-QuickSetupAuthenticodePublisher -Path $temporaryPath -ExpectedPublisher $definition.Publisher -ExpectedCommonName $definition.ExpectedCommonName
      if (!$signature.IsValid) { throw $signature.Message }
    }
    if ($temporaryPath -ne $cachePath) {
      Move-Item -LiteralPath $temporaryPath -Destination $cachePath -Force
    }
    Write-QuickSetupGuiPackageEvent -Type "verification-completed" -Id $id -Status "verified"
    Write-QuickSetupGuiPackageEvent -Type "package-status" -Id $id -Status "ready" -Message "Download and installer checks completed."
    return 0
  }

  if ($request.confirmed -ne $true) {
    throw "The GUI worker will not install packages without an explicit confirmation."
  }
  if (!$operatingSystem.IsSupported) {
    Write-QuickSetupEvent -Type "operation-completed" -Status "unsupported" -Message ($operatingSystem.Reasons -join " ")
    return 1
  }

  $startedAt = [DateTime]::UtcNow.ToString("o")
  $results = New-Object System.Collections.Generic.List[object]
  $errors = New-Object System.Collections.Generic.List[string]
  $manualSteps = New-Object System.Collections.Generic.List[string]
  $reportPath = Join-Path (Join-Path $env:LOCALAPPDATA "configureMe\Reports") "setup-report.json"
  foreach ($id in $orderedIds) {
    $catalogPackage = Get-QuickSetupPackageDefinition -Id $id
    $name = [string]$catalogPackage.name
    $result = New-QuickSetupPackageResult -Id $id -Name $name -RequestedVersion "latest stable"
    try {
      $detectedVersion = Get-QuickSetupDetectedVersion -Id $id
      $result.DetectedVersion = $detectedVersion
      if ($id -eq "docker-desktop") {
        $docker = Get-QuickSetupDockerDiagnostics
        $result.DetectedVersion = $docker.Version
        $result.Source = [string]$catalogPackage.website
        $result.Method = "Detection only; no install or configuration"
        $result.Status = if ($docker.IsInstalled) { "Already installed" } else { "Not supported" }
        $result.Notes = "Context: $($docker.Context); container type: $($docker.ContainerType). $($docker.Notes) Docker Desktop is not officially supported on Windows Server 2022; no installer was run."
        if (!$docker.IsInstalled) { $manualSteps.Add("Docker Desktop is not supported on Windows Server 2022. No installer was run: $($catalogPackage.website)") }
      } elseif ($detectedVersion) {
        $result.Status = "Already installed"
        $result.Source = "Detected locally"
        $result.Method = "Detected locally; no update performed"
        $result.Notes = "The existing installation was preserved."
      } elseif ($catalogPackage.windowsMode -in @("manual", "web-fallback")) {
        $result.Status = "Requires user action"
        $result.Source = [string]$catalogPackage.website
        $result.Method = [string]$catalogPackage.platforms.windows.label
        $result.Notes = [string]$catalogPackage.description
        $manualSteps.Add("$name requires a manual action: $($catalogPackage.website)")
      } elseif (!$operatingSystem.IsSupported) {
        $result.Status = "Not supported"
        $result.Notes = $operatingSystem.Reasons -join " "
      } else {
        $installer = Get-QuickSetupInstallerDefinition -Id $id -OfflinePreview:$false
        if (!$installer -or !$installer.Automatic) {
          $result.Status = "Requires user action"
          $result.Method = "Manual; no verified automatic installer"
          $result.Notes = [string]$catalogPackage.description
          $manualSteps.Add("$name has no verified automatic installation route: $($catalogPackage.website)")
        } elseif (!(Test-QuickSetupAdministratorRequirement -RequiresAdministrator ([bool]$installer.RequiresAdministrator) -IsAdministrator $isAdministrator)) {
          $result.Status = "Requires user action"
          $result.RequiresAdministrator = $true
          $result.Method = [string]$installer.Method
          $result.Source = [string]$installer.Source
          $result.Notes = "No installer was downloaded or started. Re-run the setup under the same Windows account with administrator rights; do not use Run as different user."
          $manualSteps.Add("$name requires administrator rights. Re-run configureMe Setup under the same Windows account as an administrator.")
        } else {
          $result.RequestedVersion = [string]$installer.Version
          $result.InstallerType = [string]$installer.InstallerType
          $result.RequiresAdministrator = [bool]$installer.RequiresAdministrator
          $result.Source = [string]$installer.Source
          $result.Method = [string]$installer.Method
          $result.Notes = [string]$installer.Notes
          Write-QuickSetupGuiPackageEvent -Type "package-status" -Id $id -Status "installing" -Message "Installation preparation started."
          $progressCallback = {
            param($stage)
            Write-QuickSetupGuiPackageEvent -Type $stage -Id $id -Status $stage
          }.GetNewClosure()
          $cachePath = if ($installer.InstallerType -in @("msi", "exe", "msix")) {
            Get-QuickSetupInstallerCachePath -Id $id -Definition $installer
          } else { $null }
          $cachedInstaller = if ($cachePath -and (Test-Path -LiteralPath $cachePath -PathType Leaf)) { $cachePath } else { $null }
          $installResult = Invoke-QuickSetupPackageInstall -Id $id -Definition $installer -ProgressCallback $progressCallback -CachedInstallerPath $cachedInstaller
          if ($installResult.ExitCode -notin @(0, 3010)) {
            $result.Status = "Failed"
            $result.ErrorCode = [string]$installResult.ExitCode
            $result.Notes = "$($installer.Notes) Installer exited with code $($installResult.ExitCode)."
            $errors.Add("$name installer exit code $($installResult.ExitCode).")
          } else {
            $result.RestartRequired = [bool]$installResult.RestartRequired
            Sync-QuickSetupProcessPath
            $result.DetectedVersion = Get-QuickSetupDetectedVersion -Id $id
            if ($result.DetectedVersion) {
              $result.Status = "Installed"
            } else {
              $result.Status = "Failed"
              $result.ErrorCode = if ($id -eq "git") { "git-version-verification-failed" } else { "verification-failed" }
              $result.Notes = "The installer returned success, but the installed package could not be verified."
              $errors.Add("$name could not be verified after installation.")
            }
          }
        }
      }
    } catch {
      $result.Status = if ($_.Exception.Message -match "signature|publisher|SHA-256|redirected outside|not an allowed official") { "Requires user action" } else { "Failed" }
      $result.ErrorCode = if ($result.Status -eq "Requires user action") { "verification-refused" } else { "install-error" }
      $result.Notes = $_.Exception.Message
      if ($result.Status -eq "Failed") { $errors.Add("$name`: $($_.Exception.Message)") }
      else { $manualSteps.Add("$name was not run because verification refused the installer. Review the official source manually: $($catalogPackage.website)") }
    }
    $results.Add($result)
    Write-QuickSetupGuiPackageEvent -Type "package-installation-completed" -Id $id -Status $result.Status -Message $result.Notes -Data $result
  }

  $summary = if ($errors.Count -gt 0) { "Completed with failures" } elseif ($manualSteps.Count -gt 0) { "Completed with manual steps" } else { "Completed" }
  $report = [pscustomobject]@{
    BootstrapVersion = "0.3.0"
    ProfileId = "windows-server-2022-developer"
    OperatingSystem = $operatingSystem
    Architecture = $operatingSystem.Architecture
    StartedAt = $startedAt
    FinishedAt = [DateTime]::UtcNow.ToString("o")
    Summary = $summary
    Packages = $results.ToArray()
    Errors = $errors.ToArray()
    ManualSteps = @($manualSteps | Select-Object -Unique)
  }
  Write-QuickSetupReport -Report $report -Path $reportPath
  Write-QuickSetupEvent -Type "report-written" -Status $summary -Data @{ jsonPath = $reportPath; textPath = [System.IO.Path]::ChangeExtension($reportPath, ".txt") }
  Write-QuickSetupEvent -Type "operation-completed" -Status $summary -Data $report
  if ($errors.Count -gt 0) { return 1 }
  return 0
}

Export-ModuleMember -Function Invoke-QuickSetupGuiWorker, Resolve-QuickSetupGuiDependencies
