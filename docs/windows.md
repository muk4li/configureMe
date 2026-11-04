# Windows-Bootstrap

configureMe enthält zwei Windows-Installationspfade:

- Die bestehenden Windows-Profile verwenden weiterhin die festen WinGet-IDs aus dem Katalog.
- Das Profil `windows-server-2022-developer` erzeugt ein eigenständiges ZIP unter `bootstrap\windows-server-2022-developer`. Dieses ZIP läuft lokal mit Windows PowerShell 5.1 und benötigt weder WinGet noch den configureMe-Webserver. Das vollständige Zielsystem ist Windows Server 2022 x64 mit Desktop Experience.

Für den Quick Setup Ablauf, Status je Paket, Report-Formate, Quellen und Release-Hinweise siehe [Kurzanleitung Windows Server 2022](quickstart-windows-server-2022.md). Das ZIP kann reproduzierbar mit `scripts\New-WindowsServer2022QuickSetup.ps1` gebaut werden.

Automatische Herstellerinstallationen erfolgen erst nach einer sichtbaren Planübersicht und der Eingabe `YES`. Bereits installierte Programme werden nicht aktualisiert. Paketdefinitionen deklarieren MSI, EXE, MSIX, Windows Capability oder manuell explizit. MSI-/EXE-Dateityp und deklarierte Architektur, HTTPS/Redirect-Hosts, Authenticode-Herausgeber und verfügbare offizielle Hash-Metadaten werden vor der Ausführung geprüft. Beim Python-MSIX werden Manifestidentität und x64-Architektur geprüft; Windows validiert die Signatur bei `Add-AppxPackage`. MSI-Dateien laufen über `msiexec.exe`; systemweite Pakete und OpenSSH erfordern Administratorrechte, ohne automatische Elevation. Python wird über den offiziellen Installationsmanager und dessen dokumentierten Runtime-Befehl per-user eingerichtet. Git bleibt manuell, weil ein unterstützter Silent-Aufruf und eine dafür geprüfte Publisher-Identität in diesem Bootstrap nicht verifiziert wurden. Docker Desktop wird auf Server nicht installiert und nur lesend geprüft. Teams erhält einen Web-Fallback.

Das ZIP enthält ein Datei-Hash-Manifest mit Quell-Commit und Dirty-Tree-Status; ein SHA-256-Beileger ist kein Herkunftsnachweis. Der Workflow `Windows Quick Setup validation` legt ein CI-Artefakt mit sieben Tagen Aufbewahrung ab, publiziert aber kein GitHub Release. Weder Release-Signierung noch ein frischer Windows Server 2022 End-to-End-Installationslauf sind zugesichert. Tests führen keine Softwareinstallation aus.
