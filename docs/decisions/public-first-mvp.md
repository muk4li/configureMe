# Public-first Windows-Konfigurator: Produktauftrag und lokale Architektur

Stand 2026-11-13. Basis: configureMe `70a032ae19e2e0da0d39af5a5a5f8991f668e913`. Stufen A/B sind autorisiert; C/D haben zusätzliche Gates. Kein Deployment oder Merge.

## Verbindliche Produktentscheidungen

PD-001 (Eigentümerauftrag): Browser plant und liefert nach Freigabe Downloads; Ausführung lokal nach Bestätigung, ohne Portal-/Privatinfrastrukturverbindung oder Geräte-Agent. Herstellerdownloads bleiben möglich.

PD-002 (Eigentümerauftrag): öffentliche Profile künftig aus myConfigs-data als validierter, commitgebundener Snapshot; keine GitHub-Abfrage pro Request. Installertrust bleibt configureMe-Code. Der konkrete Datenvertrag ist noch **Proposed**, kein produktiver Import freigegeben.

PD-003 (Eigentümerauftrag): anonyme Änderungen nur in sessionStorage; keine Benutzerpersistenz, Secrets oder Identitätsbehauptung daraus.

PD-004 (Eigentümerauftrag): Windows 11 x64 und Server 2022 x64 Desktop Experience zuerst; vorhandene WinGet-/Serverstrategien, keine neue Engine. Planbarkeit ist kein tatsächlicher Kompatibilitätsnachweis jedes Pakets.

Diese lokalen Produktentscheidungen ändern keine Centrality-ADR automatisch. D-001/D-002/D-005/D-006 bleiben maßgeblich; D-007/ADR-002 sind im geprüften Register Proposed. Kein VPN/SSO-/Hub-/Netzwerkprojekt wird freigegeben. Globale Exposition/Deployment bleibt gesondert. Keine vertraulichen Inhalte übernommen.

## Geprüfter Ausgangsstand und parallele Arbeit

- `main`: 70a032a, bestehendes geschütztes Next.js-Portal, Einzelprofile, authentifizierter ZIP-Endpunkt, lokale Engine/EXE.
- Separater Engine-Fix: `fix/engine-cache-extraction-race`, `a1ab0b52a4f5560ec16734f38b96f7696a3867a5`, offener PR #8 laut öffentlicher PR-Liste. Windows-CI [43444854566](https://github.com/muk4li/configureMe/actions/runs/43444854566) bestanden. Dieser Feature-Branch übernimmt **keine Engine-/Windows-Teständerungen**; CM-016 bleibt dort reserviert. Vor einem Merge Dokumentationskonflikte kontrolliert zusammenführen.
- Centrality: `12776e9582cc2f9c413f40b7c6a9604f4b43e5b0`; 2026-11-13 erneut `docs/START-HERE.md`, `DECISIONS.md`, `docs/decisions/ADR-002-CONTRACT-OWNERSHIP.md`, `CURRENT-STATE.md`, `ROADMAP.md`, `SECURITY.md` geprüft.
- myConfigs-data: `75b91cfba94476393e7cfb4fe247b3f223aa4054`; 2026-11-13 erneut `docs/integration-configureme.md`, Profil-/Paketschemas geprüft. F-07/AF-003 weiterhin relevant: platform/platforms, $schema, IDs/Limits, Optionspflicht und v1-Namensraum inkompatibel. Keine fremden Änderungen.
- Git-Reads funktionieren; GitHub-API/GraphQL bleibt Forbidden. Offene PRs/CI daher über öffentliche GitHub-Seiten geprüft, kein vollständiger API-/Branch-Protection-Nachweis.

## Stufen A/B: kleinste lokale Architektur

Öffentliche Startseite mit eigenem Konfigurator; geschützte Routengruppe und bestehende Auth-APIs bleiben geschützt. Gemeinsame reine Planungsfunktion für Browserführung und erneute Serverprüfung, ohne fs, Prozesse, Installer oder Secrets. Ein ausdrücklich synthetischer, versionierter Fixturebestand wird lokal vollständig validiert; kein Produzentenimport vor Vertragsfreigabe.

Die Zielplattform ist Windows 11 oder Server 2022, Architektur ausschließlich x64. Windows 11 verwendet nur bekannte WinGet-fähige Katalogstrategien; Server 2022 seine vorhandenen automatischen/manuellen/detection-only/Web-Modi. Legacy-Aliase werden nicht global umgeschrieben. Unbekannte IDs, ungültige Fixtures und Zyklen scheitern geschlossen.

