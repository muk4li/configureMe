[CmdletBinding()]
param(
  [Parameter(Mandatory = $true)][string]$PublishDirectory,
  [Parameter(Mandatory = $true)][string]$OutputPath,
  [string]$SourceCommitSha = (& git rev-parse --verify HEAD).Trim()
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$resolvedPublishDirectory = (Resolve-Path -LiteralPath $PublishDirectory -ErrorAction Stop).Path
$executablePath = Join-Path $resolvedPublishDirectory "configureMe-Setup.exe"
if (!(Test-Path -LiteralPath $executablePath -PathType Leaf)) {
  throw "The published configureMe-Setup.exe is missing."
}
foreach ($requiredFile in @("README.md", "SECURITY.md")) {
  if (!(Test-Path -LiteralPath (Join-Path $repositoryRoot "windows\ConfigureMe.Setup\$requiredFile") -PathType Leaf)) {
    throw "Required setup documentation is missing: $requiredFile"
  }
}
if ($SourceCommitSha -notmatch "^[A-Fa-f0-9]{40,64}$") {
  throw "A valid source commit SHA is required for package provenance."
}
$workingTreeDirty = [bool](& git -C $repositoryRoot status --porcelain --untracked-files=all)

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) { $OutputPath } else { Join-Path (Get-Location).Path $OutputPath }
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (!(Test-Path -LiteralPath $outputDirectory)) { New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null }
$stagePath = Join-Path $env:TEMP ("configureMe-Setup-package-" + [guid]::NewGuid().ToString("N"))
New-Item -ItemType Directory -Path $stagePath -Force | Out-Null
try {
  Copy-Item -LiteralPath $executablePath -Destination (Join-Path $stagePath "configureMe-Setup.exe")
  Copy-Item -LiteralPath (Join-Path $repositoryRoot "windows\ConfigureMe.Setup\README.md") -Destination $stagePath
  Copy-Item -LiteralPath (Join-Path $repositoryRoot "windows\ConfigureMe.Setup\SECURITY.md") -Destination $stagePath
  $versionInfo = [ordered]@{
    product = "configureMe Setup"
    version = "0.3.0"
    architecture = "win-x64"
    sourceCommitSha = $SourceCommitSha.ToLowerInvariant()
    workingTreeDirty = $workingTreeDirty
    buildType = "unsigned development build"
    selfContained = $true
    singleFilePublish = $true
    targetOs = "Windows Server 2022 x64 Desktop Experience"
  }
  $versionPath = Join-Path $stagePath "version.json"
  [System.IO.File]::WriteAllText($versionPath, ((ConvertTo-Json -InputObject $versionInfo -Depth 4) + "`n"), (New-Object System.Text.UTF8Encoding($false)))

  $files = @("configureMe-Setup.exe", "README.md", "SECURITY.md", "version.json")
  $manifestFiles = foreach ($file in $files) {
    $path = Join-Path $stagePath $file
    [pscustomobject]@{
      path = $file
      sha256 = (Get-FileHash -LiteralPath $path -Algorithm SHA256).Hash.ToLowerInvariant()
      sizeBytes = (Get-Item -LiteralPath $path).Length
    }
  }
  $manifest = [ordered]@{
    schemaVersion = 1
    packageName = "configureMe-Setup-win-x64"
    sourceCommitSha = $SourceCommitSha.ToLowerInvariant()
    workingTreeDirty = $workingTreeDirty
    unsigned = $true
    buildType = "development"
    files = @($manifestFiles)
  }
  $manifestPath = Join-Path $stagePath "manifest.json"
  [System.IO.File]::WriteAllText($manifestPath, ((ConvertTo-Json -InputObject $manifest -Depth 6) + "`n"), (New-Object System.Text.UTF8Encoding($false)))
  $sumLines = @()
  foreach ($file in @($files + "manifest.json")) {
    $hash = (Get-FileHash -LiteralPath (Join-Path $stagePath $file) -Algorithm SHA256).Hash.ToLowerInvariant()
    $sumLines += "$hash  $file"
  }
  Set-Content -LiteralPath (Join-Path $stagePath "SHA256SUMS.txt") -Value $sumLines -Encoding ASCII

  if (Test-Path -LiteralPath $resolvedOutputPath) { throw "Output ZIP already exists; choose a fresh OutputPath." }
  Add-Type -AssemblyName System.IO.Compression
  $stream = [System.IO.File]::Open($resolvedOutputPath, [System.IO.FileMode]::CreateNew)
  $archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
  try {
    foreach ($file in @(Get-ChildItem -LiteralPath $stagePath -File | Sort-Object Name)) {
      $entry = $archive.CreateEntry($file.Name, [System.IO.Compression.CompressionLevel]::Optimal)
      $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
      $entryStream = $entry.Open()
      try {
        $inputStream = [System.IO.File]::OpenRead($file.FullName)
        try { $inputStream.CopyTo($entryStream) } finally { $inputStream.Dispose() }
      } finally { $entryStream.Dispose() }
    }
  } finally {
    $archive.Dispose()
    $stream.Dispose()
  }
  $zipHash = (Get-FileHash -LiteralPath $resolvedOutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
  Set-Content -LiteralPath "$resolvedOutputPath.sha256" -Value "$zipHash  $(Split-Path -Leaf $resolvedOutputPath)" -Encoding ASCII
  Write-Host "Created unsigned development package $resolvedOutputPath"
  Write-Host "SHA-256: $zipHash"
} finally {
  Remove-Item -LiteralPath $stagePath -Recurse -Force -ErrorAction SilentlyContinue
}
