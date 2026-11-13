# Ausführbares lokales Backlog

Stand: 2026-11-13. Stabile IDs, keine Umnummerierung. Status: **Backlog**, **Ready**, **In Progress**, **Blocked**, **Done**. Ready heißt ausführbar im beschriebenen Umfang, nicht freigegeben für echte Installationen/Secrets/Deployment. Blockierte Teilaufgaben nicht durch ungeprüfte Annahmen entsperren. Abhängigkeiten auf fremde Repos sind nur Vorschläge; dort wurden keine Backlogs verändert. Definition of Done: [AGENTS.md](AGENTS.md).

Priorität: P0 blockiert die betroffene Sicherheits-/Distributionsfreigabe; P1 wesentliche Stabilität/Nachweise; P2 kontrollierter Ausbau; P3 Zukunft. Kein P0 behauptet einen laufenden Angriff. Herkunft aller AF-Befunde: [Initialaudit](docs/audits/initial-audit.md). CM-011/012/013/014 sind ausdrücklich keine Implementierungsfreigabe im aktuellen Dokumentationsauftrag.

| ID | Priorität | Status | Phase | Titel |
| --- | --- | --- | --- | --- |
| [CM-001](#cm-001) | P0 | Ready | CM-2 | Unabhängige Release-Vertrauenskette und Distributionsgate |
| [CM-002](#cm-002) | P1 | Ready | CM-1 | Clean-Checkout-Docker- und Env-Voraussetzungen reparieren |
| [CM-003](#cm-003) | P1 | Ready | CM-3 | F-07-Vertrag mit Datenowner abstimmen |
| [CM-004](#cm-004) | P1 | Ready | CM-1 | Web-Qualitätsgates und echte Testzählung ergänzen |
| [CM-005](#cm-005) | P1 | Blocked | CM-2 | Vollständige Windows-Server-2022-Abnahme belegen |
| [CM-006](#cm-006) | P1 | Ready | CM-1 | Dateihandoff und lokale Angreifergrenze härten |
| [CM-007](#cm-007) | P2 | Ready | CM-1 | Session-Widerruf und Allowlist-Lebenszyklus entscheiden |
| [CM-008](#cm-008) | P2 | Ready | CM-1 | Web-Fehlerfälle und OAuth-Byteprüfung korrigieren |
| [CM-009](#cm-009) | P1 | Ready | CM-1 | Trust- und Installermodus in der UI korrekt benennen |
| [CM-010](#cm-010) | P1 | Ready | CM-2 | Aufgelöste Installer- und Build-Provenienz erfassen |
| [CM-011](#cm-011) | P2 | Blocked | CM-3 | Versionierten Profiladapter implementieren |
| [CM-012](#cm-012) | P2 | Blocked | CM-3 | Read-only GitHub-Provider erst nach Vertrag bauen |
| [CM-013](#cm-013) | P2 | Blocked | CM-4 | Eigenständigen Betriebs-/Integrationsvertrag vorbereiten |
| [CM-014](#cm-014) | P3 | Blocked | CM-5 | Späteren Gerätezugangsvertrag nur als Vorschlag vorbereiten |
| [CM-015](#cm-015) | P1 | Done | CM-0 | Engineering-Baseline und Initialaudit reviewfähig erstellen |

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

**Web-Qualitätsgates und echte Testzählung ergänzen** — P1; Status: **Ready**; Komponente: Web/CI/QA; Phase: [CM-1](ROADMAP.md#cm-1).

- Beschreibung: Node-Lockfile-Install, Typecheck, Lint, Tests und Build in CI prüfen. Plattformabhängige Parserprüfung wirklich unter Windows ausführen oder explizit als nicht ausgeführt kennzeichnen.
- Technische Evidenz: AF-004: nur Windows-Workflow; Vitest-Parserfall beendet unter Linux ohne Assertion und wird trotzdem als passed gezählt.
- Dateien/Module: package.json; .github/workflows/; tests/configuration.test.ts
- Abhängigkeiten/Freigaben: Keine Produktänderung; Testtoolversionen aus Lockfile.
- Akzeptanzkriterien: Alle Webgates auf PR prüfbar; keine stille Nullassertion als Windows-Nachweis; PR-Fehler führt ungleich null.
- Verifikation: Absichtlich gebrochene Typ-/Test-/Parserfixtures im geeigneten Testzweig; tatsächliche Testzahl und Plattform im Ergebnis.

## CM-005

**Vollständige Windows-Server-2022-Abnahme belegen** — P1; Status: **Blocked**; Komponente: Windows/QA; Phase: [CM-2](ROADMAP.md#cm-2).

- Beschreibung: Eine vollständig aktualisierte isolierte Ziel-VM ohne globales .NET mit dem Produktionsartefakt prüfen; reales Installieren braucht eigene Freigabe.
- Technische Evidenz: AF-005: CI-Self-Tests und historische Bedienberichte ersetzen keine vollständige versionierte Abnahmematrix.
- Dateien/Module: docs/windows-setup-0.3.0-retest.md; Windows Self-Tests; tests/; externes Testharness-Vertragsangebot
- Abhängigkeiten/Freigaben: Eigentümerfreigabe für echte Drittanbieterinstallationen; Infrastruktur-Owner stellt isolierte VM/Reset bereit; CM-001 für öffentliche Distribution.
- Akzeptanzkriterien: OS/UBR, Artefakt-SHA, Single-File-Start, echte DPI, Pflichtpakete, Rechte, Nachprüfung, Wiederholung, Abbruch/Neustartfälle dokumentiert.
- Verifikation: Frischer Snapshot je Szenario, tatsächliche Binärversion/Architektur, Vorher-/Nachherzustand, maschinenlesbare Berichte und sichere Artefaktablage; keine Produktionsgeräte.

## CM-006

**Dateihandoff und lokale Angreifergrenze härten** — P1; Status: **Ready**; Komponente: Windows/Supply Chain; Phase: [CM-1](ROADMAP.md#cm-1).

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

**Aufgelöste Installer- und Build-Provenienz erfassen** — P1; Status: **Ready**; Komponente: Windows/Reporting/Release; Phase: [CM-2](ROADMAP.md#cm-2).

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

## Priorisierte nächste Arbeit

1. **CM-001 / P0:** unabhängige Release-Vertrauensentscheidung und Distributionsgate vorbereiten; keine Signer-Credentials anfassen.
2. **CM-006 / P1:** lokale Handoff-Angriffsannahme mit Windows-Dateisystemtests eingrenzen und absichern.
3. **CM-002 / P1:** Clean-Checkout-Docker-/Env-Voraussetzungen reparieren.
4. **CM-004 / P1:** Webgates und echte plattformabhängige Testzählung ergänzen.
5. **CM-003 / P1:** Proposed-Datenvertrag mit Datenowner reviewen; noch keinen GitHub-Provider bauen.

CM-009 ist ein kleiner parallel ausführbarer lokaler Korrektur-PR; CM-005 bleibt bis zur Freigabe realer VM-Installationen blockiert. Eine Dokumentationsbaseline macht keine dieser Produktaufgaben automatisch Done.
