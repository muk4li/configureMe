function ConvertTo-QuickSetupProvenanceUri {
  param([uri]$Uri)
  if (!$Uri -or !$Uri.IsAbsoluteUri -or $Uri.Scheme -ne "https") { return $null }
  $safe = New-Object System.UriBuilder($Uri)
  $safe.UserName = ""; $safe.Password = ""; $safe.Query = ""; $safe.Fragment = ""
  return $safe.Uri.AbsoluteUri
}

function Assert-QuickSetupSafePath {
  param([Parameter(Mandatory = $true)][string]$Path)
  $current = [IO.Path]::GetFullPath($Path)
  while ($current) {
    $item = Get-Item -LiteralPath $current -Force -ErrorAction SilentlyContinue
    if ($item -and ($item.Attributes -band [IO.FileAttributes]::ReparsePoint)) {
      throw "The setup path '$current' is a reparse point; refusing to use it."
    }
    $parent = [IO.Path]::GetDirectoryName($current)
    if ($parent -eq $current) { break }
    $current = $parent
  }
}

function Invoke-QuickSetupOfficialRequest {
  param(
    [Parameter(Mandatory = $true)][uri]$Uri,
    [Parameter(Mandatory = $true)][string[]]$AllowedHosts,
    [string]$Destination
  )
  $current = $Uri
  for ($redirect = 0; $redirect -le 10; $redirect++) {
    if ($current.Scheme -ne "https" -or $current.UserInfo -or !$current.IsDefaultPort -or
      !(Test-QuickSetupAllowedHost -HostName $current.DnsSafeHost -AllowedHosts $AllowedHosts)) {
      throw "The download redirected outside the allowed official HTTPS hosts."
    }
    $request = [Net.HttpWebRequest]::Create($current)
    $request.AllowAutoRedirect = $false
    $request.Timeout = 90000
    $request.ReadWriteTimeout = 90000
    $request.UserAgent = "configureMe-Windows-QuickSetup"
    $request.Accept = "application/json, text/plain, */*"
    $response = $request.GetResponse()
    try {
      if ([int]$response.StatusCode -in @(301, 302, 303, 307, 308)) {
        if (!$response.Headers["Location"] -or $redirect -eq 10) { throw "The official source exceeded its redirect limit." }
        $current = [uri]::new($current, $response.Headers["Location"])
        continue
      }
      if ($Destination) {
        Assert-QuickSetupSafePath -Path $Destination
        $output = [IO.File]::Open($Destination, [IO.FileMode]::Create, [IO.FileAccess]::Write, [IO.FileShare]::None)
        try { $response.GetResponseStream().CopyTo($output) } finally { $output.Dispose() }
        return $current
      }
      $reader = New-Object IO.StreamReader($response.GetResponseStream(), [Text.Encoding]::UTF8, $true)
      try { return [pscustomobject]@{ Content = $reader.ReadToEnd(); Uri = $current } } finally { $reader.Dispose() }
    } finally { $response.Dispose() }
  }
}

function Get-QuickSetupOfficialMetadata {
  param([uri]$Uri, [string[]]$AllowedHosts, [switch]$Json)
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $response = Invoke-QuickSetupOfficialRequest -Uri $Uri -AllowedHosts $AllowedHosts
  if ($Json) { return ($response.Content | ConvertFrom-Json -ErrorAction Stop) }
  return $response
}

function Test-QuickSetupAllowedHost {
  param(
    [Parameter(Mandatory = $true)][string]$HostName,
    [Parameter(Mandatory = $true)][string[]]$AllowedHosts
  )

  foreach ($allowedHost in $AllowedHosts) {
    if ($HostName -ieq $allowedHost -or $HostName.EndsWith(".$allowedHost", [System.StringComparison]::OrdinalIgnoreCase)) {
      return $true
    }
  }
  return $false
}

