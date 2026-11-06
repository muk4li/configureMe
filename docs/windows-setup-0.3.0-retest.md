# Windows Server 2022: GUI-Nachtest für Setup 0.3.0

Verwende das Windows-x64-ZIP aus dem CI-Lauf des Korrektur-Commits. Entpacke es in ein neues Verzeichnis und prüfe `version.json`, `manifest.json`, `SHA256SUMS.txt` und die ZIP-Prüfsumme gegen die enthaltenen Dateien. Der Commit muss dem geprüften Pull Request entsprechen; das Entwicklungsartefakt ist unsigniert.

1. Starte `configureMe-Setup.exe` unter dem vorgesehenen normalen Benutzerkonto. Die Liste muss sofort Kategorien und alle unterstützten Pakete mit Checkbox, Name, Beschreibung, Status und Aktion zeigen. Prüfe die komplette Liste per vertikalem Scrollen, auch den letzten Eintrag. Falls die Systemprüfung scheitert, muss die Liste sichtbar bleiben und betroffene Zeilen als Erkennungsfehler erscheinen.
2. Prüfe das Fenster bei 100 %, 150 % und 200 % Windows-Skalierung sowie bei breitem und kleinstem erlaubtem Fenster. Kategorien und Zeilen dürfen nicht überlappen oder abgeschnitten sein. Lange Beschreibungen sollen enden, ohne Aktionsbuttons zu verdecken. Der CI-Layouttest prüft nur WinForms-Grenzen; diese Sichtprüfung ist weiterhin nötig.
3. Vergleiche vorhandene Versionen mit der Anzeige. Beispiele aus dem ersten Test sind Git `2.56.0.windows.4`, Copilot Desktop `1.1.34`, Firefox `159.0`, Docker Desktop `4.97.0`, VS Code `1.144.0`, Node.js `26.13.0` und LibreOffice `26.8.2.2`. Das sind Testbeispiele, keine geforderten Zielversionen. Klicke **System prüfen** erneut; die Zeilen müssen sich aktualisieren.
4. Klicke **Nur fehlende**. Vorhandene, nur manuelle und nicht unterstützte Pakete dürfen nicht markiert werden. **Developer-Profil** soll dessen Pakete einschließlich Abhängigkeiten markieren. Fehlende Administratorrechte müssen vor dem Start für betroffene Pakete angezeigt werden. Docker Desktop bleibt reine Erkennung, Teams ein Web-Fallback und Copilot CLI manuell.
5. Starte einen **Dry-Run** und exportiere den Bericht. Prüfe, dass kein Installer startet und vorhandene Einstellungen/Programme unverändert bleiben. Beim Installationsplan wähle einmal **Nein**; auch dann darf nichts installiert werden.
6. Für einen echten Installationsversuch verwende eine fehlende Anwendung und sichere zuvor den Serverzustand. Bei Python müssen Fortschrittsereignisse und ein Abschlussbericht erscheinen; der bisherige Fehler `Write-QuickSetupGuiPackageEvent wurde nicht ... erkannt` darf nicht auftreten. Teste .NET 10 SDK und 7-Zip nur mit passenden Rechten und nach ausdrücklicher Bestätigung. Notiere bei Fehlern Paketname, Phase, Fehlercode, Worker-Code und die strukturierte Meldung aus GUI und JSON-Bericht. Die Fehler dürfen keinen nachfolgenden Bericht überschreiben.
7. Prüfe, dass bereits installierte Anwendungen nicht erneut installiert werden, kein automatischer Neustart erfolgt und keine Selbst-Elevation oder Änderung an Defender/ExecutionPolicy stattfindet.

Der Test benötigt den echten Windows-Server-Desktop. Linux-Crossbuilds und der CI-Test für Layout-Grenzen ersetzen diesen Sicht- und Installationsnachweis nicht.

## Abnahme der Installer-Korrekturen (noch auf echter VM auszuführen)

Bisher ist nach Updates nur der **nicht gebündelte**, selbstständige Build auf der Test-VM gestartet. Der Produktions-Single-File-Build und die folgenden Installationen sind damit ausdrücklich **nicht** abgenommen.

