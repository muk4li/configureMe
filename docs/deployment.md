# Self-Hosting und Deployment

## Lokal

Voraussetzungen: Node.js 22 oder neuer und npm.

```powershell
Copy-Item .env.example .env.local
# AUTH_SECRET, GitHub OAuth-Daten und Benutzernamen in .env.local eintragen
npm ci
npm run dev
```

GitHub OAuth muss als Callback `http://localhost:3000/api/auth/github/callback` eingetragen haben. Ohne OAuth-Konfiguration bleiben geschützte Bereiche gesperrt. Zum Erzeugen eines Secrets kann `openssl rand -base64 48` verwendet werden.

## Docker Compose

```powershell
Copy-Item .env.example .env
# Pflichtwerte in .env setzen, insbesondere AUTH_SECRET und GitHub OAuth
docker compose up --build -d
docker compose ps
```

Der Dienst ist absichtlich nur auf `127.0.0.1:3000` des Hosts gebunden. Falls der Port belegt ist, `HOST_PORT` in `.env` ändern; der Dienst bleibt an Loopback gebunden. `profiles/` wird read-only eingebunden. Für Reverse-Proxy-Zugriff HTTPS am Proxy terminieren und `APP_URL` auf die öffentliche HTTPS-Adresse setzen; OAuth verweigert in Produktion fehlende oder nicht-HTTPS-Werte. Ein Cloudflare Tunnel ist eine mögliche private Veröffentlichung, aber nicht Bestandteil der Einrichtung. Keine Router-Portfreigabe wird geändert.

Der Container läuft als unprivilegierter Benutzer, setzt `no-new-privileges`, nutzt ein schreibgeschütztes Root-Dateisystem und stellt `/api/health` für den Healthcheck bereit. Es gibt in v1 keine Datenbank oder persistente Sitzungstabelle.

## Öffentliches Hosting

Vor Internetbetrieb sind ein öffentlich vertrauenswürdiges HTTPS-Zertifikat, eine sichere Reverse-Proxy-Konfiguration, geschützte Umgebungsvariablen, regelmäßige Updates und ein unabhängig vertrauenswürdiger Signatur-/Provenienzprozess für Bootstrap-Downloads erforderlich. Aktuell sind die Downloads unsigned; deshalb ist ein kompromittiertes Portal nicht kryptografisch von einem manipulierten Paket unterscheidbar. Nicht als vertrauenswürdig signiert darstellen.

## Clean-Checkout-Voraussetzungen (Review CM-041)

`public/.gitkeep` stellt die vom bestehenden Dockerfile kopierte Quelle bereit. `.env.example` enthält ausschließlich leere Authwerte und lokale Entwicklungsnamen; nur diese Beispieldatei ist von `.gitignore` ausgenommen, reale Envdateien bleiben ignoriert. Leere Werte aktivieren keinen Administrator und erlauben keinen privaten Login. Produktion benötigt weiterhin sichere Laufzeitwerte und eine bewusst gewählte HTTPS-Origin; das Entwicklungsbeispiel ist keine Produktionsfreigabe.

In der Cloud scheitert bereits `docker info` an der Docker-Socketberechtigung. Es wurden keine Hostgruppen, Rechte, Dienste oder Container geändert. Clean-Checkout-Containerbuild, read-only Start, Health und öffentliche/private API-Fälle sind damit **nicht ausgeführt**. CM-002 bleibt offen. Nach separater Bereitstellung eines isolierten Dockerhosts: aus sauberem Reviewcheckout `docker build --tag configureme-review .`, dann ausschließlich einen ausdrücklich autorisierten Loopback-Test mit synthetischen Envwerten durchführen; nicht als produktives Deployment interpretieren. Web-CI ist kein Dockerbeleg.
