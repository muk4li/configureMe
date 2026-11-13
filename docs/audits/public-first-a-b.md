# Public-first A/B: Implementierung und Nachweise

Datum 2026-11-13. Ausgangsbasis configureMe main `70a032ae19e2e0da0d39af5a5a5f8991f668e913`; separater Feature-Branch `feature/public-windows-configurator`. Kein Cherry-Pick/Merge des Engine-Fixes; PR #8 mit a1ab0b5 bleibt unabhängig. Quellen/PD-001..004: [lokaler Produktvertrag](../decisions/public-first-mvp.md). Centrality- und myConfigs-data-SHAs wurden erneut gelesen und sind unverändert zum dort genannten Stand. Keine Nachbar-Repo-Änderungen oder privaten Betriebsdetails übertragen.

## Umgesetzt

Öffentliche Startseite ohne Login, Windows11-/Server2022-x64-Auswahl, Kategorien/Katalog, kombinierbare synthetische Profile, Paket- und Optionsänderungen, Herkunft, sortierte transitive Abhängigkeiten und sichtbare Konflikte. sessionStorage ist begrenzt/validiert; defekte Daten werden verworfen und verweigerter Storage fällt auf RAM zurück. Keine serverseitige Benutzerpersistenz. Ein unabhängig geöffneter Tab beginnt neu; Browser können beim Duplizieren sessionStorage kopieren.

Neue reine Planungslogik wird im Browser zur Führung und serverseitig erneut mit dem eigenen Datenbestand ausgeführt. Profilreihenfolge erzeugt keine versteckten Vorrangänderungen. Optionenkonflikte benötigen explizite zulässige Overrides; benötigte entfernte Abhängigkeiten bleiben sichtbar und blockieren die Planfreigabe. Änderungen während laufender Servervalidierung verhindern den Export eines veralteten Ergebnisses.

POST /api/public/plan akzeptiert nur ein Strict-Auswahlschema, kein Planobjekt/Script/URL/Argument. 8-KiB-Bytegrenze, fünf Sekunden Bodyzeit, vier parallele Bodies und 60 Requests/Minute pro Prozess; eigener begrenzter Ratebucket ohne Identitäts-/Keyeviction. JSON/Origin/Fetch-Metadata, no-store/nosniff. Anonym bleiben private Profile/Bootstrap 401 und die private Routengruppe umgeleitet. Cookies/OAuth/private Daten werden im öffentlichen Berechnungspfad nicht verwendet.

Export ist ausschließlich servervalidiertes nicht ausführbares JSON: `kind=configureme-preview`, `executable=false`, `source.kind=local-fixture`, `sourceCommit=null`, `distribution.enabled=false`. Keine öffentliche ZIP-/EXE-Generierung oder Freischaltvariable. Bestehende Installerdefinitionen, Engine und Windows-CI-Datei sind unverändert.

## Bewusst nicht implementiert / Freigaben

[Snapshotvertrag](../integrations/public-snapshot-v1-proposal.md) bleibt Proposed: Datenowner, öffentlicher Dateisatz, konkrete Schemas/IDs/Mapping/Migration vor Importer. Die Fixtures sind keine produktive myConfigs-Integration. Der gegenseitige Gegenformatcheck wurde erneut mit den echten vorhandenen Validatoren ausgeführt: alle sechs Consumer- und fünf Datenrepo-Profile erwartungsgemäß inkompatibel. F-07/AF-003 bleiben offen.

Stufe D: Downloadalternativen verglichen, aber kein neuer ausführbarer Download. CM-001/005/006/010 bleiben unverändert; isolierte echte Windows-Installerabnahmen und Release-/Trustfreigabe gesondert. [Windowsmatrix](../windows-platform-matrix.md) unterscheidet Planbarkeit und tatsächliche Kompatibilität. Keine VPN-/Geräteidentität, Secretverwaltung, Cloud-/Homelab-/Hub-Anbindung oder private Profilverwaltung. Kein Deployment, Netzwerk-/Systemänderung oder Merge.

Öffentliche Ressourcenlimits sind keine verteilte DoS-Abwehr und keine Internetbetriebsfreigabe. Globale Proxy-/Verbindungs-/TLS-/Hostlimits und reale Betriebslast müssen vor Deployment nachgewiesen werden. Origin ist kein Login und kann von direkten Clients gesetzt werden; solche Anfragen erhalten ausschließlich dieselbe begrenzte öffentliche Berechnung. Unterschiedliche gleichnamige v1-Formate werden nicht gleichgesetzt.

## Tatsächliche lokale Prüfungen

Host: Debian 13 x64, Node 24.22.1/npm 11.9.0, Chromium 155.0.8059.79, vorhandenes PowerShell 7.5.4. Browser-/Buildbefehle mit lokalen Sockets mussten außerhalb der Agent-Sandbox laufen. Keine Windows-Installation oder Systempaketänderung.

