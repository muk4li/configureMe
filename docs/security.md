# Sicherheitsmodell und Einschränkungen

## Vertrauensgrenzen

- Das Webportal plant Installationen, führt aber keine Installation auf dem Server oder Zielgerät aus.
- GitHub OAuth verwendet nur `read:user`; die Allowlist stammt aus serverseitiger Konfiguration. Der initiale Administrator wird über `INITIAL_ADMIN_GITHUB_USER` gesetzt.
- Sessions sind HMAC-signiert, HttpOnly, SameSite=Lax und laufen nach acht Stunden ab. In Produktion wird `Secure` gesetzt. OAuth bindet den Callback an einen zufälligen, kurzlebigen State-Cookie.
- Profile sind strikt validierte Daten. Benutzerwerte werden nicht in PowerShell-Quelltext interpoliert. Paket-IDs werden gegen den Anwendungskatalog geprüft und im Bootstrap erneut auf eine feste WinGet-ID abgebildet.
- Bootstrap-POSTs benötigen eine Sitzung und den exakt passenden Origin. Anmelde-Callback und Bundle-Erstellung haben prozesslokale Rate-Limits; sie sind für eine einzelne Instanz gedacht und ersetzen keinen Schutz am Reverse Proxy.
- Sicherheits-Header verhindern MIME-Sniffing, Framing und unnötige Browser-Berechtigungen.

## Download-Provenienz

Windows-Pakete enthalten `plan.json`, `plan.sha256`, einen festen `install.ps1`-Einstiegspunkt und eine README. Der Bootstrap vergleicht SHA-256 vor dem Parsen des Plans. Diese Prüfsumme schützt nur vor unbeabsichtigter Beschädigung: Ein Angreifer, der Plan und Prüfsumme gemeinsam ändert, wird dadurch nicht erkannt.

Die Artefakte sind **nicht signiert**. Es gibt keinen eingebetteten, unabhängig vertrauenswürdigen Herausgeberschlüssel und keine Authenticode-Signierung. Die Pakete bewerben sich deshalb nicht als nachweislich vom Herausgeber stammend. Für öffentliches Hosting sind ein unabhängiger Signatur-/Provenienzprozess, ein außerhalb des Downloads verteilter Trust Anchor sowie eine signierte Windows-Veröffentlichung erforderlich.

## Bedrohungsmodell

| Bedrohung | V1-Maßnahme und Grenze |
|---|---|
| Manipuliertes Profil | Striktes Schema, bekannte IDs, keine freien Befehle oder URLs; Katalogänderungen erfordern eine Codeänderung. |
| Manipulierter Plan | Schema- und Allowlist-Prüfung auf Server und Client; SHA-256 erkennt zufällige Beschädigung, aber keine böswillige gemeinsame Änderung. Signaturen fehlen. |
| Kompromittiertes Portal | Installationen laufen nicht remote. Ein kompromittiertes Portal kann weiterhin Bootstrap-Dateien und Seiteninhalte verändern; unsigned Downloads bieten keinen unabhängigen Herkunftsschutz. Nicht öffentlich ohne Signierung/Review betreiben. |
| Kompromittiertes privates GitHub-Repository | Der GitHub-Provider ist nicht implementiert; Profile sind lokale, geprüfte JSON-Dateien. |
| Replay eines alten Plans | Schema- und Katalogversion werden gebunden, aber es gibt keine Widerrufsliste oder kryptografische Replay-Sperre. |
| Gestohlene Sitzung | Kurze Lebensdauer, HttpOnly, SameSite=Lax, Secure in Produktion, Allowlist und nur lesendes OAuth. Es gibt keine zentrale Session-Widerrufsdatenbank. |
| Nicht unterstützte Plattform | Planer und Bootstrap akzeptieren ausschließlich Windows x64; Linux/macOS sind sichtbar als geplant, aber nicht automatisiert. |
| Unbeabsichtigte Installation | Lokaler Dry-Run, sichtbare Zusammenfassung und explizite Eingabe `YES`; der Browser installiert nichts. Kein automatischer Neustart oder Sicherheits-Bypass. |

Die WinGet-CLI und die jeweiligen Paketquellen bleiben externe Vertrauensabhängigkeiten. Die App pinnt keine Paketversionen. Prüfe Bundle und Paketquelle vor dem Einsatz auf einem wichtigen System.

## Standalone Windows Server 2022 Quick Setup

