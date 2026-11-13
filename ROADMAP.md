# Lokale technische Roadmap

Stand: 2026-11-13. Diese Roadmap betrifft ausschließlich configureMe; [Centrality](https://github.com/muk4li/centrality) besitzt globale Prioritäten und Abhängigkeiten. Kein lokaler Phasenabschluss bedeutet eine globale Betriebsfreigabe. **Keine Termine zugesagt, keine Zukunftsintegration als vorhanden markiert.** Evidenz: [Initialaudit](docs/audits/initial-audit.md), Aufgaben: [TASKS.md](TASKS.md).


## Public-first-Priorität seit PD-001..004

Lokale Phasen behalten ihre IDs. Innerhalb dieser Phasen gilt: (1) CI-/Engine-Stabilität im getrennten PR #8, (2) öffentliche UI, (3) Mehrprofile/Sitzungsänderungen, (4) akzeptierter Snapshotvertrag vor Import, (5) Download-UX mit weiterhin gesperrter ausführbarer Distribution, (6) native Planübergabe/echte Windows-11-/Server-Abnahme, (7) optionale private Profile/Auth, (8) spätere Centrality-Geräteintegration. A/B dürfen vor Release-Signierung als nicht ausführbare Vorschau entstehen.

CM-1 erhält CM-017..022: Produktvertrag, öffentliches Routing/Katalog, reine Kombination, Sitzungsspeicherung, begrenzte Serverprüfung und Browser-/CI-Preview. Voraussetzung sind explizite Trustgrenzen und unveränderte private Auth. Abschluss nur mit Unit-/API-/Browsernachweisen und ohne Engine-/Installeraktivität. CM-3 erhält CM-023 erst nach Vertragsannahme. CM-2/4 erhalten CM-024/025: Vergleich/Planexport jetzt, ausführbare ZIPs/native Imports und tatsächliche Kompatibilität erst nach deren Gates. Risiken: anonyme Ressourcenlast, irreführende Fixture-/Supportzusagen, manipulierter Browserzustand, voreilige Distribution. Keine globale Phasenfreigabe daraus.

## CM-0

**Audit und Engineering-Baseline.** Status: Abschluss an CM-015 gebunden; offene Produktbefunde sind ausdrücklich zulässig, eine Sicherheitsfreigabe nicht.

- Ziel: aktueller Default-Branch, Architekturautoritäten, Schnittstellen und Prüfgrenzen nachvollziehbar machen.
- Deliverables: AGENTS.md, REPO.md, dieses Dokument, TASKS.md, datierter Audit und Proposed-Datenvertrag.
- Voraussetzungen/Abhängigkeiten: lesbarer Quellstand; Zugriffslücken transparent dokumentiert, keine erfundenen Nachbar-Repo-Entscheidungen.
- Risiken: veraltete Statusangaben, Vermischung privater Daten und öffentlicher Dokumentation, Testzahlen ohne ausgeführte Assertions.
- Akzeptanz: Quellen mit Repo/Pfad/SHA/Datum; Befunde mit Evidenz/Task; Links/IDs/Status geprüft; keine Produkt- oder Nachbar-Codeänderungen.
- Abschlussbeleg: CM-015 vollständig erfüllt und Review-Commit vorhanden; PR nur bei verfügbarem API-Zugriff, sonst Review-Diff und klarer Blocker.

## CM-1

**Stabilität und Codequalität.** Status: geplant, lokale Fehlerarbeit unabhängig von der Plattform möglich.

- Ziel: reproduzierbare Webentwicklung und nachvollziehbare Fehler-/Trust-Aussagen.
- Deliverables: CM-002 Docker-/Env-Basis, CM-004 Web-CI, CM-006 sichere Dateihandoff-Prüfung, CM-008 Web-Fehlerbehandlung, CM-009 konsistente UI-Aussagen; Sessionentscheidung CM-007.
- Voraussetzungen: CM-0; bestätigte reproduzierbare Fälle und kleinste geeignete Änderung pro PR.
- Risiken: Sicherheitskorrekturen werden durch unpassende Mock-Erleichterungen verdeckt; lokale Fixes brechen Legacy-/native Pakete.
- Abhängigkeiten: keine Hub-/VPN-/Konfigurationsdienst-Pflicht; falls eine Betreiberentscheidung benötigt wird, nur diese Teilaufgabe blockieren.
- Akzeptanz: zielgerichtete Positiv-/Negativtests, Clean-Checkout-Webgates, echte Fehlerzustände bleiben sichtbar; keine Signatur-/Architekturausnahmen ohne konkrete Bindung.
- Abschlussbeleg: alle für den gewählten Umfang verpflichtenden CM-1-Tasks Done, CI-Laufbelege und verbleibende bewusste Risiken mit Eigentümerentscheidung.

## CM-2

**Nachweisbare Windows-Release-Qualität.** Status: geplant; CI-Self-Tests vorhanden, vollständige Zielsystemfreigabe offen.

- Ziel: vertrauenswürdig verteilbares, reproduzierbar nachgeprüftes Windows-Setup.
- Deliverables: CM-001 unabhängige Release-Vertrauenskette/Distributionsgate, CM-005 reale VM-Abnahme, CM-010 aufgelöste Installer-/Toolchain-Provenienz; Handoff-Härtung CM-006.
- Voraussetzungen: stabile CM-1-Basis für betroffene Bereiche, freigegebene isolierte Windows-Testumgebung und explizite Autorisierung echter Installationen.
- Risiken: CET-/Update-/DPI-Varianten, Herstellerrotationen, unsigned Ausnahmen, per-user/systemweite Verwechslung, unvollständige Nachprüfung.
- Abhängigkeiten: externe Signer-/Schlüsselentscheidung; Testinfrastruktur bleibt beim zuständigen Infrastruktur-Owner, Testvertrag/Assertions in configureMe.
- Akzeptanz: Clean VM ohne globales .NET, Produktions-Single-File, Erststart/echte DPI, alle Pflichtpakete, Fehler-/Abbruchfälle und Wiederholung geprüft; unabhängig überprüfbare Herkunft und vollständige Belege.
- Abschlussbeleg: keine unbekannten Pflichtprüfungen; aufgezeichnete Artefakt-/OS-/Versionen und Resultate, tatsächliche Signaturverifikation, menschliches Release-Review. Ein grüner Hosted Runner genügt nicht allein.

## CM-3

**Konfigurationsdaten und Profilverwaltung.** Status: Proposed, Implementierung durch Vertragsfreigabe blockiert.

- Ziel: myConfigs-data sicher nutzen, ohne Daten zu Installer-Code aufzuwerten.
- Deliverables: CM-003 Vertrag/Ownerreview, CM-011 versionierter Adapter mit Migrationstests, anschließend gegebenenfalls CM-012 read-only GitHub-Provider. Ein Schreibeditor ist eine separate spätere Freigabe.
- Voraussetzungen: abgestimmte Schemaidentitäten, Paket-/Workflow-Mapping, unveränderliche Snapshots und Fehlersemantik.
- Risiken: v1-Namenskollisionen, inkompatible IDs, Plattformfilterung mit stillen Paketverlusten, Offline-Stale-Zustände und Credential-Ausweitung.
- Abhängigkeiten: Datenowner-Review in separatem myConfigs-data-Auftrag; Centrality nur bei Änderung übergreifender Grenzen aktualisieren, niemals automatisch.
- Akzeptanz: atomare Gesamtvalidierung, fail-closed Negativfälle, Offline-/Snapshot-/Konflikttests; lokale Entwicklung bleibt ohne Nachbar-Repos möglich.
- Abschlussbeleg: akzeptierter Vertrag plus ausgeführte Produzenten-/Konsumententests und koordinierte Versionen. Der aktuelle Proposed-Text ist kein Implementierungsauftrag.

## CM-4

**Eigenständiger Betrieb und optionale Produktintegration.** Status: geplant/abhängig vom konkreten Bedarf.

- Ziel: klarer Workload-/Proxy-/Auth-Vertrag für Hosting und eventuell Hub-Navigation, keine zentrale Laufzeitabhängigkeit.
- Deliverables: CM-013 versionsgebundene Schnittstellen, Readiness-/Fehlervertrag, direkte API-Negativtests und dokumentierte Betreibergrenzen.
- Voraussetzungen: relevante CM-1/CM-2-Gates, entschiedenes Betriebs-/Expositionsmodell im autoritativen Repo.
- Risiken: VPN mit App-Autorisierung verwechseln, Header-Vertrauen ausweiten, gemeinsame Admin-/Datenbankkopplung einführen.
- Abhängigkeiten: Centrality sowie Home-/Cloud-/Hub-Owner nur für deren tatsächliche Grenze; kein pauschales Gesamtsystem-Monorepo.
- Akzeptanz: configureMe unabhängig start-/testbar; Proxy-/Origin-/Login-/Ausfallverhalten positiv und negativ geprüft, keine ungewollten öffentlichen Routen.
- Abschlussbeleg: expliziter akzeptierter Vertrag und reale Staging-Abnahme; Deployment benötigt einen gesonderten Auftrag.

## CM-5

**Spätere Geräte-Onboarding-Integration.** Status: **Blocked / Zukunft**, keine Implementierungsfreigabe.

- Ziel: nur nach Centrality-Entscheidung minimal berechtigten, zeitlich begrenzten Gerätezugang ermöglichen.
- Deliverables: zunächst ausschließlich CM-014: Proposed-Vertrag mit Ownern, AuthN/AuthZ/MFA, Geräteidentität, APIs/Versionen, Audit, TTL und serverseitigem Widerruf.
- Voraussetzungen: echte Betriebs-/Identity-/VPN-Control-Plane, Release-Trust und vorherige CM-2/CM-4-Nachweise; Freigabe der globalen Abhängigkeiten.
- Risiken: Enrollment-Tokenablauf wird mit Entzug aktiver Netzberechtigung verwechselt; kompromittierte Fremdgeräte und fehlendes Offboarding.
- Abhängigkeiten: globale Centrality-Phase 7 und deren Sicherheitsgates; Tailscale für eigene vertrauenswürdige Geräte autorisiert diese Integration nicht.
- Akzeptanz: anfangs nur vollständiger reviewter Vorschlag; spätere Implementierung erfordert separate Zustimmung sowie Negativtests für Ablauf, Widerruf, Offline/Crash, Schlüssel-/Scope-Trennung und minimale Rechte.
- Abschlussbeleg: lokale Vorbereitung schließt die globale Phase 7 ausdrücklich nicht ab. Keine Control-Plane, Geräteschlüssel oder temporären Netzrechte werden im aktuellen Auftrag implementiert.
