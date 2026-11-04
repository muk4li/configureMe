# Windows-Bootstrap

Der MVP erzeugt einen Windows-x64-Plan für die im Katalog freigegebenen WinGet-IDs. Windows 10/11 ist die primäre Zielumgebung. Windows Server wird nicht als vollständig validiert beworben; dort lässt der Bootstrap nur Git, GitHub CLI und PowerShell 7 zu.

Benötigt werden Windows PowerShell 5.1, WinGet (App Installer) und Internetzugang. Git, Node.js, Python oder GitHub CLI müssen nicht vorinstalliert sein. Ist WinGet nicht verfügbar, bricht das Skript ab, bevor es Software installiert, und nennt offizielle manuelle Quellen.

1. ZIP vom vertrauenswürdigen configureMe-Portal herunterladen und Inhalte prüfen.
2. `.\install.ps1 -DryRun` in Windows PowerShell ausführen.
3. Den Plan und die Paketliste prüfen.
4. `.\install.ps1` ausführen und nur nach eigener Prüfung exakt `YES` bestätigen.

Der Installer fordert selbst keine Administratorrechte an. Einzelne WinGet-Installer können eigene Dialoge anzeigen. Installationsfehler werden gesammelt; ein erneuter Lauf überspringt erkannte Programme. Die Prüfsumme ist keine Signatur. Windows-Bootstrap wurde in dieser Entwicklungsumgebung nicht auf einem frischen Windows-Zielsystem end-to-end ausgeführt und bleibt Preview.
