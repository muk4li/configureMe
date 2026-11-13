# Public profile snapshot import v1

**Proposed; Stufe C gesperrt bis Vertragsreview.** PD-002 entscheidet die Datenquelle und Snapshotstrategie, aber nimmt kein konkretes Schema oder ID-Mapping stillschweigend an. Quellen: [Produktauftrag/SHAs](../decisions/public-first-mvp.md), [AF-003](../audits/initial-audit.md#af-003), [Alternativenvergleich](configuration-contract-proposal.md#alternativenvergleich). Keine fremden Dateien geändert, kein Importer implementiert.

## Formatidentitäten und kleinste Lösung

Empfehlung bleibt ein versionierter Adapter zwischen `myConfigs-data/profile@1` und einem eigenen `configureme/public-snapshot@1`; `schemaVersion: 1` allein ist keine Identität. Native/Legacyprofile bleiben getrennt. Kein automatisches `platforms` → `platform` oder globales Umbenennen von `7zip`/`seven-zip`, `powershell`/`powershell-7`. Producer-ID-Regeln beginnen mit Buchstaben, Consumer-Limits und Optionssemantik sind enger. Ein gemeinsamer neuer Major-Vertrag wäre teurer und benötigte koordinierte Migration/Rollback; Transformation ohne versionierten Adapter würde Drift fördern.

Vorgeschlagenes Manifest: formatId, schemaVersion, adapterVersion, Consumer-Katalogrevision, freigegebenes Quellrepo, vollständiger 40-Hex-Commit-SHA, Producer-Schemaidentität/-Version, sortierte erlaubte Dateiliste mit Bytezahl/SHA-256, normalisierte öffentliche Profile mit Ziel-/Architekturmatrix und eindeutigem public-Profil-Namensraum. Prüfsummen schaffen Bindung an den autorisierten Snapshot, keine unabhängige Herausgebersignatur.

## Offline-Importvertrag

1. Reviewter lokaler Checkout des expliziten Quellcommits; kein Refdefault, kein Auto-Pull, keine Laufzeit-Credentials. Nur freigegebene `configureMe/catalog.json`, explizit als öffentlich bestätigte `configureMe/profiles/*.json` und lokal gebundene Schemas. Keine Geräte-/Override-/Privatdaten in öffentlichen Snapshots. Ein deklaratives Datenrepo bedeutet nicht automatisch öffentliche Veröffentlichungsfreigabe jeder Datei.
2. Sämtliche Quellen gegen die zugehörigen vollständigen Producer-Schemas, Byte-/Datei-/Tiefen-/Arraygrenzen prüfen. Referenzen lokal auflösen, kein HTTP-Schemafetch und keine beliebigen Dateipfade. Alle Katalog-Profilreferenzen und ID-Eindeutigkeit prüfen. Keine Teilbestände bei Fehlern.
3. Explizite versionsgebundene Positivliste für Paket-ID **und Zielworkflow**. Windows 11 WinGet und Server-2022-Engine sind verschiedene Fähigkeiten. Linux/macOS nicht still zu Windows konvertieren. Öffentlich ausgewählte Profile ohne Zielstrategie führen zu Fehlern; kein stiller Paketverlust.
4. Producer-Limits > Consumer-Limits ablehnen statt still kürzen. Nicht gesetzte Optionen bleiben ungesetzt; gegenläufige Werte sind sichtbar. Explizite Sitzungseinstellungen können nur die zwei zulässigen nicht geheimen Hinweise überschreiben, keine Sicherheitsregeln.
5. Zweite Validierung gegen Consumerformat und vertrauenswürdigen Anwendungskatalog, transitive Abhängigkeiten und Zyklus-/Konfliktprüfung. Keine Shellaktionen, URLs, Installerargumente, Secrets oder Autorisierung aus Quelldaten.
6. Gesamten normalisierten Snapshot deterministisch serialisieren, Digests vergleichen, erst dann atomar publizieren. Derselbe Quell-SHA + Adapter-/Katalogversion muss bytegleiches Ergebnis liefern. Eine fehlerhafte neue Revision aktiviert keinen Teilbestand.
7. Laufzeit liest nur den gebündelten geprüften Snapshot. Offline unverändert nutzbar, keine GitHub-API pro Request. Aktualisierung ist eigener Review-Diff mit Quelle, Format-/Mappingänderung, Tests und eventueller Migration. Veraltete Browser-Selections mit anderer Snapshot-ID müssen neu geprüft/gezielt migriert werden; kein verstecktes Aliasraten.

Spezifisch noch zu entscheiden: öffentlicher Dateisatz, Schema-/Adapter-IDs, konkrete Importlimits, Mapping für alle existierenden Profile, Zielworkflowzuordnung, Katalogrevision, Options-/Migrationssemantik und Releaseprozess. Vorher nur `local-fixture-v1`, gekennzeichnet als synthetisch und ohne externen sourceCommit.

## Getrennte Aufträge und Tests

configureMe CM-003/CM-023: Vertrag abstimmen; CM-011 erst danach Adapter/Importer. myConfigs-data nur als Vorschlag: Consumerbeschreibung aktualisieren, öffentlichen Exportumfang und gemeinsame synthetische Contractfixtures bestätigen. CM-012 wird kein Runtime-GitHub-Provider für die öffentliche Seite; ein optionaler manueller Read-only-Import benötigt eigene Rechtefreigabe. Editor, private Profile und Write-Tokens sind nicht Teil von A/B/C.

Abnahme: echte commitgebundene Quellfixtures beider Formate, unbekannte Versionen/IDs/Aktionen, fehlende Referenzen, Kollisionen, falsche Hashes, übergroße/inkompatible Dateien, Linux/macOS/ARM, Optionskonflikte, Branchbewegung, wiederholte bytegleiche Imports, Offline-Start, Fehler ohne Teilaktivierung sowie explizite öffentliche Datenfreigabe. Kein Installer oder Secret im Contracttest.
