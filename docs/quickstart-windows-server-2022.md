# Kurzanleitung: Windows Server 2022 Developer Quick Setup

## Paket beziehen und Herkunft prüfen

Es wird kein öffentliches oder stabiles GitHub Release automatisch veröffentlicht. Das geprüfte CI-ZIP findest du nach einem erfolgreichen Lauf in **Actions → Windows Quick Setup validation → Artifacts**. Das Artefakt enthält das ZIP und seine SHA-256-Datei und läuft nach sieben Tagen ab. Es ist unsigniert und kein vertrauenswürdiger öffentlicher Release.

Für einen lokalen Build aus einem geprüften Checkout:

```powershell
.\scripts\New-WindowsServer2022QuickSetup.ps1
```

Das ZIP liegt danach unter `dist\configureMe-WindowsServer2022-Developer-QuickSetup.zip`; daneben wird eine `.sha256`-Datei erzeugt. `configureMe-QuickSetup\manifest.json` im Archiv enthält Bootstrap-Version, Quell-Commit, Dirty-Tree-Kennzeichnung und SHA-256/Größe jeder Paketdatei. Prüfe den Commit und die einzelnen Hashes; ein lokaler Build aus einem geänderten Arbeitsverzeichnis ist mit `workingTreeDirty: true` markiert. Zum Prüfen:

```powershell
Get-FileHash .\dist\configureMe-WindowsServer2022-Developer-QuickSetup.zip -Algorithm SHA256
Get-Content .\dist\configureMe-WindowsServer2022-Developer-QuickSetup.zip.sha256
```

Prüfe vor der Ausführung den CI-Lauf beziehungsweise lokalen Quell-Commit, den Manifestinhalt und die Prüfsumme über einen getrennt vertrauenswürdigen Kanal. **Das ZIP und die Prüfsumme sind nicht signiert.** Eine zusammen mit dem ZIP heruntergeladene Prüfsumme beweist weder Herausgeber noch Herkunft. configureMe hat derzeit keinen unabhängigen Signaturschlüssel; das Paket ist daher nicht für öffentliches Vertrauens-Onboarding freigegeben.

## Entpacken, prüfen und starten

Entpacke das ZIP zum Beispiel nach `C:\configureMe-QuickSetup`. Öffne Windows PowerShell 5.1 unter demselben Benutzerkonto, das VS Code und Python verwenden soll:

```powershell
Expand-Archive .\configureMe-WindowsServer2022-Developer-QuickSetup.zip -DestinationPath C:\configureMe-QuickSetup
Set-Location C:\configureMe-QuickSetup\configureMe-QuickSetup
```

Prüfe zuerst:

```powershell
.\bootstrap.ps1 -Profile windows-server-2022-developer -List
.\bootstrap.ps1 -Profile windows-server-2022-developer -DryRun -ReportPath .\setup-report.json
.\bootstrap.ps1 -Profile windows-server-2022-developer -DryRun -SkipOptional
```

Prüfe die Paketliste sowie `setup-report.json` und `setup-report.txt`. Für den Installationslauf:

```powershell
.\bootstrap.ps1 -Profile windows-server-2022-developer -ReportPath .\setup-report.json
Get-Content .\setup-report.txt
```

Der erste Installationslauf zeigt den Plan und verlangt vor Änderungen die ausdrückliche Eingabe `YES`. Er unterstützt ausschließlich Windows Server 2022 x64 mit Desktop Experience, aktualisiert erkannte vorhandene Installationen nicht und fordert keinen Neustart an. Systemweite Pakete und OpenSSH erfordern Administratorrechte. Der Bootstrap eleviert sich nicht selbst; wenn nötig, starte PowerShell erhöht unter demselben Konto, niemals über `Run as different user`.

Für die Planerstellung kann die CLI bereits vor `YES` offizielle Versionsmetadaten abrufen. Installer werden erst nach der Bestätigung heruntergeladen und gestartet. Das Webportal-ZIP enthält den lokalen Katalog und alle benötigten Worker-Module; sein Manifest listet SHA-256 und Größe jeder Datei.

Bei `RemoteSigned` können Dateien aus einem ZIP noch als Internetdateien markiert sein. Erst nach unabhängiger Herkunftsprüfung und eigener Quellcodeprüfung lässt sich der Mark-of-the-Web gezielt für die geprüften lokalen PowerShell-Dateien entfernen:

```powershell
Get-ChildItem . -Recurse -File -Include *.ps1,*.psm1 | Unblock-File
```

`Unblock-File` ändert die Execution Policy nicht. Bei `AllSigned` oder einer restriktiven Organisationsrichtlinie die Richtlinie nicht umgehen; das derzeit unsignierte Paket benötigt dann eine freigegebene, signierte Veröffentlichung.

`-SkipOptional` überspringt LibreOffice, Teams, Docker Desktop und Copilot CLI. Copilot Desktop gehört jetzt zum Standardprofil und wird bei Bedarf nach Git installiert; vorhandene Installationen werden nicht geändert.

