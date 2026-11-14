# Linux-Runner-Fixtures

- `50unattended-upgrades.noble` und `20auto-upgrades.noble`: unveränderte Standarddateien aus `/usr/share/unattended-upgrades/` des Ubuntu-Pakets `unattended-upgrades_2.9.1+nmu4ubuntu1_all.deb` (Ubuntu-Archiv, noble/main, Paket-SHA-256 `13c576c7d8184f509d5ddc4d75bec6e62ef3f745319cce60f8131f401091113b`), geladen am 2026-11-14. Öffentliche Paketdateien, keine Betriebsdaten. Das Paket legt diese Inhalte per `ucf` nach `/etc/apt/apt.conf.d/` ab.
- Alle übrigen Zustände (dpkg, gpg, getent, Dateien) werden in `tests/linux/fake_host.py` **synthetisch** erzeugt; kein Test ruft echte Systembefehle auf.