### Ursachen und Prüfumfang

- **VS Code:** Der offizielle x64-User-Inno-Installer kann einen x86-PE-Startteil besitzen. Die Auswahl kommt jetzt aus `https://update.code.visualstudio.com/api/update/win32-x64-user/stable/latest`, einschließlich stabiler Version und zwingendem SHA-256. Nur dieses paketgebundene x64-Setup mit gültiger Microsoft-Signatur darf den x86-Startteil verwenden. Die installierte `Code.exe` muss x64 sein; `bin\code.cmd --version` muss Version und `x64` melden.
- **.NET SDK:** Die `win-x64`-SDK-Auswahl ist vom PE-Startteil des Burn-Bundles zu unterscheiden. Der .NET-10-Feed muss den SHA-512 enthalten; die Microsoft-Signatur bleibt Pflicht. Installation mit `/install /quiet /norestart`; `3010` und `1641` werden als Neustartbedingungen geführt, andere Fehlercodes bleiben Fehler. Ein Nullcode genügt nicht: die tatsächliche x64-`%ProgramFiles%\dotnet\dotnet.exe --list-sdks` muss ein stabiles SDK `10.x` ausgeben. Ein Runtime-only-Paket reicht nicht. Die Erkennung benutzt den absoluten Pfad, unabhängig von einem alten Prozess-PATH.
- **7-Zip:** Das offizielle `7z2501-x64.exe` hat einen x86-Startteil und keine PE-Signaturtabelle. Statt einer allgemeinen Ausnahme wird die offizielle **x64-MSI 25.01** verwendet: `https://github.com/ip7z/7zip/releases/download/25.01/7z2501-x64.msi`, SHA-256 `e7eb0b7ed5efa4e087b7b17f191797f7af5b7f442d1290c66f3a21777005ef57`. Der Hash wurde am offiziellen Download geprüft und mit dem [Microsoft-WinGet-Manifest 25.01](https://github.com/microsoft/winget-pkgs/blob/master/manifests/7/7zip/7zip/25.01/7zip.7zip.installer.yaml) abgeglichen. Kein WinGet wird ausgeführt. Nur diese exakten Bytes dürfen `NotSigned` ohne Zertifikat melden; `HashMismatch`, `NotTrusted` und sonstige Signaturfehler bleiben gesperrt. MSI-Plattform und installierte `7z.exe` müssen x64 sein. Der Pin wird bewusst nicht automatisch aktualisiert; neue Versionen benötigen eine erneute Prüfung von URL, Hash und Signaturstatus.
- **Python:** `0x80073CF0`/`0x80040154` zeigt einen Fehler beim Öffnen/Bereitstellen des MSIX, nicht einen bewiesenen Fehler des Python-Runtimes. Server 2022 unterstützt MSIX grundsätzlich; AppXSVC-/Registrierungs-/Imagezustand, AppX-Ereignisse, Paketformat und Abhängigkeiten müssten mit der ursprünglichen VM/Activity-ID untersucht werden. Der Serverprofil-Pfad vermeidet diese Voraussetzung vollständig: neuester stabiler klassischer **CPython-3.14-amd64-Vollinstaller** von python.org mit gültiger PSF-Signatur, `/quiet /norestart InstallAllUsers=0 PrependPath=1 Include_pip=1 Include_test=0 Include_launcher=0`. Kein Store-/MSIX-Installer, kein `pymanager`, kein Alias wird gestartet. Die [offizielle Python-Dokumentation](https://docs.python.org/3.14/using/windows.html#installing-without-ui) beschreibt diese Option. Erkennung über PEP 514 prüft einen echten x64-Interpreter, unterstützte stabile Python-Version (3.11+) und erfolgreiches `-m pip --version`; vorhandene geprüfte Installationen werden nicht erneut installiert. Der optionale `py`-Launcher ist keine Erfolgsvoraussetzung.

### Produktionsbuild

Auf dem Entwicklungsrechner .NET 10 SDK installieren; auf der Ziel-VM ist dies nicht erforderlich. Vom Repository-Root:

```powershell
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests\installer-regressions.ps1
powershell.exe -NoProfile -NonInteractive -ExecutionPolicy Bypass -File tests\quicksetup-smoke.ps1
dotnet test windows\ConfigureMe.Setup.Tests\ConfigureMe.Setup.Tests.csproj --configuration Release
dotnet publish windows\ConfigureMe.Setup\ConfigureMe.Setup.csproj --configuration Release -p:PublishProfile=win-x64 --output .\dist\configureMe-Setup
powershell.exe -NoProfile -NonInteractive -File scripts\New-SetupReleasePackage.ps1 -PublishDirectory .\dist\configureMe-Setup -OutputPath .\dist\configureMe-Setup-win-x64.zip
```

Das Publishprofil enthält weiterhin `SelfContained=true`, `PublishSingleFile=true`, `win-x64`, native Extraktion und kein Trimming. Der Manifest-Buildprozess setzt `-ExecutionPolicy Bypass` nur in seinem eigenen PowerShell-Unterprozess und quotiert alle Pfade; der frühere Property-Workaround mit eingebetteten Argumenten entfällt. Gruppenrichtlinien können weiterhin Vorrang haben; keine globale Policy ändern.

### Saubere Windows-Server-2022-VM

1. VM-Snapshot anlegen; Datacenter Evaluation x64 Desktop Experience vollständig aktualisieren und neu starten. OS-Build samt UBR, installierte Updates und Hyper-V-Konfiguration protokollieren. **Kein .NET SDK/Runtime vorinstallieren.** CET/Exploit-Schutz aktiviert lassen. Keine angeblich ausreichende KB voraussetzen: eine Mindest-KB ist noch nicht verifiziert.
2. Nur das ZIP des überprüften Builds übertragen, Herkunft/Commit und alle Paket-/Archivhashes prüfen. **Genau die Single-File-EXE** direkt starten. Erfolg nicht aus einem `publish-debug`-Lauf ableiten. Bei frühem Absturz optional `powershell.exe -NoProfile -File .\Start-SetupWithDiagnostics.ps1` starten und Application-/`.NET Runtime`-/`coreclr.dll`-Ereignisse sichern. Der Wrapper kann vor .NET 10 starten und `0x80131506` erklären; er kann CET-Unterstützung nicht zuverlässig vorhersagen. `Main` wird bei diesem Crash nicht erreicht.
3. `configureMe-Setup.exe --self-test` und `--layout-self-test` ausführen; Exitcode jeweils 0 verlangen. Mit vorhandenem Windows PowerShell keine externe Engine und keinen globalen .NET-Pfad hinzufügen. Diese Tests installieren nichts.
4. Bei **100, 125, 150 und 200 %** echter Windows-Skalierung ab-/anmelden bzw. neu starten; zusätzlich Fenster zwischen Monitoren mit unterschiedlicher Skalierung bewegen. 1024×768, 1280×720 und 1920×1080 sowie das kleinste erlaubte Fenster prüfen. Alle Aktionsbuttons vollständig lesbar, keine Überschneidung; gegebenenfalls scrollen. Paketliste, Checkboxen, Status, Fortschritt, Abbrechen und Log müssen bedienbar bleiben. Simulierte `Control.Scale`-Tests ersetzen das nicht.
5. Dry-Run und abgelehnte Bestätigung dürfen keine Installer starten. Dann nur die vier betroffenen Pakete mit erforderlichen Rechten unter **demselben Benutzerkonto** bestätigen. Fortschritts-/Phasenmeldungen und JSON-/Textbericht vergleichen. Ein einzelner Fehler muss nachfolgende Pakete und den Bericht weiterhin zulassen. Neustartbedingungen im Bericht erhalten; keinen automatischen Neustart anfordern.
6. Vor einem neuen Terminal bereits die Worker-Erkennung kontrollieren. Danach in einem neuen Terminal manuell prüfen:

   ```powershell
   & "$env:LOCALAPPDATA\Programs\Microsoft VS Code\bin\code.cmd" --version
   & "$env:ProgramFiles\dotnet\dotnet.exe" --list-sdks
   & "$env:ProgramFiles\7-Zip\7z.exe"
   # Tatsächlichen Python-Pfad aus PEP-514-Registrierung ermitteln:
   Get-ChildItem HKCU:\Software\Python\PythonCore | ForEach-Object {
     Get-ItemProperty (Join-Path $_.PSPath InstallPath)
   }
   # <PythonPath> durch den dortigen ExecutablePath ersetzen:
   & '<PythonPath>' -I -c "import platform,struct; print(platform.python_version(), struct.calcsize('P') * 8)"
   & '<PythonPath>' -I -m pip --version
   ```

   VS Code muss `x64` ausgeben; .NET ein **SDK 10.x**, 7-Zip `25.01 (x64)`, Python eine stabile unterstützte Version und `64`, pip Exitcode 0. Zusätzlich liest die Engine die installierten PE-Header ohne Bootstrap-Ausnahme. Ergebnisse, Versionen und Exitcodes protokollieren.
7. GUI neu starten, erneut **System prüfen** und dieselbe Auswahl ausführen: erfolgreich installierte Programme müssen **Bereits installiert** melden; keine erneuten Downloads/Installationen. Bestehende Git-/Node-/Firefox-/Copilot-/LibreOffice-Abläufe stichprobenartig prüfen. Eine x86-Installation darf nicht als geprüfte x64-Installation gelten.
8. Für Sicherheits-Negativtests nur isolierte Fixtures/Mock-Tests verwenden: manipulierte Hashes, falsche Architektur, falscher Publisher und ungültige Signaturen müssen vor Prozessstart scheitern. Keine echten manipulierten Installer ausführen.

Die CI führt Regressionstests sowohl unter Windows PowerShell 5.1 als auch PowerShell 7 aus und veröffentlicht unter geerbter restriktiver Prozesspolicy in einen Pfad mit Leerzeichen. Sie startet das gebündelte Artefakt mit aus PATH/DOTNET_ROOT entfernten globalen .NET-Pfaden. Das bleibt eine CI-Prüfung mit vorhandenen Runner-Komponenten und ersetzt keine saubere VM ohne .NET.

## Folgekorrektur: .NET-Signer und vorhandenes VS Code

Ein realer Serverlauf meldete den vertrauenswürdigen .NET-Signer `.NET` statt des bisher erwarteten CN `Microsoft Corporation`. Der offizielle SDK-10.0.403-Download wurde erneut gegen Microsofts SHA-512 geprüft; dessen Signerzertifikat hat `CN=.NET, O=Microsoft Corporation`. Die Paketdefinition verlangt jetzt diese beiden exakten Felder und weiterhin eine gültige Windows-Authenticode-Prüfung. Falsche Organisationen, gleichnamige Publisher in anderen DN-Feldern und ungültige Signaturen bleiben gesperrt.

VS Code war trotz negativem Worker-Ergebnis tatsächlich unter LocalAppData installiert. Die CLI-basierte Nachprüfung wird deshalb nicht mehr als Installationsvoraussetzung verwendet: x64-PE, `Code.exe`-Produktname/-version und stabile `resources\app\package.json`-Version müssen zusammenpassen. Fehlende oder widersprüchliche Dateien bleiben Fehler. Die Nachprüfung versucht bis zu zehnmal im Zwei-Sekunden-Abstand zu lesen, ohne erneut zu installieren. Auf der VM zusätzlich erneut **System prüfen** ausführen: das bereits vorhandene VS Code muss erkannt und erhalten werden. Das .NET SDK erneut auswählen und nach Installation den absoluten x64-`dotnet.exe --list-sdks`-Aufruf prüfen.

Der zusätzliche Codex-Desktop-Helfer ist im EXE-ZIP enthalten; seine Store-Voraussetzungen und Exitcodes stehen in `windows/ConfigureMe.Setup/README.md`. Auf Server 2022 ohne Store ist `codex-store-unavailable`/Exit 2 ein expliziter externer Blocker, kein erfolgreicher Desktop-Installationsnachweis.
