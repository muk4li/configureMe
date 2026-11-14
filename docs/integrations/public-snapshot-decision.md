# Entscheidungsvorlage: öffentliche Profile als unveränderlicher Snapshot

**Proposed, nicht Accepted und nicht produktiv aktiviert. Stand 2026-11-14.** Dieser Text und synthetische Kompatibilitätsfixtures bereiten das Datenowner-/Consumerreview vor. Sie implementieren weder einen Adapter noch einen Provider und geben keine privaten Quelldateien öffentlich frei.

## Verifizierte Grundlagen

- configureMe: `f744d63c5d245f113e3104161abf04d9f5e900e1`, einschließlich gemergtem Setup-Plan-v1-PR #12; aktuelle Consumer `src/lib/profiles.ts`, `public-planning.ts` und `setup-plan.ts` geprüft.
- myConfigs-data: lokaler lesender Checkout `75b91cfba94476393e7cfb4fe247b3f223aa4054`; Profil-, Katalog- und Paketauswahlschema sowie Integrationsbeschreibung geprüft. Keine realen Profile übernommen, kein fremdes Repository geändert. Ein späterer Import braucht einen neu geprüften autorisierten Quell-SHA und öffentlichen Dateisatz.
- Centrality: `12776e9582cc2f9c413f40b7c6a9604f4b43e5b0`; D-001/D-002/D-005/D-006 sind Accepted, D-007 und ADR-002 bleiben Proposed. Kein lokales Testresultat akzeptiert diesen übergreifenden Vertrag.
- Der aktuelle öffentliche Provider bleibt `local-fixture-v1` mit synthetischen Profilen und ohne externen Quellcommit. Der vorhandene private LocalConfigurationProvider bleibt getrennt.

## Konkrete Entscheidungspunkte

| Entscheidung | Empfohlener Vorschlag | Alternative / Risiko |
| --- | --- | --- |
| Quelle und Freigabe | Explizit öffentlich bestätigter Dateisatz aus einem commitgebundenen myConfigs-data-Snapshot; nur Katalog und referenzierte öffentliche Profile, keine Geräte/Overrides | Separates öffentliches Repo ist möglich, benötigt aber neue Ownership, Migration und Centrality-Review; die Deklarativität eines Repos beweist keine Veröffentlichungsfreigabe |
| Format und Version | Eigene Identität `configureme/public-snapshot` und separat versionierter Adapter; Producer-, Adapter-, Consumer- und Katalogversion getrennt | Gleiche `schemaVersion: 1` zu übernehmen verschleiert die nachgewiesenen inkompatiblen Formate |
| Zielworkflow | Explizite Freigabetabelle pro Profil/Paket und Ziel Windows 11 oder Server 2022 x64; generic `platforms: [windows]` bedeutet nicht beide Ziele | Ableitung aus `windows` kann Server-only-Pakete oder einen ungetesteten nativen Adapter implizit freischalten |
| IDs | Versionierte Positivliste, einschließlich bewusst freigegebener identischer IDs; keine globale Aliasumbenennung | `powershell`/`powershell-7` und `7zip`/`seven-zip` bezeichnen im Consumer unterschiedliche Legacy-/native Wege |
| Größenlimits | Maximal 8 Profile/Snapshot, 50 eindeutige Pakete/Profil, 80 Zeichen Name und 240 Beschreibung; Gesamtbyte-/Datei-/Tiefenlimit vor Adapterfreigabe explizit festlegen | Producer erlaubt längere Namen/Beschreibungen und keine feste Paketobergrenze; stilles Kürzen verliert Nutzerauswahl. Einzelne Consumergrenzen sind keine bereits abgestimmten Producerlimits |
| Reihenfolge | Sortierte stabile Vereinigung und topologische Abhängigkeiten wie im öffentlichen Consumer, unabhängig von Profilauswahlreihenfolge | Die Producerbeschreibung nutzt Profil-/Arrayreihenfolge und erstes Auftreten. Diese Semantik ist ausdrücklich abzustimmen, nicht nur `platforms` umzubenennen |
| Optionen | Abwesend bleibt ungesetzt; gegenläufige Booleans sind sichtbare Konflikte; nur die zwei bestehenden nicht geheimen Erinnerungen | Last-write-wins oder Default-false verändert Bedeutung und kann Konflikte verbergen. Persönliche Einstellungen benötigen später einen getrennten Vertrag |
| Aktivierung | Vollständige Quell-/Referenz-/Mapping-/Consumerprüfung, dann atomarer Snapshotwechsel mit Diff und erneuter Planprüfung | Teilaktivierung kann fehlende Profile/Abhängigkeiten als erfolgreiche Auswahl ausgeben |
| Offline und veraltete Revision | Ein zuvor ausdrücklich aktivierter, erneut validierter gebündelter Snapshot funktioniert offline; Revision sichtbar, unbekannte Browser-Snapshot-ID geschlossen ablehnen | Automatisches Mischen/Refreshen, stille Migration oder ein erfundenes Maximalalter. Ein konkretes Alters-/Widerrufsmodell ist vor produktivem Import festzulegen |

