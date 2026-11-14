# configureMe

Engineering-Einstieg: [REPO.md](REPO.md) · [Arbeitsregeln](AGENTS.md) · [Roadmap](ROADMAP.md) · [Aufgaben](TASKS.md) · [Initialaudit](docs/audits/initial-audit.md).

configureMe ist ein öffentlicher Windows-Konfigurator ohne Loginpflicht für Planung und Vorschau, mit dem sich nachvollziehbare Setup-Pläne für neue Computer zusammenstellen lassen. Die Anwendung installiert nicht aus dem Browser und betreibt keinen Geräte-Agenten: Ein Benutzer lädt ein lokales Paket herunter, prüft es und bestätigt die Installation auf dem Zielgerät.

> **v1 ist ein MVP/Preview.** Bestehende Windows-Profile verwenden WinGet. Das Profil `windows-server-2022-developer` ist zusätzlich als natives Windows Forms Setup für Windows Server 2022 x64 vorgesehen. Das selbstständige Setup benötigt beim Start weder eine .NET-Runtime noch Git, WinGet, Node.js oder den configureMe-Webserver; Windows PowerShell 5.1 bleibt der lokale Worker für die vorhandene Installationsengine. CI erzeugt ein kurzlebiges, unsigniertes Entwicklungsartefakt; es wird kein öffentliches Release erstellt. Das Artefakt ist nicht für öffentliches Vertrauens-Onboarding freigegeben. Ein echter interaktiver GUI-/E2E-Lauf auf einem frischen Windows Server 2022 ist noch erforderlich.

## Funktionsumfang

- Öffentliche Windows-11-/Server-2022-Planung mit Mehrprofil-Auswahl, sichtbaren Abhängigkeiten/Konflikten und sessionStorage
- Klar gekennzeichnete synthetische Fixtures; servervalidierter Preview-Export sowie separater Setup-Plan-v1-JSON-Export für die vorhandene EXE. Öffentliche ZIP-/EXE-Downloads bleiben gesperrt

- Responsives, dunkles Portal mit Produktstartseite, Dashboard, Softwarekatalog, Profilübersicht und Setup-Assistent
- GitHub OAuth mit serverseitiger Benutzer-Allowlist, initialem Administrator, signierten HttpOnly-Sessions und CSRF-State im OAuth-Flow
- Lokale JSON-Profile, Zod-Validierung und JSON-Schemas
- Katalog mit stabilen Paket-IDs; feste WinGet-ID-Zuordnung statt frei konfigurierbarer Befehle
- Windows-x64-Planer und ZIP-Bundle mit `install.ps1`, Plan, Prüfsumme und README
- Standalone Windows Server 2022 Quick Setup mit PowerShell-5.1-Modulen, offiziellen signaturgeprüften Installerpfaden, manuellen Fallbacks und JSON-/Textreport
- Native deutsche Windows Forms GUI mit Katalogauswahl, Dry-Run, strukturierter PowerShell-Worker-Kommunikation, parallelen Downloads (maximal zwei) und serieller Installationswarteschlange
- Lokaler Dry-Run, Bestätigungsabfrage, Erkennung vorhandener Software und kontrolliertes Fehlerreporting
- Dockerfile, Compose, Healthcheck und deutschsprachige Deployment-/Sicherheitsdokumentation

GitHub-Konfigurationsprovider, Profil-Editor, Linux/macOS-Adapter im Portal, authenticode-/kryptografisch signierte Bootstrap-Artefakte, Paketversions-Pinning, dauerhafte Datenbank und Mehrbenutzerverwaltung sind nicht enthalten. Siehe [Sicherheitsmodell](docs/security.md) und [Deployment](docs/deployment.md).

## Voraussetzungen

- Node.js 22+ und npm für lokale Entwicklung
- Optional ein GitHub OAuth App Client ausschließlich für das bestehende private Portal
- Ein öffentlich erreichbarer configureMe-Host mit HTTPS, wenn der Dienst extern bereitgestellt wird
- Für bestehende Windows-Profile: Windows PowerShell 5.1, Windows x64 und WinGet
- Für das Windows Server 2022 Setup: Windows Server 2022 x64 Desktop Experience, Windows PowerShell 5.1 und Internetzugang für offizielle Vendorfeeds/-installer (kein WinGet und keine vorinstallierte .NET-Runtime)

## Ohne Login und ohne Installationen ansehen

Empfohlen: sauberer separater Arbeitsordner, vorhandenes Node.js 22+/npm.

```powershell
npm ci
npm run preview
```

`http://127.0.0.1:3000` öffnen. Kein OAuth nötig. Der Previewprozess verwendet keine .env-Dateien oder produktiven App-Credentials und startet keine Engine. Ausgewählte Software wird weder heruntergeladen noch installiert. [Windows-Anleitung mit temporärem Checkout, Schreibzugriffen und Tests](docs/public-preview.md).

