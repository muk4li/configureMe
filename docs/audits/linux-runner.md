# Prüfprotokoll: Linux-Runner (CM-042) – Docker-Pins und Schlüssel

- Prüfdatum: **2026-11-14**, Abruf 12:10 UTC (Erstabruf 11:55 UTC mit identischen Ergebnissen).
- Repo/Branch: configureMe `cm-042-4-apply` (aufbauend auf `cm-042-3-runner-dry-run` `0b6023e`).
- Geprüft durch: Claude-Code-Sitzung im Auftrag des Eigentümers. Kein Zielsystem berührt, keine Installation.
- Gilt für: `linux/catalog.json` (SHA-256 `0b8ceff0a4ee398aa7d06013019d5283cd5567d04fed7168a1ad2ee8b06f47d3`) und `linux/trusted.py`.

## Quellen

| Quelle | Erreichbar | Ergebnis |
| --- | --- | --- |
| `https://docs.docker.com/engine/install/ubuntu/` | **nein** (Proxy dieser Sitzung: `CONNECT tunnel failed, response 403`; Fetch-Werkzeug: Host nicht erlaubt) | nicht direkt geprüft, siehe nächste Zeile |
| Quelle der Doku-Seite: GitHub `docker/docs`, Commit `553482ce632f00c6e7faabab863422b4916e7c18` (= `main` beim Abruf), Datei `content/manuals/engine/install/ubuntu.md` (SHA-256 `963238b4c95bafba16513ebe60aa07753f0030bec0dbd25a7b9f8cc010941153`) und `hugo.yaml` | ja | Ubuntu Noble 24.04 unterstützt; Konfliktpakete `docker.io`, `docker-compose`, `docker-compose-v2`, `docker-doc`, `docker-buildx`, `podman-docker` sowie `containerd`, `runc`; Repo-Einrichtung mit `/etc/apt/keyrings/docker.asc`, `/etc/apt/sources.list.d/docker.sources` (deb822: `Types: deb`, `URIs: https://download.docker.com/linux/ubuntu`, `Suites: noble`, `Components: stable`, `Architectures: amd64`, `Signed-By: /etc/apt/keyrings/docker.asc`); Paketliste `docker-ce docker-ce-cli containerd.io docker-buildx-plugin docker-compose-plugin`; `hugo.yaml`: `docker_ce_version: "29.9.3"`, `download-url-base: https://download.docker.com/linux/ubuntu`. Die Seite nennt **keinen** Schlüssel-Fingerprint. |
| `https://download.docker.com/linux/ubuntu/gpg` | ja (HTTP 200, keine Weiterleitung) | SHA-256 `1500c1f56fa9e26b9b8f42452a553675796ade0807cdce11975eb98170b3a570`; `gpg --show-keys`: genau ein Primärschlüssel `9DC858229FC7DD38854AE2D88D81803C0EBFCD88`, UID `Docker Release (CE deb) <docker@docker.com>`, Unterschlüssel `D3306A018370199E527AE7997EA0A9C3F273FCD8` |
| `https://download.docker.com/linux/ubuntu/dists/noble/InRelease` | ja | SHA-256 `360a27a8fa980b1a74a732bfeeb230d471a6010f16d4a9948a0fb466924adbc9`, `Date: Fri, 13 Nov 2026 10:45:16 +0000`; `gpg --verify` mit obigem Schlüssel: **Good signature**, Primärschlüssel `9DC8 5822 9FC7 DD38 854A E2D8 8D81 803C 0EBF CD88` |
| `…/dists/noble/stable/binary-amd64/Packages` | ja | SHA-256 `c77070d435854dd768d2c49234542749678efa63ee3351b03710fc8f4455d8bc`, stimmt mit dem SHA256-Eintrag der signierten `InRelease` überein |

## Ergebnis: Pins (höchste Version je Paket in noble/stable/amd64, per `dpkg --compare-versions` sortiert)

