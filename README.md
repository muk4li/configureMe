# configureMe

configureMe ist ein selbst hostbares Portal, mit dem sich nachvollziehbare Setup-Pläne für neue Computer zusammenstellen lassen. Die Anwendung installiert nicht aus dem Browser und betreibt keinen Geräte-Agenten: Ein Benutzer lädt ein lokales Paket herunter, prüft es und bestätigt die Installation auf dem Zielgerät.

> **v1 ist ein MVP/Preview.** Automatisierte Pläne gibt es nur für Windows x64 mit WinGet. Der Bootstrap wurde noch nicht auf einem frischen Windows-Zielsystem end-to-end validiert. Download-Pakete sind nicht signiert; SHA-256 erkennt nur zufällige Beschädigung und beweist nicht die Herkunft.

## Funktionsumfang

- Responsives, dunkles Portal mit Produktstartseite, Dashboard, Softwarekatalog, Profilübersicht und Setup-Assistent
- GitHub OAuth mit serverseitiger Benutzer-Allowlist, initialem Administrator, signierten HttpOnly-Sessions und CSRF-State im OAuth-Flow
- Lokale JSON-Profile, Zod-Validierung und JSON-Schemas
- Katalog mit stabilen Paket-IDs; feste WinGet-ID-Zuordnung statt frei konfigurierbarer Befehle
- Windows-x64-Planer und ZIP-Bundle mit `install.ps1`, Plan, Prüfsumme und README
- Lokaler Dry-Run, Bestätigungsabfrage, Erkennung vorhandener Software und kontrolliertes Fehlerreporting
- Dockerfile, Compose, Healthcheck und deutschsprachige Deployment-/Sicherheitsdokumentation

GitHub-Konfigurationsprovider, Profil-Editor, Linux/macOS-Adapter, authenticode-/kryptografisch signierte Bootstrap-Artefakte, Paketversions-Pinning, dauerhafte Datenbank und Mehrbenutzerverwaltung sind nicht enthalten. Siehe [Sicherheitsmodell](docs/security.md) und [Deployment](docs/deployment.md).

## Voraussetzungen

- Node.js 22+ und npm für lokale Entwicklung
- Ein GitHub OAuth App Client für die Anmeldung
- Ein öffentlich erreichbarer configureMe-Host mit HTTPS, wenn der Dienst extern bereitgestellt wird
- Für den Windows-Bootstrap: Windows PowerShell 5.1, Windows x64 und WinGet

## Lokal starten

```powershell
Copy-Item .env.example .env.local
```

In `.env.local` mindestens ein starkes `AUTH_SECRET`, `GITHUB_CLIENT_ID`, `GITHUB_CLIENT_SECRET` und `INITIAL_ADMIN_GITHUB_USER` setzen. Weitere erlaubte GitHub-Logins kommen in `ALLOWED_GITHUB_USERS` (kommagetrennte Benutzernamen). Als OAuth-Callback muss `http://localhost:3000/api/auth/github/callback` eingetragen sein.

```powershell
npm ci
npm run dev
```

Anschließend `http://localhost:3000` öffnen. Ohne OAuth-Konfiguration bleiben alle Profile und geschützten Routen gesperrt.

## Tests und Qualität

```powershell
npm run typecheck
npm run lint
npm test
npm run build
```

Die Tests validieren Profil- und Planregeln, Paketabhängigkeiten und Session-Signaturen. Sie führen keine Installer aus. Der Windows-Bootstrap muss vor einem produktiven Einsatz zusätzlich auf einem frischen, nicht kritischen Windows-Testsystem geprüft werden.

## Docker

`.env.example` nach `.env` kopieren, Pflichtwerte setzen und starten:

```powershell
docker compose up --build -d
docker compose ps
```

Compose bindet den Dienst standardmäßig nur an `127.0.0.1:3000` (mit `HOST_PORT` änderbar). Hinter einem Reverse Proxy HTTPS terminieren und `APP_URL` auf die öffentliche HTTPS-URL setzen. Weitere Informationen: [Deployment](docs/deployment.md).

## Konfiguration und Bootstrap

Profile liegen in `profiles/*.json`; der Schema-Vertrag steht in `schemas/profile.schema.json`. Der Installationsplan ist zusätzlich in `schemas/install-plan.schema.json` beschrieben. Paketdefinitionen und Installationsstrategien befinden sich in `src/lib/catalog.ts`.

Der Bootstrap enthält keine benutzergesteuerten URLs oder Shell-Befehle. Er prüft Betriebssystem, Architektur, Katalog-IDs und SHA-256, bietet `-DryRun` und verlangt vor der Installation die Eingabe `YES`. Die Prüfsumme ist keine Signatur. Vor dem Ausführen müssen Quelle und Bundle manuell geprüft werden.

## Dokumentation

- [Architektur](docs/architecture.md)
- [Sicherheitsmodell und Bedrohungen](docs/security.md)
- [Self-Hosting und Deployment](docs/deployment.md)
- [Windows-Bootstrap](docs/windows.md)
- [Linux-Status](docs/linux.md)
- [macOS-Status](docs/macos.md)