function Get-QuickSetupOfficialDownload {
  param(
    [Parameter(Mandatory = $true)][uri]$Uri,
    [Parameter(Mandatory = $true)][string]$Destination,
    [Parameter(Mandatory = $true)][string[]]$AllowedHosts,
    [string]$ExpectedSha256,
    [string]$ExpectedSha512,
    [scriptblock]$DownloadProvider,
    [ref]$Provenance
  )

  if ($Provenance) { $Provenance.Value = $null }
  if ($Uri.Scheme -ne "https" -or $Uri.UserInfo -or !$Uri.IsDefaultPort -or !(Test-QuickSetupAllowedHost -HostName $Uri.DnsSafeHost -AllowedHosts $AllowedHosts)) {
    throw "The download URL is not an allowed official HTTPS source."
  }
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  Assert-QuickSetupSafePath -Path $Destination
  $lastError = $null
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      if ($DownloadProvider) {
        $response = & $DownloadProvider $Uri $Destination $AllowedHosts
      } else {
        $response = Invoke-QuickSetupOfficialRequest -Uri $Uri -Destination $Destination -AllowedHosts $AllowedHosts
      }
      $finalUri = if ($response -is [uri]) { $response } elseif ($response.BaseResponse) { $response.BaseResponse.ResponseUri } else { $null }
      if (!$finalUri -or $finalUri.Scheme -ne "https" -or $finalUri.UserInfo -or !$finalUri.IsDefaultPort -or
        !(Test-QuickSetupAllowedHost -HostName $finalUri.DnsSafeHost -AllowedHosts $AllowedHosts)) {
        throw "The download redirected outside the allowed official HTTPS hosts."
      }
      if (!(Test-Path -LiteralPath $Destination) -or (Get-Item -LiteralPath $Destination).Length -eq 0) {
        throw "The official download returned an empty file."
      }
      if ($ExpectedSha256) {
        if ($ExpectedSha256 -notmatch "^[A-Fa-f0-9]{64}$") { throw "The trusted SHA-256 metadata is malformed." }
        $actualHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA256).Hash
        if ($actualHash -ine $ExpectedSha256) { throw "The installer SHA-256 does not match the official metadata." }
      }
      if ($ExpectedSha512) {
        if ($ExpectedSha512 -notmatch "^[A-Fa-f0-9]{128}$") { throw "The trusted SHA-512 metadata is malformed." }
        $actualHash = (Get-FileHash -LiteralPath $Destination -Algorithm SHA512).Hash
        if ($actualHash -ine $ExpectedSha512) { throw "The installer SHA-512 does not match the official metadata." }
      }
      if ($Provenance) {
        $Provenance.Value = [pscustomobject]@{
          SourceKind = "downloaded"
          ConfiguredUri = ConvertTo-QuickSetupProvenanceUri $Uri
          ObservedFinalUri = ConvertTo-QuickSetupProvenanceUri $finalUri
        }
      }
      return $Destination
    } catch {
      $lastError = $_
      Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
      $retryable = $_.Exception -is [System.Net.WebException] -or $_.Exception -is [System.TimeoutException]
      if (!$retryable -or $attempt -eq 3) { break }
      Start-Sleep -Seconds (2 * $attempt)
    }
  }
  throw "The official download failed after $attempt attempt(s): $($lastError.Exception.Message)"
}

function Test-QuickSetupMsixPackage {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedArchitecture,
    [Parameter(Mandatory = $true)][string]$ExpectedPackageName,
    [Parameter(Mandatory = $true)][string]$ExpectedPackagePublisher
  )

  Add-Type -AssemblyName System.IO.Compression.FileSystem
  $archive = [System.IO.Compression.ZipFile]::OpenRead($Path)
  try {
    $manifestEntry = $archive.GetEntry("AppxManifest.xml")
    if (!$manifestEntry -or !$archive.GetEntry("AppxSignature.p7x")) {
      throw "The downloaded package is missing its Appx manifest or signature."
    }
    $manifestStream = $manifestEntry.Open()
    try {
      $settings = New-Object System.Xml.XmlReaderSettings
      $settings.DtdProcessing = [System.Xml.DtdProcessing]::Prohibit
      $settings.XmlResolver = $null
      $xmlReader = [System.Xml.XmlReader]::Create($manifestStream, $settings)
      try {
        $manifest = New-Object System.Xml.XmlDocument
        $manifest.XmlResolver = $null
        $manifest.Load($xmlReader)
      } finally { $xmlReader.Dispose() }
    } finally { $manifestStream.Dispose() }

    $namespaces = New-Object System.Xml.XmlNamespaceManager($manifest.NameTable)
    $namespaces.AddNamespace("appx", "http://schemas.microsoft.com/appx/manifest/foundation/windows10")
    $identity = $manifest.SelectSingleNode("/appx:Package/appx:Identity", $namespaces)
    if (!$identity -or
      $identity.GetAttribute("Name") -ne $ExpectedPackageName -or
      $identity.GetAttribute("Publisher") -ne $ExpectedPackagePublisher -or
      $identity.GetAttribute("ProcessorArchitecture") -ne $ExpectedArchitecture) {
      throw "The MSIX package identity or architecture did not match the expected publisher and package."
    }
    return [pscustomobject]@{
      InstallerType = "msix"
      Architecture = $ExpectedArchitecture
      PackageName = $identity.GetAttribute("Name")
      PackagePublisher = $identity.GetAttribute("Publisher")
    }
  } finally { $archive.Dispose() }
}

