# Windows-Bootstrap

configureMe enthält zwei Windows-Installationspfade:

- Die bestehenden Windows-Profile verwenden weiterhin die festen WinGet-IDs aus dem Katalog.
- Das Profil `windows-server-2022-developer` erzeugt ein eigenständiges ZIP unter `bootstrap\windows-server-2022-developer`. Dieses ZIP läuft lokal mit Windows PowerShell 5.1 und benötigt weder WinGet noch den configureMe-Webserver. Das vollständige Zielsystem ist Windows Server 2022 x64 mit Desktop Experience.

Für den Quick Setup Ablauf, Status je Paket, Report-Formate, Quellen und Release-Hinweise siehe [Kurzanleitung Windows Server 2022](quickstart-windows-server-2022.md). Das ZIP kann reproduzierbar mit `scripts\New-WindowsServer2022QuickSetup.ps1` gebaut werden.

Automatische Herstellerinstallationen erfolgen erst nach einer sichtbaren Planübersicht und der Eingabe `YES`. Bereits installierte Programme werden nicht aktualisiert. Der Bootstrap prüft Downloads per HTTPS/TLS, erwartete Redirect-Hosts, Authenticode-Herausgeber und verfügbare offizielle Hash-Metadaten. Für Git und Python bleiben sichere manuelle Wege; OpenSSH erfordert Administratorrechte. Docker Desktop wird auf Server nicht installiert und nur lesend geprüft. Teams erhält einen Web-Fallback.

Das ZIP ist aktuell nicht signiert. Ein SHA-256-Beileger ist kein Herkunftsnachweis. Weder Release-Signierung noch ein frischer Windows Server 2022 End-to-End-Installationslauf sind durch dieses MVP zugesichert. Es wurden keine Softwareinstallationen auf dem Entwicklungsserver ausgeführt.