Das Setup benötigt **kein WinGet** und keinen laufenden configureMe-Webserver. WinGet wird weder installiert noch vorausgesetzt. Nur erforderliche Metadaten und Installer werden zur Laufzeit direkt von festgelegten offiziellen HTTPS-Quellen bezogen.

## Ergebnis, Versionen und manuelle Schritte

Der JSON-Report enthält OS/Architektur, Bootstrap-Version, angeforderte Versionsregel, tatsächlich erkannte Version, Quelle, Methode, Status, Fehlercode, manuelle Schritte und Neustart-Hinweis. Die menschenlesbare Textfassung liegt neben der JSON-Datei. Es werden keine Authentifizierungstokens oder Umgebungsvariablen protokolliert.

| Paket | Verhalten dieses MVP |
|---|---|
| Git | Neuester offizieller Git-for-Windows-x64-EXE-Release. Vor dem Start werden der offizielle Release-Digest (wenn veröffentlicht), PE-Architektur und gültige Authenticode-Signatur geprüft; der Signer-CN muss exakt `Johannes Schindelin` sein. Verwendet werden ausschließlich `/VERYSILENT /NORESTART /NOCANCEL /SP-`; vorhandene Installationen werden nicht aktualisiert, und es wird kein Neustart angefordert |
| GitHub CLI | Offizielle x64-MSI aus dem GitHub-CLI-Releasefeed; gültige GitHub-Authenticode-Signatur erforderlich; Start über `msiexec.exe` |
| VS Code | Offizielles stabiles Benutzer-Setup; Signaturprüfung; Dark-Theme-Einstellung nur im Profil des aktuellen Benutzers, vorherige Datei wird gesichert |
| Node.js | Neueste stabile Active-LTS-Version aus dem offiziellen Node-Index; x64-MSI mit SHA-256 aus `SHASUMS256.txt` plus Authenticode |
| Python | Offizieller x64-Python-Installationsmanager als MSIX; Paketidentität und Architektur werden geprüft, Windows validiert die Signatur bei `Add-AppxPackage`; `pymanager install default` installiert die neueste stabile Python-Version per-user, ohne andere Versionen/venvs zu ersetzen |
| .NET 10 SDK | Aktueller SDK-Eintrag aus Microsofts .NET-10-Releasefeed; .NET 10 SDK, nicht nur Runtime |
| PowerShell 7 | Offizielle stabile x64-MSI aus dem PowerShell-Releasefeed; Authenticode; parallel zu Windows PowerShell 5.1 |
| 7-Zip | x64-Installer-Link von der offiziellen Projektseite; gültige Herausgebersignatur; `/S` ist in der Hersteller-FAQ dokumentiert |
| Firefox | Offizieller stabiler x64-Enterprise-MSI-Kanal; gültige Mozilla-Signatur; bestehende Profile bleiben unberührt |
| OpenSSH Client | Vorhandene Windows Capability erkennen; fehlend nur nach Bestätigung und in erhöhter Sitzung über `Add-WindowsCapability` ergänzen |
| Copilot Desktop | Fehlende Installation automatisch nach Git einrichten: fest gepinntes offizielles v1.1.34-EXE, SHA-256 und exakter gültiger `GitHub, Inc.`-Signer. Der geprüfte Tauri-NSIS-Installer nutzt `/S` für den aktuellen Benutzer. Ein vorhandenes Copilot Desktop bleibt unberührt. Die Anmeldung erfolgt anschließend interaktiv. Der echte Installationslauf auf Windows Server 2022 steht noch aus |
| LibreOffice | Optionaler Katalogeintrag; nicht im Standardprofil ausgewählt. Nur nach Ergänzung der Paket-ID `libreoffice` in der lokalen Profil-JSON wird das offizielle stabile x64-MSI geladen und dessen veröffentlichter SHA-256 sowie Authenticode-Signer `The Document Foundation` geprüft |
| Teams | Kein klassischer Teams-Client; Web-Fallback unter [teams.microsoft.com/v2](https://teams.microsoft.com/v2) |
| Docker Desktop | Nur lesende Versions-/Kontext-/Engine-Diagnose, wenn vorhanden; sonst `Not supported`. Docker Desktop ist auf Windows Server 2022 nicht offiziell unterstützt und wird nicht installiert oder geändert |
| Copilot CLI | Optionaler manueller Installationsweg nach [offizieller Anleitung](https://docs.github.com/copilot/how-tos/copilot-cli/set-up-copilot-cli/install-copilot-cli); Node.js 22+ bzw. PowerShell 6+ und berechtigtes Abo erforderlich |

LibreOffice wird nicht standardmäßig ausgewählt. Um es optional zu installieren, ergänze `"libreoffice"` in `bootstrap\windows-server-2022-developer\config\windows-server-2022-developer.json` unter `packages`, prüfe den Plan erneut mit `-DryRun` und bestätige erst dann den Installationsplan. Copilot Desktop und CLI haben eigene IDs (`github-copilot-desktop`, `github-copilot-cli`) und sind nicht mit der vorhandenen VS-Code-Copilot-Erweiterung `github-copilot` gleichzusetzen. Es gibt keine Änderung am Repository `myConfigs-data`.

Copilot Desktop ist auf `v1.1.34` fest gepinnt. Der geprüfte offizielle Installer `GitHub-Copilot-windows-x64-setup.exe` hat SHA-256 `4a8070a63b228895344a6c4f4536a01a62085e02821829b21786638234580e00`. Er enthält einen Tauri-NSIS-Installer mit x86-Startprogramm und x64-Nutzlast. Die [Tauri-NSIS-Vorlage](https://github.com/tauri-apps/tauri/blob/dev/crates/tauri-bundler/src/bundle/windows/nsis/installer.nsi) dokumentiert den aktuellen Benutzer und den stillen Schalter `/S`; `/R` zum Starten der App wird nicht verwendet. Vor Ausführung prüft Windows die Authenticode-Vertrauenskette und den exakten Signer-CN `GitHub, Inc.`. Die tatsächliche Kompatibilität mit Windows Server 2022 muss auf dem Zielsystem geprüft werden.

Jede automatische Paketdefinition legt den Installer-Typ (`msi`, `exe`, `msix` oder `windows-capability`) und die Zielarchitektur explizit fest. MSI-Dateien werden als OLE/Windows-Installer-Datenbank sowie über Windows Installer auf x64 geprüft und mit `msiexec.exe` gestartet. EXE-Dateien müssen gültige PE-Dateien sein und werden direkt mit paketbezogenen Argumenten gestartet. Beim Python-MSIX werden Manifestidentität und x64-Architektur geprüft; `Add-AppxPackage` prüft die kryptografische MSIX-Signatur und Publisherbindung vor der Bereitstellung. Das offizielle `pymanager install default` installiert anschließend die stabile Python-Laufzeit per-user. HTTPS, erlaubte Redirect-Hosts, erwarteter Herausgeber und verfügbare offizielle Hash-Metadaten werden vor der Ausführung geprüft. Bei nicht vertrauenswürdiger Signatur, Publisher, Hash, Architektur oder Dateityp wird die Ausführung verweigert und ein manueller Schritt berichtet.

Firefox-Lesezeichen sind in `assets\firefox-bookmarks.html` enthalten und können über den Firefox-Lesezeichen-Manager importiert werden. Firefox-Themes und optionale VS-Code-Erweiterungen werden nicht automatisch verändert; verwende dafür die offiziellen Firefox-/VS-Code-Oberflächen und Erweiterungs-IDs. VS Code setzt das Dark Modern Theme nur, wenn vorhandene `settings.json` gültiges JSON (ohne JSONC-Kommentare) ist; andernfalls bleibt sie unverändert und der Report fordert die manuelle Einstellung.

Für eine manuelle VS-Code-Erweiterungsauswahl sind die Marketplace-IDs: Python `ms-python.python`, C# Dev Kit `ms-dotnettools.csdevkit`, Docker `ms-azuretools.vscode-docker`, GitHub Copilot `GitHub.copilot` und GitHub Pull Requests and Issues `GitHub.vscode-pull-request-github`. Die Installation erfolgt ausschließlich in VS Code über den offiziellen Marketplace. Falls Git noch keine Identität hat, setze `git config --global user.name` und `git config --global user.email` selbst; der Bootstrap trägt keine Beispielwerte ein.

## Anmeldung

- **GitHub:** nach der Installation in einer neuen PowerShell-Sitzung `gh auth login` interaktiv starten. Keine Tokens in Profil, ZIP, Report oder Logs eintragen.
- **Microsoft/Teams:** im Browser auf `https://teams.microsoft.com/v2` anmelden.
- **Copilot Desktop oder CLI:** separat starten und den offiziellen interaktiven GitHub-Anmeldeablauf verwenden.

Der Bootstrap wurde syntaktisch und mit Mock-Tests geprüft. Es wurden keine echten Installer ausgeführt. Das CI validiert auf `windows-2022` Mock-Tests, Dry-Runs und ZIP-Erstellung. Es fand kein frischer Windows Server 2022 End-to-End-Installationslauf statt; die praktische Herstellerunterstützung jeder Anwendung ist nicht bestätigt. Prüfe Copilot Desktop insbesondere auf dem echten Zielsystem.

## Release-Erstellung

Der Workflow `Windows Quick Setup validation` validiert die PowerShell-Module und das JSON-Profil, führt ausschließlich Mock-Tests aus, erstellt das ZIP zweimal zum Reproduzierbarkeitstest, prüft Manifest und ZIP-Inhalt, erzeugt SHA-256 und lädt ZIP plus Prüfsumme als kurzlebiges CI-Artefakt hoch. Es gibt keine automatische Veröffentlichung als GitHub Release. Vor einer öffentlichen Vertrauensfreigabe sind unabhängige Release-Signaturen und ein außerhalb des Downloads verteilter Trust Anchor notwendig.