| Befehl / Kontext | Ergebnis / Aussagegrenze |
| --- | --- |
| `git fetch origin main:refs/remotes/origin/main`; `git ls-remote --heads origin`; öffentliche PR-Liste | Basis 70a032a, separater offener Engine-PR #8 bestätigt; API-PR-Abfrage Forbidden |
| Centrality/myConfigs-data: `git fetch origin main`, `git show FETCH_HEAD:…` | aktuelle SHAs und relevante Architektur-/Vertragspfade gelesen; keine fremden Quelldateien geändert |
| `npm install --save-dev --save-exact @playwright/test@1.62.1 --cache /workspace/.npm-cache --no-audit --no-fund` | neue gepinnte Entwicklungstestabhängigkeit; keine Produktdependency. Automatische Metadatenänderungen anderer Lockeinträge wurden verworfen; ursprüngliche Versionen/Integritäten vollständig erhalten |
| `npm ci --cache /workspace/.npm-cache --no-audit --no-fund` | saubere Lockfileinstallation bestanden; nur Projektdependencies/Cache |
| `npx next typegen`; `npm run typecheck`; `npm run lint` | bestanden; öffentliche Route/Browsertests mitgeprüft |
| `npm test` | **36 passed, 1 ausdrücklich skipped, 5 Dateien** auf Linux; Windows-PowerShell-Parserfall wird nicht als ausgeführt behauptet |
| `NEXT_TELEMETRY_DISABLED=1 npm run build` | bestanden; öffentlicher SSR-/API-Produktionsbuild, kein Deployment |
| `PLAYWRIGHT_CHROMIUM_EXECUTABLE_PATH=/usr/bin/chromium npm run test:browser` | **12 bestanden**, reale Browser-/HTTP-Tests gegen Produktionsbuild ohne OAuth; keine externen Browserrequests erlaubt |
| `node /tmp/configureme-audit-probes/contracts.cjs` | 6+5 erwartete Gegenformat-Ablehnungen erneut bestätigt; kein Adapter oder Datenimport |
| Synthetischer Previewprozess-Smoke über `node scripts/Start-WebPreview.mjs` | bestanden: .env-Workspace verweigert, Home/Health 200, geerbte synthetische OAuthwerte entfernt, private Profile 401; eigene Prozessgruppe anschließend beendet |
| `pwsh -NoProfile -File tests/installer-regressions.ps1`; `tests/codex-desktop-script.ps1` | 86 Assertions und 10 Mock-Szenarien bestanden; kein Netzwerk-/Installerprozess |
| `python3 /tmp/configureme-public-doc-check.py`; `git diff --check` | 127 lokale Links/Anker, 25 eindeutige Task-IDs/Status/Pflichtfelder, Next-Frameworkblock unverändert; vorhandene Lockeinträge/Installer-/Engine-/Windows-CI-/Profil-/Schemadateien unverändert; keine externe URL-/Mermaid-Renderinggarantie |

Browserfälle: Profile kombinieren/deduplizieren, Overrides und Reload, unabhängige Tabs, Plattformwechsel ohne stillen Verlust, Optionskonflikt, notwendige Abhängigkeit verweigert, servervalidierter reiner JSON-Export, Storage-Injektion/Ausfall, leere 500-/defekte 200-Responses, veraltete Validierungsantwort nach Änderungen, private HTTP-Grenzen und Layoutbreiten 375/768/1440. Screenshots wurden erzeugt; Desktopansicht visuell geprüft. Unit-/API-Negativfälle ergänzen unbekannte IDs/Versionen/Aktionen, x64-/Targetgrenzen, Zyklen, Body-/Timeout-/Rate-/Parallelitätslimits. Kein Unit-Test startet einen Installer; nur der vorhandene Windowsfall parst ein Skript ohne Ausführung.

Diagnosekorrekturen: Erste Lintfassung verwendete setState direkt im Storage-Effect; ersetzt durch Reacts useSyncExternalStore. Der erste Turbopackversuch scheiterte an gesperrtem IPC, dessen Cachefehler wurde erhalten und mit frischem generiertem .next außerhalb der Sandbox erfolgreich neu gebaut. Erste Browserselektoren trafen auch Nexts Route-Announcer und erwarteten unzutreffend ein tatsächliches Abwählen einer Pflichtabhängigkeit; präzise Konfiguratorselektoren und ausdrückliche Refusal-Assertions bestehen. Ein bestehender Auth-Test schlug bei einem Lauf zufällig fehl: das letzte Base64url-Zeichen durch x zu ersetzen verändert gegebenenfalls nur ungenutzte Kodierungsbits, nicht die dekodierte HMAC-Signatur. Der Test verändert jetzt garantiert ein Signaturbyte, prüft die tatsächliche Byteänderung und verlangt weiterhin Ablehnung. Produktive Authfunktionen unverändert. Keine Sicherheitsassertion entfernt oder abgeschwächt.

## CI / Reviewstatus

Neuer Webworkflow: Linux und Windows mit Node22, Lockinstall, Typegen, Typecheck, Lint, Unit-/API-Tests und Build; unter Windows tatsächlicher PS5.1-Syntaxparser. Linux zusätzlich Playwright mit Entwicklungsbrowser. Branchgebundener Pushtrigger ermöglicht Prüfung trotz blockierter PR-API; bestehender Windows-Engineworkflow unverändert. Ein definierter Job ist noch kein erfolgreicher Laufnachweis. Aktueller tatsächlicher CI-Status wird im Abschluss ergänzt.

A/B-Tasks CM-017..022 bleiben bis vollständiger Verifikation In Progress. CM-023/024/025 bleiben Blocked. CM-016 ist ausschließlich als reservierte externe Arbeit referenziert. CM-004 erhält Webgates und ausdrücklichen Windows-Skip, wird nicht allein durch lokale Linuxprüfung Done. Historische Auditbefunde bleiben als Snapshots erhalten. Review-PR vorbereiten, kein automatischer Merge; eventuelle Dokumentationskonflikte mit #8 separat auflösen.
