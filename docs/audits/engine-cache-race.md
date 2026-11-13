# Folgeprüfung: nebenläufige Engine-Extraktion

Datum: 2026-11-13. Basis: `main` / `70a032ae19e2e0da0d39af5a5a5f8991f668e913`. Befund [AF-012](initial-audit.md#af-012), Aufgabe [CM-016](../../TASKS.md#cm-016). Keine Systemkonfiguration, echten Installer, Adminanforderungen oder Änderungen an Installerdefinitionen.

## Bestätigte Ursache

Der öffentliche [fehlgeschlagene Windows-Lauf 43435533839](https://github.com/muk4li/configureMe/actions/runs/43435533839) enthält genau den gemeldeten Stacktrace von `ShowsEveryCategoryAndPackageAcrossResizeAndScale` über `SetupForm` nach `EngineBundle`/`File.Move`. `File.Exists` und anschließender Move sind getrennte Operationen. Die manifestgebundene Cacheadresse ist für identische Ressourcen absichtlich gleich; zwei Instanzen können beide den Fehlend-Zweig betreten. Der zweite Move kollidiert mit der fertig veröffentlichten Datei. Layouttests und ein Engine-Test verwendeten außerdem den produktiven Benutzer-Cache.

Der Regressionstest verwendet zwei dedizierte Threads, CountdownEvent und ein Abschlussereignis. Beide erreichen den Publikationspunkt mit noch fehlender bootstrap.ps1; der zweite wartet bis zum vollständigen Abschluss des ersten. Kein Sleep, Zufallsstress oder Retry-to-pass. Die ursprüngliche Move-Logik (nur um denselben Beobachtungspunkt ergänzt) scheitert deterministisch mit IOException/already exists für bootstrap.ps1. Anschließend wurde die korrigierte Quelle wiederhergestellt und neu gebaut.

## Korrektur und Sicherheitsgrenzen

- Ein fehlendes Ziel wird weiterhin über eine exklusiv erstellte, eindeutige temporäre Datei und Move **ohne Überschreiben** veröffentlicht.
- Nur eine IOException mit inzwischen existierendem Dateiziel führt zur anschließenden erneuten Validierung. Ein Verzeichnis-/fehlendes Ziel oder andere Fehler bleiben Fehler. Existenz allein begründet niemals Vertrauen.
- Jeder Cachetreffer und jeder Publikationsgewinner wird gegen vollständigen Pfad, Reparse-Points, Manifestgröße und SHA-256 geprüft. Dateizugriff während der Prüfung verwendet FileShare.Read, das unter Windows paralleles Schreiben/Löschen dieses geöffneten Files verweigert. VerifyUnchanged prüft dieselbe Größe und denselben Hash erneut vor Workerverwendung.
- Ein korrumpiertes Ziel wird verweigert und weder ersetzt noch gelöscht. Cleanup entfernt ausschließlich die eigene GUID-temporäre Datei nach Pfadprüfung; keine rekursive Cachebereinigung oder Reparatur fremder Gewinner.
- Ressourcen-Allowlist, Manifest-/Ressourcenhash, Ressourcengröße, Traversal-/Rootprüfung, Reparse-Prüfungen und Worker-Nachprüfung bleiben erhalten. Keine Änderung an Pakettrust oder Installerfunktionen.
- Der optionale applicationDataRoot von SetupForm ist eine kleine lokale Testnaht. Alle Layouttests und Engine-Tests benutzen eigene temporäre Roots; keine globale Umleitung von LOCALAPPDATA. Die normale Anwendung behält ihren bisherigen Cachepfad.
- Auch --self-test, --layout-self-test und --startup-layout-self-test nutzen pro Prozess einen temporären Root, den sie im finally bereinigen. Normale Starts erhalten keine neue Cleanup-Operation im Benutzer-Cache.
- Die STA-Testhilfe meldet Erfolg erst nach Form-Disposal und Temp-Cleanup; Konstruktorfehler erreichen xUnit. Die drei CI-Durchläufe sind unabhängige vollständige Suiten; der erste Fehler beendet den Job und wird nicht durch spätere Erfolge verdeckt.

Dies löst die kooperative Extraktionskonkurrenz, nicht das gesamte lokale adversariale Dateisystem-/ACL-/Reparse-/Elevationsmodell aus AF-006. Geöffnete Readhandles werden nach der Prüfung geschlossen; daraus wird keine lückenlose Sperre bis zum Workerstart behauptet.

## Tatsächlich ausgeführte Prüfungen

Host: Debian 13 x64, .NET SDK 10.0.403, PowerShell 7.5.4. Für alle dotnet-Befehle waren PATH um `/workspace/tools/dotnet` und `/workspace/tools/pwsh`, DOTNET_CLI_HOME/NUGET_PACKAGES sowie XDG_CACHE_HOME/XDG_CONFIG_HOME/XDG_DATA_HOME auf die bereits vorhandenen beschreibbaren Workspaceverzeichnisse gesetzt.

| Befehl / Prüfung | Tatsächliches Ergebnis und Grenze |
| --- | --- |
| `gh api repos/muk4li/configureMe/actions/runs` | 403 Forbidden durch aktuelle Umgebung; keine Credentials extrahiert oder Netzrichtlinie verändert |
| `curl --fail --silent --show-error --max-time 30 https://github.com/muk4li/configureMe/actions/runs/43435533839` | öffentliche Failure-Annotation und passender Stacktrace gelesen; kein korrigierter Lauf |
| `dotnet test windows/ConfigureMe.Setup.Portable.Tests/ConfigureMe.Setup.Portable.Tests.csproj --configuration Release --no-restore --filter FullyQualifiedName~ConcurrentExtractionsAcceptOnlyTheVerifiedWinner` gegen ursprüngliche Move-Logik mit Beobachtungspunkt | erwarteter Red-Nachweis, IOException für bootstrap.ps1; ursprünglicher erster Sandboxlauf scheiterte bereits am lokalen Testhost-Socket, daher tatsächlicher Test außerhalb der Sandbox wiederholt |
| `dotnet test windows/ConfigureMe.Setup.Portable.Tests/ConfigureMe.Setup.Portable.Tests.csproj --configuration Release --no-restore --logger "trx;LogFileName=portable-N.trx" --results-directory /tmp/configureme-engine-race-results` für N=1,2,3 | **je 28 bestanden, 0 fehlgeschlagen, 0 übersprungen**; enthält Parallelpublikation, manipulierter Gewinner gleicher Länge, verkürztes Ziel, Verzeichniskonflikt, unverändertes Konfliktziel, Temp-Cleanup und bisherige portable Tests |
| `dotnet build windows/ConfigureMe.Setup.Tests/ConfigureMe.Setup.Tests.csproj --configuration Release --no-restore` | erfolgreich, 0 Warnungen/Fehler; nur Kompilierung, keine Windows-GUI-Ausführung |
| `dotnet publish windows/ConfigureMe.Setup/ConfigureMe.Setup.csproj --configuration Release -p:PublishProfile=win-x64 --output /tmp/configureme-race-publish` | erfolgreicher Produktions-Single-File-Crossbuild; EXE auf Linux nicht gestartet |
| Workflow-YAML mit vorhandenem PyYAML gelesen; neun PowerShell-run-Blöcke über `System.Management.Automation.Language.Parser.ParseFile` geprüft | Syntaxprüfung bestanden; keine Ausführung der Windows-Schritte daraus abgeleitet |
| `pwsh -NoProfile -File tests/installer-regressions.ps1`; `tests/codex-desktop-script.ps1`; `tests/quicksetup-portable.ps1` | 86 Assertions, 10 Szenarien und portable Checks bestanden; nur Fixtures, kein Netzwerk/Installerprozess |
| [Windows-Workflow 43444044357](https://github.com/muk4li/configureMe/actions/runs/43444044357), Push für `8e02da34c23cabcf9c06c126b22a1b4e8e50dffe` | **Success**, 3m 6s; gesamter Job auf windows-2022 bestanden: PS5.1/PS7-Fixtures, drei vollständige Windows-GUI-/Controller-/Engine-Testsuiten, portable Tests, Single-File-Publish unter restriktiver Prozesspolicy, alle drei EXE-Self-Tests und beide ZIP-Packagings; kein Installerlauf |
| `gh pr create --base main --head fix/engine-cache-extraction-race --title "Fix concurrent engine extraction and isolate GUI test caches" --body-file /tmp/configureme-engine-race-pr.md` | `POST https://api.github.com/graphql: Forbidden`; kein PR erstellt, kein Merge |
| `git diff --check`; lokale Markdown-Links/IDs und Diffreview | bestanden; keine Installerdefinitionsänderungen oder fremden Cache-Löschungen |

**Windows-Ergebnis:** Der gesamte Workflow wurde tatsächlich ausgeführt und sein öffentlicher Abschlussstatus geprüft; kein lokaler Linux-Build wird dafür als Ersatz gewertet. Der gezielte Push-Trigger ausschließlich für `fix/engine-cache-extraction-race` ermöglicht diesen Nachweis trotz gesperrter PR-API. Bestehende main-/PR-/Tag-/Dispatch-Trigger und read-only Berechtigungen bleiben erhalten; kein Push/Merge nach main und keine Netzwerk-/Credentialänderung. Die grüne CI belegt Tests auf dem Hosted Runner, keine reale Herstellerinstallation, echte DPI-Hardware oder frische Server-2022-VM ohne vorinstalliertes SDK. Letztere bleiben AF-005/CM-005.

**Noch offen:** tatsächliche PR-Erstellung. API-POST bleibt Forbidden; Review-Branch und PR-Beschreibung sind vorbereitet. Daher bleibt CM-016 bis zum separaten PR formal Blocked, obwohl Korrektur und geforderte Windows-CI-Prüfung bestanden sind. Die einzige CI-Warnung betrifft Node-20-Metadaten bestehender @v4-Actions (vom Runner auf Node 24 ausgeführt); keine ungefragte Actions-Aktualisierung in diesem Fix.

Die vier neuen Fälle sind im gemeinsamen EngineBundleTests-Code und werden sowohl vom portablen als auch vom Windows-Testprojekt kompiliert. Keine Produktdatei wird für die gewöhnliche Testausführung mutiert; die einmalige Red-Diagnose lief mit garantiertem Wiederherstellen der Quelle. Temporäre Testroots werden im Dispose/finally entfernt. Keine realen Drittanbieterinstallationen oder Änderungen an Windows/Systemkonfiguration durchgeführt.