| Paket | Pin | Datei im Pool (SHA-256 laut signiertem Index) |
| --- | --- | --- |
| `docker-ce` | `5:29.9.3-1~ubuntu.24.04~noble` | `docker-ce_29.9.3-1~ubuntu.24.04~noble_amd64.deb` `c546181f…09a4` |
| `docker-ce-cli` | `5:29.9.3-1~ubuntu.24.04~noble` | `docker-ce-cli_29.9.3-1~ubuntu.24.04~noble_amd64.deb` `24f78a89…46d4` |
| `containerd.io` | `2.4.2-4~ubuntu.24.04~noble` | `containerd.io_2.4.2-4~ubuntu.24.04~noble_amd64.deb` `15cc3d6c…1b75` |
| `docker-buildx-plugin` | `0.39.0-1~ubuntu.24.04~noble` | `docker-buildx-plugin_0.39.0-1~ubuntu.24.04~noble_amd64.deb` `165c2fe2…8dc6` |
| `docker-compose-plugin` | `5.7.1-1~ubuntu.24.04~noble` | `docker-compose-plugin_5.7.1-1~ubuntu.24.04~noble_amd64.deb` `c2f65499…50ac` |

`docker-ce` 29.9.3 stimmt mit `docker_ce_version` der Doku-Quelle überein. Für die übrigen Pakete nennt die Doku keine Version; gewählt ist jeweils die höchste im signierten Index.

## Fingerprint

`9DC858229FC7DD38854AE2D88D81803C0EBFCD88` (in `linux/trusted.py`) ist belegt durch: (1) Schlüssel über HTTPS mit TLS-Prüfung direkt von `download.docker.com`, (2) gültige Signatur der aktuellen `InRelease` mit genau diesem Primärschlüssel, (3) Übereinstimmung mit dem im akzeptierten Vertrag (PR #17) genannten Wert. Eine unabhängige zweite Veröffentlichung des Fingerprints (z. B. auf docs.docker.com) war in dieser Sitzung **nicht erreichbar**. Empfehlung an den Eigentümer: vor dem ersten Apply einmal im Browser auf docs.docker.com bzw. in der Docker-Doku gegenprüfen.

## Weitere Belege

- `unattended-upgrades` noble (`2.9.1+nmu4ubuntu1`, Archiv-SHA-256 `13c576c7…113b`): Standard-`20auto-upgrades` ist byte-gleich mit `trusted.AUTO_UPGRADES_CONTENT`; Standard-`50unattended-upgrades` erlaubt nur `${distro_codename}`, `-security`, ESM-Apps-/Infra-Security, `Automatic-Reboot` ist auskommentiert. Dateien als Fixture in `tests/fixtures/linux-runner/`.
- Ubuntu-Archivpakete (`ca-certificates`, `curl`, `git`, `gnupg`, `unattended-upgrades`) sind laut Entscheidung 4 nicht gepinnt; der Bericht nennt ihre installierte Version.
- Docker-Pakete werden von `unattended-upgrades` nicht aktualisiert (Ursprung `Docker` ist nicht in `Allowed-Origins`); neue Docker-Versionen kommen nur über eine bewusste Pin-Änderung mit neuem Prüfprotokoll.

## Was in dieser Sitzung zusätzlich ausgeführt wurde (kein Zielsystem)

Der Entwicklungscontainer der Sitzung ist selbst Ubuntu 24.04.5 amd64 (mit vorinstalliertem Docker aus einer alten `docker.list`). Dort liefen nur nicht ändernde Prüfungen:

- `runner.py` Dry-Run mit dem eingecheckten Katalog: Vorprüfung ok, `base-tools` bereits erfüllt, `docker-apt-repository` **Fehler** (vorhandene `docker.list`), `docker-engine` würde 29.9.2 → 29.9.3 ändern, `unattended-upgrades` würde installieren; Exit 1; nichts geändert.
- `runner.py --apply` als root ohne Terminal (stdin `/dev/null`): abgelehnt, Exit 2; `/etc/apt/keyrings` und `/etc/apt/sources.list.d` vorher/nachher identisch.
- Echter Schlüsseldownload über `host.fetch_https`: 3 817 Byte, Fingerprint korrekt; `http://`, fremder Host und eine echte 302-Weiterleitung von `download.docker.com` wurden abgelehnt.

Nicht ausgeführt: keine reale Installation, kein Lauf auf `huu-server-01`, keine Prüfung eines echten `apt-get install`. Das ist die Abnahme durch den Eigentümer.

## Wiederholung bei Pin-Änderung

1. `InRelease` und `Packages` für `noble/stable/binary-amd64` laden, Signatur mit dem festen Fingerprint prüfen, Index-Hash vergleichen.
2. Gewünschte Versionen auswählen, in `linux/catalog.json` eintragen, `catalogRevision` aller Pläne neu setzen.
3. Dieses Protokoll mit Datum, Quellen und Hashes ergänzen; `python3 -m unittest discover -s tests/linux`.
