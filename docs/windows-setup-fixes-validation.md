# Implementierungs- und Validierungsbericht

Die Korrekturen sind im Arbeitsverzeichnis implementiert. Die saubere Windows-Server-2022-VM-Abnahme ist noch offen; es wurden keine echten Drittanbieter-Installationen ausgeführt. Ursachen, Sicherheitsrichtlinien, exakte Buildbefehle und manuelle Abnahme: [Windows-Nachtest](windows-setup-0.3.0-retest.md).

## Ausgeführte Prüfungen

- `pwsh -NoProfile -File tests/installer-regressions.ps1`: 72 Assertions bestanden, reine Fixtures/Mocks ohne Netzwerk oder Installation.
- `pwsh -NoProfile -File tests/quicksetup-portable.ps1`: bestanden.
- `dotnet test windows/ConfigureMe.Setup.Portable.Tests/ConfigureMe.Setup.Portable.Tests.csproj --configuration Release`: 24 bestanden, 0 fehlgeschlagen/übersprungen. Ein zwischenzeitlicher Fixture-Fehler wurde durch Anpassung an die gemeinsame Validierungsfunktion behoben; die Fehlercode-Assertion wurde beibehalten.
- `dotnet build windows/ConfigureMe.Setup.Tests/ConfigureMe.Setup.Tests.csproj --configuration Release`: erfolgreich, 0 Warnungen/Fehler. Ausführung der WinForms-Tests unter Linux nicht möglich.
- `dotnet publish windows/ConfigureMe.Setup/ConfigureMe.Setup.csproj --configuration Release -p:PublishProfile=win-x64`: Linux-Crossbuild für selbstständiges Windows-x64-Single-File erfolgreich. Zusätzlich PowerShell-Executable- und Ausgabepfade mit Leerzeichen geprüft.
- `New-SetupReleasePackage.ps1`: ZIP erstellt; alle Manifest-Hashes und Größen, Single-File-/SelfContained-Metadaten und Kennzeichnung des geänderten Arbeitsverzeichnisses geprüft; keine externen DLLs im Publish-Ordner. Unter Linux dafür `TEMP=/tmp` gesetzt.
- `npm test`: 15 Tests in 3 Dateien bestanden. `npm run typecheck`, `npm run lint`, `git diff --check`: erfolgreich.

Werkzeuge: .NET SDK 10.0.403 und PowerShell 7.5.4, offizielle Archive vor Nutzung gegen veröffentlichte SHA-512/SHA-256 geprüft. Keine Projektabhängigkeiten hinzugefügt. Der offizielle 7-Zip-MSI-Download wurde gegen den festgelegten SHA-256 geprüft.

Nicht ausgeführt: Windows PowerShell 5.1, vollständiger Windows-Smoke-Test, WinForms-Layoutausführung, GitHub-Actions-Lauf, echte Installer, CET-/Single-File-Start auf Server 2022. Öffentliche Python-/VS-Code-Downloadziele waren im Cloud-Netz nicht freigegeben; die Auswahl ist durch Metadaten-Fixtures getestet, nicht durch einen echten Download/Installationsversuch dieser Pakete. Die genaue Ursache des ursprünglichen AppX-Fehlers bleibt ohne VM-/Activity-Logs unbestimmt. Die CI wurde für diese Windows-Prüfungen erweitert, ihr Erfolg wird nicht behauptet.

## Geänderte Dateien

- `.github/workflows/windows-quicksetup.yml`
- `bootstrap/windows-server-2022-developer/README.md`
- `bootstrap/windows-server-2022-developer/SECURITY.md`
- `bootstrap/windows-server-2022-developer/bootstrap.ps1`
- `bootstrap/windows-server-2022-developer/config/catalog.json`
- `bootstrap/windows-server-2022-developer/modules/Detection.psm1`
- `bootstrap/windows-server-2022-developer/modules/GuiWorker.psm1`
- `bootstrap/windows-server-2022-developer/modules/Installation.psm1`
- `docs/quickstart-windows-server-2022.md`
- `docs/security.md`
- `docs/windows-setup-0.3.0-retest.md`
- `docs/windows.md`
- `scripts/New-SetupReleasePackage.ps1`
- `tests/quicksetup-smoke.ps1`
- `tests/worker-callback-fixture.ps1`
- `windows/ConfigureMe.Setup.Portable.Tests/ConfigureMe.Setup.Portable.Tests.csproj`
- `windows/ConfigureMe.Setup.Tests/SetupFormLayoutTests.cs`
- `windows/ConfigureMe.Setup/ConfigureMe.Setup.csproj`
- `windows/ConfigureMe.Setup/Program.cs`
- `windows/ConfigureMe.Setup/README.md`
- `windows/ConfigureMe.Setup/SECURITY.md`
- `windows/ConfigureMe.Setup/SetupForm.cs`
- `scripts/Start-SetupWithDiagnostics.ps1`
- `tests/installer-regressions.ps1`
- `docs/windows-setup-fixes-validation.md` (dieser Bericht)
