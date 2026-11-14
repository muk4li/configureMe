# Aktueller Stand – configureMe

**Stand:** 2026-11-14 · **Basis-Commit:** `c458d11` auf `main`

- **Läuft:** Öffentlicher Windows-Konfigurator mit synthetischen Fixtures, servervalidierter Setup-Plan v1 (JSON-Export), geschütztes Portal mit GitHub-OAuth, eigenständiges Windows-Server-2022-Setup (WinForms, Worker, Berichte) inkl. gehärtetem Installer-Handoff (PR #13). Web- und Windows-CI vorhanden.
- **Offen:** Unabhängige Release-Vertrauenskette (CM-001), Clean-Checkout-Docker-Build (CM-002/CM-041), echte Windows-Abnahme (CM-005). **Linux ist nicht automatisiert** ([docs/linux.md](docs/linux.md)).
- **In Arbeit:** CM-042 Linux-Runner für `huu-server-01` – [Vertrag Accepted](docs/linux-plan-contract.md) (2026-11-14); Schema, Policy, Katalog mit geprüften Docker-Pins, Planvalidator, Runner mit Dry-Run und `--apply` vorhanden (gemockt getestet, [Prüfprotokoll](docs/audits/linux-runner.md)); **nicht** auf `huu-server-01` ausgeführt.
- **Nächster Schritt:** Doku und Anleitung „Runner auf huu-server-01 ausführen“ (CM-042 Teil 5), danach Lauf durch den Eigentümer.

Technischer Leitfaden: [REPO.md](REPO.md). Prüfprotokolle: [docs/audits/](docs/audits/).

## Protokoll (neueste zuerst)

- 2026-11-14: CM-042 Teil 4: `--apply` (Root, TTY, Hostname-Bestätigung, serielle Schritte mit Nachprüfung), Schlüsseldownload mit Fingerprint-Prüfung vor dem Schreiben, Docker-Pins 29.9.3 & Co. mit Prüfprotokoll.
- 2026-11-14: CM-042 Teil 3: `linux/runner.py` Dry-Run (ohne Root, ohne Änderung), Zustandserkennung, JSON-/Textbericht, austauschbare Systemfunktionen, Mock-Tests.
- 2026-11-14: CM-042 Teil 2: Linux-Plan-Schema, Policy, Katalog, Plan `huu-server-01`, strenger Python-Validator, synthetische Fixtures, Tests und CI-Workflow `linux-runner.yml`.
- 2026-11-14: CM-042 Eigentümerentscheidungen 1–4 als Accepted in den Linux-Plan-Vertrag übernommen; offene Fragen geschlossen. Nur Doku.
- 2026-11-14: CM-042 Linux-Plan v1 als Proposed dokumentiert; CM-042 angepasst (Firewall raus, fester Commit per `git clone`). Nur Doku.
- 2026-11-14: Repo-Doku-Standard ergänzt (`CLAUDE.md`, diese Datei); CM-042 für den Linux-Weg im Backlog angelegt. Nur Doku.
- 2026-11-14: Windows-v1-Handoff, Berichte und Review-Grenzen gehärtet (PR #13, `c8009d3`).
- Ältere Schritte: Statusspalte und Abschlussnachweise in [TASKS.md](TASKS.md).
