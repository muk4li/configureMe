# Architektur

configureMe v1 ist eine einzelne Next.js-Anwendung mit App Router. Öffentliche Produktinformationen, geschützte Portalrouten und API-Endpunkte sind getrennt. Sitzungen werden als kurzlebige, HMAC-signierte HttpOnly-Cookies gehalten; OAuth-Zugangstoken werden nach dem Abruf des GitHub-Benutzernamens verworfen.

Der lokale Konfigurationsprovider liest und validiert Profile aus `profiles/*.json`; Schreiboperationen sind serverseitig verfügbar, werden in v1 aber nicht durch eine Web-Route freigegeben. Zod-Schemas und die veröffentlichten JSON-Schemas beschränken Profile auf stabile Paket-IDs und harmlose Optionen. Der Katalog ist versionskontrollierter Anwendungscode. Profil-Daten können weder Paketquellen noch Installer-Argumente oder Shell-Befehle vorgeben.

Der Legacy-Bundle-Endpunkt verlangt eine gültige Sitzung, prüft den Request-Origin und validiert Plattform, Architektur, Profil und jedes Paket erneut. Das Windows-Bootstrap enthält eine eigene feste Paket-Allowlist; der Plan kann keine WinGet-ID oder Befehlszeile injizieren. Paketabhängigkeiten werden serverseitig ergänzt.

`ConfigurationProvider` ist in v1 lokal; ein GitHub-Provider, Profil-Editor, dauerhafte Datenbank und Mehrbenutzerverwaltung sind nicht implementiert. Die Anwendung benötigt daher keine Datenbank und speichert keine persönlichen Tokens.

## Öffentliche Planung und lokaler Planimport (2026-11-14)

Die öffentliche UI und `/api/public/plan` sind seit PD-001..004 ohne Login nutzbar; private Portal-/Bundle-/Profilrouten bleiben geschützt. Der Server revalidiert die vollständige Sitzungsauswahl aus synthetischen lokalen Fixtures. Neben Preview-JSON exportiert er einen getrennten deklarativen [Setup-Plan v1](setup-plan-contract.md). JSON ist keine ausführbare Distribution oder Installationsberechtigung.

Die vorhandene WinForms-EXE ist der lokale Runner. Sie importiert einen begrenzten Datei-Snapshot, prüft das gemeinsame Schema und die kataloggebundene effektive Auswahl unabhängig und zeigt Abhängigkeiten an. Nur auf Server 2022 x64 Desktop Experience sind Import und Dry-Run implementiert; Windows 11 benötigt noch einen getesteten nativen Adapter. Dry-Run verwendet dieselbe eingebettete PowerShell-Engine (detect + offline plan), keine zweite Engine. Manuelle Bedienung ohne Import bleibt erhalten. Keine Änderung globaler Zuständigkeiten, keine Installer-Auslagerung und kein permanenter Agent.

Öffentliche Profile enthalten nur nicht geheime Daten; private Vorlagen sind ein späterer, autorisierter Bereich. Geschützte Provisionierung/Secrets/VPN sind separat und hier nicht implementiert. Datenowner-Verträge bleiben Proposed; lokale Ausführung benötigt weder Nachbar-Repositories noch eine private Laufzeitinfrastruktur. [Datenquellenvergleich](integrations/public-snapshot-v1-proposal.md).

## Windows-v1-Folgearbeit in Reviewbranches

[Fortschritt und präzise Freigabegrenzen](audits/windows-v1-progress.md): gemeinsamer Planvertrag/Serverimport aus #12 sind in main; neue Ausführungsreview-/Windows-11-Kandidaten sind ausdrücklich unregistrierte Vorbereitungen, keine zweite Engine. Snapshot-Consumergrenzen bleiben Proposed. Handoff-/Provenienz-/UX-/OAuth-Korrekturen sind getrennte Reviews ohne Änderung globaler Zuständigkeiten. Nur die Provenienzfolge hängt kontrolliert vom Handoff-Fix ab. Keine eigenmächtige importierte Installation, Zielsystem-/Distributionsfreigabe oder fremde Repositoryänderung.
