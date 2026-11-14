# Aktueller Stand – configureMe

**Stand:** 2026-11-14 · **Basis-Commit:** `c8009d3` auf `main`

- **Läuft:** Öffentlicher Windows-Konfigurator mit synthetischen Fixtures, servervalidierter Setup-Plan v1 (JSON-Export), geschütztes Portal mit GitHub-OAuth, eigenständiges Windows-Server-2022-Setup (WinForms, Worker, Berichte) inkl. gehärtetem Installer-Handoff (PR #13). Web- und Windows-CI vorhanden.
- **Offen:** Unabhängige Release-Vertrauenskette (CM-001), Clean-Checkout-Docker-Build (CM-002/CM-041), echte Windows-Abnahme (CM-005). **Linux ist nicht automatisiert** ([docs/linux.md](docs/linux.md)).
- **Nächster Schritt:** CM-042 (Linux-Runner für `huu-server-01`, Centrality ADR-004) bzw. die priorisierte Liste in [TASKS.md](TASKS.md#priorisierte-nächste-arbeit).

Technischer Leitfaden: [REPO.md](REPO.md). Prüfprotokolle: [docs/audits/](docs/audits/).

## Protokoll (neueste zuerst)

- 2026-11-14: Repo-Doku-Standard ergänzt (`CLAUDE.md`, diese Datei); CM-042 für den Linux-Weg im Backlog angelegt. Nur Doku.
- 2026-11-14: Windows-v1-Handoff, Berichte und Review-Grenzen gehärtet (PR #13, `c8009d3`).
- Ältere Schritte: Statusspalte und Abschlussnachweise in [TASKS.md](TASKS.md).
