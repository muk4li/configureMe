function Test-QuickSetupProfile {
  param(
    [Parameter(Mandatory = $true)]$Profile,
    [Parameter(Mandatory = $true)][string[]]$AllowedPackageIds
  )

  if ($Profile.schemaVersion -ne 1 -or $Profile.id -ne "windows-server-2022-developer" -or $Profile.platform -ne "windows") {
    throw "The local profile is not a supported configureMe Windows Server 2022 profile."
  }
  if (!$Profile.packages -or $Profile.packages.Count -eq 0 -or $Profile.packages.Count -gt 50) {
    throw "The profile package list is empty or too large."
  }
  if (@($Profile.packages | Select-Object -Unique).Count -ne $Profile.packages.Count) {
    throw "The profile contains duplicate package IDs."
  }
  foreach ($packageId in $Profile.packages) {
    if ($packageId -notin $AllowedPackageIds) {
      throw "Package '$packageId' is not in the local trusted package catalog."
    }
  }
}

function Test-QuickSetupSha256Text {
  param(
    [Parameter(Mandatory = $true)][string]$Text,
    [Parameter(Mandatory = $true)][string]$FileName
  )

  $escapedName = [regex]::Escape($FileName)
  $match = [regex]::Match($Text, "(?m)^([a-fA-F0-9]{64})\s+\*?$escapedName\s*$")
  if (!$match.Success) { return $null }
  return $match.Groups[1].Value
}

function Test-QuickSetupAdministratorRequirement {
  param(
    [Parameter(Mandatory = $true)][bool]$RequiresAdministrator,
    [Parameter(Mandatory = $true)][bool]$IsAdministrator
  )

  return (!$RequiresAdministrator -or $IsAdministrator)
}

Export-ModuleMember -Function Test-QuickSetupProfile, Test-QuickSetupSha256Text, Test-QuickSetupAdministratorRequirement
