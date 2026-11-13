# Initialaudit: Engineering-Baseline für configureMe

**Prüfdatum:** 2026-11-13 (Europe/Berlin). **Implementierungsbasis:** Default-Branch `main`, Commit `23fdea3b1dec546fbf73ab930096078ba73419e1`. **Umfang:** statische Anwendungs-/Windows-/Supply-Chain-Analyse mit gezielten ungefährlichen Laufzeitproben und Dokumentationsaufbau. Keine Produktfunktion, Schemaänderung, echte Installation, Deployment, Netzwerk-/Secretänderung oder Nachbar-Repo-Schreiboperation.

Einstieg: [REPO.md](../../REPO.md), [AGENTS.md](../../AGENTS.md), [Roadmap](../../ROADMAP.md), [Aufgaben](../../TASKS.md), [Proposed-Vertrag](../integrations/configuration-contract-proposal.md).

## Ergebnis und Statusdisziplin

configureMe ist ein eigenständig implementiertes Planungs-/Downloadportal plus lokales Windows-Setup-System, kein leeres Scaffold und kein Remote-Execution-/VPN-Agent. Strikte Profile, feste Katalogstrategien, bestätigte lokale Installation, Hash-/Signer-/Architekturprüfungen, Worker-Isolation und Berichte sind reale Codebausteine. Die aktuelle Web-/Mock-/Crossbuild-Basis ist funktionsfähig; daraus folgt weder vollständige Server-2022-E2E-Kompatibilität noch eine sichere öffentliche Distribution unsignierter Artefakte.

Centrality wurde zuerst gelesen; Nachbarquellen wurden anschließend ausschließlich für Zuständigkeiten und tatsächliche/geplante configureMe-Schnittstellen geprüft. D-001/D-002/D-005/D-006 bleiben Accepted; D-007 und ADR-001/002 sind im gelesenen Register **Proposed**, ADR-003 ist eine strategische Eigentümerentscheidung und kein Betriebsnachweis. Dieser Audit übernimmt keine privaten Host-, Netzwerk-, Recovery- oder Personendetails. Er ändert keine Centrality-Entscheidung.

- **Confirmed:** konkrete Code-/Dateievidenz, gegebenenfalls gezielte Reproduktion. Keine automatische Aussage über erfolgreichen Missbrauch.
- **Probable:** begründetes Risiko mit begrenztem Test, weitere Zielsystemverifikation nötig.
- **Unverified:** notwendiger Nachweis nicht vorhanden/ausgeführt; keine behauptete Fehlfunktion.
- **Accepted Risk:** nur mit ausdrücklicher referenzierter Eigentümerentscheidung. Keiner der Befunde wird hier einseitig so eingestuft.

Schwere und Priorität beziehen sich auf die betroffene Freigabe. Eine hohe Distributionslücke behauptet keine bereits öffentlich kompromittierte Installation. Lokaler Auditabschluss CM-015 schließt keine Produktphase oder globale Centrality-Phase ab.

## Architektur- und Qualitätsabgleich

| Bereich | Nachgewiesener Code | Grenze / Bewertung |
| --- | --- | --- |
| Web | Next.js App Router; öffentliche Seite/Health; geschützte Routengruppe; Profile-/Bundle-APIs | keine Geräteausführung; Fehlerpfade und Web-CI lückenhaft |
| UI | React-Wizard, Portalshell und WinForms | keine pauschale Neuarchitektur nötig; einzelne Trusttexte falsch (AF-009) |
| Auth | GitHub-OAuth mit State, Allowlist, HMAC-HttpOnly-Sessions, Originprüfung | keine OIDC-/MFA-/zentrale Widerrufsintegration; AF-007/008 |
| Daten | sechs lokale Profile, JSON-Schema plus strengere semantische Zod-Prüfung; lokaler Provider | Interface ist keine GitHub-Provider-Implementierung; F-07 bestätigt |
| Planung | serverseitige ID-/Plattformprüfung, Abhängigkeiten/Zyklen, begrenzte Pläne | Client hat vereinfachte zweite Auflösung; Server bleibt Sicherheitsgrenze; Workflowvertrag bei Datenintegration offen |
| Windows | .NET-10-WinForms, self-contained Single-File, feste PS5.1-Workerpfade, JSON-lines | Crossbuild/Self-Test ist keine vollständige frische VM-Abnahme |
| Engine | feste Quellen, TLS/Redirects, Hashes, PE/MSI/MSIX-Prüfung, gezielte Signer und Bootstrapper | Handoff nach Prüfung nicht atomar belegt (AF-006); keine generische Ausnahme freigeben |
| Ausführung | maximal zwei Downloads, serielle Queue, aktive Installer nicht abbrechen, per-user/systemweite Rechte | keine Selbst-Elevation; neue reale Installationsversuche benötigen eigene Freigabe |
| Erkennung | tatsächliche x64-Versionen, pip/SDK-Prüfung, Registrierungs-/Dateipfade und begrenzte Nachprüfversuche | Hersteller-/OS-Varianten und echte Wiederholung bleiben Bestandteil CM-005 |
| Berichte | package-/phasenbezogene Fehler, Neustartstatus, JSON/Text, aggregierte GUI-Berichte | keine vollständige aufgelöste Binary-Provenienz (AF-010) |
| Distribution | commit-/dirty-Metadaten, Datei-/ZIP-Prüfsummen, embedded Manifest | unsigned; keine unabhängige Publisherauthentifizierung |
| Betrieb | Node-Standalone/Docker/Compose beschrieben, Loopback-/Least-Privilege-Vorgaben | Clean-Checkout-Voraussetzungen fehlen; kein Homelab-/Cloud-/Hub-Betrieb nachgewiesen |

