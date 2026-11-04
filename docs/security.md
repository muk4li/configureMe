# Sicherheitsmodell und Einschränkungen

## Vertrauensgrenzen

- Das Webportal plant Installationen, führt aber keine Installation auf dem Server oder Zielgerät aus.
- GitHub OAuth verwendet nur `read:user`; die Allowlist stammt aus serverseitiger Konfiguration. Der initiale Administrator wird über `INITIAL_ADMIN_GITHUB_USER` gesetzt.
- Sessions sind HMAC-signiert, HttpOnly, SameSite=Lax und laufen nach acht Stunden ab. In Produktion wird `Secure` gesetzt. OAuth bindet den Callback an einen zufälligen, kurzlebigen State-Cookie.
- Profile sind strikt validierte Daten. Benutzerwerte werden nicht in PowerShell-Quelltext interpoliert. Paket-IDs werden gegen den Anwendungskatalog geprüft und im Bootstrap erneut auf eine feste WinGet-ID abgebildet.
- Bootstrap-POSTs benötigen eine Sitzung und den exakt passenden Origin. Anmelde-Callback und Bundle-Erstellung haben prozesslokale Rate-Limits; sie sind für eine einzelne Instanz gedacht und ersetzen keinen Schutz am Reverse Proxy.
- Sicherheits-Header verhindern MIME-Sniffing, Framing und unnötige Browser-Berechtigungen.

## Download-Provenienz

Windows-Pakete enthalten `plan.json`, `plan.sha256`, einen festen `install.ps1`-Einstiegspunkt und eine README. Der Bootstrap vergleicht SHA-256 vor dem Parsen des Plans. Diese Prüfsumme schützt nur vor unbeabsichtigter Beschädigung: Ein Angreifer, der Plan und Prüfsumme gemeinsam ändert, wird dadurch nicht erkannt.

Die Artefakte sind **nicht signiert**. Es gibt keinen eingebetteten, unabhängig vertrauenswürdigen Herausgeberschlüssel und keine Authenticode-Signierung. Die Pakete bewerben sich deshalb nicht als nachweislich vom Herausgeber stammend. Für öffentliches Hosting sind ein unabhängiger Signatur-/Provenienzprozess, ein außerhalb des Downloads verteilter Trust Anchor sowie eine signierte Windows-Veröffentlichung erforderlich.

## Bedrohungsmodell

| Bedrohung | V1-Maßnahme und Grenze |
|---|---|
| Manipuliertes Profil | Striktes Schema, bekannte IDs, keine freien Befehle oder URLs; Katalogänderungen erfordern eine Codeänderung. |
| Manipulierter Plan | Schema- und Allowlist-Prüfung auf Server und Client; SHA-256 erkennt zufällige Beschädigung, aber keine böswillige gemeinsame Änderung. Signaturen fehlen. |
| Kompromittiertes Portal | Installationen laufen nicht remote. Ein kompromittiertes Portal kann weiterhin Bootstrap-Dateien und Seiteninhalte verändern; unsigned Downloads bieten keinen unabhängigen Herkunftsschutz. Nicht öffentlich ohne Signierung/Review betreiben. |
| Kompromittiertes privates GitHub-Repository | Der GitHub-Provider ist nicht implementiert; Profile sind lokale, geprüfte JSON-Dateien. |
| Replay eines alten Plans | Schema- und Katalogversion werden gebunden, aber es gibt keine Widerrufsliste oder kryptografische Replay-Sperre. |
| Gestohlene Sitzung | Kurze Lebensdauer, HttpOnly, SameSite=Lax, Secure in Produktion, Allowlist und nur lesendes OAuth. Es gibt keine zentrale Session-Widerrufsdatenbank. |
| Nicht unterstützte Plattform | Planer und Bootstrap akzeptieren ausschließlich Windows x64; Linux/macOS sind sichtbar als geplant, aber nicht automatisiert. |
| Unbeabsichtigte Installation | Lokaler Dry-Run, sichtbare Zusammenfassung und explizite Eingabe `YES`; der Browser installiert nichts. Kein automatischer Neustart oder Sicherheits-Bypass. |

Die WinGet-CLI und die jeweiligen Paketquellen bleiben externe Vertrauensabhängigkeiten. Die App pinnt keine Paketversionen. Prüfe Bundle und Paketquelle vor dem Einsatz auf einem wichtigen System.
