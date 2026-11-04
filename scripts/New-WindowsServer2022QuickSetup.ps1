[CmdletBinding()]
param(
  [string]$OutputPath = ".\dist\configureMe-WindowsServer2022-Developer-QuickSetup.zip",
  [switch]$Force
)

$ErrorActionPreference = "Stop"
$repositoryRoot = Split-Path -Parent $PSScriptRoot
$sourceRoot = Join-Path $repositoryRoot "bootstrap\windows-server-2022-developer"
$files = @(
  "bootstrap.ps1",
  "config\windows-server-2022-developer.json",
  "modules\Detection.psm1",
  "modules\Downloads.psm1",
  "modules\Installation.psm1",
  "modules\Logging.psm1",
  "modules\Verification.psm1",
  "assets\firefox-bookmarks.html",
  "README.md",
  "SECURITY.md"
)
foreach ($file in $files) {
  if (!(Test-Path -LiteralPath (Join-Path $sourceRoot $file) -PathType Leaf)) {
    throw "Required package file is missing: $file"
  }
}

$resolvedOutputPath = if ([System.IO.Path]::IsPathRooted($OutputPath)) {
  $OutputPath
} else {
  Join-Path (Get-Location).Path $OutputPath
}
$outputDirectory = Split-Path -Parent $resolvedOutputPath
if (!(Test-Path -LiteralPath $outputDirectory)) {
  New-Item -ItemType Directory -Path $outputDirectory -Force | Out-Null
}
if ((Test-Path -LiteralPath $resolvedOutputPath) -or (Test-Path -LiteralPath "$resolvedOutputPath.sha256")) {
  if (!$Force) {
    throw "Output ZIP or checksum already exists. Choose another OutputPath or pass -Force after reviewing the existing files."
  }
  Remove-Item -LiteralPath $resolvedOutputPath -Force -ErrorAction SilentlyContinue
  Remove-Item -LiteralPath "$resolvedOutputPath.sha256" -Force -ErrorAction SilentlyContinue
}

Add-Type -AssemblyName System.IO.Compression
$stream = [System.IO.File]::Open($resolvedOutputPath, [System.IO.FileMode]::CreateNew)
$archive = New-Object System.IO.Compression.ZipArchive($stream, [System.IO.Compression.ZipArchiveMode]::Create, $false)
try {
  foreach ($file in ($files | Sort-Object)) {
    $entryName = "configureMe-QuickSetup/" + $file.Replace("\", "/")
    $entry = $archive.CreateEntry($entryName, [System.IO.Compression.CompressionLevel]::Optimal)
    $entry.LastWriteTime = [DateTimeOffset]::new(1980, 1, 1, 0, 0, 0, [TimeSpan]::Zero)
    $entryStream = $entry.Open()
    $inputStream = [System.IO.File]::OpenRead((Join-Path $sourceRoot $file))
    try { $inputStream.CopyTo($entryStream) } finally {
      $inputStream.Dispose()
      $entryStream.Dispose()
    }
  }
} finally {
  $archive.Dispose()
  $stream.Dispose()
}

$hash = (Get-FileHash -LiteralPath $resolvedOutputPath -Algorithm SHA256).Hash.ToLowerInvariant()
Set-Content -LiteralPath "$resolvedOutputPath.sha256" -Value "$hash  $(Split-Path -Leaf $resolvedOutputPath)" -Encoding ASCII
Write-Host "Created $resolvedOutputPath"
Write-Host "SHA-256: $hash"
Write-Host "The ZIP and adjacent hash file are unsigned; the hash is not publisher authentication."