Die Formatidentitäten und Limits oben sind konkrete Vorschläge für das Review, keine neue Produktfreigabe. Der Setup-Plan bleibt ein eigener lokaler Vertrag; ein Quellcommit oder numerisches catalogVersion ersetzt weder dessen Katalogdigest noch die Identität eines öffentlichen Snapshots.

## Abnahme vor produktivem Adapter

Datenowner und configureMe-Owner müssen Dateisatz, Identitäten/Versionen, Mapping/Zielworkflows, Grenzen, Options-/Reihenfolgesemantik, Aktualisierung/Offline und Rücknahme bestätigen. Bei Änderung globaler Quellen-/Repositoryzuständigkeit ist Centrality-Review erforderlich. Erst danach folgen implementierter Adapter und vollständige commitgebundene Produzenten-/Konsumententests, keine Laufzeit-GitHub-Lesezugriffe als Nebenwirkung.

Der spätere Import liest nur lokal gebundene Schemas, keine vom Inhalt vorgegebenen Netzreferenzen. Erwartetes vollständiges Dateiset, Quell-SHA, Größe/Digests, alle Referenzen und Consumerkompatibilität werden vor Aktivierung geprüft. Ein Hash allein ist kein Herkunftsnachweis. Fehlgeschlagene neue Revision lässt den bisherigen gültigen Snapshot unverändert und zeigt den Fehler; sie erzeugt keinen Teilplan. Private Vorlagen/Secrets benötigen getrennte autorisierte Lesewege und gehören weder in die öffentliche UI noch ins Standard-Setup-JSON.

## Jetzt ausgeführte, begrenzte Vorbereitung

`tests/fixtures/public-profile-boundaries/*.json` enthält ausschließlich neu erfundene source-shaped Beispiele, keine kopierten privaten Profile. `tests/public-profile-boundaries.test.ts` prüft echte vorhandene Consumer: source-shaped Daten und Versionsfehler bleiben unverträglich, gemischte Bestände werden vollständig abgelehnt, Größenlimits werden nicht still gekürzt, Quellrevisionen ersetzen keine Snapshot-ID und Legacy-Aliase/Zielworkflows werden nicht geraten. Ein positiver lokaler Kontrollfall verhindert einen bloßen Alles-ablehnen-Test.

Diese Tests prüfen die heutige Ablehnungsgrenze; sie validieren keinen zukünftigen Producervertrag und behaupten keine funktionierende Datenintegration. Es gibt bewusst keine neue `src/`-Adapterfunktion, keine Schema-Kopie aus einem privaten Nachbar-Repo, keinen Netzabruf und keine neue Abhängigkeit. Die spätere vollständige Snapshotabnahme bleibt [Proposed](public-snapshot-v1-proposal.md).
