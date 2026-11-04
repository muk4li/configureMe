# Architektur

configureMe v1 ist eine einzelne Next.js-Anwendung mit App Router. Öffentliche Produktinformationen, geschützte Portalrouten und API-Endpunkte sind getrennt. Sitzungen werden als kurzlebige, HMAC-signierte HttpOnly-Cookies gehalten; OAuth-Zugangstoken werden nach dem Abruf des GitHub-Benutzernamens verworfen.

Der lokale Konfigurationsprovider liest und validiert Profile aus `profiles/*.json`; Schreiboperationen sind serverseitig verfügbar, werden in v1 aber nicht durch eine Web-Route freigegeben. Zod-Schemas und die veröffentlichten JSON-Schemas beschränken Profile auf stabile Paket-IDs und harmlose Optionen. Der Katalog ist versionskontrollierter Anwendungscode. Profil-Daten können weder Paketquellen noch Installer-Argumente oder Shell-Befehle vorgeben.

Der Plan-Endpunkt verlangt eine gültige Sitzung, prüft den Request-Origin und validiert Plattform, Architektur, Profil und jedes Paket erneut. Das Windows-Bootstrap enthält eine eigene feste Paket-Allowlist; der Plan kann keine WinGet-ID oder Befehlszeile injizieren. Paketabhängigkeiten werden serverseitig ergänzt.

`ConfigurationProvider` ist in v1 lokal; ein GitHub-Provider, Profil-Editor, dauerhafte Datenbank und Mehrbenutzerverwaltung sind nicht implementiert. Die Anwendung benötigt daher keine Datenbank und speichert keine persönlichen Tokens.
