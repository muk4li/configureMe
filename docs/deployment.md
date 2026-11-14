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

## Linux-Entwicklungsdownload

`/linux` und `POST /api/public/linux-plan` benötigen keine Anmeldung. Der getrennte
ZIP-Endpunkt ist standardmäßig deaktiviert und verlangt für lokale Tests eine
explizite Loopback-APP_URL, `CONFIGUREME_LOCAL_LINUX_DOWNLOADS=1`, private Anmeldung,
aktuelle Allowlist und einen unveränderten Git-Checkout. Git-loses standalone ist
kein unterstützter Entwicklungsbundle-Produzent. Keine öffentliche/HTTP-LAN-
Installerdistribution freigegeben. Keine neuen Secrets oder Auth-Callbacks nötig;
existierende Auth-Konfiguration und Sicherheitsprüfungen bleiben maßgeblich.

## Kontrollierter LAN-Planungsmodus (CM-044, noch keine Betriebsfreigabe)

`npm run dev` und `npm run start` binden standardmäßig ausdrücklich an Loopback.
Für den zukünftigen VM-Zugriff gibt es `npm run preview:lan`. Es verlangt eine
**explizite, tatsächlich zugewiesene private IPv4-Adresse**, einen unprivilegierten
Port und eine Liste einzelner privater Client-IPv4-Adressen (keine Netze/Wildcards).
Keine echten Adressen sind hier bekannt oder vorgegeben. In einem dedizierten
Checkout ohne `.env`/`.env.local` validiert dieser Befehl zunächst nur:

```powershell
npm run preview:lan -- --bind <approved-host-private-ipv4> --clients <approved-vm-private-ipv4> --port <approved-port>
```

Platzhalter erst nach myHome-Lab-Netzklärung ersetzen. **Ohne `--start` kein
Listener.** Erst nach ausdrücklicher Netzwerk-/Betreiberfreigabe zusätzlich
`--start` verwenden. Das ist ein HTTP-Entwicklungsserver für `/linux` und den
öffentlichen JSON-Planexport, kein Produktionsbetrieb und kein sicherer
Installertransport. Auth-/private-/Bundle-/Windows-APIs sind am HTTP-Handler
gesperrt. Credentials werden vor dem Next-Import entfernt, lokale Env-Dateien
verweigert. Exakte Socket-Peer-, Host- und Originprüfung; Forwardingheader werden
abgewiesen, nicht als Clientidentität benutzt. Kein WebSocket-Upgrade/HMR.

Der Launcher ändert keine Firewall und kennt keine Hyper-V-/SSH-/Docker-Schnittstelle.
Windows-Firewall auf genau VM-IP/Adapter/Port begrenzt ist Aufgabe von myHome-Lab
nach Eigentümerfreigabe. Keine Routerfreigabe. TLS-Vertrauen, Netzadapter und reale
Positiv-/Negativtests bleiben offen. Über dieses HTTP-LAN werden **keine**
ausführbaren Bundles oder Login-Cookies übertragen. Dafür weiterhin den separat
geprüften Git-/Offline-Handoff nutzen; zukünftiger TLS-Download braucht eigenes
Review und CM-001-Provenienzentscheidung. Ein laufender Prozess ist kein LAN-
Abnahmenachweis. Stoppen mit Strg+C; kein Service/Autostart wird eingerichtet.
