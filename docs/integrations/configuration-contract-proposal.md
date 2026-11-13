# Konfigurationsvertrag myConfigs-data → configureMe

**Status: Proposed. Keine akzeptierte Architekturentscheidung, kein implementierter Adapter/Provider, keine Schemaänderung.** Geprüft am 2026-11-13 gegen configureMe `23fdea3b1dec546fbf73ab930096078ba73419e1` und myConfigs-data `75b91cfba94476393e7cfb4fe247b3f223aa4054`. [Quellen](../audits/initial-audit.md#quellen), [AF-003](../audits/initial-audit.md#af-003), [CM-003](../../TASKS.md#cm-003).

## Autorität und nachgewiesener Ausgangspunkt

Centrality bleibt zuständig für globale Grenzen/Entscheidungen. Der Auftrag ordnet deklarative nicht geheime Daten myConfigs-data und ausführbare Installer-/Trust-Definitionen configureMe zu. Im gelesenen Centrality-Register sind D-007 und ADR-002 **Proposed**; dieses Dokument behauptet keine Annahme dieser ADRs. Der heute tatsächlich verwendete Provider bleibt lokal in configureMe. Ein künftiger Vertrag muss von Datenowner und Konsumentenowner ausdrücklich bestätigt werden.

F-07 wurde mit den aktuellen Validatoren erneut geprüft: **6/6** configureMe-Profile scheitern am Datenrepo-Schema; **5/5** Datenrepo-Profile scheitern am configureMe-Zod-Schema. Das belegt Inkompatibilität, nicht einen Fehler der jeweiligen eigenen Validierung. Die Aussage im Datenrepo, configureMe sei leer, ist am geprüften Consumer-Stand veraltet; eine dortige Korrektur ist ein separater Auftrag.

| Dimension | configureMe heute | myConfigs-data heute | Konsequenz |
| --- | --- | --- | --- |
| Formatidentität | internes Profil; `schemaVersion: 1` | eigenes Profil-/Geräte-/Katalogformat; ebenfalls v1 | gleiche Zahl ist kein gemeinsamer Vertrag |
| Plattform | genau `platform` | nicht leeres `platforms`-Array | Zielplattform ausdrücklich auswählen/validieren |
| `$schema` | im strikten Profil nicht zulässig | definierter relativer Schemahinweis erforderlich | erst Quellformat validieren, dann ausdrücklich transformieren; keine fremden Schemas abrufen |
| Optionen | optional, Default `{}` | erforderlich, begrenzte boolesche Felder | Abwesenheit nicht mit `false` verwechseln |
| Namen/Beschreibung | 80/240 Zeichen | 100/500 Zeichen | längere Quelle ablehnen oder Migration separat entscheiden; nicht still kürzen |
| IDs | führende Ziffer möglich; Paketanzahl maximal 50 | Buchstabe am Anfang, maximal 64 Zeichen; keine feste Paket-Enum | lokales `7zip` scheitert schon am Muster; bekannte Pakete zusätzlich im Consumer auflösen |
| Pakete/Workflows | repo-eigener Katalog, Legacy- und native Modi, nur Windows freigegeben | deklarative Auswahl für mehrere Plattformen | formal bekannte ID bedeutet nicht automatisch ausführbare Strategie |
| Katalogversion | Plan `catalogVersion: "1"` | numerische Daten-Katalogrevision | getrennte Namen und Semantik, keine automatische Gleichsetzung |
| Quelle | lokale Dateien; keine Snapshotrevision im Profil | Git-SHA als vorgesehene Revision | Provider-/Planvertrag braucht zusätzliche, versionierte Provenienz |

Insbesondere sind `7zip` und `seven-zip` sowie `powershell` und `powershell-7` im Consumer nicht bloß Schreibvarianten: Legacy-WinGet- und eigenständige Installerpfade unterscheiden sich. Eine Quell-ID darf nicht ungeprüft umbenannt oder in einen anderen Workflow verschoben werden. Linux/macOS haben im aktuellen Consumer-Katalog keine installierbaren Pakete.

## Alternativenvergleich

| Alternative | Aufwand/Migration | Wartbarkeit und Kompatibilität | Sicherheitsfolgen |
| --- | --- | --- | --- |
| **1. Versionierter Adapter** zwischen ausdrücklich benannten Formaten | mittlerer lokaler Aufwand, begrenzte Fixtures; bestehende Dateien bleiben erhalten | explizite unterstützte Producer-/Consumer-/Adapterversionen, unabhängig aktualisierbar | kleine prüfbare Übersetzungsgrenze; doppelte Validierung und Mappingtests nötig |
| **2. Gemeinsamer neuer Datenvertrag** mit koordinierter Migration | hoher Aufwand in beiden Repos; Migration, alte Leser, Veröffentlichungsreihenfolge und Rollback nötig | langfristig weniger Formatübersetzung, aber gemeinsame Releasekoordination | Chance auf klare Grenzen; Risiko der impliziten Übernahme ausführbarer Katalogregeln oder Breaking Changes |
| **3. Getrennte Modelle mit definierter Transformation pro Import/Export** | zunächst gering bis mittel; später viele Transformationspfade | lose Kopplung, aber ohne einheitliche versionierte Implementierung höhere Drift-/Testlast | jeder Import muss dieselbe Fail-closed-Policy beweisen; keine ad-hoc Feldumbenennung zulassen |

**Empfehlung: Alternative 1, unter Beibehaltung getrennter Modelle.** Damit wird Alternative 3 bewusst zu einer einzelnen versionierten, getesteten Adaptergrenze konkretisiert. Alternative 2 erst bei belegtem Mehrkonsumentenbedarf erneut bewerten. Keine neue Datenbank, kein zentraler Konfigurationsdienst und keine frühzeitige Hub-Abhängigkeit.

## Proposed-v1-Adaptervertrag

### Identitäten und Owner

- Quellformat als Tupel aus `myConfigs-data/profile` und dessen Major-Version erkennen; internen Consumer als `configureMe/profile` mit eigener Version behandeln.
- Adapter erhält eine unabhängige Version, beispielsweise `myconfigs-to-configureme-profile@1`. Diese Namen sind Vorschlag, keine bereits veröffentlichten Schema-IDs.
- Quellkatalogrevision, Consumer-Katalogversion, Adapterversion, Repository, Commit-SHA und Inhaltsdigests getrennt halten. Neue Metadaten gehören in einen abgestimmten Snapshot-/Plan-Envelope, nicht unbemerkt in heute strikte Profile/Pläne.
- myConfigs-data entscheidet deklarative Auswahl; configureMe besitzt Strategie, Installerargumente, URLs, Pins, Publisher und Rechtebedarf. Der Adapter erzeugt ausschließlich deklarative interne Daten, keinen ausführbaren Code.

### Lesen, Snapshot und Integrität

1. Nur freigegebenes Repository und erlaubte JSON-Pfade lesen. Den gewählten Ref **einmal** auf einen unveränderlichen Commit auflösen; alle Dateien und Schemas müssen zu diesem Snapshot gehören. Kein Mischen mehrerer `main`-Zeitpunkte.
2. Schemas aus lokal freigegebenen Versionen verwenden; `$schema`/`$ref` aus Daten darf keine beliebigen Netzabrufe/SSRF auslösen. Byte-, Datei-, Profil-, Paket- und Tiefengrenzen sind vor Implementierung konkret zu entscheiden und zu testen.
3. Katalog, sämtliche referenzierten Profile und gegebenenfalls Geräteobjekte gegen das Producer-Schema und alle Referenzen validieren. SHA/Digest und vollständiges Dateiset gegen den gewählten Snapshot prüfen.
4. Erst nach vollständiger Quellvalidierung und Transformation das Consumer-Zod-Schema, Paketkatalog, Abhängigkeiten und Zielstrategie prüfen. Kein partiell brauchbarer Snapshot und kein unvollständiger Installationsplan.
5. Commit-Pin und Hash sichern Wiederholbarkeit/Integrität relativ zur autorisierten Quelle; sie sind keine unabhängige Release-Signatur oder Berechtigungsvergabe an das Zielgerät. Authentifizierter Datenzugriff ersetzt keine Installerprüfung.

### Plattform, Workflow und Mapping

- Benutzer/Consumer wählen eine konkrete Zielplattform und einen freigegebenen Installationsworkflow. Die Quelle darf keinen Enginepfad oder privilegierten Modus aktivieren.
- Zielplattform muss in `platforms` vorkommen; sonst Fehler. Keine still übersprungenen Profile/Pakete. Für Linux/macOS aktuell verständlich „kein freigegebener Installerpfad“ statt Erfolg melden.
- Mapping ist eine versionierte Positivliste pro Quellversion **und Zielworkflow**. Bekannte identische IDs können identisch bleiben; Legacy-Aliase werden nicht global umgeschrieben. Unbekannte/veraltete IDs und fehlende Strategien sind Fehler.
- Der derzeitige HTTP-Consumer wählt das native Serverbundle über die feste Profil-ID `windows-server-2022-developer` und deren Paket-Allowlist. Ein externes `developer`-Profil darf nicht durch willkürliches Umbenennen dieses Gate umgehen. Die konkrete Adapter-/Workflow-Zuordnung benötigt eine Entscheidung in CM-003 vor CM-011/012.
- Automatisch, manuell, detection-only und Web-Fallback unterscheiden; „im Katalog vorhanden“ ist keine Zusage einer automatischen Installation. Auswahl/Review muss den Modus sichtbar machen.
- Deterministische, deduplizierte Abhängigkeitsreihenfolge; Zyklen und nicht unterstützte Abhängigkeiten ablehnen. Der Zielkatalog bleibt maßgeblich.
- Profil-IDs nur innerhalb des expliziten Providers/Snapshots interpretieren. Lokale und externe Listen nicht still zusammenführen; ID-Kollisionen sichtbar ablehnen. Eine zukünftige Zusammenführung/qualifizierte ID ist eine separate Vertragsentscheidung.

### Optionen, Zusammenführung und Geräte

Boolean-Abwesenheit bleibt ungesetzt; Consumer-Defaults müssen dokumentiert sein. Widersprüchliches `true`/`false` aus mehreren Profilen führt zu einem sichtbaren Konflikt, nicht „letzter Wert gewinnt“. Reihenfolge und Deduplication richten sich nach dem akzeptierten Vertrag; sie dürfen keine Optionen still ändern.

Gerätedaten sind keine Geräteidentität oder Autorisierung. Nur freigegebene nicht geheime Einstellungen importieren; keine Netzwerkberechtigungen, Schlüssel, Benutzertokens oder beliebigen Installationsparameter. Die Umsetzung von Zeitzonen-/Geräteeinstellungen wäre eine gesonderte Produktfunktion.

### Cache, Offline und Synchronisierung

- Snapshot nach vollständiger Validierung atomar als „last known good“ aktivieren. Bei Download-/Validierungsfehlern unverändert lassen und Ursache anzeigen.
- Cache nach Repository, Commit und Adapter-/Schema-/Katalogversion identifizieren; private Inhalte mit angemessenen lokalen Dateirechten, ohne Tokens oder Live-Secrets.
- Offline nur einen ausdrücklich erlaubten, vollständig revalidierten Snapshot nutzen; Revision, Alter und Offlinezustand anzeigen und Benutzerfreigabe verlangen. Ohne gültigen Snapshot kein Installationsplan. Maximales Alter ist noch zu entscheiden, kein erfundener Default.
- Synchronisierung ist ein expliziter Snapshotwechsel mit Diff/erneuter Review; keine Änderung eines bereits freigegebenen Installationsplans während seiner Ausführung.
- Fehler in Struktur, Mapping, Verfügbarkeit oder Optionen liefern Datei, Feld, Revision und sichere Fehlerklasse, niemals private Rohdaten/Tokens. Beispiele: `UNSUPPORTED_SCHEMA`, `UNKNOWN_PACKAGE`, `WORKFLOW_UNAVAILABLE`, `SNAPSHOT_INCOMPLETE`, `OPTIONS_CONFLICT`, `OFFLINE_CACHE_UNAVAILABLE` sind vorgeschlagene Codes.

### GitHub-Rechte und mögliche spätere Schreiboperationen

Reader nur mit Repo-begrenztem `Contents: Read`, sofern nötig kurzlebigem serverseitigem Installationstoken. GitHub-OAuth des Portals dient heute dem Login und wird dafür nicht still erweitert. Keine Tokens im Browser, Bundle oder Gerät. Entwicklungs-/Contracttests verwenden lokale synthetische Fixtures statt privatem GitHub-Zugriff.

Ein zukünftiger Editor ist **nicht Teil dieser Empfehlung zur ersten Implementierung**. Er benötigt eigene Freigabe, serverseitige minimale Write-Rechte, Basis-Commit und Datei-SHAs, sichtbare Konflikte, Gesamtvalidierung und einen Review-Branch. Keine blinden Updates, kein Force-Push/Auto-Merge. Mehrdateiänderungen müssen einen konsistenten atomaren Snapshot ergeben; Datei-SHA-Prüfung allein ist kein Mehrdatei-Transaktionsvertrag. Offline keine automatischen Remote-Schreibvorgänge.

## Migration und getrennte Folgeaufträge

1. **configureMe CM-003:** Vorschlag mit Datenowner/Eigentümer prüfen; aktuelle Profile und alle veröffentlichten v1-Formate unverändert lassen.
2. **myConfigs-data, nur vorgeschlagen:** veraltete Consumerbeschreibung korrigieren, nach Entscheidung Quellformat/Revision und gemeinsame synthetische Fixtures dokumentieren. Dort wurde nichts geschrieben.
3. **configureMe CM-011:** nach Freigabe Adapter mit beidseitigen Positiv-/Negativtests, Limits, Aliaskonflikten und Workflowentscheidung entwickeln. Eigene alte Profile bleiben kompatibel.
4. **configureMe CM-012:** optional danach read-only Provider und Snapshotcache; kein Schreibeditor als Voraussetzung.
5. Gemeinsamer Major-Vertrag/Migration nur bei neuem ausdrücklichem Auftrag: explizite Versionierung, getestete Datenmigration, Konsumentenmatrix, Rückwärtsleser und Rollback. Kein „beide v1, also kompatibel“.
6. Falls globale Grenzen betroffen sind: Eigentümer kann den abgestimmten Vorschlag in Centrality übernehmen. Dieses Audit schreibt weder Centrality-ADRs noch fremde Backlogs um.

## Abnahme des späteren Vertrags

Gemeinsame synthetische Fixtures müssen bekannte Profile, ungültige Felder/Versionen, unbekannte/aliasierte IDs, Plattform-/Workflowgrenzen, Rechte-/Modusdarstellung, Optionen-/ID-Konflikte, Zyklen, Größenlimits, fehlende Dateien, Digestabweichung, Refbewegung, Rate-Limit/Timeout, Offline/Stale und Cache-Aktivierung abdecken. Keine echten Installer und keine Credentials im Contracttest. Erst die akzeptierte Entscheidung plus ausgeführte Consumer-/Producer-Tests erlauben eine Integrationsbehauptung.
