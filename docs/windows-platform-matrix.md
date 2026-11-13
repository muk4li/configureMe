# Windows-Matrix: Planbarkeit versus tatsächliche Installation

Stand 2026-11-14. Ausschließlich x64. Öffentliche A/B-Vorschau installiert nichts und liefert keine EXE/ZIPs.

| Ziel | In A/B implementierte Strategie-/Planprüfung | Tatsächlicher Installationsnachweis | Freigabegrenze |
| --- | --- | --- | --- |
| Windows 11 x64 | bekannte Katalogpakete mit vorhandener windowsPackageId: WinGet; übrige Pakete sichtbar unavailable; deklarative Planung und Konflikte | keine realen Herstellerinstallationen in diesem Auftrag; Legacy-Bootstrap existiert, neue Previewdatei ist damit nicht direkt ausführbar | lokaler Planadapter, passende OS-/x64-Prüfung, WinGet-Prerequisites, Installertrust und Releasegates vor Download |
| Windows Server 2022 x64 Desktop Experience | vorhandene automatic/manual/web-fallback/detection-only-Modi; Legacy-catalog-only-IDs ausgeschlossen | vorhandener getrennter Windows-CI-/Engine-Fix prüft Mocks/GUI; keine frische echte Installationsabnahme hier | CM-001/005/006/010, vollständig aktualisiertes OS/CET, lokale Bestätigung, verifizierter nativer/PS5.1-Planimport |
| Server Core, andere Releases, ARM64/x86 | nicht wählbar; Anfrage/Storage mit anderer Architektur/Ziel-ID abgelehnt | keine Zusage | außerhalb PD-004 |
| Linux/macOS | nicht wählbar, keine stillschweigende Konvertierung von Datenprofilen | keine Zusage | außerhalb MVP |

Ein package-target-Fehler blockiert den Planexport; manuell/web/detection-only sind sichtbar und keine Installationszusagen. Reale Herstellerverfügbarkeit/Signaturen werden weiterhin ausschließlich von vorhandenen lokalen Paketdefinitionen geprüft. Diese Matrix fügt keine neue Installerstrategie hinzu.

Spätere isolierte Abnahme nach separater Installationsfreigabe: frisches Zielsystem je Szenario, Artefakt-/Plan-/OS-SHAs und Versionen, kein globales .NET für GUIstart, tatsächliche x64-Versionen, Rechtekontext, Idempotenz, fehlendes WinGet/PATH, offline/abgebrochene Downloads und Neustartbedingungen. Windows 11 benötigt einen eigenen Zielsystemnachweis; ein Hosted Server-Runner bestätigt ihn nicht.

## Lokaler Setup-Plan v1 (Masterauftrag)

Beide x64-Ziele sind im neuen Vertrag exportierbar. Die vorhandene EXE unterstützt sicheren Import und detect/offline-plan-Dry-Run ausschließlich auf Server 2022 Desktop Experience. Windows 11 wird beim nativen Import ausdrücklich abgelehnt, bis ein getesteter Adapter vorhanden ist. Importierte Pläne dürfen in v1 keine reale Installation auslösen. [Vertrag](setup-plan-contract.md), [tatsächliche CI-/Testnachweise](audits/setup-plan-v1.md). Das ersetzt keine echte saubere VM-Abnahme oder öffentliche Distributionsfreigabe.
