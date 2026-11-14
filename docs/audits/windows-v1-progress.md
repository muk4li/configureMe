# Windows-v1: Reviewfortschritt und verbleibende Freigaben

2026-11-14. Geprüfter Default-Branch: `f744d63c5d245f113e3104161abf04d9f5e900e1`, PR #12 gemergt. **Die folgenden Änderungen liegen in separaten Review-Branches, nicht in main.** Keine eigenen Merges nach main, echten Installationen, Hostkonfiguration, Releases oder Signierungen. [Ausgangsprüfung und Architekturautorität](windows-v1-baseline.md).

## Implementierte Reviewpakete

| Paket / Task | Branch | Tatsächlich getesteter Code | Vollständige CI |
| --- | --- | --- | --- |
| A / CM-032 | docs/windows-v1-baseline | reine Dokumentationspflege, 87474c5 | Links/IDs/Status/Scope; bestehende main-CI separat belegt |
| B / CM-033 | feature/imported-plan-execution-contract | d2c8aba | [Windows 43564728870](https://github.com/muk4li/configureMe/actions/runs/43564728870), inklusive 20 neuer Reviewfälle |
| D / CM-034 | feature/windows11-preview-preparation | c035c99 | [Windows 43564860415](https://github.com/muk4li/configureMe/actions/runs/43564860415), 12 synthetische Kandidatenfälle |
| E / CM-035 | test/public-snapshot-boundaries | 4848a0f | [Web 43564368520](https://github.com/muk4li/configureMe/actions/runs/43564368520), lokal 100 Tests + 1 Linux-Skip |
| F / CM-036/038 | fix/installer-handoff-lock | d5c6a52 | [Windows 43564614212](https://github.com/muk4li/configureMe/actions/runs/43564614212), PS5.1/7-Inhaltslocks und gesamte GUI-/Publishsuite |
| F-Folge / CM-037 | feature/installer-provenance | d8f79c9 | [Windows 43565667258](https://github.com/muk4li/configureMe/actions/runs/43565667258), 25 neue PS-Provenienzassertions + Aggregate-Test |
| G / CM-039 | fix/installer-mode-disclosures | 7742d44 | [Web 43565106502](https://github.com/muk4li/configureMe/actions/runs/43565106502), lokal 101 Tests + 1 Linux-Skip |
| Sicherheitsfolge / CM-040 | fix/oauth-state-byte-length | 549a85b | [Web 43565869811](https://github.com/muk4li/configureMe/actions/runs/43565869811), lokal 104 Tests + 1 Linux-Skip |
| Checkoutfolge / CM-041 | fix/docker-checkout-inputs | 73db0ef | [Web 43566003380](https://github.com/muk4li/configureMe/actions/runs/43566003380); Docker selbst ausdrücklich nicht geprüft |

Alle genannten CI-Läufe erfolgreich. Windows-Workflows führen PS5.1/7-Fixtures, drei vollständige GUI-/Controller-/Engine-Suiten, portable Tests, restriktive Build-Prozesspolicy, Single-File-Publish und EXE-Self-Tests aus; keine echten Drittanbieterinstaller. Webmatrix prüft Linux/Windows und 22 Linux-Browserfälle. Finale Nachweis-/Triggerbereinigungscommits sind keine neu getesteten Produktänderungen. Alle temporären Review-Pushtrigger danach entfernt, normale main/PR/manual-Trigger erhalten.

Alle Featurebranches basieren direkt auf main außer **feature/installer-provenance**: kontrollierte Abhängigkeit auf **fix/installer-handoff-lock**, zuerst Handoff reviewen/übernehmen, dann Provenienz. Keine neuen Profile-/Katalog-/Planversionen, neue Dependencies oder Authsysteme. Gemeinsame append-only Dokumentations-/Projektlisten können beim Reviewmerge zusammengeführt werden; IDs erhalten, keine Featurevorbereitung dadurch aktivieren.

## Konkrete Änderungen und Grenzen

B erzeugt katalog-/ziel-/snapshotgebundene read-only Reviewdaten, prüft vollständige eindeutige Workerbeobachtungen, behält unklare Detection/Rechte/manuelle Modi und verwirft Abbruch/late results. **Kein Execute-/Authorize-API, keine GUI-Registrierung**; Ausführungsvertrag bleibt Proposed.

D prüft eigene Windows-11-Client/Build/x64-Kandidaten und Fixturebeobachtungen, behält unsupported Pakete und verwendet keinen Server-Installerplan als WinGet-Nachweis. Nativer Import bleibt gesperrt; kein echter Windows-11-Test wird behauptet.

E dokumentiert konkrete Unterschiede einschließlich Producer-Reihenfolge versus sortierter Vereinigung, Limits, Identitäten und expliziten Zielworkflows. Synthetische source-shaped Daten bleiben durch echte Consumer abgelehnt. Kein Adapter/Provider oder private Datenkopie.

F hält verifizierte Installerdateien vor Prüfung bis Prozessende gegen Schreiben/Löschen gesperrt. Der alte Mockfall ließ geänderte Bytes bis zum Runner gelangen; neue Windowsfälle verweigern Mutation und bestehende Writer. **CM-006 bleibt umfassend offen**: Parent-Namespace/ACL-/Privileggrenzen sind nicht vollständig atomar abgesichert. Release-Vertrauensplan und ausführbare Zielmatrix sind Vorbereitungen, keine reale Abnahme.

Provenienz erhält Hash/Größe, erwartete Hashes, denselben Signaturbefund, Paket-/Feedversion, redigierte konfigurierte und tatsächlich beobachtete finale URI im JSONbericht, auch nach späterem Prozessfehler. Cache-Final-URI bleibt unbekannt. Ursprüngliche Pfadhashprüfung bleibt erhalten und muss gegen den gehaltenen Stream übereinstimmen. **CM-010 bleibt für Build-/Toolchainbindung und separate finale Apparchitektur offen**, SHA ist keine unabhängige Authentizität.

G korrigiert CPython-Vollinstaller/7-Zip-Unsigned-Ausnahme und verständliche leere/HTML/trunkierte Fehler; tatsächliche ZIPbytes bleiben erhalten, ZIP-Header ist keine Trustprüfung. OAuthfolge behebt den mit zwei Rotfällen belegten UTF16/UTF8-Längenfehler ohne Session-/Allowlistlockerung. Checkoutfolge stellt fehlenden public-COPY-Eingang und leere Envvorlage bereit; echte Envdateien bleiben ignoriert. **CM-002/041 bleiben offen**, weil Docker-Socketzugriff fehlt; keine Rechte-/Gruppenänderung als Umgehung.

## v1-Reife (main versus Vorbereitung)

| Bereich | Belegbarer Status |
| --- | --- |
| Öffentliche Planung | Implementiert/Getestet in main; keine Betriebs-/Veröffentlichungsbehauptung |
| JSON-Export | Implementiert/Getestet in main, versioniert/kataloggebunden |
| Nativer Import | Implementiert/Getestet für Server 2022 in CI |
| Detection/Dry-Run | Implementiert/Getestet in CI; zusätzliche Review-/Fehlergrenzen vorbereitet |
| Kontrollierte Installation | Bestehender manueller Pfad implementiert/mockgetestet; importierte Installation Blockiert |
| Server 2022 | Hosted CI Getestet; frische interaktive VM-/Herstellerabnahme Blockiert |
| Windows 11 | Contract implementiert; unregistrierte Vorbereitung synthetisch Getestet; native Aktivierung Blockiert |
| Öffentliche Profildaten | Lokale synthetische Fixtures Getestet; produktive Snapshotquelle Blockiert |
| Release-Sicherheit | Vorbereitungen Implementiert/Getestet; unabhängige Signierung/Distribution Blockiert |
| Wiederholbare Einrichtung | Detection/Skip-/Fehlerpfade implementiert/mockgetestet; keine vollständige reale Idempotenzzusage |

Kein neues Paket wird als öffentlich signiert/veröffentlicht dargestellt. Lokale Cloud-Build-/Browser-/VSTest-Sockets waren eingeschränkt; echte Suiteergebnisse stammen aus den verlinkten Workflows, Crossbuild/temporäre In-Process-Diagnosen werden nicht damit gleichgesetzt. `npm ci` wurde mit Lockfile und Workspacecache ausgeführt; keine neue Dependency.

## Tatsächlich benötigte Eigentümerentscheidungen

1. **Ausführungsvertrag und Paket C:** vorgeschlagenen Vertrag nach Review akzeptieren und die anschließende mockgetestete Integrationsphase ausdrücklich autorisieren; Aktivierung/echte Installationen gesondert lassen. Alternative: Import weiter nur Dry-Run. Risiko: veraltete Detection/Consent oder Handoffgrenzen; Schutzbereich lokale Installerautorität. B und negative Tests sind ohne Entscheidung fertig.
2. **Isolierte Zielabnahme:** autorisierte Windows-11-/Server-VMs und zunächst nichtinstallierende Plattform-/Detection-/Dry-Run-Prüfung bereitstellen; reale Herstellerinstallation separat freigeben. Alternative: Kandidaten weiter gesperrt. Risiko: OS/CET/Rechte/DPI und tatsächliche Version/Architektur; Matrix bereits vorbereitet.
3. **Öffentlicher Datenvertrag:** freigegebenen Dateisatz, Zielworkflow-/ID-Mapping, Reihenfolge, Limits und Offline-/Revisionswechsel explizit gemeinsam akzeptieren. Empfehlung: versionierter Snapshot aus der bestehenden Quelle, kein neues Repo. Alternative getrenntes öffentliches Repo erfordert Centrality-Review. E-Entscheidungsvorlage/Tests sind fertig; kein Provider aktiv.
4. **Publisher-/Releaseidentität:** geschützte nicht exportierbare Signeridentität und unabhängig verifizierte Freigabekette wählen. Alternative ausschließlich unsignierte Entwicklungsartefakte behalten. Risiko Schlüsselverlust/kompromittierte Distribution; keine Secrets benutzt, Trustplan/Prüfmatrix fertig.

GitHub-API-POST bleibt Forbidden; gepushte Reviewbranches und fertige PR-Beschreibungen/Comparelinks sind der ausdrücklich erlaubte Ersatz. Kein automatischer Merge oder Branch-Protection-Eingriff. Diese Entscheidungen betreffen konkrete reviewbare Ergebnisse, keine erfundenen globalen Freigaben.
Bei der ursprünglichen Vorbereitung war GitHub-API-POST Forbidden; deshalb wurden gepushte Reviewbranches und fertige Beschreibungen/Comparelinks bereitgestellt. Nach Freigabe des API-Zugriffs und ausdrücklichem Folgeauftrag wurde der vollständige [PR #13](https://github.com/muk4li/configureMe/pull/13) gegen main erstellt. Kein automatischer Merge oder Branch-Protection-Eingriff. Diese Entscheidungen betreffen konkrete reviewbare Ergebnisse, keine erfundenen globalen Freigaben.

## Zusätzlicher gemeinsamer Integrationstest

Alle Reviewpakete wurden nur auf `test/windows-v1-review-integration` zusammengeführt, nicht auf main und nicht als riesiger Produkt-PR. Code `9775d28baee0d32cd34ecb2820dc0546ca654022`: [Web-CI 43585849918](https://github.com/muk4li/configureMe/actions/runs/43585849918) und [Windows-CI 43585849765](https://github.com/muk4li/configureMe/actions/runs/43585849765) erfolgreich; lokal 115 Tests + 1 expliziter Linux-Skip, Typecheck/Lint und beide .NET-Crossbuilds grün. Alle 41 stabilen Task-IDs und Compileeinträge erhalten. Temporäre Testtrigger danach entfernt; Ausführungs-/Releasegrenzen unverändert. Dieser gemeinsame Test belegt das Zusammenwirken, ersetzt aber keine echten Zielsystem-/Hersteller-/Signierungsfreigaben.