Die vorhandenen Module sind fachlich sinnvoll. Keine zusätzliche Plattform, Datenbank, Pluginarchitektur, allgemeine Installer-DSL oder zentrale Konfigurations-Control-Plane wird aus diesem Audit abgeleitet. Ein GitHub-Provider bleibt abhängig von einem vereinbarten Datenvertrag. Auth- und Installer-Trust sind verschiedene Grenzen.

## Befunde

### AF-001

**Unabhängige Release-Vertrauenskette fehlt.** Schwere: **Hoch vor öffentlicher vertrauenswürdiger Distribution**. Kategorie: Supply Chain. Status: **Confirmed**. Task: [CM-001](../../TASKS.md#cm-001).

**Betroffene Komponente:** Release und Bootstrap-Distribution.

- Komponente/Fundstellen: `bootstrap/windows-server-2022-developer/SECURITY.md:5`, `scripts/New-SetupReleasePackage.ps1`, `scripts/New-WindowsServer2022QuickSetup.ps1`, `src/lib/server-bundle.ts:45`.
- Evidenz: EXE/ZIP ausdrücklich unsigned; SHA-256/Manifest kommen mit dem Artefakt. Portal-Quellcommit kann null sein bzw. stammt aus Laufzeitkonfiguration. Embedded Ressourcen authentifizieren sich nur relativ zur EXE.
- Risiko: Austausch eines Pakets samt Prüfsummen wird nicht durch einen unabhängig verteilten Trust Anchor erkannt. Session-HMAC/HTTPS ersetzt keine Release-Signatur; blockiert öffentliche Trust-/spätere Gerätezugangsfreigabe.
- Prüfung: Security-/Packagingquellen gelesen; beide ZIP-Manifeste lokal gegen alle Dateien geprüft; unsigned-/dirty-Kennzeichnung erhalten. Kein aktueller Angriff oder vollständiger Signer-/Releasebetrieb behauptet.
- Maßnahme: Optionen/Ownerentscheidung für unabhängige Verifikation und Distributionsgate vorbereiten; echte Signer-/Credentialoperation separat freigeben.

### AF-002

**Dokumentierter Clean-Checkout-Deploymentpfad ist unvollständig.** Schwere: **Mittel**. Kategorie: Reproduzierbarkeit/Betrieb. Status: **Confirmed**. Task: [CM-002](../../TASKS.md#cm-002).

**Betroffene Komponente:** Web-Dockerbuild und Deploymentanleitung.

- Fundstellen: `Dockerfile:21`, `docs/deployment.md:8` und `:19`, `.gitignore`, Root-README.
- Evidenz: `COPY --from=builder /app/public ./public`, aber `git ls-tree HEAD public .env.example` liefert keine Einträge; beide dokumentierten Voraussetzungen fehlen im geprüften Git-Baum. `.env*` wird allgemein ignoriert.
- Risiko: ein sauberer Docker-Kontext kann den geforderten public-Pfad nicht liefern; Setup-Anweisungen können nicht unverändert befolgt werden. Lokaler vorhandener Buildzustand kaschiert dies.
- Prüfung: Git-Baum, Dockerfile und Anleitung verglichen. **Dockerbuild/Containerstart nicht ausgeführt**; bestätigte fehlende COPY-/Anleitungs-Voraussetzung, kein behaupteter Docker-Laufbeleg.
- Maßnahme: minimale Asset-/COPY-/Env-Korrektur und Clean-Checkout-Regression ohne echte OAuth-Werte.

### AF-003

**F-07: zwei inkompatible v1-Profilverträge.** Schwere: **Mittel, integrationsblockierend**. Kategorie: Datenvertrag. Status: **Confirmed**. Task: [CM-003](../../TASKS.md#cm-003); spätere Umsetzung CM-011/012.

**Betroffene Komponente:** Profilprovider und Cross-Repo-Datenvertrag.

- Fundstellen: `src/lib/profiles.ts:7`, `:73`, `:79`, `schemas/profile.schema.json`, `profiles/minimal.json`; Datenrepo `schemas/profile.schema.json`, `schemas/package-selection.schema.json`, `docs/integration-configureme.md` am Quellstand im Register.
- Evidenz: lokales `platform` gegen `platforms` plus `$schema`, unterschiedliche Limits/Optionspflicht und ID-Muster; `7zip` scheitert am Datenregex mit Buchstabenanfang. **Keine feste Paket-Enum im Daten-Schema**; echte Katalogkenntnis bleibt Consumeraufgabe. Quellkatalogrevision und Consumer-Katalogversion sind nicht gleichbedeutend.
- Risiko: blindes Kopieren, ungeprüftes Alias-Mapping oder Gleichsetzen von v1 erzeugt Fehler oder falsche Workflowannahmen. Datenrepo beschreibt Consumer noch als leer; heute ist nur der lokale Consumer implementiert.
- Prüfung: echte Producer-AJV-Schemas lokal registriert, alle sechs configureMe-Profile dagegen; alle fünf Datenrepo-Profile gegen das echte configureMe-Zod-Schema. **Alle elf erwartungsgemäß abgelehnt.** Eigene Datenvalidierung besteht.
- Maßnahme: [versionierter Adaptervorschlag](../integrations/configuration-contract-proposal.md), ausdrücklich Proposed. Kein Provider, keine Migration oder fremde Dateiänderung in diesem Auftrag.

### AF-004

**Webgates und plattformgetreue Testzählung fehlen.** Schwere: **Mittel**. Kategorie: CI/Testqualität. Status: **Confirmed**. Task: [CM-004](../../TASKS.md#cm-004).

**Betroffene Komponente:** Webtests und CI.

- Fundstellen: einzige Workflowdatei `.github/workflows/windows-quicksetup.yml:16`; `package.json`; `tests/configuration.test.ts:80`.
- Evidenz: Workflow prüft Windows/PowerShell/.NET, ruft aber weder npm-Test/Lint/Typecheck noch Next-Build auf. Ein Vitest-Fall kehrt auf Nicht-Windows vor sämtlichen Assertions zurück und wird dennoch als passed gezählt.
- Risiko: Webregression kann trotz grünem Windowslauf nach main gelangen; „15 passed“ auf Linux beweist nicht den Windows-Parserfall. Fehlende CI ist kein Beweis, dass der heutige Build fehlschlägt.
- Prüfung: lokal alle Webbefehle bestanden; Vitest meldet 15, davon 1 Windowsfall ohne ausgeführte Assertion. Workflow statisch vollständig gelesen.
- Maßnahme: kleine Webgates und echte Windows-Parserprüfung bzw. explizite Skips, keine Assertions entfernen.

### AF-005

**Vollständige Zielsystemabnahme bleibt unbelegt.** Schwere: **Mittel bis Hoch vor Release**. Kategorie: Windows/QA. Status: **Unverified**. Task: [CM-005](../../TASKS.md#cm-005).

**Betroffene Komponente:** Windows-Setup und Zielsystem-QA.

- Fundstellen: `windows/ConfigureMe.Setup/README.md:25`, `docs/windows-setup-0.3.0-retest.md`, Workflow-Publish/Self-Tests.
- Evidenz: dokumentierte interaktive Abnahmepflichten; Hosted Runner mit vorhandener SDK-/OS-Umgebung und eingeschränktem PATH ist keine frische VM ohne .NET. Bedienberichte ersetzen kein vollständig versioniertes Pflichtszenario-Artefakt.
- Risiko: CET/Updates, echte DPI, Herstellerinstallation, Neustart, Konto-/Rechtekontext und Wiederholung können abweichen, obwohl Mocks/Self-Tests bestehen.
- Prüfung: Linux-Crossbuild und portable Tests heute; öffentlicher historischer Windows-CI-Erfolg für denselben Implementierungscommit beobachtet. Keine echte Windows-GUI oder Drittanbieterinstallation heute ausgeführt.
- Maßnahme: isolierte, ausdrücklich freigegebene VM-Abnahme und Testharness-Vertrag mit Infrastruktur-Owner. Kein neues Produktfeature als Ersatz.

### AF-006

**Möglicher Dateiaustausch zwischen Verifikation und Start.** Schwere: **Hoch unter lokaler Angreifer-/Elevationsannahme**. Kategorie: lokaler Trust/Supply Chain. Status: **Probable**. Task: [CM-006](../../TASKS.md#cm-006).

**Betroffene Komponente:** Installer-Cache, Engine-Extraktion und Workerstart.

- Fundstellen: `modules/Installation.psm1:32`, `:475` bis `:493`; `EngineBundle.cs:125`; `PowerShellWorkerClient.cs:74` bis `:111`. Modulpfade liegen unter `bootstrap/windows-server-2022-developer/`, C# unter `windows/ConfigureMe.Setup/`.
- Evidenz: Hash-/Signaturlesen und nachfolgender pfadbasierter Prozessstart sind getrennte Operationen; kein durchgehender schreibsperrender Handoff belegt. Cache/Engine liegen im per-user Kontext, auch wenn später mit Rechten gestartet wird.
- Prüfung: synthetische x64-PE-Fixture, korrekter Fixturehash und gemockter Signer; `ProgressCallback` verändert Bytes nach `verification-completed`, `ProcessRunner` beobachtet geänderten Hash. **Kein EXE gestartet, keine echte Signatur umgangen, keine Windows-ACL-/Privilegieneskalation getestet.** Das belegt den Mock-Handoff, nicht den realen Exploit.
- Risiko: lokale Manipulation/Parallelität könnte eine höhere Ausführungskontextgrenze verletzen. Reparse-Point-Prüfungen sind nützlich, allein aber kein atomarer Windows-Dateisystem-/ACL-Nachweis.
- Maßnahme: konkrete Angreiferrechte und Cross-Process-Dateizugriffe prüfen, sichere Handoff-/Rechte-/Lockstrategie mit Positiv-/Negativtests entwickeln. Nicht pauschal die bestehende Engine für unsicher erklärt.

### AF-007

**Allowliständerung widerruft bestehende Sessions nicht sofort.** Schwere: **Mittel**, spätere privilegierte Integration gesondert. Kategorie: Auth-Lebenszyklus. Status: **Confirmed**. Task: [CM-007](../../TASKS.md#cm-007).

**Betroffene Komponente:** Web-Session und Login-Allowlist.

- Fundstellen: `src/lib/auth.ts:5`, `:30`, `:61`, `:85`; OAuth-Callback.
- Evidenz: Allowlist beim Login; `getSession` prüft danach nur HMAC/Claims/Ablauf. Synthetisch ausgegebenes Cookie bleibt gültig, obwohl `isAllowedUser` nach Entfernen false liefert. Maximalalter acht Stunden; Logout löscht nur das lokale Cookie.
- Risiko: unerwartete Restberechtigung nach Benutzerentzug. Kein bestehendes VPN-/MFA-/Admin-Control-Plane-Recht daraus ableiten; solche Systeme existieren hier nicht.
- Prüfung: echte Authfunktionen mit kurzlebigem synthetischem In-Memory-Testsecret, keinerlei reale Credentialverwendung.
- Maßnahme: gewünschte Revocation-/Rollen-/Rotationssemantik entscheiden und minimal testen, keine Datenbank aus Gewohnheit hinzufügen. Stateless-Design ist dokumentiert, aber hier nicht als ausdrücklich Accepted Risk eingestuft.

### AF-008

**OAuth-State-Längenprüfung verwendet Zeichen statt Bytes.** Schwere: **Niedrig**. Kategorie: robuste Fehlerbehandlung. Status: **Confirmed**. Task: [CM-008](../../TASKS.md#cm-008).

**Betroffene Komponente:** GitHub-OAuth-Callback.

- Fundstelle: `src/app/api/auth/github/callback/route.ts:27` und `:32`.
- Evidenz: gleich lange JavaScript-Strings können verschieden lange UTF-8-Buffer erzeugen; `timingSafeEqual` steht vor dem try-Block. 64-mal `é` gegen 64 ASCII-Cookiezeichen erzeugt RangeError/HTTP 500.
- Risiko: unkontrollierter Fehler auf ungültigem Input, kein nachgewiesener Login-/CSRF-Bypass.
- Prüfung: lokaler Produktionsserver, synthetisches State-Cookie und Code; erwarteter HTTP 500 ohne Tokenaustausch/externen OAuth-Aufruf reproduziert.
- Maßnahme: Byte-Längen vor konstantzeitlichem Vergleich prüfen, fail-closed Authfehler liefern und Unicode-/Malformed-Fälle testen.

### AF-009

**Wizard verspricht falsche Installer-/Trust-Eigenschaften.** Schwere: **Mittel**. Kategorie: Sicherheitskommunikation/Drift. Status: **Confirmed**. Task: [CM-009](../../TASKS.md#cm-009).

**Betroffene Komponente:** Web-Setup-Wizard.

- Fundstellen: `src/components/setup-wizard.tsx:13` und `:16`; aktuelle Python-/7-Zip-Definitionen in `modules/Installation.psm1`.
- Evidenz: gerendert „Official Python install manager“ und „Official signed installer“ für 7-Zip; Engine verwendet klassischen CPython-Vollinstaller und eine ausdrücklich hashgebundene unsigned-MSI-Ausnahme.
- Risiko: Benutzerreview erhält unzutreffende Vertrauensaussage, obwohl die eigentliche Engine keine globale Signaturausnahme macht. Doppelt gepflegte UI-Modustexte können weiter driften.
- Prüfung: Chromium-Wizard mit synthetischer lokaler Session bis Paketauswahl durchlaufen; beide veralteten Texte gerendert gesehen.
- Maßnahme: Modustexte konsistent machen und gerenderte Aussagen prüfen, keine Sicherheitsroutinen abschwächen.

### AF-010

**Aufgelöste Binary-/Toolchain-Provenienz ist unvollständig.** Schwere: **Mittel**. Kategorie: Reporting/Reproduzierbarkeit. Status: **Confirmed**. Task: [CM-010](../../TASKS.md#cm-010).

**Betroffene Komponente:** Installerberichte und Release-Toolchain.

- Fundstellen: `modules/Logging.psm1:54`, Paketresultatzuweisung in `GuiWorker.psm1`, `windows/ConfigureMe.Setup/SetupRunReport.cs`, dynamische Definitionen in `Installation.psm1`; `package.json`, Dockerfile, CI/.NET-Projekte.
- Evidenz: Berichte speichern Version, Source, Methode, Status/Fehler; keine vollständige tatsächliche Final-URI-/Binary-Digest-/Signerbindung. Einige Versionen werden zur Laufzeit aufgelöst, Vendorhashes sind nicht bei jedem Paket verfügbar. SDK-/Imagebereiche und Transitivauflösung sind nicht vollständig fest eingefroren.
- Risiko: derselbe Produkt-Codecommit führt nicht zwangsläufig zu identischen Herstellerbytes/Buildwerkzeugen; Rekonstruktion und Incidentanalyse erschwert. Vorhandene Signatur-/Hashprüfungen bleiben sinnvoll.
- Prüfung: Reportmodelle und Paketdefinitionen verglichen, Build-/ZIP-Provenienz tatsächlich gelesen. Kein CVE- oder vollständiges SBOM-/Dependency-Scan-Zertifikat erteilt.
- Maßnahme: aufgelöste sichere Metadaten/Toolchainbelege berichten und Redaktions-/Signaturrolle klar halten; keine URLs mit Secretquery protokollieren.

### AF-011

**Nicht-JSON-Fehlerantworten werden als roher Parserfehler gezeigt.** Schwere: **Niedrig**. Kategorie: Web-Fehlerbehandlung. Status: **Confirmed**. Task: [CM-008](../../TASKS.md#cm-008).

**Betroffene Komponente:** Web-Setup-Wizard und API-Fehleranzeige.

- Fundstelle: `src/components/setup-wizard.tsx:85`, catch-/Erroranzeige desselben Komponentenmoduls.
- Evidenz: bei nicht erfolgreicher Antwort wird ungeprüft `response.json()` aufgerufen. Ein im Browser abgefangener leerer HTTP-500-Response zeigt `Failed to execute 'json' on 'Response': Unexpected end of JSON input`.
- Risiko: unverständliche Fehlermeldung und verlorener HTTP-/Vorgangskontext. Kein Beweis für die Ursache früherer Meldungen außerhalb dieses getesteten Wizards.
- Prüfung: Playwright/Chromium, ausschließlich lokale Dummy-Session und Browser-Route-Mock; kein echter Proxyfehler oder externer Dienst manipuliert.
- Maßnahme: sichere Content-Type-/Body-/Fallbackbehandlung und Negativtests; ZIP-Erfolg unverändert.

<a id="prufungen"></a>
## Prüfungen

### Umgebung und Grenzen

Linux **Debian 13 x86_64**, Node **24.22.1**, npm **11.9.0**, .NET SDK **10.0.403**, PowerShell **7.5.4**, Chromium **155.0.8059.79**. Vorhandene Werkzeuge/Dependencies genutzt; nur der temporäre Datenrepo-Klon bekam seinen unveränderten Lockfile-Install. Netzwerkzugriff lief über die vorhandene Plattformauthentifizierung mit TLS; manche Git/Testhost-/Browserbefehle benötigten die unterstützte Befehlssandbox-Eskalation. Das änderte keine Cloud-Netzwerkrichtlinie oder Installerprüfungen.

Befehle mit relativen Pfaden liefen im configureMe-Root, außer explizit anders angegeben. Die lokalen Pfade im Protokoll sind Audit-Arbeitskopien, keine Produktabhängigkeiten. Für .NET: `PATH=/workspace/tools/dotnet:/workspace/tools/pwsh:$PATH`, `DOTNET_CLI_HOME=/workspace/.dotnet`, `NUGET_PACKAGES=/workspace/.nuget/packages`. Für PowerShell: `XDG_CACHE_HOME=/workspace/.cache`, `XDG_CONFIG_HOME=/workspace/.config`, `XDG_DATA_HOME=/workspace/.local/share`; Packaging unter Linux zusätzlich `TEMP=/tmp`.

| Tatsächlich ausgeführter Befehl / Kontext | Ergebnis | Abdeckung / Grenze |
| --- | --- | --- |
| `git ls-remote …/centrality.git HEAD`; `git clone --depth 1 --no-tags … /tmp/configureme-audit-centrality` | erfolgreich | Git-Leserecht, kein API-/Schreibnachweis |
| entsprechende flache Klone von myConfigs-data, myHome-Lab, personal-platform | erfolgreich, alle fremden tracked Arbeitsstände sauber | nur beauftragte Schnittstellen, keine umfassenden Fremdaudits/Historienprüfung |
| `git fetch origin main`; `git ls-remote --symref origin HEAD` | main / `23fdea3…` | aktueller Default-Branch gelesen, nicht überschrieben |
| `npm test` | Vitest **15 passed**, 3 Dateien | **14 Fälle mit Assertions + 1 Linux-Frühreturn** des Windows-Parsers; keine Windowsparser-Ausführung |
| `npm run lint`; `npm run typecheck`; `npm run build` | alle bestanden | tatsächlicher Web-Build, kein Docker-/Browser-/OAuth-E2E-Nachweis allein |
| `dotnet test windows/ConfigureMe.Setup.Portable.Tests/ConfigureMe.Setup.Portable.Tests.csproj --configuration Release --no-restore` | **24 passed, 0 failed/skipped** | portable Controller-/Engine-/Worker-/Berichtsfixtures, keine WinForms-Ausführung |
| `pwsh -NoProfile -File tests/installer-regressions.ps1` | **86 Assertions bestanden** | synthetische Architektur-/Signer-/Hash-/Nachprüfungsfälle, kein realer Vendorinstaller |
| `pwsh -NoProfile -File tests/codex-desktop-script.ps1` | **10 Szenarien bestanden** | Mocks, kein Store-/Codex-Desktop-Installationsbeleg |
| `pwsh -NoProfile -File tests/quicksetup-portable.ps1` | bestanden | vorhandene Mockroute, keine Installation |
| Datenklon: `npm ci --cache /workspace/.npm-cache --no-audit --no-fund`; `npm run validate` | bestanden | Lockfile bleibt gleich, eigene Schemas/Referenzen gültig |
| Datenklon: `npm test`; zusätzlich `node tests/validate-configs.test.mjs` | npm meldet einen aggregierten Dateifall; direkter Lauf **4 Testfälle bestanden** | Runnergranularität getrennt berichtet, kein Consumer-Kompatibilitätsbeweis |
| `node /tmp/configureme-audit-probes/contracts.cjs` | **11 erwartete Gegenformat-Ablehnungen** | echte Zod-/AJV-Validatoren beider Commits; alle lokalen Schemas registriert, kein remote Schemafetch |
| `AUTH_SECRET=synthetic-audit-secret-never-for-deployment APP_URL=https://audit.invalid INITIAL_ADMIN_GITHUB_USER=audit-user npm run start -- --hostname 127.0.0.1 --port 3100` | lokal gestartet, anschließend beendet | reine synthetische Testauth; `next start` warnt bei standalone, aber Requests wurden bedient; kein Deployment |
| `node /tmp/configureme-audit-probes/http.cjs` | **9 positive/negative Smokechecks + 1 gezielt reproduzierter OAuth-500-Fall** | Health/Home 200; anonym Profile 401/Portal 307; Dummy-Session Profile 200; Fremd-Origin 403; kaputtes JSON/unzulässiges Feld 400; gültiges Bundle ZIP 200; Unicode-State 500 |
| synthetische Authprobe mit echten transpilierten `auth.ts`-Funktionen | `allowlistNow=false`, `existingSessionValid=true` | AF-007; kein reales Secret oder Benutzercookie gelesen |
| `node /tmp/configureme-audit-probes/browser.cjs` | Wizard durchlaufen; zwei falsche Labels und leerer Fehlerresponse reproduziert | vorhandenes Playwright/Chromium, nur localhost und abgefangener Response, keine echten Benutzerdaten |
| `pwsh -NoProfile -File /tmp/configureme-audit-probes/handoff.ps1` | nach Verifikation veränderte Fixture am gemockten Runner beobachtet | AF-006, kein gestarteter Installer/Windows-Exploit |
| `dotnet build windows/ConfigureMe.Setup.Tests/ConfigureMe.Setup.Tests.csproj --configuration Release --no-restore` | erfolgreich | Windows-Testprojekt nur kompiliert; WinForms-Tests auf Linux nicht ausführbar |
| `dotnet publish windows/ConfigureMe.Setup/ConfigureMe.Setup.csproj --configuration Release -p:PublishProfile=win-x64 --output /tmp/configureme-audit-publish` | erfolgreich; keine externen DLLs | self-contained Single-File-Crossbuild, EXE nicht ausgeführt |
| `pwsh -NoProfile -File scripts/New-SetupReleasePackage.ps1 -PublishDirectory /tmp/configureme-audit-publish -OutputPath /tmp/configureme-audit-setup.zip` | 6 Manifestdateien/Größen/Hashes geprüft | dirty=true wegen Dokumentationsarbeit, unsigned; keine Veröffentlichung |
| `pwsh -NoProfile -File scripts/New-WindowsServer2022QuickSetup.ps1 -OutputPath /tmp/configureme-audit-quick1.zip` und gleicher Befehl für `quick2.zip` | **byteidentische ZIPs**, 12 Manifestdateien geprüft | identischer Eingabestand; kein allgemeiner Build-/Vendor-Reproduzierbarkeitsnachweis |
| `gh api 'repos/muk4li/configureMe/pulls?state=open&per_page=5' …` | **Forbidden / Exit 1** | API-Zugriff durch aktuelle Umgebung blockiert; kein fehlendes Git-Leserecht daraus abgeleitet, keine Credentialextraktion/Umgehung |
| öffentliche GitHub-Actions-Webübersicht gelesen | Run **42174844057**, Success für **23fdea3** | historischer beobachteter CI-Lauf, kein neu ausgeführter Windows-Test in dieser Linux-Session |
| `python3 /tmp/configureme-audit-probes/check-docs.py`; `git diff --check` | bestanden; Details im Dokumentationsabschluss | nur tatsächlich geprüfte lokale Ziele/Quellobjekte; keine externe URL-/Mermaid-Renderinggarantie |

Diagnosefehler der temporären Proben wurden nicht als Produktbefunde verbucht: ein nativer Node-TS-Import scheiterte zunächst an `next/headers`-ESM-Auflösung und wurde durch CommonJS-Transpilation korrigiert; der erste Browserselektor traf auch Nexts Route-Announcer und wurde auf `.error-note[role="alert"]` eingeschränkt. Ein erneuter Crossbuild ohne die oben angegebenen XDG-Verzeichnisse scheiterte an der schreibgeschützten PowerShell-Cacheposition `/home/agent/.cache/powershell`; mit den dokumentierten XDG-Werten bestand er mit 0 Warnungen/Fehlern. Das ist eine Testhost-Voraussetzung, kein Windows-ExecutionPolicy-Befund. Die Wiederholungen prüfen diese konkreten Korrekturen. Die Scratchskripte bleiben außerhalb Git; Kernreproduktionen stehen unten. Es wurden keine echten OAuth-Credentials verwendet und keine OAuth-Tokenanforderungen an GitHub ausgelöst.

**Nicht durchgeführt:** Windows PowerShell 5.1/WinForms/echte DPI auf dieser Maschine, tatsächliche Hersteller-/Storeinstallationen, aktualisierte saubere Ziel-VM, Docker-/Compose-Ausführung, reale OAuth-Anmeldung, Reverse-Proxy-/Internet-/VPN-Abnahme, Secretrotation oder vollständiger Secret-/Dependency-/CVE-/Historien-/Penetrationstest. Keine Produkt-/Betriebsfreigabe aus grünen Mocks ableiten.

### Reproduktionskern ohne Produktänderung

Für AF-003 nach lesenden, commitgebundenen Checkouts mit deren Lockfile-Dependencies: echtes `profileSchema` aus `src/lib/profiles.ts` über vorhandenes TypeScript als CommonJS laden, `loadValidators()` aus `myConfigs-data/tools/validate-configs.mjs` importieren (registriert alle vier lokalen AJV-Schemas), dann sämtliche `profiles/*.json` gegen `validators.profile` und sämtliche Datenprofile gegen `profileSchema.safeParse` prüfen. Keine Feldtransformation vor dem Test. Erwartet: sechs/fünf Ablehnungen; `minimal.packages[2]` zusätzlich Datenregexfehler. Dies ist eine Auditprobe, kein implementierter Adapter.

Für AF-007 mit rein synthetischem Prozess-Secret: `createSessionToken("audit-user", "user")`, danach Listenwerte leeren; `isAllowedUser("audit-user")` und `verifySessionToken(token)` getrennt prüfen. Keine reale Session oder Betriebsvariable dafür verwenden.

Für AF-008 auf lokalem Testserver: GET `/api/auth/github/callback?code=synthetic&state=` plus URL-kodierte 64-mal `é`, Cookie `configureme_oauth_state=` plus 64 ASCII-`a`. Keine echten OAuthwerte konfigurieren. Erwartet am Basiscommit HTTP 500, nicht ein erfolgreicher Login.

Für AF-009/011 den Wizard mit einer synthetischen lokalen Session bis Server-Paketauswahl/Review öffnen. Im Testbrowser nur `/api/bootstrap` auf HTTP 500 mit leerem Body abfangen. `.error-note[role="alert"]` zeigt den Parserfehler. Dies beweist keinen realen Proxyfehler und setzt keine produktiven Responses um.

Für AF-006 eine 256-Byte-x64-PE-Fixture im temporären Verzeichnis mit ihrem korrekten SHA-256 verwenden. Nur `SignatureProvider` und `ProcessRunner` injizieren; im ProgressCallback nach `verification-completed` eine Fixturebyte ändern. Der Runner liest nur den Hash und startet **keine EXE**. Die Beobachtung „Runner sieht geänderte Bytes“ ist ein Handoff-Indiz; Windows-ACL-/Lock-/Elevationsprüfung separat autorisieren.

## Cross-Repo-Empfehlung und Prioritäten

Die [drei Vertragsalternativen](../integrations/configuration-contract-proposal.md#alternativenvergleich) sind verglichen. Empfohlen ist ein explizit versionierter Adapter zwischen getrennten Modellen, nicht Schemaangleichung oder Providerbau in dieser Session. Daten-/Consumer-/Adapterrevision und Zielworkflow müssen getrennt bleiben; alle Teilbestände, Konflikte und nicht unterstützten Strategien fail-closed. Quellen sind keine Installer-DSL. Reale Reads/Writes würden gesonderte Rechte und Offline-/Snapshot-/Konflikttests benötigen.

Lokale Phasen CM-0 bis CM-5 stehen in ROADMAP.md. Vorrang: **CM-001** unabhängige Release-Vertrauensentscheidung; **CM-006** Handoff-Abgrenzung; **CM-002** Clean-Checkout-Verfahren; **CM-004** Webgates; **CM-003** Vertragsreview. CM-009 ist parallel klein ausführbar. CM-005 benötigt eine reale Installationsfreigabe; CM-011/012 bleiben bis Vertragsannahme blockiert. CM-014 ist nur eine Zukunftsvorbereitung und autorisiert niemals globale Phase 7.

Offene Eigentümerentscheidungen: Release-Identität/Trust Anchor und Distribution; Signatur-/Rotationsbetrieb; tatsächliche VM-Abnahme und deren Infrastrukturauftrag; Annahme/Version des Datenvertrags samt Alias-/Zielworkflow-/Offlinepolitik; gewünschte Session-Widerrufssemantik; optionale spätere Provider-/Write-/Hub-/VPN-Verträge. Keine fremden Backlogs oder ADRs wurden geändert.

<a id="quellen"></a>
## Quellen und Vertraulichkeit

Alle Quellen geprüft am **2026-11-13**. Ein privater Quelllink kann für andere Leser nicht erreichbar sein; das erzeugt keine Laufzeitabhängigkeit. Die nachfolgende Liste dokumentiert Provenienz und generische Zuständigkeiten, keine privaten Betriebsparameter. Rohquellen, Inventories, Domains, IPs, persönliche Hardware-/Recovery-/Kostendetails und vertrauliche Inhalte werden nicht übernommen. Die Empfehlung nutzt die bereits im Auftrag benannten Architekturgrenzen und eigene configureMe-Befunde.

| Repository | Geprüfter Commit | Tatsächlich für diesen Auftrag gelesene Pfade / Scope |
| --- | --- | --- |
| [muk4li/configureMe](https://github.com/muk4li/configureMe/tree/23fdea3b1dec546fbf73ab930096078ba73419e1) | `23fdea3b1dec546fbf73ab930096078ba73419e1` | README/AGENTS, bestehende Architektur-/Security-/Deployment-/Windows-Dokumentation; `src/app/`, `src/components/`, `src/lib/`, `schemas/`, `profiles/`, `bootstrap/windows-server-2022-developer/`, `windows/`, `scripts/`, `tests/`, Docker/Compose und einzige CI; spezifische Befundpfade oben |
| [muk4li/centrality](https://github.com/muk4li/centrality/tree/12776e9582cc2f9c413f40b7c6a9604f4b43e5b0) | `12776e9582cc2f9c413f40b7c6a9604f4b43e5b0` | `README.md`, `AGENTS.md`, `docs/START-HERE.md`, `VISION.md`, `ARCHITECTURE.md`, `REPOSITORIES.md`, `CURRENT-STATE.md`, `SECURITY.md`, `DECISIONS.md`, `ROADMAP.md`, `docs/CONTRIBUTING.md`, `docs/integrations/INTEGRATION-MATRIX.md`, `docs/audits/ARCHITECTURE-AUDIT-001.md`, `docs/decisions/ADR-001-EXPOSURE-BOUNDARIES.md`, `ADR-002-CONTRACT-OWNERSHIP.md`, `ADR-003-INITIAL-OPERATING-BASELINE.md` im gleichen Verzeichnis; zuerst gelesen, akzeptierte/proposed Status getrennt |
| [muk4li/myConfigs-data](https://github.com/muk4li/myConfigs-data/tree/75b91cfba94476393e7cfb4fe247b3f223aa4054) | `75b91cfba94476393e7cfb4fe247b3f223aa4054` | `README.md`, `docs/integration-configureme.md`, `docs/schema-versioning.md`, `schemas/profile.schema.json`, `schemas/package-selection.schema.json`, durch `loadValidators` zusätzlich Geräte-/Katalogschema, `configureMe/profiles/*.json`, `package.json`, `tools/validate-configs.mjs`, `tests/validate-configs.test.mjs`; nur Schema-/Consumer-Schnittstelle |
| [muk4li/myHome-Lab](https://github.com/muk4li/myHome-Lab/tree/e067ad95b8389d67b04bb62fa0a47754a4b290c5) | `e067ad95b8389d67b04bb62fa0a47754a4b290c5` | `README.md` und configureMe-relevanter Abschnitt `aktuellerStand.md`; geplante Testadapter-/Betriebsverantwortung, keine umfassende Infrastruktur-/Securityprüfung und keine Übernahme privater Planungsdetails |
| [muk4li/personal-platform](https://github.com/muk4li/personal-platform/tree/8e9ece9b630edd446ea14d8f184e7368c3c74fb6) | `8e9ece9b630edd446ea14d8f184e7368c3c74fb6` | `README.md`, `package.json`, `apps/calendar-diary/src/App.tsx`; nur unabhängige Apps/API-Grenzen und fehlende direkte configureMe-Integration geprüft |

Die vier temporären Nachbar-Checkouts hatten nach Abschluss keine tracked Änderungen. Keine zusätzlichen Repos myCloud-Lab/myagents/repopilot/chatidy wurden geklont oder auditiert: keine konkrete Implementierungsschnittstelle für diesen Auftrag im configureMe-Code nachgewiesen. Deren in Centrality dokumentierte Rolle ist Kontext, kein neuer Komponentenbefund. Kein pauschales Fremd-Audit oder Abschreiben des Centrality-Audits.

Unveränderliche zentrale Ausgangspunkte: [F-07 im früheren Audit](https://github.com/muk4li/centrality/blob/12776e9582cc2f9c413f40b7c6a9604f4b43e5b0/docs/audits/ARCHITECTURE-AUDIT-001.md), [Entscheidungsregister](https://github.com/muk4li/centrality/blob/12776e9582cc2f9c413f40b7c6a9604f4b43e5b0/DECISIONS.md), [ADR-002 Proposed](https://github.com/muk4li/centrality/blob/12776e9582cc2f9c413f40b7c6a9604f4b43e5b0/docs/decisions/ADR-002-CONTRACT-OWNERSHIP.md). Sie werden referenziert, nicht als öffentliche Kopie privater Architektur geführt.

## Dokumentationsabschluss und Review

Pflichtdateien werden über README/REPO miteinander verknüpft; stabile CM-/AF-IDs, phasenbezogene Abhängigkeiten und Proposed-/Blocked-Zustände bleiben erhalten. Der bestehende Next.js-AGENTS-Block wurde unverändert integriert. Nur Markdown gehört zum Review-Diff; temporäre Auditproben, private Checkouts und Buildausgaben bleiben außerhalb Git. Kein automatischer Merge in main und kein Release/Deployment. API-Zugriffsgrenzen werden im Abschlussbericht getrennt vom bereitgestellten Git-Review-Branch genannt.

Abschließende lokale Konsistenzprüfung: **7 Markdown-Dateien, 91 lokale Links/Anker, 15 eindeutige Task-IDs mit übereinstimmenden Tabellen-/Detailstatus und Pflichtfeldern, 11 eindeutige Befunde, 6 Roadmap-Phasen, 4 unveränderte Nachbar-Commits**; ursprünglicher Next.js-Block bytegleich, Codefences ausgeglichen, keine unerwarteten Steuerzeichen und ausschließlich Markdown im Diff. Beide einfachen Mermaid-Flussdiagramme wurden auf Richtung, eindeutige Knoten und vorhandene Kantenendpunkte gegen die beschriebenen Modulgrenzen geprüft; kein Mermaid-Rendering durchgeführt. Private Quellinhalte wurden manuell gegen den vorgesehenen öffentlichen Scope geprüft. `git diff --check` bestand. Der lokale Testserver wurde beendet. CM-015 bezeichnet nur den abgeschlossenen Dokumentationsauftrag; die Produkt-/Betriebsbefunde bleiben offen.

## Folgeprüfung 2026-11-13: Engine-Cache-Race

### AF-012

**Nebenläufige Extraktion kollidiert im gemeinsam genutzten Benutzer-Cache.** Schwere: **Mittel**. Kategorie: Verfügbarkeit/Testisolierung. Status: **Confirmed** am Folgeprüfungs-Basiscommit `70a032ae19e2e0da0d39af5a5a5f8991f668e913`. Betroffene Komponente: Embedded Engine/GUI-Tests. Task: [CM-016](../../TASKS.md#cm-016).

- Fundstelle: ursprüngliches `windows/ConfigureMe.Setup/EngineBundle.cs:94–112`, `SetupForm.cs:54`, Layouttests und der erste EngineBundle-Test ohne isolierten Root.
- Evidenz: [Windows-Lauf 43435533839](https://github.com/muk4li/configureMe/actions/runs/43435533839) scheitert mit dem gemeldeten Move-Stacktrace. Zwei Instanzen können beide ein fehlendes Ziel beobachten; nach der Publikation des Gewinners schlägt der zweite Move fehl. xUnit-Testklassen teilen dabei ohne Root-Injektion denselben manifestgebundenen Benutzer-Cache.
- Risiko: sporadischer Test-/Anwendungsstartfehler bei Parallelität; Tests schreiben unbeabsichtigt nach LOCALAPPDATA. Keine Hash- oder Signaturumgehung als Exploit nachgewiesen.
- Prüfung: Zwei dedizierte Threads werden nach dem Fehlend-Check synchronisiert; der zweite Move erfolgt garantiert nach Abschluss des ersten ExtractVerified. Ursprüngliche Logik scheitert reproduzierbar; korrigierte portable Suite besteht dreimal. Der vollständige [Windows-Lauf 43444044357](https://github.com/muk4li/configureMe/actions/runs/43444044357) für `8e02da34c23cabcf9c06c126b22a1b4e8e50dffe` besteht einschließlich drei kompletter Windows-Testsuiten, Publish/EXE-Self-Tests und Packaging. Das ist Hosted-Runner-Evidenz, keine frische interaktive VM-Abnahme.
- Maßnahme: kein Überschreiben; bei konkurrierendem Ziel dieselbe Pfad-/Reparse-/Größen-/Hashprüfung wie bei Cachetreffern. Einzig eigene temporäre Dateien entfernen. Expliziter Test-Root für SetupForm und temporäre Roots für Self-Tests. Details und Grenzen: [Folgeprüfprotokoll](engine-cache-race.md).

Diese Ergänzung ändert weder die ursprünglichen Audit-Snapshot-Ergebnisse noch den offenen AF-006/CM-006-Handoff-Befund. CM-016 wird erst nach tatsächlichem Windows-CI-Erfolg und separatem PR Done.
## Folgeauftrag 2026-11-13: Public-first A/B

PD-001..004 des Eigentümers autorisieren öffentliche Windows-Planung ohne Login mit begrenzter Serverprüfung und synthetischen Fixtures. Die ursprüngliche Bestandsaufnahme oben beschreibt weiterhin ihren Basiscommit. [A/B-Implementierung und tatsächliche Prüfungen](public-first-a-b.md) dokumentieren den neuen Stand einschließlich erneuter F-07-Prüfung. [Snapshotintegration](../integrations/public-snapshot-v1-proposal.md) bleibt Proposed und ausführbare Downloads bleiben hinter CM-001/005/006/010. Keine globale Centrality-Entscheidung wurde umgeschrieben; der separate Engine-Fix/PR #8 wird nicht in diese Featurearbeit übernommen.
