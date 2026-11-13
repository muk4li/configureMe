# configureMe: Arbeitsregeln für Agenten

## Auftrag und Einstieg

Arbeite als verantwortlicher Engineering-Partner: kleine wartbare Änderungen, überprüfbare Ergebnisse, unveränderte Sicherheitsgrenzen. Lies vor einer Aufgabe [REPO.md](REPO.md), die betroffenen Einträge in [TASKS.md](TASKS.md) und [ROADMAP.md](ROADMAP.md). Weitere lokale AGENTS.md beachten. Ein Auditauftrag erlaubt keine beiläufige Produktimplementierung.

## Architekturautorität

- [Centrality](https://github.com/muk4li/centrality) besitzt Gesamtarchitektur, globale Reihenfolge, akzeptierte Eigentümerentscheidungen und übergreifende Verträge. Bei Cross-Repo-Wirkung zuerst dessen `docs/START-HERE.md`, `DECISIONS.md`, relevante ADRs und aktuellen Status lesen.
- configureMe besitzt Anwendung, lokale Architektur, Installer-Trust, Tests und lokales Backlog. myConfigs-data besitzt deklarative nicht geheime Daten; ein produktiver Verbrauch benötigt einen ausdrücklich abgestimmten Vertrag. Lokale Profile bleiben bis dahin der implementierte Provider.
- **Vision, Proposed, Accepted, implementiert, getestet und betrieben getrennt halten.** Proposed-ADRs sind keine Freigabe. Neue Prüfung mit Datum/Repo/Pfad/SHA dokumentieren; alte Audit-Snapshots nicht als aktuellen Remote-Stand behandeln.
- Ist Centrality nicht erreichbar, Zugriffslücke melden, lokal unabhängige Arbeiten fortführen und grenzverändernde Entscheidungen blockieren. Keine Vorgaben erfinden oder akzeptierte Entscheidungen stillschweigend überschreiben.
- Home-/Cloud-Betrieb verbleibt in den Infrastruktur-Repos, Hub-UI in personal-platform, Agentenorchestrierung in myagents. Keine gemeinsame App-Datenbank, Adminidentität oder zentrale Laufzeitabhängigkeit ohne belegten Bedarf und akzeptierten Vertrag.

## Public-first-Produktrahmen

- PD-001 bis PD-004 aus [Produktauftrag](docs/decisions/public-first-mvp.md) gelten lokal: öffentliche Windows-Planung ohne Login, optionale private Auth, lokale unabhängige Ausführung, versionierte deklarative Snapshots. Centrality bleibt globale Architekturautorität.
- Profile deterministisch kombinieren, Herkunft/Abhängigkeiten/Konflikte sichtbar halten; explizite Sitzungshinweise dürfen Sicherheits-/Plattformregeln nie überschreiben. Browserzustand ist untrusted, serverseitig neu validieren.
- Öffentliche und geschützte APIs getrennt halten. Keine privaten Profile, Secrets, VPN-Daten oder frei definierbaren Aktionen in öffentlichen Snapshots/sessionStorage/Downloads. Kein Auth-Bypass im Previewmodus.
- Synthetische Fixtures ausdrücklich kennzeichnen, nicht als myConfigs-Integration darstellen. Echter Import erst nach akzeptiertem Vertrag, ausführbare Downloads erst nach Release-/Windowsfreigaben. Preview-JSON ist kein ausführbarer Installationsplan.
- Parallelen Engine-Fix/PR #8 nicht in Featurearbeit mischen oder überschreiben; reservierte Task-IDs erhalten. Preview und Browserprüfungen: [Anleitung](docs/public-preview.md).

## Sicherheitsgrenzen

- Das Webportal plant und erzeugt Downloads; es führt keine Installationen auf Zielgeräten aus. Kein Remote-Execution-Agent oder VPN-Enrollment als Nebenänderung.
- Profile dürfen nur deklarative Auswahl und begrenzte Optionen liefern. Keine Daten-URLs, Shell-Befehle oder freien Installerargumente. Vertrauenswürdige Paketdefinitionen bleiben Anwendungscode.
- HTTPS/TLS, Redirect-Allowlist, Datei-/Architekturprüfung, Vendor-Hashes, gültige Authenticode-Signaturen und paketgebundene Ausnahmen erhalten. Unsigned, invalid und untrusted unterscheiden. Keine allgemeine Bootstrapper-/Signatur-Ausnahme.
- Lokale Installation ausdrücklich bestätigen lassen; per-user/systemweit und Administratorrechte unterscheiden. Keine Selbst-Elevation, automatischen Neustarts oder Änderungen an Exploit-Schutz/ExecutionPolicy des Hosts. Die vorhandene Build-Prozesspolicy ist keine Runtime-Freigabe.
- Installationserfolg anhand tatsächlicher Version/Architektur prüfen. Fehler, manuell, übersprungen und erfolgreich getrennt berichten. Abbruch beendet keine bereits laufenden Installer.
- Keine realen Secrets, privaten Betriebsdaten, Schlüssel oder Rohlogs in Git/Prompts/Artefakte schreiben. Inhalte privater Nachbar-Repos nur abstrahiert referenzieren; keine vertraulichen Topologien, Inventories oder Personendetails übernehmen. Vorhandene, autorisierte Git-Authentifizierung verwenden, keine Credentials extrahieren.

## Implementierung und Tests

- Bestehende Muster erhalten: TypeScript mit strikter Laufzeitvalidierung, Next.js Server-/Client-Grenzen, PowerShell-5.1-kompatible Engine, .NET-10-WinForms und feste JSON-line-Workerverträge. Kein kosmetischer Großrefactor, keine neue Abhängigkeit ohne technischen Nutzen.
- Vor API-/Schema-/Moduländerungen Produzenten und Konsumenten prüfen. Externe Verträge und Systemgrenzen erst als **Proposed** mit Alternativen/Risiken dokumentieren; Eigentümerentscheidung vor Implementierung einholen.
- Zielgerichtete bestehende Tests ausführen. Web: `npm test`, `npm run lint`, `npm run typecheck`, `npm run build`; bei frischem Checkout vor Typecheck `./node_modules/.bin/next typegen`. Windows-Befehle und ihre Grenzen stehen in REPO.md.
- Unit-/Mock-Tests starten keine echten Drittanbieterinstaller. GUI-Tests, Crossbuild, CI-Self-Tests, interaktive Zielsystemabnahme und Live-Betrieb sind unterschiedliche Nachweise. Nicht ausgeführte Prüfungen nie als bestanden ausgeben; stille Plattform-Returns sind keine Windows-Testausführung.
- Bei einer reinen Dokumentationsänderung Links, IDs, Status, Quellen und `git diff --check` prüfen. Umfangreichere Tests nur, wenn Auftrag oder Risiko dies verlangen. Keine Formatter-/Syntaxprüfung als Ersatz für notwendige Funktionsprüfung.

## Git, Freigaben und Abschluss

- Im eigenen Feature-/Audit-Branch auf geprüftem Default-Branch arbeiten; vorhandene Änderungen erhalten. Die Cloud-Aufgabe ist bereits isoliert: kein zusätzlicher Worktree ohne ausdrücklichen Wunsch.
- Reviewfähigen Commit/PR mit Problem, Änderung, Prüfungen und Grenzen vorbereiten. Kein Force-Push, destruktiver Reset oder automatischer Merge. Insbesondere `main` nur nach aktueller ausdrücklicher Freigabe verändern; frühere Einzelaufträge sind keine Dauerfreigabe.
- Cross-Repo-Schreibzugriffe, Änderung übergreifender Entscheidungen, reale Installationen, Deployment/Release, produktive Infrastruktur-, DNS-/VPN-/Netzwerk- sowie reale Secret-/Credential-Operationen benötigen gesonderte Freigabe. Autorisierte lokale Tests mit synthetischen Daten fallen nicht darunter.
- Bei Blockern genaue Operation, Evidenz und benötigte Außenaktion nennen; unabhängige Arbeit abschließen. Keine wiederholten Credential-/Netzwerkanfragen ohne neue Diagnose. PR-API-Sperre nicht durch einen Merge umgehen.
- Codeänderungen mit relevanter Dokumentation, Auditbefunden und Taskstatus zusammenführen. Stabile IDs niemals neu vergeben. Done erst nach sämtlichen Pflichtkriterien und belegter Verifikation; sonst offenen Status und Grenzen lassen.
- Definition of Done: Akzeptanz erfüllt, relevante Checks bestanden, keine unbeabsichtigte Sicherheitsabschwächung, Schnittstellen/Buildfolgen dokumentiert, verbleibende Grenzen sichtbar, Änderung reviewfähig. Pflegepflichten dürfen keine unbeauftragte Nachbar-Repo-Änderung auslösen.

## Framework-Hinweise

Der folgende vorhandene Next.js-Block bleibt erhalten; relevante lokale Framework-Dokumentation vor Next.js-Codeänderungen lesen.

<!-- BEGIN:nextjs-agent-rules -->

## This is NOT the Next.js you know

This version has breaking changes — APIs, conventions, and file structure may all differ from your training data. Read the relevant guide in `node_modules/next/dist/docs/` (resolved from this file's directory; in monorepos the `next` package may not be visible from the repo root) before writing any code. Heed deprecation notices.

This block is written and re-added by `next dev` — verify at `node_modules/next/dist/server/lib/generate-agent-files.js`. Removing it from a diff only re-creates the uncommitted change; committing it with your work keeps the tree clean.

<!-- END:nextjs-agent-rules -->