function Test-QuickSetupInstallerFile {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][ValidateSet("msi", "exe", "msix")][string]$InstallerType,
    [string]$ExpectedArchitecture = "x64",
    [switch]$AllowX86BootstrapForX64,
    [scriptblock]$MsiPlatformReader,
    [string]$ExpectedPackageName,
    [string]$ExpectedPackagePublisher
  )

  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) {
    throw "The downloaded installer file does not exist."
  }
  if ($InstallerType -eq "msix") {
    if (!$ExpectedPackageName -or !$ExpectedPackagePublisher) {
      throw "The expected MSIX package identity was not configured."
    }
    return Test-QuickSetupMsixPackage -Path $Path -ExpectedArchitecture $ExpectedArchitecture -ExpectedPackageName $ExpectedPackageName -ExpectedPackagePublisher $ExpectedPackagePublisher
  }
  $stream = [System.IO.File]::OpenRead($Path)
  try {
    $reader = New-Object System.IO.BinaryReader($stream)
    if ($InstallerType -eq "msi") {
      $signature = $reader.ReadBytes(8)
      $expected = [byte[]](0xD0, 0xCF, 0x11, 0xE0, 0xA1, 0xB1, 0x1A, 0xE1)
      if ($signature.Length -ne $expected.Length -or [System.BitConverter]::ToString($signature) -ne [System.BitConverter]::ToString($expected)) {
        throw "The downloaded file is not a Windows Installer database (MSI)."
      }
      $stream.Dispose()

      if ($ExpectedArchitecture) {
        $platform = if ($MsiPlatformReader) {
          [string](& $MsiPlatformReader $Path)
        } else {
          $installer = $null
          $database = $null
          $summary = $null
          try {
            $installer = New-Object -ComObject WindowsInstaller.Installer
            $database = $installer.OpenDatabase($Path, 0)
            $summary = $database.SummaryInformation(0)
            [string]$summary.Property(7)
          } catch {
            throw "The MSI architecture could not be verified using Windows Installer: $($_.Exception.Message)"
          } finally {
            foreach ($comObject in @($summary, $database, $installer)) {
              if ($null -ne $comObject -and [System.Runtime.InteropServices.Marshal]::IsComObject($comObject)) {
                [void][System.Runtime.InteropServices.Marshal]::ReleaseComObject($comObject)
              }
            }
          }
        }
        $msiArchitecture = ($platform -split ";", 2)[0]
        if ($ExpectedArchitecture -eq "x64" -and $msiArchitecture -notin @("x64", "Intel64")) {
          throw "The downloaded MSI is not verified as x64 (Windows Installer template: '$platform')."
        }
        if ($ExpectedArchitecture -eq "x86" -and $msiArchitecture -ne "Intel") {
          throw "The downloaded MSI is not verified as x86 (Windows Installer template: '$platform')."
        }
      }
      return [pscustomobject]@{ InstallerType = $InstallerType; Architecture = $ExpectedArchitecture }
    }

    if ($stream.Length -lt 64) { throw "The downloaded file is too small to be a valid PE executable." }
    $stream.Position = 0
    if ($reader.ReadUInt16() -ne 0x5A4D) { throw "The downloaded file is not a Windows PE executable." }
    $stream.Position = 0x3C
    $peOffset = $reader.ReadInt32()
    if ($peOffset -lt 64 -or $peOffset -gt ($stream.Length - 6)) {
      throw "The downloaded executable has an invalid PE header."
    }
    $stream.Position = $peOffset
    if ($reader.ReadUInt32() -ne 0x00004550) { throw "The downloaded file is not a Windows PE executable." }
    $machine = $reader.ReadUInt16()
    $architecture = switch ($machine) {
      0x8664 { "x64" }
      0x014c { "x86" }
      0xAA64 { "arm64" }
      default { "unknown" }
    }
    $x64PayloadWithX86Bootstrap = ($ExpectedArchitecture -eq "x64" -and $AllowX86BootstrapForX64 -and $architecture -eq "x86")
    if ($ExpectedArchitecture -and $architecture -ne $ExpectedArchitecture -and !$x64PayloadWithX86Bootstrap) {
      throw "The downloaded executable architecture is '$architecture'; expected '$ExpectedArchitecture'."
    }
    return [pscustomobject]@{ InstallerType = $InstallerType; Architecture = if ($x64PayloadWithX86Bootstrap) { "x64 payload (x86 bootstrap)" } else { $architecture } }
  } finally {
    $stream.Dispose()
  }
}

