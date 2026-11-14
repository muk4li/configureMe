# configureMe Portal – Dienst- und Integrationsvertrag

## 1. Identität und Stand

Owner: muk4li/configureMe; Stand 2026-11-14, Reviewref `feature/local-lan-handoff`,
auf `cbbfdbb` (CM-043) und `4bf423d` (CM-042), Basis main `e2646fa`.
Nach [Centrality CE-103](https://github.com/muk4li/centrality/blob/1526c77408815337831408417d679e461b3fa17e/docs/integrations/SERVICE-CONTRACT-PROPOSAL.md).
Implementiert: Next-Portal, öffentliche deklarative Windows-/Linux-Planung, optionale
private Auth; lokal unabhängige Windows-/Linux-Runner. Getestet: Unit-/Mocktests,
Build und Browser; Belege in [Stand](aktuellerStand.md). Geplant/offen: tatsächlicher
Windows-Host/Ubuntu-VM-LAN-Handoff und signierte Releaseprovenienz. Betrieb nicht
nachgewiesen; keine Freigabe einer externen Hub-API.

## 2. Fähigkeiten und Schnittstellen

- HTTP GET `/`, `/catalog`, `/linux`: öffentliche Planung; POST
  `/api/public/plan`, `/api/public/linux-plan`: begrenzte deklarative Vorschau,
  Fehler 400/403/413/429/503, keine Installerberechtigung. Code [API](src/app/api/public).
- Private GitHub-OAuth-Routen `/api/auth/github`, `/api/auth/github/callback`,
  `/api/auth/logout`; private Profile/Bootstrap mit Session und Allowlist. Existenz
  ist keine öffentliche Installerdistributionsfreigabe. [Auth](src/lib/auth.ts).
- POST `/api/linux/bundle`: standardmäßig 404, separat aktivierter authentifizierter
  Loopback-Entwicklungsdownload, 401/403/422/429/503; reproduzierbares unsigned ZIP,
  kein Release. [Bundle](src/lib/linux-bundle.ts), [Prüfung](docs/linux.md).
- Dateien: [Windows-Setup-Plan v1](docs/setup-plan-contract.md) und eigenständiger
  [Linux-Plan v1](docs/linux-plan-contract.md); CLI `python3 linux/runner.py --plan …`
  standardmäßig unprivilegierter Dry-Run. Portal führt diese Runner nicht aus.

## 3. Benötigte Dienste

Öffentliche Planung nutzt app-lokale Profile/Kataloge; kein myConfigs-data-, Hub-
oder VM-Laufzeitupstream. GitHub OAuth ist nur für optionale private Anmeldung nötig;
bei fehlender Konfiguration bleibt diese gesperrt. Git ist für den lokalen Linux-
Entwicklungsbundle-Produzenten erforderlich; fehlt sauberer Checkout, kein Download.
Installer kontaktieren erst lokal ihre fest erlaubten offiziellen Paketquellen.

## 4. Exposition und Sicherheit

Normale npm-Startbefehle binden Loopback. Compose veröffentlicht Loopback; andere
Deploymentgrenzen stehen in [Deployment](docs/deployment.md). APP_URL, Sessions,
Allowlist, Host/Origin, Request-/Ratelimits bleiben wirksam, kein Proxyheader-Bypass.
Separater LAN-Devmodus verlangt explizite zugewiesene private IPv4, einzelne Clients
und `--start`; nur Planung über HTTP, keine Auth/privaten APIs/Installerdownloads.
Kein tatsächliches LAN-Listening hier getestet oder freigegeben. TLS/Firewall/IPs
sind offen bei myHome-Lab/Betreiber. Keine Remote Execution, SSH, Hyper-V oder Docker-
Socket. [Sicherheitsgrenzen](docs/security.md); kein Hash aus gleichem Kanal als Provenienz.

## 5. Laufzeit und Deployment

Node >=22/npm, Next 16; `npm ci`, `npm run build`, `npm start` oder vorhandenes
standalone-/Containerartefakt. Entwicklungsbundle benötigt zusätzlich Git/Quellen;
Verifier/Runner Python >=3.12, Ziel Ubuntu24.04/amd64. Konfigurationsnamen:
`APP_URL`, `AUTH_SECRET`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET`,
`ALLOWED_GITHUB_USERS`, `INITIAL_ADMIN_GITHUB_USER`,
`CONFIGUREME_LOCAL_LINUX_DOWNLOADS`; LAN erhält Bind/Clients/Port als CLI-Optionen.
GET `/api/health` dient dem vorhandenen Dienstcheck, ist kein VM-/Installer-
Readinessnachweis. LAN-Allowlist veröffentlicht Health nicht. Kein neuer Autostart,
Restartmanager oder Deployment eingerichtet; Runbook [Deployment](docs/deployment.md).

## 6. Persistenz, Backup und Restore

App-lokale Profile/Kataloge sind versionierte Dateien; keine gemeinsame Datenbank.
Sessions sind signierte Cookies, Authkonfiguration liegt außerhalb des Repos.
Pläne/ZIPs und Runnerberichte sind benutzerseitige Dateien, keine Portal-Agentdatenbank.
Git-Checkout und Betreiberkonfiguration separat sichern; Secrets nicht ins Bundle.
Kein produktiver Backup-/Restorelauf nachgewiesen, keine Migration eingeführt.

## 7. Kompatibilität und Evidenz

Versionierte JSON-Verträge im Repo sind autoritativ; HTTP ist keine freigegebene
stabile externe Integrations-API. Windows/Linux-Pläne nicht austauschbar. Prüfungen:
[Web-CI](.github/workflows/web.yml), [Linux-CI](.github/workflows/linux-runner.yml),
[Windows-CI](.github/workflows/windows-quicksetup.yml), [Audit](docs/audits/linux-runner.md).
CM-001 Releasevertrauen, CM-042/043 echte VM-Abnahme und CM-044 Netz-/TLS-/E2E-Gates
bleiben offen. Verantwortung für Host/Netz/Firewall bei myHome-Lab; Anwendung hier.
