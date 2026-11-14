# Linux

## Implementiert

Nichts. Linux ist in v1 nicht automatisiert. Das Beispielprofil `linux-developer` ist nur eine Planungsvorlage und enthält keine installierbaren Pakete. Es gibt keine APT-, DNF-, Pacman- oder Flatpak-Adapter. configureMe bewirbt Linux daher nicht als unterstützte Installationsplattform.

## Geplant (Proposed, CM-042)

Ein lokaler Runner soll eine frisch installierte Ubuntu-Server-24.04-VM (`huu-server-01`) aus einem versionierten Plan einrichten: Basiswerkzeuge, Docker Engine + Compose-Plugin aus dem offiziellen Docker-APT-Repo, unattended-upgrades. Der Runner läuft auf der VM selbst; das Webportal führt nichts aus. Firewall und Isolation gehören zu myHome-Lab. Entwurf und offene Entscheidungen: [Linux-Plan v1 – Vorschlag](linux-plan-contract.md). Noch nicht angenommen, nicht implementiert, nicht getestet.