Für das optionale private Portal separat sichere Laufzeitkonfiguration für AUTH_SECRET, GITHUB_CLIENT_ID, GITHUB_CLIENT_SECRET und die Login-Allowlist bereitstellen und `npm run dev` verwenden. Die öffentliche Planung funktioniert ohne diese Werte; private Routen bleiben geschützt. Keine produktiven Secrets in den Preview-Checkout kopieren.

## Setup-Plan v1: Web → vorhandene EXE → Dry-Run

In der öffentlichen UI eine konfliktfreie Auswahl treffen und **Export setup plan v1** wählen. Die Datei `configureme-setup-plan.v1.json` lokal speichern. In der vorhandenen EXE auf vollständig aktualisiertem Windows Server 2022 x64 Desktop Experience **Setup-Plan importieren** und danach **Dry-Run** wählen. Import startet keine Installation; die EXE validiert Format, Katalog, Ziel, IDs, Modi und Abhängigkeiten unabhängig. Importierte Auswahl ist vorerst nur für Review/Dry-Run freigegeben. **Manuelle Auswahl** stellt die bisherige lokale Bedienung wieder her. Details und Grenzen: [Planvertrag](docs/setup-plan-contract.md), [Prüfprotokoll](docs/audits/setup-plan-v1.md).

Windows 11 ist im Planformat modelliert, der native Import/Dry-Run dafür noch nicht implementiert. Legacy-Plan und Preview-JSON sind separate, nicht automatisch migrierte Formate. Der JSON-Plan enthält keine Secrets, freien Befehle oder Installationsrechte. Es bleibt eine universelle self-contained EXE; keine Neukompilierung pro Plan, kein Agent und keine private Infrastrukturpflicht. CI-Artefakte sind weiterhin unsigniert und keine öffentlich freigegebenen Releases.

## Tests und Qualität

```powershell
npx next typegen
npm run typecheck
npm run lint
npm test
npm run build
npx playwright install chromium
npm run test:browser
```

Die Tests validieren Profil- und Planregeln, Paketabhängigkeiten und Session-Signaturen. Sie führen keine Installer aus. Der Windows-Bootstrap muss vor einem produktiven Einsatz zusätzlich auf einem frischen, nicht kritischen Windows-Testsystem geprüft werden.

## Docker

Der bestehende Dockerpfad hat bekannte Clean-Checkout-Lücken (CM-002; fehlende public-/Env-Voraussetzungen) und wurde in diesem Feature nicht freigegeben. Nach separater Korrektur sichere Laufzeitkonfiguration bereitstellen und starten:

```powershell
docker compose up --build -d
docker compose ps
```

Compose bindet den Dienst standardmäßig nur an `127.0.0.1:3000` (mit `HOST_PORT` änderbar). Hinter einem Reverse Proxy HTTPS terminieren und `APP_URL` auf die öffentliche HTTPS-URL setzen. Weitere Informationen: [Deployment](docs/deployment.md).

## Konfiguration und Bootstrap

Profile liegen in `profiles/*.json`; der Schema-Vertrag steht in `schemas/profile.schema.json`. Der Installationsplan ist zusätzlich in `schemas/install-plan.schema.json` beschrieben. Die gemeinsame Paketdefinition für Portal, Windows-GUI und PowerShell-Worker liegt in `bootstrap\windows-server-2022-developer\config\catalog.json`; `src/lib/catalog.ts` importiert diese Datei.

Der Bootstrap enthält keine benutzergesteuerten URLs oder Shell-Befehle. Er prüft Betriebssystem, Architektur, Katalog-IDs und SHA-256, bietet `-DryRun` und verlangt vor der Installation die Eingabe `YES`. Die Prüfsumme ist keine Signatur. Vor dem Ausführen müssen Quelle und Bundle manuell geprüft werden.

Das Standalone-Profil und das reproduzierbare ZIP-Packaging sind in [docs/quickstart-windows-server-2022.md](docs/quickstart-windows-server-2022.md) beschrieben. Die GUI, der self-contained `win-x64`-Build und dessen Sicherheitsgrenzen stehen in [windows/ConfigureMe.Setup/README.md](windows/ConfigureMe.Setup/README.md) und [SECURITY.md](windows/ConfigureMe.Setup/SECURITY.md).

## Dokumentation

- [Architektur](docs/architecture.md)
- [Sicherheitsmodell und Bedrohungen](docs/security.md)
- [Self-Hosting und Deployment](docs/deployment.md)
- [Windows-Bootstrap](docs/windows.md)
- [Linux](docs/linux.md): lokaler Runner für Ubuntu Server 24.04 (CM-042, [Vertrag](docs/linux-plan-contract.md)); implementiert und mit Mocks getestet, noch nicht auf `huu-server-01` betrieben; Anleitung „Runner auf huu-server-01 ausführen“ dort
- [macOS-Status](docs/macos.md)
