# Ausführbares lokales Backlog

Stand: 2026-11-14. Stabile IDs, keine Umnummerierung. Status: **Backlog**, **Ready**, **In Progress**, **Blocked**, **Done**. Ready heißt ausführbar im beschriebenen Umfang, nicht freigegeben für echte Installationen/Secrets/Deployment. Blockierte Teilaufgaben nicht durch ungeprüfte Annahmen entsperren. Abhängigkeiten auf fremde Repos sind nur Vorschläge; dort wurden keine Backlogs verändert. Definition of Done: [AGENTS.md](AGENTS.md).

Priorität: P0 blockiert die betroffene Sicherheits-/Distributionsfreigabe; P1 wesentliche Stabilität/Nachweise; P2 kontrollierter Ausbau; P3 Zukunft. Kein P0 behauptet einen laufenden Angriff. Herkunft aller AF-Befunde: [Initialaudit](docs/audits/initial-audit.md). CM-011/012/013/014/023/024/025 bleiben hinter ihren Freigaben. PD-001..004 autorisieren A/B für öffentliche Planung; keine produktive Distribution.

| ID | Priorität | Status | Phase | Titel |
| --- | --- | --- | --- | --- |
| [CM-001](#cm-001) | P0 | Ready | CM-2 | Unabhängige Release-Vertrauenskette und Distributionsgate |
| [CM-002](#cm-002) | P1 | Ready | CM-1 | Clean-Checkout-Docker- und Env-Voraussetzungen reparieren |
| [CM-003](#cm-003) | P1 | Ready | CM-3 | F-07-Vertrag mit Datenowner abstimmen |
| [CM-004](#cm-004) | P1 | In Progress | CM-1 | Web-Qualitätsgates und echte Testzählung ergänzen |
| [CM-005](#cm-005) | P1 | Blocked | CM-2 | Vollständige Windows-Server-2022-Abnahme belegen |
| [CM-006](#cm-006) | P1 | In Progress | CM-1 | Dateihandoff und lokale Angreifergrenze härten |
| [CM-007](#cm-007) | P2 | Ready | CM-1 | Session-Widerruf und Allowlist-Lebenszyklus entscheiden |
| [CM-008](#cm-008) | P2 | Ready | CM-1 | Web-Fehlerfälle und OAuth-Byteprüfung korrigieren |
| [CM-009](#cm-009) | P1 | Ready | CM-1 | Trust- und Installermodus in der UI korrekt benennen |
| [CM-010](#cm-010) | P1 | In Progress | CM-2 | Aufgelöste Installer- und Build-Provenienz erfassen |
| [CM-011](#cm-011) | P2 | Blocked | CM-3 | Versionierten Profiladapter implementieren |
| [CM-012](#cm-012) | P2 | Blocked | CM-3 | Read-only GitHub-Provider erst nach Vertrag bauen |
| [CM-013](#cm-013) | P2 | Blocked | CM-4 | Eigenständigen Betriebs-/Integrationsvertrag vorbereiten |
| [CM-014](#cm-014) | P3 | Blocked | CM-5 | Späteren Gerätezugangsvertrag nur als Vorschlag vorbereiten |
| [CM-015](#cm-015) | P1 | Done | CM-0 | Engineering-Baseline und Initialaudit reviewfähig erstellen |
| [CM-016](#cm-016) | P1 | Done | CM-1 | Engine-Cache-Publikation nebenläufigkeitssicher machen |
| [CM-017](#cm-017) | P1 | Done | CM-1 | Public-first-Produktvertrag und Architektur dokumentieren |
| [CM-018](#cm-018) | P1 | Done | CM-1 | Öffentlicher Windows-Konfigurator und Katalog |
| [CM-019](#cm-019) | P1 | Done | CM-1 | Deterministische Mehrprofil-/Abhängigkeitsauflösung |
| [CM-020](#cm-020) | P1 | Done | CM-1 | Sitzungsspeicherung und explizite Overrides |
| [CM-021](#cm-021) | P1 | Done | CM-1 | Begrenzte anonyme serverseitige Planvalidierung |
| [CM-022](#cm-022) | P1 | Done | CM-1 | Isolierte Preview und Web-/Browser-CI |
| [CM-023](#cm-023) | P1 | Blocked | CM-3 | Snapshotvertrag akzeptieren und offline importieren |
| [CM-024](#cm-024) | P1 | Blocked | CM-2 | Sichere öffentliche Setup-Downloadintegration |
| [CM-025](#cm-025) | P1 | Blocked | CM-2 | Windows-Matrix und lokale Planübergabe nachweisen |
| [CM-026](#cm-026) | P1 | Done | CM-1 | UX-Runde 1: Auswahl, Targetfilter und Layout konsistent machen |
| [CM-027](#cm-027) | P0 | Done | CM-1 | ZIP-Determinismus und CI-Baseline |
| [CM-028](#cm-028) | P1 | Done | CM-1 | Gemeinsamen lokalen Setup-Plan-Vertrag v1 implementieren |
| [CM-029](#cm-029) | P1 | Done | CM-1 | Servervalidierten Setup-JSON-Export anbinden |
| [CM-030](#cm-030) | P1 | Done | CM-1 | Nativen Snapshotimport und sicheren Dry-Run ergänzen |
| [CM-031](#cm-031) | P1 | Done | CM-1 | Gemeinsame Contractfixtures und Integrationsnachweise |
| [CM-032](#cm-032) | P1 | Done | CM-1 | Windows-v1-Baseline nach PR #12 synchronisieren |
| [CM-033](#cm-033) | P1 | Done | CM-1 | Importierten Ausführungsvertrag ohne Aktivierung vorbereiten |
| [CM-034](#cm-034) | P1 | Done | CM-1 | Windows-11-Previewadapter ohne Registrierung vorbereiten |
| [CM-035](#cm-035) | P1 | Done | CM-1 | Öffentliche Snapshot-Vertragsgrenzen synthetisch absichern |
| [CM-036](#cm-036) | P1 | Done | CM-1 | Verifizierte Installerdatei bis zum Prozessende sperren |
| [CM-037](#cm-037) | P1 | Done | CM-1 | Geprüfte Installerbytes und Quellen im Bericht erhalten |
| [CM-038](#cm-038) | P1 | Done | CM-1 | Release-Vertrauensplan und ausführbare Zielsystemmatrix vorbereiten |
| [CM-039](#cm-039) | P1 | Done | CM-1 | Legacy-Downloadfehler und Installermodus verständlich anzeigen |
| [CM-040](#cm-040) | P1 | Done | CM-1 | OAuth-Statevergleich gegen UTF8-Längenfehler härten |
| [CM-041](#cm-041) | P1 | In Progress | CM-1 | Fehlende Docker-Checkoutdateien bereitstellen |
| [CM-042](#cm-042) | P1 | In Progress | CM-6 | Linux-/Ubuntu-Provisionierung über lokalen Runner (huu-server-01) |

## CM-001

**Unabhängige Release-Vertrauenskette und Distributionsgate** — P0; Status: **Ready**; Komponente: Release/Supply Chain; Phase: [CM-2](ROADMAP.md#cm-2).

- Beschreibung: Trust-Anchor-/Signer-Optionen und Freigabegate vorbereiten; keine realen Schlüsseloperationen im Rahmen dieses Backlogs automatisch ausführen. Unsigned Entwicklungsartefakte bis zur bewussten Freigabe getrennt halten.
- Technische Evidenz: AF-001: eigene Dokumentation und Packaging kennzeichnen EXE/ZIP als unsigniert; Hashsidecar wird mit dem Download ausgeliefert.
- Dateien/Module: scripts/New-SetupReleasePackage.ps1; scripts/New-WindowsServer2022QuickSetup.ps1; Windows SECURITY.md; CI
- Abhängigkeiten/Freigaben: Eigentümerentscheidung zu Identität/Trust-Anchor vor Signer-/Credential-Einsatz; CM-006/CM-010 für belastbare Freigabe.
- Akzeptanzkriterien: Optionen mit Bedrohungsmodell reviewbar; zugelassene Distribution prüft unabhängige Herkunft und verweigert fehlende/falsche Signatur; Entwicklung bleibt explizit unsigned.
- Verifikation: Synthetische falsche/fehlende Signaturen, ersetzte/manipulierte Pakete und Ablauf-/Rotationfälle; reale Signierung erst separat autorisiert.

## CM-002

**Clean-Checkout-Docker- und Env-Voraussetzungen reparieren** — P1; Status: **Ready**; Komponente: Web/Packaging; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Fehlende öffentliche Assets-/COPY-Voraussetzung und dokumentierte Env-Vorlage mit kleinster Änderung korrigieren; keinen Betriebsdienst starten.
- Technische Evidenz: AF-002: Dockerfile COPY /app/public, aber public und .env.example sind im Git-Baum nicht vorhanden.
- Dateien/Module: Dockerfile; .dockerignore; .gitignore; docs/deployment.md; README.md
- Abhängigkeiten/Freigaben: Keine; keine realen OAuth-Werte benötigt.
- Akzeptanzkriterien: Build aus sauberem Git-Kontext funktioniert; sichere wertfreie Env-Vorlage tatsächlich vorhanden oder Anleitung konsistent; kein Secret im Kontext.
- Verifikation: Clean-Checkout-Build/Start mit synthetischen Variablen, Health/Profiles-Fehlerfälle; Containerbetrieb nicht mit öffentlichem Deployment verwechseln.

## CM-003

**F-07-Vertrag mit Datenowner abstimmen** — P1; Status: **Ready**; Komponente: Konfigurationsvertrag; Phase: [CM-3](ROADMAP.md#cm-3).

- Beschreibung: Den vorhandenen Proposed-Adaptervorschlag reviewen: Schemaidentitäten, Zielworkflow/Plattform, IDs, Optionen, Snapshots und Ablehnung festlegen; noch keinen Provider implementieren.
- Technische Evidenz: AF-003: sechs lokale und fünf Datenrepo-Profile gegenseitig abgelehnt; Centrality F-07 erneut bestätigt.
- Dateien/Module: docs/integrations/configuration-contract-proposal.md; src/lib/profiles.ts; schemas/; Datenowner-Verweise
- Abhängigkeiten/Freigaben: Datenowner/Eigentümerreview; Centrality ADR-002 und D-007 sind weiterhin Proposed.
- Akzeptanzkriterien: Eine explizite dokumentierte Entscheidung mit Besitzer, Versionen, Mapping und atomarer Fehlersemantik; getrennte Folgeaufträge für beide Repos.
- Verifikation: Commitgebundene positive/negative Produzenten-/Konsumentenfixtures; keine Schemakopie oder automatische Migration im Abstimmungsauftrag.

## CM-004

**Web-Qualitätsgates und echte Testzählung ergänzen** — P1; Status: **In Progress**; Komponente: Web/CI/QA; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Node-Lockfile-Install, Typecheck, Lint, Tests und Build in CI prüfen. Plattformabhängige Parserprüfung wirklich unter Windows ausführen oder explizit als nicht ausgeführt kennzeichnen.
- Technische Evidenz: AF-004: nur Windows-Workflow; Vitest-Parserfall beendet unter Linux ohne Assertion und wird trotzdem als passed gezählt.
- Dateien/Module: package.json; .github/workflows/; tests/configuration.test.ts
- Abhängigkeiten/Freigaben: Keine Produktänderung; Testtoolversionen aus Lockfile.
- Akzeptanzkriterien: Alle Webgates auf PR prüfbar; keine stille Nullassertion als Windows-Nachweis; PR-Fehler führt ungleich null.
- Verifikation: Absichtlich gebrochene Typ-/Test-/Parserfixtures im geeigneten Testzweig; tatsächliche Testzahl und Plattform im Ergebnis.

A/B-Fortschritt: Linux-/Windows-Webgates und tatsächlicher Windows-Parser jetzt grün (Lauf 43454638089), stille Linux-Frühreturns entfernt. Die ursprünglich weiter geforderte gezielte CI-Gate-Fault-Injection ist nicht durchgeführt; deshalb diese ältere Aufgabe nicht Done. CM-017..022 besitzen ihre eigenen erfüllten A/B-Kriterien.

## CM-005

**Vollständige Windows-Server-2022-Abnahme belegen** — P1; Status: **Blocked**; Komponente: Windows/QA; Phase: [CM-2](ROADMAP.md#cm-2).

- Beschreibung: Eine vollständig aktualisierte isolierte Ziel-VM ohne globales .NET mit dem Produktionsartefakt prüfen; reales Installieren braucht eigene Freigabe.
- Technische Evidenz: AF-005: CI-Self-Tests und historische Bedienberichte ersetzen keine vollständige versionierte Abnahmematrix.
- Dateien/Module: docs/windows-setup-0.3.0-retest.md; Windows Self-Tests; tests/; externes Testharness-Vertragsangebot
- Abhängigkeiten/Freigaben: Eigentümerfreigabe für echte Drittanbieterinstallationen; Infrastruktur-Owner stellt isolierte VM/Reset bereit; CM-001 für öffentliche Distribution.
- Akzeptanzkriterien: OS/UBR, Artefakt-SHA, Single-File-Start, echte DPI, Pflichtpakete, Rechte, Nachprüfung, Wiederholung, Abbruch/Neustartfälle dokumentiert.
- Verifikation: Frischer Snapshot je Szenario, tatsächliche Binärversion/Architektur, Vorher-/Nachherzustand, maschinenlesbare Berichte und sichere Artefaktablage; keine Produktionsgeräte.

## CM-006

**Dateihandoff und lokale Angreifergrenze härten** — P1; Status: **In Progress**; Komponente: Windows/Supply Chain; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Mock-Befund zwischen Prüfung und Prozessstart prüfen, Rechte-/ACL-/Reparse-/Cross-Process-Modell festlegen und kleinste sichere Handoff-Strategie testen.
- Technische Evidenz: AF-006 Probable: Fixture kann nach verification-completed vor ProcessRunner geändert werden; privilegierter Windows-Exploit nicht getestet.
- Dateien/Module: modules/Installation.psm1; Downloads.psm1; EngineBundle.cs; PowerShellWorkerClient.cs; Tests
- Abhängigkeiten/Freigaben: Synthetische Tests zunächst ausreichend; reale Exploit-/Admin-Tests nur gesondert und isoliert.
- Akzeptanzkriterien: Keine ausführbare geänderte Fixture nach erfolgreich behaupteter Prüfung; Pfadaustausch, parallele Instanzen und Rechte getrennt testen; bestehende Installer weiterhin verwendbar.
- Verifikation: Deterministische Mutations-/Reparse-/Paralleltests ohne Installerprozesse; zusätzliche Windows-Dateisystemtests mit dokumentierten Privilegien.

## CM-007

**Session-Widerruf und Allowlist-Lebenszyklus entscheiden** — P2; Status: **Ready**; Komponente: Web/Auth; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Erwartete Semantik bei Benutzerentfernung, Rollenwechsel, Logout und Schlüsselrotation festlegen; kleinste Lösung ohne vorschnelle zentrale Datenbank wählen.
- Technische Evidenz: AF-007: isAllowedUser=false bei weiterhin gültigem signiertem Cookie; acht Stunden stateless Sessions.
- Dateien/Module: src/lib/auth.ts; Auth-Routen; tests/auth.test.ts; docs/security.md
- Abhängigkeiten/Freigaben: Lokale Auth-Entscheidung; plattformweites SSO wäre gesonderter Vertrag.
- Akzeptanzkriterien: Dokumentierter Widerrufs-/Ablaufvertrag und passende Tests; keine behauptete zentrale Revocation, solange nicht implementiert.
- Verifikation: Entfernte Benutzer, Rollenwechsel, Ablauf, Logout, Secretrotation und direkte APIs mit synthetischen Tokens.

## CM-008

**Web-Fehlerfälle und OAuth-Byteprüfung korrigieren** — P2; Status: **Ready**; Komponente: Web/Auth/UI; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Byte-Längen vor timingSafeEqual prüfen und nicht-JSON/leere Upstreamfehler benutzerverständlich behandeln; keine Statusfehler als Download-Erfolg ausgeben.
- Technische Evidenz: AF-008: Unicode-State produziert 500; AF-011: leere 500-Antwort zeigt rohen JSON-Parserfehler im Browser.
- Dateien/Module: src/app/api/auth/github/callback/route.ts; src/components/setup-wizard.tsx; API-/Browser-Tests
- Abhängigkeiten/Freigaben: Keine echten OAuth-Credentials nötig; echte Login-Abnahme separat.
- Akzeptanzkriterien: Ungültiger State fail-closed ohne 500; HTML/leere Fehlerantworten verständlich; erfolgreiche ZIPs unverändert.
- Verifikation: UTF-8 vs. UTF-16-Längen, fehlender State/Cookie, leere/HTML/JSON-Fehler und gültiger ZIP-Download mit Mocks.

## CM-009

**Trust- und Installermodus in der UI korrekt benennen** — P1; Status: **Ready**; Komponente: Web/UI/Sicherheitskommunikation; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Wizardtexte mit den tatsächlichen Engine-Definitionen abgleichen; keine zweite konkurrierende Trust-Quelle einführen.
- Technische Evidenz: AF-009: Browser zeigt Python install manager und official signed 7-Zip installer, obwohl klassische EXE und hashgebundene unsigned MSI verwendet werden.
- Dateien/Module: src/components/setup-wizard.tsx; katalognahe Metadaten; Browser-Tests
- Abhängigkeiten/Freigaben: Installer-Trust unverändert; CM-010 kann Nachvollziehbarkeit ergänzen.
- Akzeptanzkriterien: Keine pauschale Signaturzusage für unsigned Ausnahmen; Python-/manuelle/unsupported-Pfade stimmen; keine Änderung an Prüfroutinen.
- Verifikation: Gerenderte Paketbeschreibungen gegen genehmigte Modi; Negativprüfung auf irreführende Signatur-/Automatikzusagen.

## CM-010

**Aufgelöste Installer- und Build-Provenienz erfassen** — P1; Status: **In Progress**; Komponente: Windows/Reporting/Release; Phase: [CM-2](ROADMAP.md#cm-2).

- Beschreibung: Quellrevision, tatsächliche Download-/Final-URI, erwartete/ist Digests, Signer und exakte Toolchain/Versionen reproduzierbar berichten, ohne Query-Secrets zu protokollieren.
- Technische Evidenz: AF-010: Paketbericht hat Source/Version/Status, aber keinen vollständigen Binary-Digest-/Signerbeleg; dynamische Feeds und Versionsbereiche verhindern Gleichsetzung von Code-SHA und Installerbytes.
- Dateien/Module: Logging.psm1; GuiWorker.psm1; SetupRunReport.cs; Packaging; CI; Toolchainpins
- Abhängigkeiten/Freigaben: Datenschutz-/Redaktionsregeln; mit CM-001 koordinieren, keine neue externe Control Plane.
- Akzeptanzkriterien: Bericht kann einen Installationsversuch eindeutigen Bytes/Toolchain zuordnen; Fehlerpfade erhalten; Hash wird nicht als Herausgebersignatur bezeichnet.
- Verifikation: Vorhersehbare Mockmetadaten, Redirect-/Digestwechsel, Queryredaktion, Offlinebezug und Toolchain-Reproduktion.

## CM-011

**Versionierten Profiladapter implementieren** — P2; Status: **Blocked**; Komponente: Profilverarbeitung; Phase: [CM-3](ROADMAP.md#cm-3).

- Beschreibung: Erst nach CM-003 einen begrenzten Adapter zwischen getrennten Quell-/Konsumentenmodellen implementieren; Legacy-Profile bleiben lesbar.
- Technische Evidenz: AF-003 und Proposed-Vertrag: Targetplattform/Workflow und ID-Kollisionen sind kein reines Feldumbenennen.
- Dateien/Module: src/lib/profiles.ts; künftige Adaptertests; schemas/; Proposed-Vertrag
- Abhängigkeiten/Freigaben: CM-003 explizit akzeptiert, Produzentenversion/Mapping abgestimmt; eigener Implementierungsauftrag.
- Akzeptanzkriterien: Atomare Validierung, versioniertes Mapping, klare Fehler, keine Befehle/URLs aus Daten; lokale Nutzung unabhängig.
- Verifikation: Alle realen Profile beider Snapshots plus unbekannte Versionen/IDs, Konflikte, Limits, Linux/macOS und unzulässige Felder.

## CM-012

**Read-only GitHub-Provider erst nach Vertrag bauen** — P2; Status: **Blocked**; Komponente: ConfigurationProvider; Phase: [CM-3](ROADMAP.md#cm-3).

- Beschreibung: Optionalen snapshotgebundenen Reader mit minimalen Rechten, lokalen Testfixtures und Offline-/Cache-Semantik ergänzen; kein Editor oder Write-Token als Voraussetzung.
- Technische Evidenz: AF-003: nur LocalConfigurationProvider implementiert; OAuth-Login liefert keine Repo-Contents-Integration.
- Dateien/Module: src/lib/profiles.ts; künftige Provider-/Contract-Tests; Deployment-Dokumentation
- Abhängigkeiten/Freigaben: CM-011 und CM-003; ausdrücklich freigegebene Credential-/Netzanforderungen und Fehlerpolitik.
- Akzeptanzkriterien: Unveränderlicher SHA, erlaubte Quellpfade, Gesamtvalidierung, last-known-good nur markiert nach Policy; keine Tokens an Browser/Gerät.
- Verifikation: 401/403/404/Rate-Limit, Timeout, Teilbestand, falscher Digest, Branchbewegung, Offline und Cache-Alter; keine echten Secrets in Tests.

## CM-013

**Eigenständigen Betriebs-/Integrationsvertrag vorbereiten** — P2; Status: **Blocked**; Komponente: Betrieb/Architektur; Phase: [CM-4](ROADMAP.md#cm-4).

- Beschreibung: Nur bei beauftragtem Bedarf einen Workload-/Proxy-/Health-/Auth-Vertrag anbieten; keine Infra-Dateien aus Nachbar-Repos kopieren oder Dienste deployen.
- Technische Evidenz: REPO.md: aktueller Standalone-Portalpfad; keine tatsächliche Hub-/Home-/Cloud-Kopplung nachgewiesen.
- Dateien/Module: REPO.md; docs/deployment.md; künftige versionierte Schnittstellenbeschreibung
- Abhängigkeiten/Freigaben: Konkreter Betriebsauftrag und zuständige Centrality-/Home-/Cloud-/Hub-Entscheidungen; CM-002 vor Docker-Nachweis.
- Akzeptanzkriterien: Owner, Versionen, Listener, Secretschnittstelle, AuthN/AuthZ, Readiness, Fehler, Daten-/Restoregrenzen und Rollback klar; App bleibt unabhängig.
- Verifikation: Isolierte positive/negative Proxy-/API-/Readiness-Prüfungen, keine öffentlichen oder produktiven Änderungen ohne Freigabe.

## CM-014

**Späteren Gerätezugangsvertrag nur als Vorschlag vorbereiten** — P3; Status: **Blocked**; Komponente: Zukunftsintegration; Phase: [CM-5](ROADMAP.md#cm-5).

- Beschreibung: Keine VPN-Funktion implementieren. Erst bei separatem Auftrag Verantwortungen und Sicherheitsvertrag für Enrollment/Ablauf/Widerruf erarbeiten.
- Technische Evidenz: Centrality D-006 und globale Phase 7; aktuelle App besitzt keine passende Control Plane oder Geräteidentität.
- Dateien/Module: Künftiger Proposed-Vertrag; Verweise auf Centrality
- Abhängigkeiten/Freigaben: Globale Sicherheits-/Betriebsgates und Eigentümerfreigabe; CM-001/CM-005/CM-013; kein Tailscale-MVP-Automatismus.
- Akzeptanzkriterien: Scope, MFA/AuthZ, Geräteschlüssel, APIs/Versionen, TTL, aktiver Widerruf, minimale Rechte und Auditereignisse vollständig beschrieben.
- Verifikation: Vertraglich festgelegte Positiv-/Negativfälle für Ablauf, Offline/Crash, Widerruf und Offboarding; keine Implementierung in diesem Task.

## CM-015

**Engineering-Baseline und Initialaudit reviewfähig erstellen** — P1; Status: **Done**; Komponente: Dokumentation/Audit; Phase: [CM-0](ROADMAP.md#cm-0).

- Beschreibung: Den aktuellen Auditauftrag ohne Produktcodeänderung abschließen; Quellen, Testgrenzen und private Informationsgrenzen sichern.
- Technische Evidenz: Initialaudit für Default-Branch 23fdea3; Centrality zuerst gelesen, Datenvertrag erneut geprüft.
- Dateien/Module: AGENTS.md; REPO.md; ROADMAP.md; TASKS.md; docs/audits/initial-audit.md; Proposed-Vertrag
- Abhängigkeiten/Freigaben: Keine Außenaktion für lokale Dokumentation; PR-API-Blocker transparent statt automatischem Merge.
- Akzeptanzkriterien: Alle Pflichtdokumente konsistent; Quellen mit SHA/Datum; ausführbares Backlog, Alternativenvergleich und Tests belegt; nur Markdown-Diff, keine fremden Änderungen; Review-Commit/Branch vorhanden.
- Verifikation: Link-/Anker-/ID-/Status-/Quellenprüfung, git diff --check, Diff auf Privates/Scope prüfen; tatsächliche Auditchecks aus initial-audit.md.

## CM-016

**Engine-Cache-Publikation nebenläufigkeitssicher machen** — P1; Status: **Done** (PR #8 gemergt, in main 5f878a7 geprüft); Komponente: Embedded Engine/GUI-Tests; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: konkurrierendes File.Move ohne Überschreiben sicher behandeln, jeden vorhandenen Gewinner erneut prüfen und GUI-/EXE-Self-Tests vom Benutzer-Cache isolieren.
- Technische Evidenz: [AF-012](docs/audits/initial-audit.md#af-012); Windows-Lauf 43435533839 und deterministischer Zweithreadtest gegen ursprünglichen Code scheitern mit bereits vorhandenem Ziel.
- Dateien/Module: EngineBundle.cs; SetupForm.cs; Program.cs; EngineBundleTests.cs; SetupFormLayoutTests.cs; TestApplicationData.cs; portable Testprojektverknüpfung; Windows-CI.
- Abhängigkeiten/Freigaben: keine echten Installationen oder Adminrechte; PR #8 nach Eigentümerreview gemergt. Vollständiger Windows-Lauf 43444044357 auf dem Fix-Branch bestanden.
- Akzeptanzkriterien: gültiger konkurrierender Gewinner akzeptiert; beschädigtes/zu kurzes Ziel oder Verzeichnis verweigert und erhalten; keine fremden Dateien überschrieben/gelöscht; Hash/Größe/Pfad/Reparse-Prüfungen erhalten; Testcache bereinigt; drei vollständige Windows-GUI-Testläufe und gesamter Windows-Workflow erfolgreich; separater PR.
- Verifikation: [Folgeprüfung](docs/audits/engine-cache-race.md) mit Red/Green-Nachweis, drei portablen Läufen, Windows-Crossbuild/Single-File-Publish und erfolgreichem dreifachen Windows-Testlauf plus vollständigem CI-Workflow 43444044357 für 8e02da3. PR #8 gemergt (e4a9ebc); geprüft am 2026-11-14. CM-006 bleibt separat offen: kein umfassender adversarialer Handoff-/ACL-Nachweis.

## CM-017

**Public-first-Produktvertrag und Architektur dokumentieren** — P1; Status: **Done**; Komponente: Architektur/Dokumentation; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: PD-001..004, Ist/Soll, Datenowner, Migrations- und Sicherheitsgates festhalten.
- Technische Evidenz: Aktueller Nutzerauftrag; docs/decisions/public-first-mvp.md; Centrality/myConfigs-SHAs erneut geprüft.
- Dateien/Module: AGENTS.md; REPO.md; ROADMAP.md; TASKS.md; Entscheidungs-/Snapshotdokumente
- Abhängigkeiten/Freigaben: Keine globale ADR-Änderung oder Cross-Repo-Schreibfreigabe.
- Akzeptanzkriterien: Quellen und Proposed/Accepted klar; A/B autorisiert, C/D blockiert; Historie/Frameworkblock erhalten.
- Verifikation: Dokumentationslinks, IDs, Status, Quellen-/Privatheitsreview und git diff --check.

## CM-018

**Öffentlicher Windows-Konfigurator und Katalog** — P1; Status: **Done**; Komponente: Web/UI; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Öffentlicher Einstieg ohne Login, zwei x64-Ziele, Profile/Kategorien/Modi und finale Übersicht.
- Technische Evidenz: PD-001/004; eigene öffentliche Komponente, private Routengruppe unverändert.
- Dateien/Module: src/app/page.tsx; src/components/public-configurator.tsx; globals.css; public-planning.ts
- Abhängigkeiten/Freigaben: CM-017; nur ausdrücklich lokale Fixtures bis CM-023.
- Akzeptanzkriterien: Anonyme Bedienung auf mobilen/Desktop-Viewports; unsupported/manual/detection sichtbar; keine private Profilfreigabe.
- Verifikation: Browser- und HTTP-Tests ohne OAuth bei 375/768/1440px; geschützte Routen bleiben geschützt.

## CM-019

**Deterministische Mehrprofil-/Abhängigkeitsauflösung** — P1; Status: **Done**; Komponente: Reiner Planer; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Null bis mehrere Profile, Herkunft, Deduplizierung, transitive Abhängigkeiten, Konflikte und Grenzen.
- Technische Evidenz: PD-003; src/lib/public-planning.ts und öffentliche Unitfälle.
- Dateien/Module: public-planning.ts; fixtures/public/profiles.v1.json; tests/public-planning.test.ts
- Abhängigkeiten/Freigaben: CM-017; kein Import fremder Profile vor CM-023.
- Akzeptanzkriterien: Profilreihenfolge ändert Ergebnis nicht; unbekannte IDs/Zyklen blockieren; erforderliche Entfernung sichtbar; kein stilles Teil-Ergebnis als gültiger Plan.
- Verifikation: Positive/negative deterministische Tests, injizierte trusted-Testkatalogzyklen, Zielwechsel, Herkunft und gleiche/gegenläufige Optionen.

## CM-020

**Sitzungsspeicherung und explizite Overrides** — P1; Status: **Done**; Komponente: Browserzustand; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: sessionStorage mit striktem Snapshot-/Selektionsschema; additions/removals und begrenzte Optionshinweise.
- Technische Evidenz: PD-003; public-session.ts, use-public-selection.ts.
- Dateien/Module: public-session.ts; use-public-selection.ts; öffentliche Komponente; Browserfälle
- Abhängigkeiten/Freigaben: CM-019; keine Secrets, Benutzerpersistenz oder Auth-Bypass.
- Akzeptanzkriterien: Reload behält zulässige Auswahl; unabhängiger Tab startet neu; defekte/alte Daten fail-closed; Storageverweigerung RAM-Fallback; explizite Optionsauflösung.
- Verifikation: Unit-/Browserfälle zu Reload, Tab, manipuliertem/zu großem Storage, Ausfall und Plattformwechsel.

## CM-021

**Begrenzte anonyme serverseitige Planvalidierung** — P1; Status: **Done**; Komponente: Öffentliche API/Sicherheit; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Nur eingeschränkte deklarative Auswahl neu berechnen; keine Installer- oder ZIP-Aktivität.
- Technische Evidenz: Neue öffentliche Angriffsfläche; POST /api/public/plan, public-request.ts, eigener Ratebucket.
- Dateien/Module: öffentliche Route; public-request.ts; public-rate-limit.ts; tests/public-api.test.ts
- Abhängigkeiten/Freigaben: CM-019; Proxy-/Mehrprozessgrenzen bleiben Deploymentvoraussetzung.
- Akzeptanzkriterien: 8-KiB-/5s-/Parallelitäts-/Ratelimits, striktes Schema, Origin/JSON, keine Cookies/privaten Daten; Fehler geschlossen, no-store.
- Verifikation: HTTP-/Unitfälle für gültig/ungültig, cross-site, Payload/Timeout, vier parallele Bodies, Rateablauf, unbekannte Felder und private 401/Redirectgrenzen.

## CM-022

**Isolierte Preview und Web-/Browser-CI** — P1; Status: **Done**; Komponente: Entwicklung/QA; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Loopback-Preview ohne OAuth/Engine, Schreibzugriffe dokumentieren; reproduzierbare echte Browsertests und Webgates.
- Technische Evidenz: scripts/Start-WebPreview.mjs; docs/public-preview.md; neuer Webworkflow.
- Dateien/Module: Previewskript; Playwright-Konfiguration/-Tests; package.json/lock; .github/workflows/web.yml
- Abhängigkeiten/Freigaben: Vorhandenes Node22+/Git; Entwicklungspakete separat von Systeminstallation; CM-018..021.
- Akzeptanzkriterien: Keine .env-/Auth-Credentials in Preview; keine Hersteller-/Enginezugriffe; Browser/HTTP/Reload/Layouts geprüft; Linux-/Windows-Web-CI tatsächlich grün.
- Verifikation: npm ci, typegen/typecheck/lint/test/build; Playwright ohne externe Seitenzugriffe; tatsächlichen CI-Status dokumentieren. Neuer genau gepinnter Playwright-Test-Devdependency begründet.

## CM-023

**Snapshotvertrag akzeptieren und offline importieren** — P1; Status: **Blocked**; Komponente: Cross-Repo-Datenvertrag; Phase: [CM-3](ROADMAP.md#cm-3).

- Beschreibung: Proposed public-snapshot-v1-Vertrag mit Owner reviewen; erst nach Annahme Adapter/Offlineimport implementieren.
- Technische Evidenz: F-07/AF-003 weiterhin bestätigt; PD-002 benennt Quelle, ersetzt kein konkretes Schema-Review.
- Dateien/Module: docs/integrations/public-snapshot-v1-proposal.md; späterer Importer; CM-003/011
- Abhängigkeiten/Freigaben: Explizite Vertrags-/öffentliche Dateisatzfreigabe und separater C-Auftrag; keine fremden Schreibzugriffe.
- Akzeptanzkriterien: Volle SHA-/Schema-/Digestbindung, alle Referenzen/IDs/Targets, atomare Aktivierung, keine privaten Geräte/Secrets; reproduzierbarer Offlinebestand.
- Verifikation: Commitgebundene Producer-/Consumerfixtures, falsche Versionen/Hashes/Referenzen, unbekannte Aktionen und bytegleicher Wiederholungsimport.

## CM-024

**Sichere öffentliche Setup-Downloadintegration** — P1; Status: **Blocked**; Komponente: Distribution/Download-UX; Phase: [CM-2](ROADMAP.md#cm-2).

- Beschreibung: JSON-Preview und separat autorisierter lokaler JSON-Import/Dry-Run (CM-028..031); öffentliche ausführbare ZIP-/EXE-Distribution erst nach Releasefreigaben.
- Technische Evidenz: PD-001 und unveränderte CM-001/005/006/010; Alternativenvergleich im Produktauftrag.
- Dateien/Module: Öffentliche Download-UX; spätere lokale Adapter; bestehende Bootstrap-/Bundlemodule
- Abhängigkeiten/Freigaben: Unabhängiger Release-Trust, Zielsystemnachweise, eigener D-Auftrag; keine Freischaltung per bloßem UI-/Envflag.
- Akzeptanzkriterien: Keine öffentliche ausführbare Ausgabe bis Freigabe; danach passende signierte/validierte lokale Übergabe ohne Portal-/Agentenzwang.
- Verifikation: Negativtests gegen anonymen ZIP-/EXE-Zugriff; lokale Plan-/OS-/x64-/Signer-/Hash-/Bestätigungsprüfung mit Fixtures vor echten separat genehmigten Tests.

## CM-025

**Windows-Matrix und lokale Planübergabe nachweisen** — P1; Status: **Blocked**; Komponente: Windows-Kompatibilität; Phase: [CM-2](ROADMAP.md#cm-2).

- Beschreibung: Matrix zwischen Planbarkeit, vorhandenen Strategien und echter Installation pflegen; spätere native Planübergabe testen.
- Technische Evidenz: docs/windows-platform-matrix.md trennt WinGet Windows11 und Servermodi; keine aktuelle reale Win11-Installerabnahme.
- Dateien/Module: Kompatibilitätsmatrix; spätere Bootstrap-/GUI-Planadaptertests; Retestdokumentation
- Abhängigkeiten/Freigaben: CM-024-Gates und eigene Autorisierung isolierter echter Tests; PR #8 ist gemergt, lokaler JSON-Import/Dry-Run separat über CM-028..031 autorisiert.
- Akzeptanzkriterien: x64-Ziele, keine Core-/ARM-Zusagen; Previewformat nicht direkt ausführbar; tatsächliche Version/Architektur, Rechte, Offline/Neustart/Idempotenz nachgewiesen.
- Verifikation: Matrixreview jetzt; später freigegebene frische VMs mit Quell-/Artefakt-/Plan-/OSbindung und negativen Ziel-/Rechtefällen.

## CM-026

**UX-Runde 1: Auswahl, Targetfilter und Layout konsistent machen** — P1; Status: **Done**; Komponente: öffentlicher Konfigurator/QA; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: erforderliche Pakete ohne versteckte Ausschlüsse behandeln; inkompatible Auswahl sichtbar bewahren; breiteres responsives Grid, höher beginnende Planübersicht, verständliche vorhandene Hinweise und lokale lizenzierte Icons.
- Technische Evidenz: [UX-Bericht](docs/ux/feedback-round-1.md); alter Handler speicherte Git-Abwahl trotz requiredBy; Basis main 3442f9f mit PR #8/#9/#10, keine offenen PRs beim Start.
- Dateien/Module: public-selection.ts; öffentliche React-Komponenten; globals.css; vorhandene Unit/API-/Playwrighttests; lokale Iconassets/Lizenzen; Vorschau-/UX-Dokumentation.
- Abhängigkeiten/Freigaben: keine C/D-/Deployment-/Installerfreigabe; Engine/Auth/Trust/DataProvider unverändert. PR-API aktuell Forbidden, eigener Review-Branch erforderlich.
- Akzeptanzkriterien: sichtbarer Zustand, gültiger Plan und Payload konsistent; gemeinsame Abhängigkeiten korrekt; Zielwechsel ohne stillen Verlust; normale Kategorien nur mit verfügbaren Einträgen; bestehende Hinweise ohne neue Wirkung verständlich; 375/768/1280/1440/1920 ohne Overflow/Überlappung, Desktop zweispaltig mit erreichbarer Übersicht; Icons lokal mit belegter Lizenz oder neutralem Fallback.
- Verifikation: Typegen/Typecheck/Lint/Produktionsbuild bestanden; 51 Unit/API-Tests plus 1 expliziter Linux-Skip, 21 Browserfälle; Web-CI 43522606123 für bb651df erfolgreich. Screenshots, Asset-/Lizenz-/Hashprüfung und Scopeprüfung dokumentiert. PR-Erstellung durch API-Forbidden blockiert, Review-Branch gepusht; kein Merge. Done betrifft die implementierten UX-Kriterien, keine Release-/Deploymentfreigabe.

## CM-027

**ZIP-Determinismus und CI-Baseline** — P0; Status: **Done**; Komponente: ZIP/CI; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Vier implizite JSZip-Verzeichnisse enthielten aktuelle DOS-Zeiten; createFolders=false, feste Metadaten und vollständiger Bytevergleich bleiben.
- Technische Evidenz: 96533c2, reproduzierte acht Zeitfeld-Differenzen und Rot/Grün-Regressionsnachweis.
- Dateien/Module: server-bundle.ts; server-bundle.test.ts; Webworkflow; TASKS.md
- Abhängigkeiten/Freigaben: Keine Installationsfreigabe; vollständige CI-Nachweise nötig.
- Akzeptanzkriterien: Identische Archivbytes über DOS-Ticks und Zeitzonen; Manifest/Hash/Größe erhalten; alter UX-Trigger entfernt, CM-016 eindeutig.
- Verifikation: Zwei ZIP-Tests, UTC/Los Angeles/Kiritimati; Linux-/Windows-Webgates; Ergebnis im Audit.

Abschlussnachweis: [Audit](docs/audits/setup-plan-v1.md), Code 79bf3e1; Web-CI 43561655099 und vollständige Windows-CI 43561655089 erfolgreich. Implementiert/Getestet im autorisierten lokalen Umfang, keine Release-/Distributionsfreigabe.

## CM-028

**Gemeinsamen lokalen Setup-Plan-Vertrag v1 implementieren** — P1; Status: **Done**; Komponente: TS/.NET/Schema; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Eindeutige Identität, Version, Katalogbindung, Ziele, deklarative Roots/effektive Pakete, Erinnerungen und keine Ausführungsrechte.
- Technische Evidenz: Expliziter Masterauftrag 2026-11-14; bestehendes Legacy-/Previewformat bewusst getrennt.
- Dateien/Module: schemas/setup-plan-v1.schema.json; contracts/; setup-plan.ts; SetupPlanContract.cs
- Abhängigkeiten/Freigaben: Lokal autorisiert; keine Änderung externer Datenverträge/Repositorygrenzen.
- Akzeptanzkriterien: Gemeinsame strukturelle Quelle; unbekannte Versionen/Felder/Aktionen und manipulierte Closure fail-closed; deterministisch.
- Verifikation: Gemeinsame TS/C#-Fixtures, Profile-/Inputreihenfolge, Kataloghash und Negativfälle.

Abschlussnachweis: [Audit](docs/audits/setup-plan-v1.md), Code 79bf3e1; Web-CI 43561655099 und vollständige Windows-CI 43561655089 erfolgreich. Implementiert/Getestet im autorisierten lokalen Umfang, keine Release-/Distributionsfreigabe.

## CM-029

**Servervalidierten Setup-JSON-Export anbinden** — P1; Status: **Done**; Komponente: Web/API/UI; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Bestehende öffentliche Vollvalidierung vor getrenntem JSON-Download; Browser bleibt untrusted.
- Technische Evidenz: Masterauftrag Phase C, bestehende PublicSelection/Resolver und Requestlimits wiederverwendet.
- Dateien/Module: öffentliche Planroute; public-configurator.tsx; API-/Browsertests
- Abhängigkeiten/Freigaben: CM-028; keine anonyme ausführbare ZIP-/EXE-Distribution.
- Akzeptanzkriterien: Ohne Login exportierbar; keine stillen Verluste, Secrets oder freien Aktionen; Preview/Plan/Releasestatus klar.
- Verifikation: API-Grenzen, konfliktbehaftete/manipulierte Auswahl, gespeicherter Download und Schutz privater Routen.

Abschlussnachweis: [Audit](docs/audits/setup-plan-v1.md), Code 79bf3e1; Web-CI 43561655099 und vollständige Windows-CI 43561655089 erfolgreich. Implementiert/Getestet im autorisierten lokalen Umfang, keine Release-/Distributionsfreigabe.

## CM-030

**Nativen Snapshotimport und sicheren Dry-Run ergänzen** — P1; Status: **Done**; Komponente: WinForms/Dateisicherheit/Worker; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Begrenzten lokalen Snapshot validieren, Pakete/Abhängigkeiten anzeigen und ausschließlich detect/offline plan ausführen.
- Technische Evidenz: Masterauftrag Phase D; bestehende EXE und PowerShell-5.1-Engine wiederverwendet.
- Dateien/Module: SetupPlanFile.cs; SetupPlanContract.cs; SetupPlanDryRun.cs; SetupForm.cs; native Tests
- Abhängigkeiten/Freigaben: CM-028; Server 2022 x64 Desktop Experience; Windows 11 ausdrücklich nicht unterstützt.
- Akzeptanzkriterien: Keine Importwirkung vor Prüfung; keine Installation im importierten Modus; Snapshot/Schreibsperre/Reparse/Versions-/Target-/Closureprüfung; manuelle Bedienung erhalten.
- Verifikation: Geteilte Bytefixtures, Windows-Dateisystem-/GUI-Tests, echte Offline-Workerplanung ohne Installer; keine Adminrechte nötig.

Abschlussnachweis: [Audit](docs/audits/setup-plan-v1.md), Code 79bf3e1; Web-CI 43561655099 und vollständige Windows-CI 43561655089 erfolgreich. Implementiert/Getestet im autorisierten lokalen Umfang, keine Release-/Distributionsfreigabe.

## CM-031

**Gemeinsame Contractfixtures und Integrationsnachweise** — P1; Status: **Done**; Komponente: QA/Dokumentation; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Webexport und nativer Import nutzen dieselben positiven/negativen Fixtures; vollständige vorhandene Workflows und Dokumentationsgrenzen prüfen.
- Technische Evidenz: Masterauftrag Phase E; gemeinsamer valid-server-Export wird in TS byteinhaltlich und nativ vor Workerplanung geprüft.
- Dateien/Module: tests/fixtures/setup-plan-v1; TS/API/Playwright-/C#-Tests; vorhandene CI; Architektur-/Auditdokumente
- Abhängigkeiten/Freigaben: CM-027..030; GitHub-API-Forbidden als PR-Blocker, keine Freigaben erfinden.
- Akzeptanzkriterien: Alle ausführbaren Gates tatsächlich grün; OS-/Provenienz-/Releasegrenzen sichtbar; separater reviewfähiger PR, kein Merge.
- Verifikation: Kommandos und tatsächliche CI-Links im Setup-Plan-Audit; echte VM-/DPI-/Installationsabnahme nicht als bestanden ausgeben.

Abschlussnachweis: [Audit](docs/audits/setup-plan-v1.md), Code 79bf3e1; Web-CI 43561655099 und vollständige Windows-CI 43561655089 erfolgreich. Die damalige PR-Erstellungsblockade ist durch den Eigentümer gemergten PR #12 erledigt (f744d63). Erneut geprüft: main-Web-CI 43562422332 und Windows-CI 43562422337 erfolgreich. Keine öffentliche Releasefreigabe.

## CM-032

**Windows-v1-Baseline nach PR #12 synchronisieren** — P1; Status: **Done**; Komponente: Dokumentation/Audit; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: gemergten Stand, CI-/Vertragsstatus und tatsächliche Folgefreigaben synchronisieren; historische Audits erhalten.
- Technische Evidenz: main f744d63; PR #12 merged; Web-CI 43562422332 und Windows-CI 43562422337 erfolgreich; Centrality 12776e9, Datenmodell 75b91cf nur lesend geprüft.
- Dateien/Module: REPO.md; ROADMAP.md; TASKS.md; Setup-Plan-/Vorschau-/Auditdokumentation.
- Abhängigkeiten/Freigaben: nur lokale Dokumentationspflege; keine fremden Änderungen oder Release-/Installationsfreigabe.
- Akzeptanzkriterien: CM-031 nicht fälschlich blockiert; Import/Dry-Run versus Installation/Release klar; stabile eindeutige IDs; reviewfähiger Branch/PR-Beschreibung bei API-Sperre.
- Verifikation: lokale Links/Anker, Task-IDs/Status und git diff --check; Produktcode unverändert; aktuelle Nachweise im Baseline-Audit.

## CM-033

**Importierten Ausführungsvertrag ohne Aktivierung vorbereiten** — P1; Status: **Done**; Komponente: Nativer Reviewzustand/Sicherheitsvertrag; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Snapshot-/Katalog-/Ziel-gebundene read-only Reviewzustände und klare spätere Bestätigungsgrenze schaffen; keine Installationsfunktion registrieren.
- Technische Evidenz: Masterauftrag B; main f744d63 hat bewusst gesperrte importierte Installation. Vorhandenes detect/offline plan wird wiederverwendet.
- Dateien/Module: ImportedPlanExecutionReview.cs; zugehörige portable/Windows-Tests; docs/imported-plan-execution-contract.md
- Abhängigkeiten/Freigaben: Ausführungsvertrag bleibt Proposed; Paket C und reale importierte Installation benötigen eigene Annahme/Phasenfreigabe. Keine zweite Engine.
- Akzeptanzkriterien: Eigene unveränderliche Bytes; erneut validierte Katalog-/Zielbindung; vollständige eindeutige Beobachtungen; fehlende/unklare Detection, Rechte und Modi sichtbar; Abbruch/late results geschlossen; kein Execute-/Authorize-API.
- Verifikation: 20 gezielte Fälle, portable/Windows-Komplettsuite und EXE-Selftests; kein realer Installer. Temporäre In-Process-Diagnose nur ergänzend, nicht als VSTest zählen.

Abschluss im begrenzten Vorbereitungs-/Fixumfang: Code `d2c8aba`, [vollständige CI 43564728870](https://github.com/muk4li/configureMe/actions/runs/43564728870) erfolgreich. Temporärer Branchtrigger danach entfernt; Folgecommit nur Nachweise/Triggerbereinigung. Kein Main-Merge, keine Aktivierungs-/Release-/Zielsystemfreigabe.

## CM-034

**Windows-11-Previewadapter ohne Registrierung vorbereiten** — P1; Status: **Done**; Komponente: Native Plattformvorbereitung; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Unabhängige Windows-11/x64-Kandidatenprüfung mit unveränderlichen Snapshots und begrenzten Fixturebeobachtungen implementieren; keine native Aktivierung.
- Technische Evidenz: Main f744d63 modelliert Windows 11, verweigert nativen Import; generische Windowsmetadaten belegen keine Zielsystemunterstützung.
- Dateien/Module: Windows11PreviewPreparation.cs; Tests; docs/windows11-preview-preparation.md
- Abhängigkeiten/Freigaben: Echte Windows-11-Plattform-/Detection-/Dry-Run-Abnahme vor Registrierung; Installation separat. Katalog-/Import-/Worker-OS-Prüfungen bleiben unverändert.
- Akzeptanzkriterien: Client/Build/x64 unterscheiden; alle Abhängigkeiten/unsupported erhalten; keine Serverstrategie als WinGet darstellen; falsche Architektur/unklare Beobachtungen verweigern; kein Installations-API.
- Verifikation: 12 gezielte Fälle plus vorhandene Windows-/portable Komplettsuiten; synthetische Hostevidenz ist kein echter Windows-11-Nachweis.

Abschluss im begrenzten Vorbereitungs-/Fixumfang: Code `c035c99`, [vollständige CI 43564860415](https://github.com/muk4li/configureMe/actions/runs/43564860415) erfolgreich. Temporärer Branchtrigger danach entfernt; Folgecommit nur Nachweise/Triggerbereinigung. Kein Main-Merge, keine Aktivierungs-/Release-/Zielsystemfreigabe.

## CM-035

**Öffentliche Snapshot-Vertragsgrenzen synthetisch absichern** — P1; Status: **Done**; Komponente: Consumer-Contracttests/Datenentscheidung; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Konkrete Producer-/Consumer-Abweichungen mit synthetischen Beispielen und echten Consumer-Validatoren testen; produktiven Import gesperrt lassen.
- Technische Evidenz: Centrality 12776e9 und Datenquelle 75b91cf nur lesend geprüft; ADR-002/D-007 weiter Proposed; Reihenfolge, Limits, Zielworkflow und Identitäten unterscheiden sich.
- Dateien/Module: docs/integrations/public-snapshot-decision.md; tests/public-profile-boundaries.test.ts; synthetische Fixturedateien.
- Abhängigkeiten/Freigaben: Keine externe Schemaannahme oder produktive Providerfreigabe; CM-003/023 bleiben blockierend für echten Import.
- Akzeptanzkriterien: Konkrete Entscheidungsvorlage; source-shaped Daten und unbekannte Versionen/Revisionen nicht implizit akzeptieren; keine Kürzung/Alias-/Targetkonvertierung; keine privaten Profile kopieren.
- Verifikation: Fünf gezielte Vitestfälle; Typecheck/Lint und vorhandene komplette Web-CI; keine Installer oder Secrets.

Abschluss im begrenzten Vorbereitungs-/Fixumfang: Code `4848a0f`, [vollständige CI 43564368520](https://github.com/muk4li/configureMe/actions/runs/43564368520) erfolgreich. Temporärer Branchtrigger danach entfernt; Folgecommit nur Nachweise/Triggerbereinigung. Kein Main-Merge, keine Aktivierungs-/Release-/Zielsystemfreigabe.

## CM-036

**Verifizierte Installerdatei bis zum Prozessende sperren** — P1; Status: **Done**; Komponente: Installer-Handoff/Sicherheit; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Bestätigten Inhaltsaustausch nach Verifikation durch deny-write/delete Handle während Prüfung und Installerwait verhindern.
- Technische Evidenz: AF-006 erneut mit synthetischem PE und Mockrunner reproduziert; Parent-Namespace/ACL-Risiken separat offen.
- Dateien/Module: Installation.psm1; installer-regressions.ps1; docs/audits/installer-handoff-lock.md
- Abhängigkeiten/Freigaben: Keine echten Installer; Windows-Kernel-Sharingtests in PS5.1/7 erforderlich. Vollständiger CM-006 bleibt offen.
- Akzeptanzkriterien: Mutationsversuche und vorhandene Writer vor Runner verweigern; unveränderte Bytes/Exitcodes/Reboot erhalten; Handle in allen Pfaden freigeben; keine Securitychecks lockern.
- Verifikation: Bestehende 86 portable Assertions; neue deterministische Windowsfälle und vollständiger Windowsworkflow 43564614212 für d5c6a52 erfolgreich; keine Linux-Locks als Windowsbeleg.

## CM-037

**Geprüfte Installerbytes und Quellen im Bericht erhalten** — P1; Status: **Done**; Komponente: Installer-/Worker-/Report-Provenienz; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Additive lokale Prüfevidenz desselben Verifikationsvorgangs mit tatsächlichem Digest/Größe/Signatur und redigierter beobachteter Quelle erhalten, auch bei späterem Prozessfehler.
- Technische Evidenz: CM-010: ursprüngliche Downloadfunktion verwirft finale validierte URI; Installresultat enthält nur Exit/Reboot. Kontrollierte Abhängigkeit auf Handoff-Branch ca290e3.
- Dateien/Module: Downloads/Installation/GuiWorker/Logging/bootstrap; installer-provenance.ps1; Aggregate-Reporttest; docs/audits/installer-provenance.md
- Abhängigkeiten/Freigaben: Zuerst Handoff-Reviewbranch übernehmen; keine Releaseauthentizität/Signierung. Build-/Toolchain-Provenienz und finale Apparchitektur bleiben CM-010 offen.
- Akzeptanzkriterien: Bisherige Rückgaben/stdout erhalten; erwarteter Pfadhash weiter geprüft und gegen gehaltenen Stream gebunden; SignatureProvider exakt einmal; cached finale URI unbekannt lassen; userinfo/query/fragment entfernen; ungültige Signaturen nie als erfolgreich berichten.
- Verifikation: 86 bestehende + 25 neue PS7-Fixtureassertions; Windows PS5.1/7, Worker-/Aggregate-Suiten und vollständiger Publishworkflow; Mismatch-Stream/Pfad vor Signer verweigert.

Abschluss im begrenzten Vorbereitungs-/Fixumfang: Code `d8f79c9`, [vollständige CI 43565667258](https://github.com/muk4li/configureMe/actions/runs/43565667258) erfolgreich. Temporärer Branchtrigger danach entfernt; Folgecommit nur Nachweise/Triggerbereinigung. Kein Main-Merge, keine Aktivierungs-/Release-/Zielsystemfreigabe.

## CM-038

**Release-Vertrauensplan und ausführbare Zielsystemmatrix vorbereiten** — P1; Status: **Done**; Komponente: Release/QA-Vorbereitung; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Unabhängige Signer-/Provenienz-/Distributionsgates und reproduzierbare nichtinstallierende sowie getrennt zu autorisierende reale VM-Szenarien konkretisieren.
- Technische Evidenz: Main f744d63 ist unsigned Entwicklungsartefakt; CI ersetzt keine Publisheridentität oder frische VM-Abnahme.
- Dateien/Module: docs/release-trust-plan.md; docs/qa/windows-v1-acceptance.md
- Abhängigkeiten/Freigaben: Signer-/Schlüsselentscheidung, VMbereitstellung und echte Installationsfreigabe bleiben extern; CM-001/005 nicht als abgeschlossen ausgeben.
- Akzeptanzkriterien: Konkrete Quelle/Build/Signatur/Verifikation/Rotation/Freigabe-Kette; Matrix für OS/DPI/Rechte/Version/Architektur/Wiederholung/Fehler mit sicheren ausführbaren Befehlen; keine Releaseaktivierung.
- Verifikation: Dokumentationslinks/Status/Scope und git diff --check; vorhandener kompletter Windows-CI-Lauf 43564614212, keine neue echte Zielsystemausführung behauptet.

## CM-039

**Legacy-Downloadfehler und Installermodus verständlich anzeigen** — P1; Status: **Done**; Komponente: Geschütztes Wizard-UX; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Bestätigten leeren/HTML-/defekten JSON-Fehler benutzerverständlich behandeln; unerwartete Erfolgsausgaben nicht als ZIP herunterladen; Python/7-Zip-Anzeige an reale Modi anpassen.
- Technische Evidenz: AF-009/011 und aktuelle setup-wizard.tsx: Pythonmanager/pauschal signed 7-Zip sowie ungeprüftes response.json bei Fehlern.
- Dateien/Module: setup-wizard.tsx; legacy-bundle-response.ts; gezielte Antworttests.
- Abhängigkeiten/Freigaben: Keine Auth-/Katalog-/Installerpolicyänderung; ZIP-Headerprüfung ist nur UX, keine Signatur-/Herkunftszusage.
- Akzeptanzkriterien: Leere/HTML/trunkierte Fehler ohne rohen Parsertext; korrekte JSON-Fehler begrenzt erhalten; tatsächliche ZIPbytes erhalten; kein Navigation/Selektionswechsel während laufendem Download.
- Verifikation: Sechs Response-Regressionstests mit realem ZIP-Kontrollfall; vollständige bestehende Webgates/Browsergrenzen. OAuth-State-Sicherheitsfrage CM-008 bleibt separat offen.

Abschluss im begrenzten Vorbereitungs-/Fixumfang: Code `7742d44`, [vollständige CI 43565106502](https://github.com/muk4li/configureMe/actions/runs/43565106502) erfolgreich. Temporärer Branchtrigger danach entfernt; Folgecommit nur Nachweise/Triggerbereinigung. Kein Main-Merge, keine Aktivierungs-/Release-/Zielsystemfreigabe.

## CM-040

**OAuth-Statevergleich gegen UTF8-Längenfehler härten** — P1; Status: **Done**; Komponente: Bestehender OAuth-Callback; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Gleiche UTF16-Zeichenlängen mit unterschiedlichen UTF8-Bytelängen sicher ablehnen, ohne RangeError/500 und ohne Authentifizierungsumbau.
- Technische Evidenz: Original main: zwei Unicode-GET-Fälle reproduzieren RangeError; sieben Kontrollfälle bestehen. Fix vergleicht Bufferlängen vor timingSafeEqual.
- Dateien/Module: src/app/api/auth/github/callback/route.ts; tests/oauth-callback.test.ts
- Abhängigkeiten/Freigaben: Nur bestehende Fehlergrenze; keine echten OAuth-Credentials oder Upstreamrequests, keine Allowlist-/Sessionlockerung.
- Akzeptanzkriterien: Unpassender State führt zu sicherem Redirect und Cookie-Löschung ohne Upstream; gültiger ASCII-State durchläuft konfigurierte synthetische Session-/Allowlistkontrolle unverändert.
- Verifikation: Neun echte GET-Pfadtests mit gemocktem Fetch, Rot/Grün-Nachweis; bestehende komplette Web-/Browsergates.

Abschluss im begrenzten Vorbereitungs-/Fixumfang: Code `549a85b`, [vollständige CI 43565869811](https://github.com/muk4li/configureMe/actions/runs/43565869811) erfolgreich. Temporärer Branchtrigger danach entfernt; Folgecommit nur Nachweise/Triggerbereinigung. Kein Main-Merge, keine Aktivierungs-/Release-/Zielsystemfreigabe.

## CM-041

**Fehlende Docker-Checkoutdateien bereitstellen** — P1; Status: **In Progress**; Komponente: Entwicklungs-/Containerbuild-Voraussetzungen; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Tatsächlich referenzierten public-Ordner und sichere wertfreie Env-Vorlage versionieren; keine Container starten oder Authvorgaben lockern.
- Technische Evidenz: Dockerfile COPY /app/public sowie dokumentiertes .env.example fehlten; Dockerinfo scheitert hier an Socketberechtigung.
- Dateien/Module: public/.gitkeep; .env.example; .gitignore; Deploymentdokumentation.
- Abhängigkeiten/Freigaben: Dockerdaemonzugriff und isolierter Clean-Checkout-Build/Health/API-Test fehlen; keine Gruppenzuordnung/Sudo-/Hoständerung als Umgehung.
- Akzeptanzkriterien: Alle COPY-Quellen vorhanden; einzig explizite Env-Beispieldatei aus Ignore ausnehmen, echte Dateien weiter ignoriert; leere Authwerte; vollständigen Dockerbuild erst nach tatsächlichem Test als bestanden melden.
- Verifikation: Git-/Datei-/Env-Struktur geprüft; vollständige Web-CI 43566003380 für 73db0ef erfolgreich; Dockerbuild/-start ausdrücklich nicht durchgeführt, CM-002/041 bleiben offen.

## CM-042

**Linux-/Ubuntu-Provisionierung über lokalen Runner** — P1; Status: **In Progress** (Vertrag Accepted 2026-11-14; Schema/Katalog/Validator und Runner-Dry-Run implementiert, Apply nicht); Komponente: neuer Linux-Plan, Linux-Katalog, lokaler Runner; Phase: CM-6 (neu, siehe Centrality).

- Beschreibung: Erster Linux-Weg für configureMe. Ein deklarativer, versionierter Plan richtet eine frisch per Autoinstall installierte Ubuntu-Server-24.04-VM ein: Basiswerkzeuge, offizielles Docker-APT-Repo, Docker Engine + Compose-Plugin, unattended-upgrades, optional Docker-Gruppe nur bei ausdrücklicher Planentscheidung. Ausgeführt durch einen **lokalen Runner auf der VM**, den der Eigentümer per SSH startet; das Webportal führt nichts aus.
- Bezug auf die VM: Der Runner kommt per `git clone` eines festen configureMe-Commits auf die VM und läuft mit einem Plan aus dem Repo.
- Auftrag/Quelle: Centrality [ADR-004](https://github.com/muk4li/centrality/blob/main/docs/decisions/ADR-004-HUU-FIRST-DEPLOY.md), O-024/O-025 (geprüft `6fee069`). Erster Einsatz: `huu-server-01`. Vertrag: [Linux-Plan v1](docs/linux-plan-contract.md) (**Accepted** 2026-11-14: eigenes Format, Python-3.12-Standardbibliothek, Docker-Gruppe `false` für huu-server-01, nur Docker-Pakete gepinnt).
- Grenzen: keine frei definierbaren Shell-Befehle aus Plandaten; Paketdefinitionen und Quellen sind Anwendungscode (Ubuntu-Archiv, offizielles Docker-APT-Repo mit festem Schlüssel-Fingerprint); Dry-Run als Standard; ausdrückliche Bestätigung vor Root-Aktionen, keine Selbst-Elevation; idempotent; keine Secrets in Plan oder Bericht; kein Remote-Agent, kein VPN-Enrollment.
- Abgrenzung: Autoinstall/cloud-init (myHome-Lab) übernimmt Platte, Benutzer, SSH-Key, Locale, openssh. **Firewall/ufw und Isolation gehören zu myHome-Lab**, nicht zu CM-042. Caddy und Apps kommen danach per Compose, nicht über configureMe. Hyper-V, VPN, Secrets nicht im Umfang.
- Schnitt: (1) Vertrag Proposed → (2) Schema/Katalog/Validierung → (3) Runner mit Dry-Run → (4) Installationsschritte → (5) Doku/Anleitung. Teil 1 abgeschlossen (Vertrag Accepted); Teile 2–5 als aufeinander aufbauende PRs.
- Akzeptanzkriterien: Plan validiert gegen ein Linux-Schema; Dry-Run zeigt alle Schritte ohne Änderung; zweiter Lauf ändert nichts; Erkennung prüft tatsächliche Versionen; Bericht trennt erfolgreich/bereits erfüllt/übersprungen/fehlgeschlagen; Tests ohne echte Installation; bestehende Web- und Windows-Gates unverändert grün.
- Verifikation: Teil 2: `python3 -m unittest discover -s tests/linux` (Python 3.12 und 3.13, synthetische Fixtures), CI-Workflow `linux-runner.yml` auf `ubuntu-24.04`. Teil 3: Dry-Run mit synthetischem Host gemockt getestet, zusätzlich lesender Dry-Run auf einem Ubuntu-24.04-Entwicklungscontainer (kein Zielsystem). Docker-Pins noch Platzhalter, `--apply` noch abgelehnt. Keine reale Installation; diese nur durch den Eigentümer nach Freigabe.

## Priorisierte nächste Arbeit

1. **CM-001 / P0:** unabhängige Release-Vertrauensentscheidung und Distributionsgate vorbereiten; keine Signer-Credentials anfassen.
2. **CM-006 / P1:** lokale Handoff-Angriffsannahme mit Windows-Dateisystemtests eingrenzen und absichern.
3. **CM-002 / P1:** Clean-Checkout-Docker-/Env-Voraussetzungen reparieren.
4. **CM-004 / P1:** Webgates und echte plattformabhängige Testzählung ergänzen.
5. **CM-003 / P1:** Proposed-Datenvertrag mit Datenowner reviewen; noch keinen GitHub-Provider bauen.

Public-first A/B (CM-017..022) ist durch PD-001..004 zusätzlich autorisiert. Externer Datenimport/ausführbare Distribution/echte Zielsystemabnahme (CM-023/024/025) bleiben gesperrt; der Masterauftrag autorisiert separat CM-027..031 für JSON-Import/Dry-Run. CM-016 ist durch den gemergten separaten PR #8 abgeschlossen. Die obige Sicherheitspriorisierung bleibt bestehen; eine reine Vorschau benötigt keine ausführbare Releasefreigabe.

CM-009 ist ein kleiner parallel ausführbarer lokaler Korrektur-PR; CM-005 bleibt bis zur Freigabe realer VM-Installationen blockiert. Eine Dokumentationsbaseline macht keine dieser Produktaufgaben automatisch Done.

CM-012-Präzisierung durch PD-002: kein GitHub-Runtimeprovider für die öffentliche Seite. Ein künftiger Reader wäre höchstens ein separat autorisierter manueller Snapshotimport; CM-003/011/023 müssen zuerst erfüllt sein.

A/B-Abschlussnachweis: [Web-CI 43454638089](https://github.com/muk4li/configureMe/actions/runs/43454638089) für c5bcdba, beide Plattformjobs erfolgreich; lokal 39 Unit-/API-Tests plus 1 expliziter Linux-Skip, 12 Browserfälle, Preview-Smoke und Scopeprüfung. CM-017..022 Done bedeutet keine C/D-, Release-, Deployment- oder globale Architekturfreigabe.