Mehrfachprofile werden nach stabilen IDs sortiert vereinigt; Paket-ID-Deduplizierung, sortierte transitive Abhängigkeiten und Herkunft pro Profil. Explizite Zusätze/Entfernungen folgen danach. Benötigte entfernte Abhängigkeiten bleiben sichtbar im Ergebnis und blockieren die Freigabe. Gegenläufige Profiloptionen sind Konflikte; zulässige explizite Sitzungsoptionen können sie auflösen. Kein last-write-wins durch Profilreihenfolge. Plattformwechsel behält die Auswahl und zeigt Inkompatibilitäten; keine stille Teilübernahme.

POST /api/public/plan nimmt nur einen begrenzten deklarativen Auswahlvertrag an, lädt keine fremden Profile und berechnet alles neu. Der Export ist **nicht ausführbares Preview-JSON**, kein vorhandenes Installerplanformat. Er wird nur nach erfolgreicher Serverprüfung angeboten. Kein anonymer ZIP-/EXE-Endpunkt und kein öffentlicher Aufruf des bestehenden /api/bootstrap. Produktive Setup-Downloads bleiben gesperrt, bis CM-001/005/006/010 erfüllt und Distribution gesondert freigegeben sind.

## Sicherheits- und Migrationsplan

Öffentliche Daten ausschließlich Fixtures/Katalogmetadaten. Strict-Schemas, Maximalzahlen/Längen, maximal 8 KiB Request, begrenzte Bodylesezeit, globales Prozess-Ratelimit und Parallelitätslimit. JSON-/Same-Origin-/Fetch-Metadata-Prüfung ist Missbrauchsschutz, keine Authentifizierung. Keine CORS-Freigabe, keine Cookie-/OAuthabhängigkeit. Rate-/Parallelitätslimits sind pro Prozess; TLS, Proxy-/Verbindungs-/globale Ressourcenlimits und echte Internetabnahme bleiben Deploymentvoraussetzungen.

Sessiondaten gelten als untrusted: bytebegrenzt, versioniert, strikt validiert, keine Profile/URLs/Befehle aus dem Browser. Unbekannte/defekte/veraltete Daten werden verworfen; verweigerter Storage fällt auf Arbeitsspeicher zurück. Browserzustand ist nie Sicherheitsautorität. Bestehende private Profile werden nicht öffentlich gemacht. Keine Änderung des HMAC-/Allowlist-/Sessionvertrags.

Migration in getrennten PRs: A Dokumentation; B Fixtureplanung/öffentliche UI/Preview-API/Browserprüfung; C erst nach akzeptiertem Snapshotvertrag; D erst nach verifiziertem lokalem Planadapter und unabhängiger Releasefreigabe. Legacy-Portal bleibt zunächst kompatibel, erhält keine anonymen Rechte.

## Downloadalternativen für spätere Stufe D

| Weg | Sicherheit/Kompatibilität | Größe/Wartung |
| --- | --- | --- |
| ZIP mit validiertem Plan und eigenständigem Bootstrap | kleinste MVP-Lösung; vorhandene plattformspezifische Validierung, Bestätigung und Trustregeln wiederverwenden; separat authentifizierte Herkunft nötig | klein, wenig zusätzliche Toolchain; PS5.1/WinGet bzw. Serverpfad unterscheiden |
| ZIP mit Plan und nativer GUI | gute lokale Auswahl-/Report-UX; validierter Planimport und signierte GUI müssen erst nachgewiesen werden | großes self-contained Artefakt, zusätzlicher Publish-/Releaseprozess |
| Native GUI und separate Plan-Datei | wiederverwendbare GUI; Plan ist untrusted, muss vor jeder Wirkung validiert und an Version/Workflow gebunden sein | GUI einmal groß, Pläne klein; Dateizuordnung/Versionsdrift/Importfehler zusätzlich testen |

Empfehlung **Proposed**: zuerst ZIP/Bootstrap nach Freigabe; keine dynamische EXE. Der neue Previewvertrag darf nicht ungeprüft in ein existierendes Installationsschema umbenannt werden. Lokaler Adapter muss OS-Build, x64, Paket-/Optionssemantik, Grenzen, Herkunft und Idempotenz erneut prüfen. Keine automatische Aktivierung per Environment-Flag in Stufe B.
