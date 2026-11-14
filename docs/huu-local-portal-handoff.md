# CM-043/044: lokales Linux-Bundle und Portal-Handoff für huu

**Status:** Nachfolgender Eigentümerauftrag 2026-11-14 autorisiert die softwareseitige Implementierung CM-042/043/044. Runner und Bundle im gestapelten PR-Review; weiterhin keine Freigabe von realem Runner-`--apply`, Host-Firewall oder Portfreigabe. Referenzen: [CM-042](../TASKS.md#cm-042), [Linux-Planvertrag](linux-plan-contract.md), [Centrality ADR-004](https://github.com/muk4li/centrality/blob/main/docs/decisions/ADR-004-HUU-FIRST-DEPLOY.md), [myHome-Lab HL-012/013/017/018](https://github.com/muk4li/myHome-Lab/blob/main/TASKS.md).

## Nutzerfluss (kein Remote Execution)

1. Auf dem Windows-Host läuft **configureMe als lokales Webportal** (nicht öffentlich); `huu-server-01` wird separat durch myHome-Lab/Hyper-V provisioniert.
2. Die frisch installierte Ubuntu-VM darf das Portal über einen **ausdrücklich freigegebenen LAN-Pfad** erreichen. Der Nutzer wählt ein **Ubuntu-24.04/amd64-kompatibles** Profil und lädt das Linux-Bundle herunter.
3. Das Bundle wird **auf der Ubuntu-VM** unabhängig geprüft. Runner und Plan sind danach ohne Verbindung zum Portal lokal ausführbar.
4. Lokaler Dry-Run ohne Root und ohne Änderungen; erst nach separatem Eigentümer-Gate interaktiver `sudo ... --apply` mit angezeigtem Zielzustand und Hostname-Bestätigung.
5. Caddy, Homepage, Firewall und Außenfreigabe bleiben ausdrücklich bei myHome-Lab; Portal sendet keine Befehle an die VM und nimmt keine Rückkanal-Agentregistrierung vor.

**Ist-Grenze 2026-11-14:** `docs/linux-plan-contract.md` beschreibt derzeit einen festen Git-Commit-Checkout auf der VM. Der hier geplante Portal-/Bundle-Download **ersetzt diesen Weg nicht stillschweigend**; er ergänzt einen getrennten, zunächst zu reviewenden Distributionstransport. Linux-Webexport, Linux-Runner und erfolgreicher Download/Apply sind nicht auf `main` nachgewiesen.

## CM-043 – Linux-Bundle aus der Weboberfläche

**Scope:** Profile und erlaubte Linux-Schritte im Portal auswählen/prüfen; serverseitig gegen `configureme/linux-plan` v1, aktuellen Katalog und Ziel `ubuntu-24.04/amd64` validieren; versioniertes Bundle bereitstellen mit Runner, Plan, Katalog, Manifest, Prüfsummen, Quellrevision und verständlicher Prüfanleitung. Keine frei wählbaren Shellbefehle/URLs in Plandaten. Keine Änderung am Windows-Setup-Plan-v1-Vertrag; keine Aktivierung bisher gesperrter öffentlicher Windows-Downloads.

**Sicherheits-/Produktentscheidungen für Implementierungsreview:** Bereitstellungsroute und Auth-/Origin-/Downloadlimits getrennt festlegen; öffentliche Preview und private Installerdistribution nicht vermischen. Version/Manifest an geprüften Source-Commit und Katalogrevision binden. **Ein mit demselben ZIP gelieferter SHA-256 beweist keine Herkunft**; für Test-Handoff müssen Bundle-Hash/Commit aus einem **unabhängig vertrauenswürdigen Kanal** verifiziert werden. Release-Signierung bleibt eigener Trust-Gate (CM-001). Portal darf keine Root-/SSH-/Hyper-V-Operation übernehmen.

**Abnahme:** synthetische Mehrprofil-/Abhängigkeitsfälle, falscher OS/Arch/Katalogrevision, Duplicate-IDs, beschädigtes/verändertes ZIP, fehlende Dateien, fehlerhafte Berechtigungen und unzulässige Downloads werden kontrolliert abgewiesen. Paket ist nach Download offline prüfbar und ohne Portal ausführbar. Genau definierte Versionen und reproduzierbarer Manifestinhalt; Tests ohne echte Installation.

## CM-044 – kontrollierter Portalzugang vom Gast

**Scope:** Hostname/Port/Protokoll, Browser- und Downloadpfad, TLS-/Herkunftsnachweis und notwendige Windows-Firewall-Anbindung **als Schnittstellenvertrag** mit HL-018 definieren. Bestehende Loopback-/OAuth-/CSRF-Grenzen nicht durch pauschales Bind an `0.0.0.0` oder Proxy-Header-Bypass umgehen.

**Abnahme:** Nach Host-/VM-Freigabe: Gast kann Portal und **genau** erlaubten Downloadpfad erreichen; unerlaubte LAN-Clients, Router/Internet und Admin-/Installerendpunkte werden durch Negativtests überprüft. Falls TLS im LAN noch nicht vertrauenswürdig verfügbar ist, gilt **kein unkontrollierter Root-Installer-Download**; stattdessen Offline-/Git-Commit-Handoff oder separat freigegebener, unabhängig verifizierter Testtransport. Keine Router-Portfreigabe des configureMe-Portals.

**Owner-Schnittstelle:** configureMe verantwortet sichere Anwendungslaufzeit, Download und prüfbare Artefakte; myHome-Lab verantwortet Windows-Host/Hyper-V/VM-Netz/Firewall. Ein eigenes offizielles `SERVICE.md` nach Centrality CE-103 folgt für den deploybaren Portal-Dienst und dokumentiert den endgültig implementierten Vertrag; dieses Dokument ist **nur ein Plan**.

## Abhängigkeiten und Gates

- CM-043 benötigt den akzeptierten CM-042-Linux-Plan und einen **reviewten, vorhandenen Runner**; zunächst dürfen Fixture-/Stub-Verträge entstehen, aber kein funktionsfähiger Installer vorgetäuscht werden.
- CM-044 benötigt HL-011/015/016-Hostinventur sowie HL-012/013-VM-Netz. Lokaler Gastzugang ist nicht gleich Produktions- oder Internetfreigabe.
- Erst `HL-012/013 + CM-042 + CM-043/044` → echter Download/Dry-Run; erst Eigentümerfreigabe → Apply; danach `HL-017/018` → Caddy/Firewall; erst dann DNS/Internet-Gate.
- Secrets, reale interne IPs, persönliche Profile und Hostinventur-Rohdaten bleiben außerhalb des Git-Repos.

## Implementierungsstand im Review

CM-043: `/linux` und öffentlicher Planexport implementiert; ZIP nur separat aktivierter, privat authentifizierter Loopback-Entwicklungsdownload. Kein Release. Sauberer Git-Checkout und unabhängiger Herkunftsnachweis erforderlich, siehe [Prüfanleitung](linux.md). Der direkte feste Git-Commit bleibt der Offline-Fallback. Echte VM-/LAN-Abnahme offen; historische Planabschnitte oben beschreiben das Gesamtziel, keinen heutigen Betriebsnachweis.

## CM-044: softwareseitige Grenze implementiert

`npm run preview:lan` prüft explizite Host-/Client-IP und Port, ohne Listener zu
starten. Erst `--start` würde binden; hier nicht ausgeführt. Die Socket-/Host-/
Origin-/Pfadallowlist ist synthetisch getestet. HTTP-LAN bietet ausschließlich
Linux-Planung/JSON, keine Anmeldung und keine ausführbaren Downloads. Details:
[Deployment](deployment.md#kontrollierter-lan-planungsmodus-cm-044-noch-keine-betriebsfreigabe).
Reale IPs/Adapter/Firewall/TLS und VM-E2E bleiben blockiert bei myHome-Lab und Betreiber.
CM-044 bleibt **Blocked**. Dieser begrenzte Modus ist keine vollständige Abnahme des
ursprünglich gewünschten direkten Bundle-Downloads von der VM.

## Nach Provisionierung der VM

1. Mit myHome-Lab Ubuntu 24.04/amd64, Python >=3.12, Host-/VM-IP, Adapter und
   begrenzten Firewallpfad klären. configureMe nimmt diese Änderungen nicht vor.
2. Die drei gestapelten PRs reviewen; geprüften festen Quellcommit verwenden.
3. Loopback-Portal oder separat genehmigten LAN-Planungsmodus nutzen; Profile und
   Docker-Gruppenentscheidung prüfen, JSON exportieren. Kein Apply über Browser.
4. Bundle lokal authentifiziert erzeugen und unabhängig geprüft offline übertragen
   oder direkt den geprüften Git-Commit auf die VM bringen. Zuerst unabhängigen
   Archivhash/Quellcommit prüfen; Verifier nur aus vertrauenswürdigem Checkout starten.
5. Als normaler VM-Benutzer Dry-Run ausführen, Plan/Katalog/Bericht prüfen. Pin- und
   Docker-Schlüssel-Aktualität vor Apply erneut aus offiziellen Quellen verifizieren.
6. Erst nach separater Eigentümerfreigabe interaktiv lokal mit Root `--apply`;
   danach Dry-Run und Wiederholung/Erkennung prüfen. Caddy, Firewall und Homepage
   sind nachfolgende myHome-Lab-Arbeit. Reale Ergebnisse getrennt dokumentieren.
