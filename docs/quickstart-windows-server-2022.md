# Kurzanleitung: Windows Server 2022 Developer Quick Setup

## Paket beziehen und Herkunft prüfen

Das Release-Artefakt wird unter [GitHub Releases](https://github.com/muk4li/configureMe/releases) veröffentlicht. **Dieses Feature-PR veröffentlicht noch kein Release.** Solange dort kein geprüftes Quick-Setup-ZIP liegt, kannst du es aus einem lokal geprüften Checkout erzeugen:

```powershell
.\scripts\New-WindowsServer2022QuickSetup.ps1
```

Das ZIP liegt danach unter `dist\configureMe-WindowsServer2022-Developer-QuickSetup.zip`; daneben wird eine `.sha256`-Datei erzeugt. Zum Prüfen:

```powershell
Get-FileHash .\dist\configureMe-WindowsServer2022-Developer-QuickSetup.zip -Algorithm SHA256
Get-Content .\dist\configureMe-WindowsServer2022-Developer-QuickSetup.zip.sha256
```

Prüfe vor der Ausführung den GitHub-Release/Tag, den zugehörigen Quellcode und die Prüfsumme über einen getrennt vertrauenswürdigen Kanal. **Das ZIP und die Prüfsumme sind nicht signiert.** Eine zusammen mit dem ZIP heruntergeladene Prüfsumme beweist weder Herausgeber noch Herkunft. configureMe hat derzeit keinen unabhängigen Signaturschlüssel; das Paket ist daher nicht für öffentliches Vertrauens-Onboarding freigegeben.

## Entpacken, prüfen und starten

Entpacke das ZIP in einen beschreibbaren Ordner. Öffne Windows PowerShell 5.1 in `configureMe-QuickSetup` und prüfe zuerst:

```powershell
.\bootstrap.ps1 -Profile windows-server-2022-developer -List
.\bootstrap.ps1 -Profile windows-server-2022-developer -DryRun -ReportPath .\setup-report.json
.\bootstrap.ps1 -Profile windows-server-2022-developer -DryRun -SkipOptional
```

Prüfe die Paketliste sowie `setup-report.json` und `setup-report.txt`. Für den Installationslauf:

```powershell
.\bootstrap.ps1 -Profile windows-server-2022-developer -ReportPath .\setup-report.json
```

Der Bootstrap verlangt vor Installationen die ausdrückliche Eingabe `YES`. Er unterstützt ausschließlich Windows Server 2022 x64 mit Desktop Experience, aktualisiert erkannte vorhandene Installationen nicht und fordert keinen Neustart an. Bei `RemoteSigned` können Dateien aus einem ZIP noch als Internetdateien markiert sein. Erst nach unabhängiger Herkunftsprüfung und eigener Quellcodeprüfung lässt sich der Mark-of-the-Web gezielt für die geprüften lokalen PowerShell-Dateien entfernen:

```powershell
Get-ChildItem . -Recurse -File -Include *.ps1,*.psm1 | Unblock-File
```

`Unblock-File` ändert die Execution Policy nicht. Bei `AllSigned` oder einer restriktiven Organisationsrichtlinie die Richtlinie nicht umgehen; das derzeit unsignierte Paket benötigt dann eine freigegebene, signierte Veröffentlichung.

`-SkipOptional` markiert nicht vorhandene Copilot-/Teams-/Docker-Sonderfälle und Copilot CLI als `Skipped by user`; vorhandene Installationen werden trotzdem erkannt und nicht geändert.

Das Setup benötigt **kein WinGet** und keinen laufenden configureMe-Webserver. WinGet wird weder installiert noch vorausgesetzt. Nur erforderliche Metadaten und Installer werden zur Laufzeit direkt von festgelegten offiziellen HTTPS-Quellen bezogen.

## Ergebnis, Versionen und manuelle Schritte

Der JSON-Report enthält OS/Architektur, Bootstrap-Version, angeforderte Versionsregel, tatsächlich erkannte Version, Quelle, Methode, Status, Fehlercode, manuelle Schritte und Neustart-Hinweis. Die menschenlesbare Textfassung liegt neben der JSON-Datei. Es werden keine Authentifizierungstokens oder Umgebungsvariablen protokolliert.

| Paket | Verhalten dieses MVP |
|---|---|
| GitHub CLI | Offizielle x64-MSI aus dem GitHub-CLI-Releasefeed; gültige GitHub-Authenticode-Signatur erforderlich |
| VS Code | Offizielles stabiles Benutzer-Setup; Signaturprüfung; Dark-Theme-Einstellung nur im Profil des aktuellen Benutzers, vorherige Datei wird gesichert |
| Node.js | Neueste stabile Active-LTS-Version aus dem offiziellen Node-Index; SHA-256 aus `SHASUMS256.txt` plus Authenticode |
| .NET 10 SDK | Aktueller SDK-Eintrag aus Microsofts .NET-10-Releasefeed; .NET 10 SDK, nicht nur Runtime |
| PowerShell 7 | Offizielle stabile x64-MSI aus dem PowerShell-Releasefeed; Authenticode; parallel zu Windows PowerShell 5.1 |
| 7-Zip | x64-Installer-Link von der offiziellen Projektseite; gültige Herausgebersignatur; `/S` ist in der Hersteller-FAQ dokumentiert |
| Firefox | Offizieller stabiler x64-Enterprise-MSI-Kanal; gültige Mozilla-Signatur; bestehende Profile bleiben unberührt |
| OpenSSH Client | Vorhandene Windows Capability erkennen; fehlend nur nach Bestätigung und in erhöhter Sitzung über `Add-WindowsCapability` ergänzen |
| Git | Manuelle Installation über [Git for Windows](https://git-scm.com/download/win); kein unbelegter Silent-Schalter |
| Python | Manuelle Auswahl über [python.org](https://www.python.org/downloads/windows/); der Python Install Manager/MSIX-Weg wird nicht ungeprüft auf Server 2022 angewendet |
| Copilot Desktop | Vorhandene Installation erkennen; andernfalls manuelle Prüfung der [offiziellen Releases](https://github.com/github/app/releases), des Pakets, der Signatur und der Server-Unterstützung |
| Teams | Kein klassischer Teams-Client; Web-Fallback unter [teams.microsoft.com/v2](https://teams.microsoft.com/v2) |
| Docker Desktop | Nur lesende Versions-/Kontext-/Engine-Diagnose, wenn vorhanden; sonst `Not supported`. Docker Desktop ist auf Windows Server 2022 nicht offiziell unterstützt und wird nicht installiert oder geändert |
| Copilot CLI | Optionaler manueller Installationsweg nach [offizieller Anleitung](https://docs.github.com/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli); Node.js 22+ bzw. PowerShell 6+ und berechtigtes Abo erforderlich |

Die bestehenden Katalog-IDs `powershell` und `7zip` bleiben für v1-Profile erhalten; das neue Serverprofil verwendet zusätzlich die stabilen Namen `powershell-7` und `seven-zip`. Copilot Desktop und CLI haben eigene IDs (`github-copilot-desktop`, `github-copilot-cli`) und sind nicht mit der vorhandenen VS-Code-Copilot-Erweiterung `github-copilot` gleichzusetzen. Es gibt keine Änderung am Repository `myConfigs-data`.

Alle automatischen Installer werden nach HTTPS-Download auf gültige Authenticode-Signatur und erwarteten Herausgeber geprüft; verfügbare offizielle Hash-Metadaten werden zusätzlich ausgewertet. Bei nicht vertrauenswürdiger Signatur oder Quelle wird die Ausführung verweigert und ein manueller Schritt berichtet. Die Auswahl ist auf aktuelle Herstellerfeeds begrenzt; der Report hält die tatsächlich ermittelte Version fest.

Firefox-Lesezeichen sind in `assets\firefox-bookmarks.html` enthalten und können über den Firefox-Lesezeichen-Manager importiert werden. Firefox-Themes und optionale VS-Code-Erweiterungen werden nicht automatisch verändert; verwende dafür die offiziellen Firefox-/VS-Code-Oberflächen und Erweiterungs-IDs. VS Code setzt das Dark Modern Theme nur, wenn vorhandene `settings.json` gültiges JSON (ohne JSONC-Kommentare) ist; andernfalls bleibt sie unverändert und der Report fordert die manuelle Einstellung.

Für eine manuelle VS-Code-Erweiterungsauswahl sind die Marketplace-IDs: Python `ms-python.python`, C# Dev Kit `ms-dotnettools.csdevkit`, Docker `ms-azuretools.vscode-docker`, GitHub Copilot `GitHub.copilot` und GitHub Pull Requests and Issues `GitHub.vscode-pull-request-github`. Die Installation erfolgt ausschließlich in VS Code über den offiziellen Marketplace. Falls Git noch keine Identität hat, setze `git config --global user.name` und `git config --global user.email` selbst; der Bootstrap trägt keine Beispielwerte ein.

## Anmeldung

- **GitHub:** nach der Installation in einer neuen PowerShell-Sitzung `gh auth login` interaktiv starten. Keine Tokens in Profil, ZIP, Report oder Logs eintragen.
- **Microsoft/Teams:** im Browser auf `https://teams.microsoft.com/v2` anmelden.
- **Copilot Desktop oder CLI:** separat starten und den offiziellen interaktiven GitHub-Anmeldeablauf verwenden.

Der Bootstrap wurde mit Windows PowerShell 5.1 auf einem Windows Server 2022 Host syntaktisch und per Dry-Run geprüft. Es wurde keine echte Softwareinstallation ausgeführt. Ein frischer Windows Server 2022 End-to-End-Installationslauf und die praktische Herstellerunterstützung jeder Anwendung sind damit nicht bestätigt.

## Release-Erstellung

In einem geprüften Checkout `.\scripts\New-WindowsServer2022QuickSetup.ps1` ausführen. Für einen absichtlichen Neuaufbau derselben Datei `-Force` übergeben. Die ZIP-Datei enthält reproduzierbar sortierte Pfade und normalisierte Zeitstempel. Ein Reviewer sollte das ZIP-Inventar, den Dry-Run, die JSON-/Textreports und den SHA-256-Wert prüfen und erst danach das ZIP zusammen mit Quell-Tag/Commit als GitHub-Release-Artefakt bereitstellen. Vor einer öffentlichen Vertrauensfreigabe sind unabhängige Release-Signaturen und ein außerhalb des Downloads verteilter Trust Anchor notwendig.
