# Linux

configureMe hat genau einen Linux-Weg: einen **lokalen Runner** für Ubuntu Server 24.04 amd64 (CM-042), erster Einsatz `huu-server-01`. Der Runner läuft auf dem Zielsystem selbst und wird vom Eigentümer per SSH gestartet. Das Webportal führt nichts aus und ist kein Remote-Ausführungsdienst. Vertrag: [Linux-Plan v1](linux-plan-contract.md) (Accepted 2026-11-14).

Andere Distributionen, Desktop-Linux, DNF/Pacman/Flatpak sowie das Profil `linux-developer` im Portal sind **nicht** automatisiert; das Profil bleibt eine Planungsvorlage ohne installierbare Pakete.

## Stand: implementiert, getestet, betrieben

| | Stand (2026-11-14) |
| --- | --- |
| Implementiert | Plan-Schema, Policy, Katalog mit festen Quellen und gepinnten Docker-Paketen, Validator, Runner mit Dry-Run und `--apply` (`linux/`). |
| Getestet | `python3 -m unittest discover -s tests/linux` mit synthetischem Host und synthetischen Fixtures (Python 3.12 und 3.13), CI-Workflow `linux-runner.yml` auf `ubuntu-24.04`. Zusätzlich nur lesende Läufe in einem Ubuntu-24.04-Entwicklungscontainer. Kein echtes `apt-get install` geprüft. Belege: [Prüfprotokoll](audits/linux-runner.md). |
| Betrieben | **Nein.** Auf `huu-server-01` ist der Runner noch nicht gelaufen. Die reale Installation macht nur der Eigentümer nach eigener Freigabe (Sicherheits-Gate „configureMe-Lauf mit Root-Rechten“ in Centrality ADR-004). |

## Was der Runner einrichtet

| Schritt | Inhalt |
| --- | --- |
| `base-tools` | `ca-certificates`, `curl`, `git`, `gnupg` aus dem Ubuntu-Archiv (nicht gepinnt, Version im Bericht) |
| `docker-apt-repository` | Docker-Schlüssel nach `/etc/apt/keyrings/docker.asc` (Fingerprint `9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88` fest im Code), `/etc/apt/sources.list.d/docker.sources` (deb822, `noble`, `stable`, `amd64`) |
| `docker-engine` | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` in exakt gepinnten Versionen (`linux/catalog.json`) |
| `unattended-upgrades` | Paket plus `/etc/apt/apt.conf.d/20auto-upgrades`; nur Sicherheitsupdates, kein automatischer Neustart; `50unattended-upgrades` wird nicht überschrieben |
| Option `addInvokingUserToDockerGroup` | nur wenn im Plan `true`: `SUDO_USER` zur Gruppe `docker`. Für `huu-server-01` **`false`** (Gruppe `docker` ist root-gleich). |

Nicht im Umfang: Firewall/ufw und Isolation (myHome-Lab), Caddy/Apps (danach per Compose), Hyper-V, VPN, Secrets.

Der Runner entfernt nichts, startet keine Dienste, rebootet nicht und rollt nicht zurück. Konfliktpakete (`docker.io`, `podman-docker` u. a.), eine alte `docker.list`, ein fremder Schlüssel oder eine neuere Docker-Version als der Pin werden als Fehler gemeldet und müssen manuell geklärt werden.

## Runner auf huu-server-01 ausführen

Voraussetzung: Ubuntu Server 24.04 per Autoinstall (myHome-Lab), SSH-Zugang mit eigenem Benutzer mit sudo-Rechten. `python3` (3.12) und `git` sind in der Server-Grundinstallation enthalten.

**Fester Stand:** Ausgeführt wird immer ein bestimmter Commit, nie ein Branch-Kopf. Geprüfter Runner-Stand dieser PR-Kette: `8fc72b5cfc741df78f9fdb4a8038b23ee4b9153c` (Branch `cm-042-4-apply`). Nach dem Merge nach `main` erhält der Code einen neuen Commit; dann diesen `main`-SHA verwenden und prüfen, dass `linux/catalog.json` denselben Hash hat (Schritt 3).

1. Anmelden (aus dem LAN):

   ```bash
   ssh <benutzer>@huu-server-01
   ```

2. Repository holen und den festen Commit auschecken:

   ```bash
   git clone https://github.com/muk4li/configureMe.git
   cd configureMe
   git checkout 8fc72b5cfc741df78f9fdb4a8038b23ee4b9153c
   ```

3. Katalog-Hash prüfen (muss zum Prüfprotokoll passen):

   ```bash
   sha256sum linux/catalog.json
   ```

   Erwartet: `0b8ceff0a4ee398aa7d06013019d5283cd5567d04fed7168a1ad2ee8b06f47d3`.

4. Dry-Run als normaler Benutzer (ohne sudo, ändert nichts):

   ```bash
   python3 linux/runner.py --plan linux/plans/huu-server-01.json
   ```

5. Bericht prüfen (`linux-runner-report.txt`, ausführlich `linux-runner-report.json`): Vorprüfung überall `ok`, Runner-Commit = Schritt 2, kein Schritt `FEHLER`. Auf einer frischen VM sind typischerweise `docker-apt-repository` und `docker-engine` „würde ändern“, `base-tools` und `unattended-upgrades` „bereits erfüllt“.

6. Anwenden (eigene Freigabe des Eigentümers; nur im interaktiven SSH-Terminal):

   ```bash
   sudo python3 linux/runner.py --plan linux/plans/huu-server-01.json --apply
   ```

   Der Runner zeigt den Dry-Run erneut und fragt nach dem Hostnamen. `huu-server-01` eingeben; jede andere Eingabe bricht ohne Änderung ab. Danach laufen die Schritte nacheinander; nach jedem prüft der Runner den tatsächlichen Zustand. Bei einem Fehler werden die folgenden Schritte übersprungen. Die Berichtsdateien gehören danach root.

7. Zweiter Dry-Run, erwartet überall „bereits erfüllt“ und `Ergebnis: no-changes`:

   ```bash
   python3 linux/runner.py --plan linux/plans/huu-server-01.json
   ```

8. Kurzer Funktionstest:

   ```bash
   sudo docker compose version
   ```

   ```bash
   sudo docker version
   ```

Ohne Docker-Gruppe (Plan: `false`) laufen alle Docker- und Compose-Befehle mit `sudo`, z. B. `sudo docker compose up -d`. Das ist gewollt.

Ein erfolgreicher Lauf ist keine Sicherheitsfreigabe: Firewall/Isolation, Router-Freigabe und Veröffentlichung sind eigene Gates in myHome-Lab bzw. Centrality.

## Exit-Codes

`0` Dry-Run fertig bzw. Apply erfolgreich · `1` Validierung, Vorprüfung, Erkennung oder ein Schritt fehlgeschlagen · `2` abgelehnt oder abgebrochen (kein root, kein Terminal, Hostname falsch), nichts geändert.

## Entwicklung

```bash
python3 -m unittest discover -s tests/linux -v
```

Tests starten keine echten Systembefehle zum Ändern; alle Zustände kommen aus `tests/linux/fake_host.py`. Neue Docker-Versionen nur mit neuem Eintrag im [Prüfprotokoll](audits/linux-runner.md) und neuem `catalogRevision` in den Plänen.
