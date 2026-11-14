# Öffentliche Windows-Vorschau lokal testen

Stufe A/B: öffentliche Planung mit **synthetischen lokalen Fixtures**, keine produktive myConfigs-data-Integration. Keine Installation, Engineausführung, Hersteller-Installerdownloads, Registryänderung oder Administratorrechte. GitHub OAuth ist für die Vorschau nicht nötig. Private Routen bleiben geschützt. Ausführbare Downloads sind gesperrt; der Preview-Export trägt `kind: configureme-preview`, `executable: false` und ist kein gültiges bestehendes Installerplanformat. Daneben exportiert der Reviewstand einen getrennten [Setup-Plan v1](setup-plan-contract.md) ausschließlich für lokalen Import/Dry-Run, ohne Installationsrechte.

## Windows: separater temporärer Arbeitsbereich

Voraussetzungen: vorhandenes Git und Node.js 22+ mit npm. Diese Anleitung installiert keine Systemwerkzeuge. npm lädt ausschließlich Projekt-/Testabhängigkeiten; das ist keine Installation der im Konfigurator ausgewählten Software.

```powershell
$previewRoot = Join-Path $env:TEMP ("configureme-preview-" + [guid]::NewGuid().ToString("N"))
git clone --branch main https://github.com/muk4li/configureMe.git $previewRoot
Set-Location $previewRoot
npm ci
npm run preview
```

Öffne `http://127.0.0.1:3000`. Der Previewprozess bindet nur Loopback, deaktiviert Next-CLI-Telemetrie und entfernt bekannte configureMe-OAuth-/Authvariablen unabhängig von Groß-/Kleinschreibung aus seiner eigenen Kindprozessumgebung. Er verändert keine Benutzer-/Maschinenvariablen, keine produktive Auth und keine bestehende .env-Datei. Verwende einen frischen Checkout ohne .env und keine produktiven Secrets. Bei belegtem Port vor Start beispielsweise `$env:CONFIGUREME_PREVIEW_PORT = "3200"` nur in dieser Shell setzen. Beenden mit Ctrl+C; anschließend kann der selbst erstellte Previewordner nach Schließen aller Prozesse entfernt werden.

Direkt im Repo sind `npm ci` und `npm run preview` ebenfalls möglich, erzeugen dort aber Build-/Dependencydateien. Der temporäre Checkout ist für maximale Trennung empfohlen. Ohne Git kann ein sauberer Source-Download in ein neues Verzeichnis entpackt werden; eine CI-EXE startet nicht diese Webvorschau.

UX-Runde 1 und Setup-Plan v1 sind mit PR #11/#12 gemergt; der Clone von main enthält beides. Geänderte Katalogfilter, bestehende Planhinweise und Screenshotnachweise: [UX-Runde 1](ux/feedback-round-1.md).

## Nachvollziehbare Schreibzugriffe

- Git: ausschließlich neuer Checkout und dessen .git; npm: node_modules und eigener npm-Cache, Lockfile aus Git bleibt maßgeblich.
- Next: .next, next-env.d.ts, gegebenenfalls bestehender markierter AGENTS-Frameworkblock; TypeScript: *.tsbuildinfo. Keine Windows-Systemdateien.
- Browser: ausschließlich sessionStorage-Schlüssel `configureme:public-selection:v1` im jeweiligen Tab; keine Tokens, persönlichen Profile, Cookies oder serverseitige Sitzungsdaten für öffentliche Planung. Vom Benutzer bewusst exportierte JSON-Datei landet im gewählten Downloadordner.
- Tests: test-results/, playwright-report/ und Entwicklungscache des Testbrowsers; keine Engine-/Paketinstallation. Ctrl+C beendet den lokalen Webprozess; der Browserzustand endet mit der Sitzung (Browser kann Tabs/Sitzungen wiederherstellen).

## Bedienung und manuelle Negativprüfungen

Windows-Ziel wählen; Essentials und Developer kombinieren; GitHub CLI fordert Git nur einmal an. Visual Studio Code abwählen und neu laden: Änderung bleibt in diesem Tab. Ein unabhängig geöffneter neuer Tab beginnt mit Defaults; Browser können beim Duplizieren/opener-basierten Öffnen sessionStorage initial kopieren. Server Operations auf Server 2022 plus Developer erzeugt einen sichtbaren Authentifizierungsoptionskonflikt; explizites Yes/No löst ihn. Wechsel zu Windows 11 behält die Auswahl und zeigt unzulässige Profile/Pakete, statt sie still zu verlieren.

Bei ausgewählter GitHub CLI ist Git als erforderlich markiert und seine Abwahl gesperrt; ein Klick erzeugt keinen versteckten Ausschluss. „Also keep Git separately“ hält Git zusätzlich direkt fest, wenn GitHub CLI später abgewählt wird. Alte/manipulierte Dependency-Ausschlüsse bleiben als Konflikt sichtbar und können ausdrücklich über Undo repariert werden. Serverprüfung und Export funktionieren ohne Login. Der Export ist ausschließlich nicht ausführbares JSON. Kein ZIP/EXE-Downloadbutton darf aktiv sein. `/api/profiles` und `/api/bootstrap` bleiben anonym 401, `/dashboard` leitet um. Verweigerter sessionStorage lässt Änderungen im RAM zu; unbekannte/manipulierte gespeicherte Daten werden verworfen oder als sichtbarer Planungskonflikt behandelt.

## Automatisierte Prüfungen

```sh
npx next typegen
npm run typecheck
npm run lint
npm test
npm run build
npx playwright install chromium
npm run test:browser
```

Die zusätzliche Playwright-Entwicklungsabhängigkeit ist exakt gepinnt und prüft echte Browserinteraktionen, Reload, Tab-Trennung, HTTP-Grenzen und responsive Layouts. Browserdownload ist eine Testabhängigkeit, kein Herstellerinstaller. Auf der vorbereiteten Cloud-Linux-Maschine kann stattdessen `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium npm run test:browser` den vorhandenen Browser nutzen. Test-Webserver bindet Loopback und stoppt mit dem Runner; keine vorhandenen Server werden übernommen. Unit-Tests starten keine Prozesse außer dem bestehenden reinen PowerShell-Syntaxparser unter Windows. Der Windows-Parserfall ist unter Linux ausdrücklich skipped.

Öffentlicher Internetbetrieb, TLS/Proxy-/Mehrprozesslimits, reale Windows-Installerabnahme und Releaseauthentifizierung sind damit nicht freigegeben. Verbindliche Grenzen: [Produktauftrag](decisions/public-first-mvp.md), [Snapshotvorschlag](integrations/public-snapshot-v1-proposal.md), CM-001/005/006/010.
