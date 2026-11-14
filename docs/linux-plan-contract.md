# Linux-Plan v1 und lokaler Runner (CM-042) – Vertrag

- Status: **Vertrag Accepted (Eigentümerentscheidung 2026-11-14), nicht implementiert.** Entscheidungen 1–4 siehe [Eigentümerentscheidungen](#eigentümerentscheidungen-2026-11-14). Nichts davon ist implementiert, getestet oder betrieben; eine reale Installation führt nur der Eigentümer nach eigener Freigabe aus.
- Ursprünglicher Vorschlag: Proposed (2026-11-14), PR #17 (gemergt in `main` als `c458d11`).
- Auftrag: [CM-042](../TASKS.md#cm-042); Centrality [ADR-004](https://github.com/muk4li/centrality/blob/main/docs/decisions/ADR-004-HUU-FIRST-DEPLOY.md), O-024/O-025 (Accepted), geprüft in Centrality `6fee069`.
- Basis: configureMe `main` `b17968b`.
- Erster Einsatz: `huu-server-01` (Ubuntu Server 24.04 LTS, amd64), Runner wird vom Eigentümer per SSH lokal gestartet.

## Umsetzungsstand

Getrennt nach implementiert, getestet und betrieben. Nur was hier steht, ist umgesetzt.

| Teil | Implementiert | Getestet | Betrieben |
| --- | --- | --- | --- |
| Schema `schemas/linux-plan-v1.schema.json`, Policy `contracts/linux-plan-v1.policy.json` (16 KiB, Tiefe 4) | ja | Konstanten-Abgleich Schema/Policy/Python (`tests/linux/test_contract_constants.py`) | – |
| Katalog `linux/catalog.json`, feste Quellen `linux/trusted.py` | ja; Docker-Pins gesetzt und belegt in [Prüfprotokoll](audits/linux-runner.md) (2026-11-14) | Katalogvalidierung (unbekannte Felder, feste Quellen, Paketnamen, Pins, Abhängigkeiten) | – |
| Plan `linux/plans/huu-server-01.json` | ja (`addInvokingUserToDockerGroup: false`) | validiert gegen echten Katalog | – |
| Validator `linux/linux_plan.py` | ja | `python3 -m unittest discover -s tests/linux` mit synthetischen Fixtures `tests/fixtures/linux-plan-v1/` | – |
| Runner Dry-Run `linux/runner.py` (+ `detect.py`, `report.py`, `host.py`) | ja; lehnt Platzhalter-Pins ab | Mock-Tests mit synthetischem Host (`tests/linux/fake_host.py`, `test_runner_dry_run.py`); zusätzlich ein lesender Dry-Run auf einem Ubuntu-24.04-Entwicklungscontainer mit nicht eingechecktem Katalog (siehe PR) | nein |
| Runner Apply `--apply` (+ `steps.py`) | ja | Mock-Tests `test_runner_apply.py` (Idempotenz, Fingerprint-Abweichung, kein Root, kein TTY, falscher Hostname, Fehler in Schritt 2); real nur Ablehnung ohne Terminal im Entwicklungscontainer | **nein** – reale Installation nur durch den Eigentümer |

Dry-Run (Standard, ohne Root, ohne Änderung): prüft Python ≥ 3.12, `/etc/os-release` (`ID=ubuntu`, `VERSION_ID=24.04`, `VERSION_CODENAME=noble`), `dpkg --print-architecture` = `amd64`, Plan und Katalog. Erkennung über den tatsächlichen Zustand: `dpkg-query` (nur Status `ii` zählt), Fingerprint der Schlüsseldatei per `gpg --show-keys --with-colons` (Schlüssel über stdin, leeres temporäres `--homedir`, genau ein Primärschlüssel), byte-gleiche `docker.sources`/`20auto-upgrades`, `getent group docker`, `systemctl is-active docker.service`. Als Fehler (nicht automatisch behoben): Konfliktpakete laut Docker-Doku (`docker.io`, `docker-compose`, `docker-compose-v2`, `docker-doc`, `docker-buildx`, `podman-docker`, `containerd`, `runc`), fremder Schlüssel unter `docker.asc`, Alt-Datei `docker.list`, Docker-Version neuer als Pin, inaktiver Docker-Dienst, `unattended-upgrades`-Konfiguration mit `-updates`/`-proposed`/`-backports`, `Origins-Pattern` oder `Automatic-Reboot`. Jeder Schritt wird als `already-satisfied`, `would-change` (mit geplanten Aktionen), `failed` oder `skipped` mit Begründung ausgegeben. Exit-Code 0 = Dry-Run fertig, 1 = Fehler, 2 = abgelehnt.

Bericht `linux-runner-report.json` + `.txt` (Format `configureme/linux-runner-report` v1) im `--report-dir` (Standard: aktuelles Verzeichnis): Runner-Commit (aus `.git` gelesen, ohne `git` auszuführen), Plan-Dateiname und SHA-256, Katalog-SHA-256, Hostname, Vorprüfung, Optionen, Warnungen, je Schritt Status, Begründung, Versionen vorher/nachher. Keine Umgebungsvariablen, kein Roh-Output von Befehlen, keine Secrets.

Apply (`sudo python3 linux/runner.py --plan … --apply`): nur mit `euid 0` (keine Selbst-Elevation) und interaktivem Terminal; erneuter Dry-Run, bei Fehlern Abbruch ohne Änderung; bei offenen Änderungen Bestätigung durch Eingabe des Hostnamens. Danach seriell; nach jedem Schritt erneute Erkennung als Erfolgsnachweis (Exit-Code allein zählt nicht). Bei Fehler Folgeschritte `skipped`, kein Rollback, kein Neustart. `apt-get` nur mit festen Argumenten (`update` bzw. `install --yes`, `-o DPkg::Lock::Timeout=300`), `DEBIAN_FRONTEND=noninteractive`, ohne `--allow-*`/`--force-*`; Docker-Pakete als `name=version`. Schlüssel über `urllib` mit TLS-Prüfung, nur `https://download.docker.com`, keine Weiterleitungen, max. 64 KiB; Fingerprint per `gpg --show-keys --with-colons` geprüft, **bevor** Schlüssel oder `docker.sources` geschrieben werden. Dateien atomar (temporäre Datei + `rename`), Modus 0644, `/etc/apt/keyrings` 0755. `50unattended-upgrades` wird nie geschrieben. Docker-Gruppe nur über `SUDO_USER` (`usermod --append --groups docker`), `root`/UID 0 abgelehnt. Fehlerzeilen von Befehlen erscheinen nur im Terminal, nie im Bericht.

Validator-Regeln: Größe ≤ 16 384 Byte, Verschachtelungstiefe ≤ 4 (vor dem Parsen geprüft), UTF-8 ohne BOM, doppelte Schlüssel (`object_pairs_hook`), `NaN`/`Infinity`, unbekannte und fehlende Felder, exakte Typen (`true` ist keine `1`), `catalogRevision` = SHA-256 der Katalogdatei, Schritte nur aus dem Katalog, eindeutig, in Katalogreihenfolge, Abhängigkeiten aus dem Katalog geprüft und nie ergänzt, Docker-Gruppe nur mit `docker-engine`. Der Katalog muss die festen Quellen aus `linux/trusted.py` exakt wiederholen und darf keine Pakete ergänzen; Platzhalter-Pins werden erkannt (`placeholder_pins`), der spätere Runner lehnt sie ab.

## Problem

ADR-004 weist die Servereinrichtung nach der Ubuntu-Grundinstallation einem configureMe-Linux-Runner zu. configureMe hat bisher keinen Linux-Weg ([linux.md](linux.md)). Gebraucht wird ein deklarativer, versionierter Plan und ein lokaler Runner, der den Plan ohne freie Befehle, mit Dry-Run, Bestätigung und idempotent umsetzt.

## Umfang

| Im Umfang | Nicht im Umfang |
| --- | --- |
| Basiswerkzeuge aus dem Ubuntu-Archiv (`ca-certificates`, `curl`, `git`, `gnupg`) | Firewall/ufw, Hyper-V-Port-ACLs, Isolation (myHome-Lab) |
| Offizielles Docker-APT-Repo mit fest im Code hinterlegtem Schlüssel-Fingerprint | Caddy, Homepage und weitere Apps (kommen per Compose) |
| Docker Engine + Compose-Plugin in gepinnten Versionen | Hyper-V, Autoinstall, Benutzer, SSH-Key, Locale (myHome-Lab) |
| `unattended-upgrades` aktivieren (nur Sicherheitsupdates, kein automatischer Neustart) | VPN/Tailscale, Secrets, Zertifikate |
| Optional: aufrufenden Benutzer zur Gruppe `docker` hinzufügen, nur wenn im Plan ausdrücklich gesetzt | Webportal-Ausführung, Remote-Agent, Fernsteuerung |

**Hinweis zu ADR-004:** Dort steht in der Zuständigkeitstabelle bei configureMe noch „Firewall“, in der Zeile darunter „Ubuntu-Firewall“ bei myHome-Lab. Dieser Vorschlag folgt deiner Vorgabe (Firewall gehört zu myHome-Lab). In Centrality wurde nichts geändert, weil Cross-Repo-Schreibzugriffe eine eigene Freigabe brauchen. Vorschlag: die Zeile in ADR-004 bei Gelegenheit bereinigen.

## Entscheidung 1: Setup-Plan v1 erweitern oder eigener Linux-Plan? (Accepted: B)

| Kriterium | A: `configureme/setup-plan` v1 erweitern | B: eigenes Format `configureme/linux-plan` v1 (**empfohlen**) |
| --- | --- | --- |
| Bestehende Konsumenten | TS-Exporter, .NET-Importer, gemeinsame Fixtures müssen Linux-Fälle kennen und ablehnen | unverändert; Windows-Gates bleiben unberührt |
| `catalogRevision` | bindet heute den SHA-256 des Windows-Katalogs; ein zweiter Katalog bräuchte v2 oder eine Unterscheidung | eigener SHA-256 des Linux-Katalogs |
| Paketmodi | `winget`, `automatic`, `manual`, … passen nicht zu APT-Repo, Dienst- und Gruppenschritten | eigene, kleine Schrittart-Liste |
| Policy | `nativeTarget: windows-server-2022` ist fest | eigene Policy-Datei |
| Erzeuger | öffentliches Webportal | zunächst nur Repo-Datei; kein Webexport |
| Risiko | Vertragsänderung an einem gemergten, getesteten Format (v2-Migration) | ein zusätzliches Format; Pflege von zwei Schemas |

Begründung für B: Der Windows-Vertrag ist gemergt und getestet, seine Felder (Modi, Katalog-Hash, Zielmatrix, Optionen) sind Windows-spezifisch. Eine Erweiterung würde ohne Nutzen zwei Konsumenten und alle Fixtures berühren. B übernimmt die bewährten Muster (feste `formatId`/`schemaVersion`, `catalogRevision` als SHA-256, `authorization: none`, strikte Ablehnung unbekannter Felder, Größen- und Tiefenlimit), ohne den bestehenden Vertrag zu ändern. Eine spätere Zusammenführung bleibt als explizite v2 möglich.

## Entscheidung 2: Runner-Technik (Accepted: Python 3.12+ Standardbibliothek)

| Option | Bewertung |
| --- | --- |
| **Python 3 Standardbibliothek** (**empfohlen**) | `python3` ist laut Eingangszustand vorhanden (Ubuntu 24.04: 3.12). `json`, `subprocess`, `hashlib`, `argparse` reichen. Strikte Validierung und Tests mit `unittest` + Mocks ohne zusätzliche Pakete. `subprocess` mit Argumentlisten, nie `shell=True`. |
| Bash | keine strenge JSON-Validierung ohne `jq` (nicht im Eingangszustand); Mocks/Tests umständlich; Quoting-Risiko |
| Ansible | widerspricht der befristeten Ausnahme O-024 und bräuchte Zusatzpakete |
| Node/TypeScript wie das Portal | Node ist auf dem Ziel nicht vorhanden |

Keine Drittanbieter-Python-Pakete, kein `pip`. Mindestversion im Runner geprüft (`>= 3.12`), damit ein falsches Zielsystem früh abbricht.

## Entwurf: Planformat `configureme/linux-plan` v1

Beispiel (synthetisch, nicht ausführbar, enthält keine Secrets):

```json
{
  "formatId": "configureme/linux-plan",
  "schemaVersion": 1,
  "catalogRevision": "<sha256 von linux/catalog.json>",
  "authorization": "none",
  "target": { "os": "ubuntu-24.04", "architecture": "amd64" },
  "steps": ["base-tools", "docker-apt-repository", "docker-engine", "unattended-upgrades"],
  "options": { "addInvokingUserToDockerGroup": false }
}
```

- `steps`: nur IDs aus dem Linux-Katalog, eindeutig, Abhängigkeiten (z. B. `docker-engine` → `docker-apt-repository` → `base-tools`) werden aus dem Katalog geprüft, nicht aus dem Plan übernommen. Fehlende Abhängigkeit = Ablehnung, keine stille Ergänzung.
- `options.addInvokingUserToDockerGroup`: einzige Option. Der Benutzername steht **nicht** im Plan; der Runner nimmt `SUDO_USER` und lehnt `root` ab.
- Kein Feld für Befehle, URLs, Pfade, Paketnamen, Versionen, Schlüssel oder Umgebungsvariablen. Unbekannte Felder, doppelte Schlüssel, falscher Typ, Datei > 16 KiB → Ablehnung.
- Ablage: `linux/plans/huu-server-01.json` im Repo; enthält nur die obigen nicht geheimen Daten.

## Linux-Katalog (Anwendungscode, nicht Plandaten)

`linux/catalog.json` + Python-Code definieren je Schritt fest:

| Schritt | Feste Quelle | Erkennung (tatsächlicher Zustand) |
| --- | --- | --- |
| `base-tools` | Ubuntu-Archiv: `ca-certificates`, `curl`, `git`, `gnupg` | `dpkg-query -W` installierte Version |
| `docker-apt-repository` | `https://download.docker.com/linux/ubuntu/gpg` → `/etc/apt/keyrings/docker.asc`, `/etc/apt/sources.list.d/docker.sources` (deb822, `Suites: noble`, `Components: stable`, `Architectures: amd64`) | Fingerprint der Schlüsseldatei = `9DC8 5822 9FC7 DD38 854A  E2D8 8D81 803C 0EBF CD88`; Inhalt der Sources-Datei byte-gleich mit Sollinhalt |
| `docker-engine` | `docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin` in exakten Versionen | `dpkg-query` Version = Pin; `docker version` / `docker compose version` |
| `unattended-upgrades` | Ubuntu-Archiv-Paket, Konfiguration `/etc/apt/apt.conf.d/20auto-upgrades` mit festem Inhalt | Paketversion + Dateiinhalt |
| Docker-Gruppe (Option) | `usermod -aG docker <SUDO_USER>` | `getent group docker` |

- Schlüssel: Download über HTTPS (Python `urllib` mit TLS-Prüfung, keine Redirects auf fremde Hosts), dann Fingerprint-Prüfung mit `gpg --show-keys` **vor** dem Ablegen. Abweichung = Abbruch ohne Änderung.
- Versions-Pins: Docker-Paketversionen stehen im Katalog (z. B. `5:<version>-1~ubuntu.24.04~noble`). Die konkreten Werte werden erst im PR „Installationsschritte“ gegen das aktuelle Docker-Repo ermittelt und in dessen Prüfprotokoll belegt; hier bewusst noch keine Zahl, damit kein ungeprüfter Wert entsteht. Ubuntu-Archivpakete werden nicht gepinnt (Sicherheitsupdates sollen greifen), ihre Version wird nur berichtet.
- `apt-get` immer mit festen Argumentlisten, `DEBIAN_FRONTEND=noninteractive`, ohne `--allow-unauthenticated`/`--force-*`.

## Ablauf und Sicherheitsgrenzen

1. `git clone` eines **festen configureMe-Commits** auf die VM, `git checkout <sha>`; der Runner meldet den eigenen Commit im Bericht.
2. `python3 linux/runner.py --plan linux/plans/huu-server-01.json` = **Dry-Run (Standard)**: validiert Plan, Katalog-Hash, OS (`/etc/os-release`: `ID=ubuntu`, `VERSION_ID=24.04`) und Architektur (`dpkg --print-architecture` = `amd64`), erkennt den Ist-Zustand und listet jeden Schritt als `bereits erfüllt` oder `würde ändern` mit Begründung. Läuft ohne Root, ändert nichts, schreibt nur den Bericht ins Arbeitsverzeichnis.
3. `sudo python3 linux/runner.py --plan … --apply`: Runner prüft `euid == 0` (keine Selbst-Elevation), zeigt den Dry-Run erneut und verlangt die Eingabe des Hostnamens zur Bestätigung. Ohne interaktives Terminal kein Apply.
4. Ausführung seriell; nach jedem Schritt erneute Erkennung als Erfolgsnachweis. Bei Fehler Abbruch der Folgeschritte (als `übersprungen` berichtet), kein Rollback, kein automatischer Neustart.
5. Zweiter Lauf: alle Schritte `bereits erfüllt`, keine Änderung (Akzeptanzkriterium).

Bericht (`linux-runner-report.json` + Textzusammenfassung): Runner-Commit, Katalog-Hash, Plan-Hash, Ziel, je Schritt `succeeded` / `already-satisfied` / `skipped` / `failed` mit erkannter Version vorher/nachher. Keine Umgebungsvariablen, kein Rohoutput von apt, keine Secrets.

## Docker-Gruppe (Accepted: `false` für huu-server-01)

Mitgliedschaft in `docker` ist faktisch root-gleich (Zugriff auf den Docker-Socket). Empfehlung für den ersten Durchlauf: `false`. Compose-Befehle laufen dann mit `sudo docker compose …`. Wer `true` setzt, muss das im Plan sichtbar tun; der Bericht weist darauf hin. Rootless Docker ist nicht Teil von CM-042.

## Tests (geplant, noch nicht ausgeführt)

- `python3 -m unittest` unter `tests/linux/`: Planvalidierung (positive/negative Fixtures), Katalog-Hash, Abhängigkeitsprüfung, Dry-Run/Apply-Logik mit gemocktem Befehlsausführer (Fixtures für `dpkg-query`, `gpg`, `os-release`), Idempotenz (zweiter Lauf → keine Aktion), Fingerprint-Abweichung → Abbruch, fehlendes Root → Ablehnung, kein `shell=True`.
- Neuer CI-Job im Web-Workflow oder eigener kleiner Workflow; bestehende Web- und Windows-Gates bleiben unverändert.
- Keine echte Installation in Tests oder CI. Die reale Abnahme auf `huu-server-01` macht nur der Eigentümer nach Freigabe.

## PR-Schnitt

1. Vorschlag (Proposed), PR #17, gemergt. Danach: Eigentümerentscheidungen als Accepted eingetragen (dieses Dokument). Kein Code.
2. Schema/Policy/Katalog + Planvalidierung + Tests.
3. Runner mit Dry-Run, Erkennung und Bericht (gemockt getestet).
4. Installationsschritte inkl. Apply/Bestätigung, gepinnte Docker-Versionen mit Quellenbeleg.
5. Doku: linux.md, REPO.md, README, Anleitung „Runner auf huu-server-01 ausführen“.

## Eigentümerentscheidungen 2026-11-14

Alle vier offenen Fragen des Vorschlags sind am **2026-11-14** vom Eigentümer entschieden (**Accepted**). Damit ist der Vertrag angenommen; Implementierung, Tests und Betrieb folgen getrennt in eigenen PRs.

| Nr. | Frage | Entscheidung (Accepted, 2026-11-14) |
| --- | --- | --- |
| 1 | Planformat | Eigenes Format `configureme/linux-plan` v1 (Option B). `configureme/setup-plan` v1 und seine Konsumenten (TypeScript-Exporter, .NET-Importer, gemeinsame Fixtures) bleiben unverändert. |
| 2 | Runner-Technik | Python 3 **Standardbibliothek**, Mindestversion **3.12**. Keine Drittpakete, kein `pip`. `subprocess` nie mit `shell=True`, nur feste Argumentlisten. Code bewusst einfach und lesbar: kleine Module, Funktionen statt Klassenhierarchien. |
| 3 | Docker-Gruppe | Plan für `huu-server-01`: `addInvokingUserToDockerGroup: false`. Die Option bleibt im Format; der Bericht warnt bei `true`, weil die Gruppe `docker` faktisch root-gleich ist. |
| 4 | Versions-Pins | Pakete aus dem Ubuntu-Archiv werden **nicht** gepinnt, ihre installierte Version wird nur berichtet. Docker-Pakete (`docker-ce`, `docker-ce-cli`, `containerd.io`, `docker-buildx-plugin`, `docker-compose-plugin`) werden **exakt** gepinnt; die Werte werden gegen die offiziellen Docker-Quellen geprüft und im Prüfprotokoll belegt. |

Zusätzlich vom Eigentümer festgelegt:

- `unattended-upgrades`: nur Sicherheitsupdates, kein automatischer Neustart; `/etc/apt/apt.conf.d/50unattended-upgrades` wird nicht überschrieben (der Ubuntu-Standard aktiviert nur `-security` und `Automatic-Reboot` ist dort aus). Der Runner schreibt nur `20auto-upgrades` mit festem Inhalt.
- Docker-Gruppe nur über `SUDO_USER`; `root` oder fehlender `SUDO_USER` wird abgelehnt.
- Konfliktpakete laut Docker-Doku werden erkannt und als Fehler gemeldet, nicht automatisch entfernt.
- Nicht im Umfang bleiben Firewall/ufw, Isolation, Caddy/Apps, Hyper-V, VPN und Secrets.

Offene Fragen: **keine**. Der Hinweis zur Firewall-Zeile in ADR-004 bleibt bestehen; Centrality wird in CM-042 nicht geändert.
