# CM-043: Linux-Bundle aus dem lokalen Portal – Vertrag

- Status: **Accepted** (2026-11-15, alle drei Entscheidungen durch den Eigentümer). Implementiert auf Branch `feat/cm-043-linux-bundle`; nicht real auf `huu-server-01` betrieben.
- Auftrag: [CM-043](../TASKS.md#cm-043); Rahmen: [Lokaler Portal-Handoff](huu-local-portal-handoff.md), [Linux-Plan v1](linux-plan-contract.md) (Accepted), Centrality [ADR-004](https://github.com/muk4li/centrality/blob/main/docs/decisions/ADR-004-HUU-FIRST-DEPLOY.md).
- Basis: configureMe `main` `d91e8dc` (Linux-Runner integriert, 93 Mocktests, nicht real betrieben).

## Nutzerfluss (Eigentümerwunsch 2026-11-15)

1. configureMe läuft lokal auf dem Windows-Host (`127.0.0.1`), nicht öffentlich.
2. Im **Host-Browser**: Linux-Profil `huu-server-01` wählen, bei Bedarf Zusatzinstallationen anhaken, Plan serverseitig prüfen lassen, Bundle herunterladen. Die VM braucht keinen Browser.
3. Bundle per **`scp`** auf die VM kopieren (Accepted, siehe Entscheidung 1).
4. Auf der VM: Prüfsumme vergleichen, entpacken, Dry-Run ohne Root, danach `sudo … --apply` nur nach eigener Freigabe (unverändert aus CM-042).

Das Portal verbindet sich nie mit der VM, führt nichts aus und erhält keinen Rückkanal.

## Entscheidung 1: Transport zur VM (Accepted: A, `scp`)

| Option | Bewertung |
| --- | --- |
| **A: Download im Host-Browser, dann `scp`** (Accepted 2026-11-15) | VM spricht nie mit dem Portal; kein Tunnel, keine Firewall-/LAN-Freigabe, kein `0.0.0.0`. Bundle < 1 MB, Übertragung im LAN praktisch sofort. CM-044 wird für diesen Weg **nicht benötigt**. |
| B: Reverse-SSH-Tunnel, VM lädt selbst | Portal während des Tunnels für jeden VM-Prozess erreichbar; bleibt als spätere CM-044-Option dokumentiert. |
| C: LAN-Freigabe des Portals | widerspricht CM-044-Grenzen ohne HL-018-Firewallmatrix; ausgeschlossen. |

## Entscheidung 2: Zusatzinstallationen (Accepted)

Zusatzinstallationen werden als **eigene Katalogschritte** umgesetzt. Das Planformat `configureme/linux-plan` v1 bleibt **unverändert**: Ein Plan wählt wie bisher nur Schritt-IDs aus dem Katalog. Paketnamen bleiben Anwendungscode (`linux/catalog.json` + `linux/trusted.py`), nie Plandaten. Alle Zusatzpakete stammen aus dem Ubuntu-Archiv, sind nicht gepinnt (Sicherheitsupdates sollen greifen), haben keine Abhängigkeiten auf Docker-Schritte und werden wie `base-tools` per `dpkg-query` erkannt und mit `apt-get install --yes` installiert.

| Schritt-ID | Paket | Zweck | Status |
| --- | --- | --- | --- |
| `tool-jq` | `jq` | JSON in der Shell lesen (z. B. Runner-Bericht, Docker-Ausgaben) | **Accepted** |
| `tool-python3-venv` | `python3-venv` | isolierte Python-Umgebungen ohne System-pip | **Accepted** |
| `tool-htop` | `htop` | Prozesse/Last ansehen | **Accepted** |
| `tool-tmux` | `tmux` | SSH-Sitzungen, die einen Verbindungsabbruch überleben (sinnvoll für lange `--apply`-Läufe) | **Accepted** |
| `tool-unzip` | `unzip` | ZIP-Archive entpacken | **Accepted** |
| `tool-rsync` | `rsync` | Dateien/Backups effizient kopieren | **Accepted** |
| `tool-ncdu` | `ncdu` | Plattenbelegung finden (VHDX ist auf 100 GiB begrenzt) | **Accepted** |
| `tool-tree` | `tree` | Verzeichnisstruktur anzeigen | **Accepted** |

Bewusst **nicht** aufgenommen: `fail2ban`/`ufw` (Firewall/Isolation gehört zu myHome-Lab), `python3-pip` systemweit (stattdessen venv), Node.js/Fremd-Repos (würden neue Quellen und Schlüssel erfordern), Tailscale/VPN (außerhalb des Umfangs).

Folge: Der Katalog-Hash (`catalogRevision`) ändert sich. Der bestehende Plan `linux/plans/huu-server-01.json` wird mit neuem Hash aktualisiert; ältere Pläne mit altem Hash werden – wie vertraglich vorgesehen – abgelehnt.

## Entscheidung 3: Wo liegt die Download-Funktion? (Accepted: A, lokaler Modus)

configureMe trennt die öffentliche Vorschau (ohne Login) vom geschützten Portal (GitHub-OAuth). Ein Bundle enthält ausführbaren Runner-Code; laut Produktrahmen dürfen ausführbare Downloads nicht beiläufig öffentlich werden.

| Option | Bewertung |
| --- | --- |
| **A: Nur im lokalen Modus** (**empfohlen**) | Route existiert nur, wenn der Server mit `CONFIGUREME_LOCAL_LINUX_BUNDLE=1` gestartet wird **und** die Anfrage über Loopback mit `Host` `127.0.0.1`/`localhost` kommt; sonst 404. Kein OAuth-Setup für den lokalen Einsatz nötig. Standard: aus. Öffentliche Deployments liefern nie ein Bundle. |
| B: Nur im geschützten Portal (Login) | stärkste Trennung, verlangt aber `AUTH_SECRET`/GitHub-OAuth lokal, nur um eine Datei zu erzeugen. |
| C: Öffentliche Route | ausgeschlossen (Produktrahmen, CM-001). |

## Bundle-Format (Accepted)

- Datei: `configureme-linux-<shortsha>.tar.gz`, Wurzelordner `configureme-bundle/` (tar ist auf Ubuntu Server immer vorhanden, `unzip` nicht).
- Inhalt (alles unter einem Wurzelordner):
  - `linux/*.py`, `linux/catalog.json` – unveränderter Runner aus dem laufenden Checkout
  - `plan.json` – der serverseitig validierte Plan
  - `MANIFEST.json` – `formatId: configureme/linux-bundle`, `schemaVersion: 1`, `sourceCommit`, `catalogRevision`, `planSha256`, Liste aller Dateien mit SHA-256
  - `ANLEITUNG.txt` – Prüf- und Ausführungsschritte
- Reproduzierbar: feste Dateireihenfolge, `mtime` 0, uid/gid 0, Dateien 0644, Ordner 0755, gzip-Kopf ohne Zeit und mit festem OS-Byte (Runner wird mit `python3 …` gestartet, kein Ausführungsbit nötig). Gleiche Eingaben ergeben mit derselben Node-Version ein byte-gleiches Archiv (getestet); über verschiedene Node-/zlib-Versionen ist das nicht zugesichert – maßgeblich ist der im Browser angezeigte Hash.
- Runner-Anpassung: Ohne `.git` liest der Bericht den Commit aus `MANIFEST.json` statt „unbekannt“; vor jedem Lauf prüft der Runner die Datei-Hashes gegen das Manifest und bricht bei Abweichung ab.

## Herkunft und Integrität (ehrliche Grenze)

- Ein SHA-256 aus demselben Bundle beweist **keine Herkunft** (siehe Handoff-Vertrag). Für diesen lokalen Weg gilt: Der Eigentümer betreibt das Portal selbst aus einem bekannten Commit; die Portalseite zeigt `sourceCommit`, `catalogRevision` und den SHA-256 des Archivs. Nach `scp` vergleicht er `sha256sum` auf der VM mit der Anzeige im Host-Browser (Integrität der Übertragung). Den `sourceCommit` kann er unabhängig auf GitHub prüfen.
- Release-Signierung bleibt CM-001; dieses Bundle ist ausdrücklich ein **lokales Test-Handoff**, keine Distribution.

## Weboberfläche (Accepted)

- Neuer Bereich „Linux-Server (Ubuntu 24.04)“, nur sichtbar im lokalen Modus (Entscheidung 3).
- Profil `huu-server-01` vorausgewählt: `base-tools`, `docker-apt-repository`, `docker-engine`, `unattended-upgrades`; Docker-Gruppe fest `false` (Accepted in CM-042).
- Zusatzinstallationen als Checkboxen mit Kurzbeschreibung; Abhängigkeiten werden angezeigt, nie still ergänzt.
- Docker-Gruppe ist im Bundle nicht wählbar (Schema erlaubt nur `false`). Das Bundle wird nur aus einem sauberen Commit erzeugt (uncommittete Änderungen in `linux/` → HTTP 409).
- „Bundle herunterladen“ zeigt danach SHA-256, Commit und die fertigen Befehle für `scp`, `sha256sum`, Entpacken, Dry-Run und Apply.

## Abnahme und Tests

- Python: neue Katalogschritte (Erkennung, Installation, Idempotenz) mit synthetischem Host; Manifest-Prüfung (fehlende/geänderte/zusätzliche Datei → Abbruch); Commit aus Manifest im Bericht.
- TypeScript: Planvalidierung serverseitig (unbekannte Schritt-IDs, Duplikate, fehlende Abhängigkeit, falsches Ziel → Ablehnung), reproduzierbares Archiv (zweimal bauen = gleicher Hash), Route ohne lokalen Modus bzw. mit fremdem `Host` → 404.
- Browser: Profil wählen, Zusatzpaket anhaken, Bundle herunterladen, Hash angezeigt.
- Keine echte Installation in CI; realer Test auf `huu-server-01` erst durch den Eigentümer.

## Umsetzung (2026-11-15)

- Route `GET/POST /api/local/linux-bundle` (`src/app/api/local/linux-bundle/route.ts`), Seite `/linux`; beide 404 ohne `CONFIGUREME_LOCAL_LINUX_BUNDLE=1` oder mit fremdem `Host`. POST nur same-origin (`Origin` = `http://<Host>`).
- Start: `npm run local:linux` (bindet `127.0.0.1:3000`, setzt die Variable), dann `http://127.0.0.1:3000/linux`.
- Builder `src/lib/linux-bundle.ts` (nur Node-Standardbibliothek + vorhandenes zod), Runner-Prüfung `linux/bundle_manifest.py`.
- Geprüft: Python 101 Tests, vitest inkl. Rundlauf Archiv → Python-Manifestprüfung, Dry-Run eines entpackten Bundles in einem Ubuntu-24.04-Container (Manifest ok, Commit aus Manifest), HTTP-Gating per curl gegen `next start`. **Nicht geprüft:** Windows-Host, echtes `scp`, Apply auf `huu-server-01`.
