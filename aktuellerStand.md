# Aktueller Stand – configureMe

**Stand:** 2026-11-14 · **Basis-Commit:** `c458d11` auf `main`

- **Läuft:** Öffentlicher Windows-Konfigurator mit synthetischen Fixtures, servervalidierter Setup-Plan v1 (JSON-Export), geschütztes Portal mit GitHub-OAuth, eigenständiges Windows-Server-2022-Setup (WinForms, Worker, Berichte) inkl. gehärtetem Installer-Handoff (PR #13). Web- und Windows-CI vorhanden.
- **Offen:** Unabhängige Release-Vertrauenskette (CM-001), Clean-Checkout-Docker-Build (CM-002/CM-041), echte Windows-Abnahme (CM-005). **Linux ist nicht automatisiert** ([docs/linux.md](docs/linux.md)).
- **In Arbeit:** CM-042 Linux-Runner für `huu-server-01` – [Vertrag Accepted](docs/linux-plan-contract.md) (2026-11-14); noch kein Code.
- **Nächster Schritt:** Schema, Policy, Katalog und Planvalidierung mit Tests (CM-042 Teil 2).

**Planungsnachtrag CE-013, 2026-11-14:** CM-043/044 [lokaler Portal-Handoff](docs/huu-local-portal-handoff.md) als separate Aufgaben dokumentiert. Portal auf Windows-Host stellt später geprüfte Linux-Bundles für die Ubuntu-VM bereit; Runner wird ausschließlich auf der VM ausgeführt. **Nicht implementiert, kein LAN-Zugriff, Download oder Apply geprüft.** CM-042-Code fehlt weiterhin auf `main`.

Technischer Leitfaden: [REPO.md](REPO.md). Prüfprotokolle: [docs/audits/](docs/audits/).

## Protokoll (neueste zuerst)

- 2026-11-15: CM-043 implementiert (Branch `feat/cm-043-linux-bundle`): lokaler Modus `npm run local:linux` mit Seite `/linux`, reproduzierbares tar.gz mit Manifest, Runner prüft Manifest, acht Zusatzpakete als Katalogschritte (neuer Katalog-Hash `22e37f4a…`). Getestet mit Mocktests und Container-Dry-Run; nicht auf Windows oder `huu-server-01` geprüft.
- 2026-11-15: CM-043 [Linux-Bundle-Vertrag](docs/cm-043-linux-bundle-contract.md) als Proposed; Eigentümer hat Transport `scp` (kein Tunnel, kein CM-044 nötig) und Zusatzpakete `jq`/`python3-venv` entschieden. Planformat v1 bleibt unverändert. Nur Doku.
- 2026-11-14: CM-042 Eigentümerentscheidungen 1–4 als Accepted in den Linux-Plan-Vertrag übernommen; offene Fragen geschlossen. Nur Doku.
- 2026-11-14: CM-042 Linux-Plan v1 als Proposed dokumentiert; CM-042 angepasst (Firewall raus, fester Commit per `git clone`). Nur Doku.
- 2026-11-14: Repo-Doku-Standard ergänzt (`CLAUDE.md`, diese Datei); CM-042 für den Linux-Weg im Backlog angelegt. Nur Doku.
- 2026-11-14: Windows-v1-Handoff, Berichte und Review-Grenzen gehärtet (PR #13, `c8009d3`).
- Ältere Schritte: Statusspalte und Abschlussnachweise in [TASKS.md](TASKS.md).

## Linux-Integrationsreview (aktueller Auftrag)

Main e2646fa enthält nur die Verträge; gestapelte PRs #19–22 landeten auf Feature-Basen, nicht auf main. Implementierung aus 2780ec8 gezielt wiederverwendet. Lokal 93 Python-Mocktests bestanden, Eingaben zusätzlich begrenzt. Keine reale Installation/VM-Ausführung. CM-042 bleibt bis vollständigen Nachweisen offen; offizielle Metadaten hier erneut HTTP 403, vorhandenes Pin-Protokoll erhalten.
