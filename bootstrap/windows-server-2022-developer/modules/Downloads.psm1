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
    [string]$ExpectedSha512
  )

  if ($Uri.Scheme -ne "https" -or !(Test-QuickSetupAllowedHost -HostName $Uri.DnsSafeHost -AllowedHosts $AllowedHosts)) {
    throw "The download URL is not an allowed official HTTPS source."
  }
  [Net.ServicePointManager]::SecurityProtocol = [Net.SecurityProtocolType]::Tls12
  $lastError = $null
  for ($attempt = 1; $attempt -le 3; $attempt++) {
    try {
      $response = Invoke-WebRequest -Uri $Uri.AbsoluteUri -UseBasicParsing -TimeoutSec 90 -MaximumRedirection 10 -OutFile $Destination -PassThru -ErrorAction Stop
      $finalUri = $response.BaseResponse.ResponseUri
      if (!$finalUri -or $finalUri.Scheme -ne "https" -or !(Test-QuickSetupAllowedHost -HostName $finalUri.DnsSafeHost -AllowedHosts $AllowedHosts)) {
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
      return $Destination
    } catch {
      $lastError = $_
      Remove-Item -LiteralPath $Destination -Force -ErrorAction SilentlyContinue
      if ($attempt -lt 3) { Start-Sleep -Seconds (2 * $attempt) }
    }
  }
  throw "The official download failed after three attempts: $($lastError.Exception.Message)"
}

function Test-QuickSetupAuthenticodePublisher {
  param(
    [Parameter(Mandatory = $true)][string]$Path,
    [Parameter(Mandatory = $true)][string]$ExpectedPublisher
  )

  $signature = Get-AuthenticodeSignature -LiteralPath $Path
  if ($signature.Status -ne [System.Management.Automation.SignatureStatus]::Valid -or !$signature.SignerCertificate) {
    return [pscustomobject]@{
      IsValid = $false
      Signer = if ($signature.SignerCertificate) { $signature.SignerCertificate.Subject } else { $null }
      Message = "The Authenticode signature is missing, invalid, or not trusted by Windows."
    }
  }
  $subject = [string]$signature.SignerCertificate.Subject
  if ($subject -notmatch [regex]::Escape($ExpectedPublisher)) {
    return [pscustomobject]@{
      IsValid = $false
      Signer = $subject
      Message = "The trusted signer '$subject' does not match expected publisher '$ExpectedPublisher'."
    }
  }
  [pscustomobject]@{ IsValid = $true; Signer = $subject; Message = "Valid Authenticode signature from $ExpectedPublisher." }
}

Export-ModuleMember -Function Get-QuickSetupOfficialDownload, Test-QuickSetupAuthenticodePublisher
