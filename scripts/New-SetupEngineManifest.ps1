[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$OutputPath
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repositoryRoot "bootstrap\windows-server-2022-developer"
$files = @(
  "bootstrap.ps1",
  "config\catalog.json",
  "config\windows-server-2022-developer.json",
  "modules\Detection.psm1",
  "modules\Downloads.psm1",
  "modules\GuiWorker.psm1",
  "modules\Installation.psm1",
  "modules\Logging.psm1",
  "modules\Verification.psm1",
  "assets\firefox-bookmarks.html"
)
$manifestFiles = foreach ($file in $files) {
  $path = Join-Path $sourceRoot $file
  if (!(Test-Path -LiteralPath $path -PathType Leaf)) { throw "Required engine resource is missing: $file" }
  $resourceName = "ConfigureMe.Engine." + $file.Replace("\", ".")
  [pscustomobject]@{
    path = $file.Replace("\", "/")
    resourceName = $resourceName
    sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
    sizeBytes = (Get-Item -LiteralPath $path).Length
  }
}
$manifest = [ordered]@{
  schemaVersion = 1
  files = @($manifestFiles)
}
$outputDirectory = Split-Path -Parent $OutputPath
if (!(Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
$json = (ConvertTo-Json -InputObject $manifest -Depth 6) + "`n"
[System.IO.File]::WriteAllText($OutputPath, $json, (New-Object System.Text.UTF8Encoding($false)))