function Test-QuickSetupAuthenticodePublisher {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedPublisher,
    [string]$ExpectedCommonName,
    [string]$ExpectedOrganization,
    [scriptblock]$SignatureProvider
  )

  $signature = if ($SignatureProvider) { & $SignatureProvider $Path } else { Get-AuthenticodeSignature -LiteralPath $Path }
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or !$signature.SignerCertificate) {
    return [pscustomobject]@{
      IsValid = $false
      Signer = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
      Message = "The Authenticode signature is missing, invalid, or not trusted by Windows."
    }
  }
  $subject = [string]$signature.SignerCertificate.Subject
  if (!$ExpectedCommonName) { $ExpectedCommonName = $ExpectedPublisher }
  if ($ExpectedCommonName) {
    $commonNameMatch = [regex]::Match($subject, '(?:^|,\s*)CN=(?:"([^"]+)"|([^,]+))')
    $commonName = if ($commonNameMatch.Groups[1].Success) { $commonNameMatch.Groups[1].Value } else { $commonNameMatch.Groups[2].Value }
    $commonName = $commonName.Trim().Trim('"')
    if (!$commonName -or $commonName -cne $ExpectedCommonName) {
      return [pscustomobject]@{
        IsValid = $false
        Signer = $subject
        Message = "The trusted signer common name '$commonName' does not exactly match approved common name '$ExpectedCommonName'."
      }
    }
  }
  if ($ExpectedOrganization) {
    # Consume complete DN fields so an O= substring inside a quoted OU/CN
    # cannot masquerade as the certificate's organization. Fail closed on
    # malformed or duplicate organization fields.
    $fieldPattern = [regex]'\G\s*(?<name>[A-Za-z][A-Za-z0-9.]*)\s*=\s*(?:"(?<quoted>(?:[^"]|"")*)"|(?<plain>[^,"]*))(?:,\s*|$)'
    $offset = 0; $organizations = @(); $validSubject = $true
    while ($offset -lt $subject.Length) {
      $field = $fieldPattern.Match($subject, $offset)
      if (!$field.Success -or $field.Length -eq 0) { $validSubject = $false; break }
      if ($field.Groups['name'].Value -ieq 'O') {
        $value = if ($field.Groups['quoted'].Success) { $field.Groups['quoted'].Value.Replace('""', '"') } else { $field.Groups['plain'].Value.Trim() }
        $organizations += $value
      }
      $offset += $field.Length
    }
    if (!$validSubject -or $organizations.Count -ne 1 -or $organizations[0] -cne $ExpectedOrganization) {
      return [pscustomobject]@{ IsValid = $false; Signer = $subject; Message = "The trusted signer organization does not exactly match '$ExpectedOrganization'." }
    }
  }
  if ($subject -notmatch [regex]::Escape($ExpectedPublisher)) {
    return [pscustomobject]@{
      IsValid = $false
      Signer = $subject
      Message = "The trusted signer '$subject' does not match expected publisher '$ExpectedPublisher'."
    }
  }
  [pscustomobject]@{ IsValid = $true; Signer = $subject; Message = "Valid Authenticode signature from $ExpectedPublisher." }
}

Export-ModuleMember -Function ConvertTo-QuickSetupProvenanceUri, Assert-QuickSetupSafePath, Invoke-QuickSetupOfficialRequest, Get-QuickSetupOfficialMetadata, Test-QuickSetupAllowedHost, Get-QuickSetupOfficialDownload, Test-QuickSetupMsixPackage, Test-QuickSetupInstallerFile, Test-QuickSetupAuthenticodePublisher
