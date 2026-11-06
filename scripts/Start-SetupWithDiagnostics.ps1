[CmdletBinding()]
param([string]$SetupPath = (Join-Path $PSScriptRoot "configureMe-Setup.exe"))

# Optional Windows PowerShell 5.1 launcher: this code runs before the .NET 10
# apphost/CoreCLR starts. It does not change updates, CET, policy or elevation.
function Get-SetupStartupFailureMessage {
  param([int]$ExitCode)
  $hexCode = ([long]$ExitCode -band 0xffffffffL).ToString("X8")
  if ($hexCode -eq "80131506") {
    return "configureMe konnte die .NET-10-Laufzeit nicht starten (0x80131506). Auf Windows Server 2022 wurde dieser Fehler mit einer CET-Inkompatibilitaet beobachtet. Installieren Sie alle verfuegbaren Windows-Updates, starten Sie die VM vollstaendig neu und pruefen Sie ausstehende Neustarts sowie Hyper-V-Host-/CPU-Kompatibilitaet. Deaktivieren Sie CET oder andere Exploit-Schutzfunktionen nicht. Der Code allein beweist keine CET-Ursache; pruefen Sie auch die Anwendungsereignisse (coreclr.dll/.NET Runtime). Eine globale .NET-Installation ist nicht erforderlich."
  }
  return "configureMe wurde mit Fehler 0x$hexCode beendet. Pruefen Sie Windows-Ereignisanzeige > Windows-Protokolle > Anwendung und den Paketbericht. Fuer Startfehler: Server 2022 vollstaendig aktualisieren und neu starten."
}

function Start-SetupWithDiagnostics {
  param([string]$Path)
  $ErrorActionPreference = "Stop"
  if (!(Test-Path -LiteralPath $Path -PathType Leaf)) { throw "Setup EXE fehlt: $Path" }
  $resolved = (Resolve-Path -LiteralPath $Path).Path
  if ([IO.Path]::GetFileName($resolved) -cne "configureMe-Setup.exe") { throw "Expected configureMe-Setup.exe." }
  $os = Get-CimInstance Win32_OperatingSystem
  if ($os.Caption -notmatch "Windows Server 2022" -or [int]$os.BuildNumber -ne 20348 -or ![Environment]::Is64BitOperatingSystem) {
    throw "Windows Server 2022 x64 Desktop Experience ist erforderlich."
  }
  foreach ($key in @("HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\Component Based Servicing\RebootPending", "HKLM:\SOFTWARE\Microsoft\Windows\CurrentVersion\WindowsUpdate\Auto Update\RebootRequired")) {
    if (Test-Path -LiteralPath $key) { Write-Warning "Windows meldet einen ausstehenden Neustart. Vor dem Setup neu starten." }
  }
  Write-Host "Voraussetzung: alle verfuegbaren Windows-Server-2022-Updates installieren und neu starten. CET bleibt aktiviert."
  $process = Start-Process -FilePath $resolved -WorkingDirectory (Split-Path -Parent $resolved) -Wait -PassThru
  if ($process.ExitCode -ne 0) {
    $message = Get-SetupStartupFailureMessage -ExitCode $process.ExitCode
    Write-Warning $message
    Add-Type -AssemblyName System.Windows.Forms
    [void][System.Windows.Forms.MessageBox]::Show($message, "configureMe Startdiagnose", "OK", "Error")
  }
  return [int]$process.ExitCode
}

if ($MyInvocation.InvocationName -ne '.') {
  exit (Start-SetupWithDiagnostics -Path $SetupPath)
}