Das Profil `windows-server-2022-developer` ist ein getrenntes, versioniertes ZIP-Paket mit lokalem PowerShell-5.1-Einstiegspunkt und geprüften Modulen. Es benötigt weder das Webportal noch WinGet. Profile enthalten nur fest bekannte IDs, keine URLs, Argumente oder Befehle. Paketdefinitionen deklarieren `msi`, `exe`, `msix`, `windows-capability` oder `manual`; MSI-/EXE-Dateityp und Zielarchitektur werden unabhängig von URL-Endungen geprüft. Das Serverprofil verwendet den signierten klassischen CPython-3.14-x64-Vollinstaller statt MSIX. Paketgebundene x86-Bootstrapper-Ausnahmen für VS Code, .NET SDK und Python ändern die Prüfung installierter x64-Programme nicht. Nur die exakt gepinnte offizielle 7-Zip-25.01-x64-MSI darf bei passendem festem SHA-256 tatsächlich unsigniert sein; ungültige oder nicht vertrauenswürdige Signaturen bleiben gesperrt. Details und Hash stehen in `windows/ConfigureMe.Setup/SECURITY.md`. Der Installationspfad verwendet ausschließlich HTTPS mit regulärer Zertifikatsprüfung und Redirect-Host-Allowlist. Bei MSI-/EXE-Signaturen muss der erwartete Herausgeber passen; verfügbare offizielle Hash-Metadaten werden zusätzlich geprüft. Es wird kein heruntergeladenes Skript direkt ausgeführt.

Git wird nur installiert, wenn es fehlt. Der Bootstrap löst die aktuelle x64-EXE ausschließlich aus den offiziellen Git-for-Windows-Releases auf, prüft den dort veröffentlichten Asset-Digest (oder den exakten Dateieintrag im Release-Hash-Table, falls der API-Digest fehlt), verlangt eine gültige Authenticode-Signatur mit exakt `Johannes Schindelin` als Common Name und verwendet ausschließlich die dokumentierten Inno-Setup-Schalter. Vorhandenes Git wird nicht aktualisiert. Copilot Desktop wird bei Bedarf nach Git automatisch mit dem offiziellen, fest gepinnten v1.1.34-Tauri-NSIS-Installer für den aktuellen Benutzer eingerichtet. SHA-256, der exakte vertrauenswürdige `GitHub, Inc.`-Signer und der geprüfte stille Schalter `/S` sind vorgeschrieben. Vorhandene Installationen bleiben unberührt; die interaktive Anmeldung und ein echter Kompatibilitätstest auf Windows Server 2022 stehen aus. LibreOffice ist optional und standardmäßig nicht ausgewählt; bei expliziter Profilaufnahme werden offizieller TDF-Release-Hash und Authenticode-Signer `The Document Foundation` geprüft. Python verwendet den offiziellen x64-Python-Installationsmanager und dessen dokumentierten Runtime-Befehl. Copilot CLI bleibt manuell. Teams wird als Web-Fallback behandelt. Docker Desktop wird ausschließlich erkannt und lesend inspiziert; eine vorhandene Installation wird nicht geändert. OpenSSH Client nutzt die Windows Capability nach gesonderter bestätigter Installation. Der Report enthält nur Paket-, Versions-, OS- und Fehlerdaten, keine Tokens oder Umgebungsvariablen.

Das ZIP-Manifest enthält den Quell-Commit, den Dirty-Tree-Status sowie Größe und SHA-256 jeder Quelldatei. Ein CI-Build aus sauberem Checkout markiert `workingTreeDirty: false`; ein lokaler Build kann Änderungen enthalten. Der GitHub-Actions-Workflow lädt ein kurzlebiges, unsigniertes CI-Artefakt hoch, aber veröffentlicht kein Release. Die neben dem ZIP erzeugte SHA-256-Datei erkennt nur versehentliche Korruption und ist kein unabhängiger Vertrauensanker. Bis ein Signatur-/Provenienzprozess eingerichtet ist, darf das Paket nicht als vollständig vertrauenswürdiges öffentliches Onboarding beworben werden. Die Änderungen werden mit PowerShell-5.1-Mock-Smoke-Tests und Dry-Run geprüft; eine echte Installation oder ein frischer Windows Server 2022 End-to-End-Test fand nicht statt. Details stehen in [der Quick-Setup-Kurzanleitung](quickstart-windows-server-2022.md).
