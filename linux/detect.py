"""Detect the actual state of the machine for each plan step.

Nothing here changes the system. Every check looks at the real state
(installed package versions, key fingerprint, exact file bytes, group
membership) instead of remembering what an earlier run did.

Each step detection returns a dict:
    {"state": "satisfied" | "change" | "blocked",
     "reason": "...", "before": {...}, "actions": [...]}
"blocked" means the runner must not continue (for example conflicting
packages); the runner never repairs such a state on its own.
"""

import re
import tempfile

import linux_plan
import trusted

SATISFIED = "satisfied"
CHANGE = "change"
BLOCKED = "blocked"

USER_NAME_PATTERN = r"^[a-z_][a-z0-9_-]{0,31}$"


# --- Preflight ---------------------------------------------------------------


def parse_os_release(text):
    """Parse KEY=value lines of /etc/os-release (values may be quoted)."""
    values = {}
    for line in text.splitlines():
        line = line.strip()
        if not line or line.startswith("#") or "=" not in line:
            continue
        key, value = line.split("=", 1)
        if len(value) >= 2 and value[0] == value[-1] and value[0] in "\"'":
            value = value[1:-1]
        values[key] = value
    return values


def preflight_checks(host):
    """Check Python version, OS and architecture. Returns a list of check dicts."""
    checks = []

    version = host.python_version()
    wanted = ".".join(str(part) for part in trusted.MIN_PYTHON)
    checks.append(
        _check(
            "python-version",
            tuple(version) >= trusted.MIN_PYTHON,
            f"Python {version[0]}.{version[1]} (mindestens {wanted})",
        )
    )

    raw = host.read_file("/etc/os-release")
    release = parse_os_release(raw.decode("utf-8", "replace")) if raw is not None else {}
    os_ok = (
        release.get("ID") == trusted.TARGET_OS_ID
        and release.get("VERSION_ID") == trusted.TARGET_VERSION_ID
        and release.get("VERSION_CODENAME") == trusted.TARGET_CODENAME
    )
    found = f"ID={release.get('ID')}, VERSION_ID={release.get('VERSION_ID')}, VERSION_CODENAME={release.get('VERSION_CODENAME')}"
    checks.append(_check("operating-system", os_ok, f"{found} (erwartet ubuntu 24.04 noble)"))

    result = host.run(["dpkg", "--print-architecture"])
    architecture = result.stdout.strip() if result.returncode == 0 else None
    checks.append(
        _check(
            "architecture",
            architecture == trusted.TARGET_ARCHITECTURE,
            f"dpkg-Architektur {architecture} (erwartet {trusted.TARGET_ARCHITECTURE})",
        )
    )
    return checks


def _check(name, passed, detail):
    return {"check": name, "status": "passed" if passed else "failed", "detail": detail}


# --- Small readers -----------------------------------------------------------


def installed_versions(host, names):
    """Return {package: installed version or None} using dpkg-query.

    Only the status "ii" (installed) counts; removed packages with leftover
    configuration ("rc") count as not installed.
    """
    versions = {name: None for name in names}
    if not names:
        return versions
    result = host.run(
        ["dpkg-query", "--show", "--showformat=${Package}\\t${db:Status-Abbrev}\\t${Version}\\n", *names]
    )
    # Exit code 1 only means "some packages are unknown".
    if result.returncode not in (0, 1):
        raise DetectionError("dpkg-query fehlgeschlagen")
    for line in result.stdout.splitlines():
        parts = line.split("\t")
        if len(parts) != 3:
            continue
        package, status, version = parts
        package = package.split(":", 1)[0]
        if package in versions and status.startswith("ii"):
            versions[package] = version
    return versions


def version_greater(host, left, right):
    """True if Debian version left > right (dpkg --compare-versions)."""
    result = host.run(["dpkg", "--compare-versions", left, "gt", right])
    if result.returncode not in (0, 1):
        raise DetectionError("dpkg --compare-versions fehlgeschlagen")
    return result.returncode == 0


def key_fingerprints(host, key_bytes):
    """Return the primary key fingerprints of key data, using gpg --show-keys.

    The key is passed on stdin, so the same check works for an installed
    key file and for a freshly downloaded key that is not written yet.
    gpg gets its own empty temporary home directory, so it never reads or
    creates a keyring of the calling user.
    """
    with tempfile.TemporaryDirectory(prefix="configureme-gpg-") as home:
        result = host.run(
            ["gpg", "--homedir", home, "--batch", "--no-options", "--show-keys", "--with-colons"],
            input_bytes=key_bytes,
        )
    if result.returncode == 127:
        raise DetectionError("gpg ist nicht verfügbar")
    if result.returncode != 0:
        raise DetectionError("gpg konnte die Schlüsseldatei nicht lesen")
    return parse_primary_fingerprints(result.stdout)


def parse_primary_fingerprints(colon_output):
    """Fingerprints of primary keys ("pub" followed by "fpr") in gpg colon output."""
    fingerprints = []
    expect_primary_fpr = False
    for line in colon_output.splitlines():
        fields = line.split(":")
        if fields[0] == "pub":
            expect_primary_fpr = True
        elif fields[0] == "fpr" and expect_primary_fpr and len(fields) > 9:
            fingerprints.append(fields[9].upper())
            expect_primary_fpr = False
        elif fields[0] in ("sub", "sec", "ssb"):
            expect_primary_fpr = False
    return fingerprints


def group_members(host, group):
    """Return the member list of a group, or None if the group does not exist."""
    result = host.run(["getent", "group", group])
    if result.returncode == 2:
        return None
    if result.returncode != 0:
        raise DetectionError("getent fehlgeschlagen")
    fields = result.stdout.strip().split(":")
    if len(fields) != 4:
        raise DetectionError("unerwartete Ausgabe von getent")
    return [member for member in fields[3].split(",") if member]


class DetectionError(Exception):
    """The state could not be determined; reported as a failed step."""


# --- Steps ---------------------------------------------------------------------


def detect_step(host, catalog, step_id):
    try:
        if step_id == "base-tools":
            return _detect_archive_packages(host, catalog, step_id)
        if step_id == "docker-apt-repository":
            return _detect_docker_repository(host)
        if step_id == "docker-engine":
            return _detect_docker_engine(host, catalog)
        if step_id == "unattended-upgrades":
            return _detect_unattended_upgrades(host, catalog)
    except DetectionError as error:
        return _result(BLOCKED, f"Zustand nicht ermittelbar: {error}", {})
    raise ValueError(f"unknown step {step_id}")


def _result(state, reason, before, actions=()):
    return {"state": state, "reason": reason, "before": before, "actions": list(actions)}


def _package_names(catalog, step_id):
    return [package["name"] for package in linux_plan.catalog_step(catalog, step_id)["packages"]]


def _detect_archive_packages(host, catalog, step_id):
    names = _package_names(catalog, step_id)
    before = installed_versions(host, names)
    missing = [name for name in names if before[name] is None]
    if not missing:
        return _result(SATISFIED, "alle Pakete installiert (Ubuntu-Archiv, nicht gepinnt)", before)
    return _result(
        CHANGE,
        f"fehlende Pakete: {', '.join(missing)}",
        before,
        ["apt-get update", f"apt-get install {' '.join(names)}"],
    )


def _detect_docker_repository(host):
    before = {}
    if host.read_file(trusted.DOCKER_LEGACY_LIST_PATH) is not None:
        return _result(
            BLOCKED,
            f"{trusted.DOCKER_LEGACY_LIST_PATH} existiert und würde mit {trusted.DOCKER_SOURCES_PATH} kollidieren; bitte manuell prüfen",
            before,
        )

    actions = []
    reasons = []
    key = host.read_file(trusted.DOCKER_KEY_PATH)
    if key is None:
        before["key"] = "fehlt"
        reasons.append("Schlüsseldatei fehlt")
        actions.append(f"Schlüssel von {trusted.DOCKER_KEY_URL} laden, Fingerprint prüfen, nach {trusted.DOCKER_KEY_PATH} schreiben")
    else:
        fingerprints = key_fingerprints(host, key)
        if fingerprints != [trusted.DOCKER_KEY_FINGERPRINT]:
            before["key"] = "unerwarteter Fingerprint"
            return _result(
                BLOCKED,
                f"{trusted.DOCKER_KEY_PATH} enthält nicht genau den erwarteten Schlüssel {trusted.DOCKER_KEY_FINGERPRINT}; bitte manuell prüfen",
                before,
            )
        before["key"] = trusted.DOCKER_KEY_FINGERPRINT

    sources = host.read_file(trusted.DOCKER_SOURCES_PATH)
    if sources == trusted.DOCKER_SOURCES_CONTENT.encode("utf-8"):
        before["sources"] = "Sollinhalt"
    else:
        before["sources"] = "fehlt" if sources is None else "abweichend"
        reasons.append(f"{trusted.DOCKER_SOURCES_PATH} {before['sources']}")
        actions.append(f"{trusted.DOCKER_SOURCES_PATH} mit festem Inhalt schreiben")

    if not actions:
        return _result(SATISFIED, "Schlüssel-Fingerprint und docker.sources entsprechen dem Soll", before)
    actions.append("apt-get update")
    return _result(CHANGE, "; ".join(reasons), before, actions)


def _detect_docker_engine(host, catalog):
    conflicts = installed_versions(host, list(trusted.DOCKER_CONFLICTING_PACKAGES))
    installed_conflicts = [name for name, version in conflicts.items() if version is not None]
    packages = linux_plan.catalog_step(catalog, "docker-engine")["packages"]
    before = installed_versions(host, [package["name"] for package in packages])
    if installed_conflicts:
        return _result(
            BLOCKED,
            f"Konfliktpakete laut Docker-Doku installiert: {', '.join(installed_conflicts)}; Runner entfernt nichts, bitte manuell entfernen",
            before,
        )

    newer = [
        f"{package['name']} {before[package['name']]} > {package['version']}"
        for package in packages
        if before[package["name"]] is not None
        and before[package["name"]] != package["version"]
        and version_greater(host, before[package["name"]], package["version"])
    ]
    if newer:
        return _result(
            BLOCKED,
            "installierte Version neuer als der Pin (Downgrade nur manuell, Runner nutzt kein --allow-downgrades): "
            + "; ".join(newer),
            before,
        )

    differing = [
        f"{package['name']} {before[package['name']] or 'fehlt'} → {package['version']}"
        for package in packages
        if before[package["name"]] != package["version"]
    ]
    if differing:
        pins = " ".join(f"{package['name']}={package['version']}" for package in packages)
        return _result(
            CHANGE,
            "Versionen weichen vom Pin ab: " + "; ".join(differing),
            before,
            ["apt-get update", f"apt-get install {pins}"],
        )

    service = host.run(["systemctl", "is-active", "docker.service"]).stdout.strip()
    if service != "active":
        return _result(
            BLOCKED,
            f"Pakete entsprechen den Pins, aber docker.service ist '{service or 'unbekannt'}'; Runner startet keine Dienste",
            before,
        )
    return _result(SATISFIED, "alle Docker-Pakete in der gepinnten Version, docker.service aktiv", before)


def _detect_unattended_upgrades(host, catalog):
    names = _package_names(catalog, "unattended-upgrades")
    before = installed_versions(host, names)
    actions = []
    reasons = []
    if before["unattended-upgrades"] is None:
        reasons.append("Paket unattended-upgrades fehlt")
        actions += ["apt-get update", "apt-get install unattended-upgrades"]
    else:
        problems = unattended_policy_problems(host)
        if problems:
            return _result(
                BLOCKED,
                "unattended-upgrades-Konfiguration erlaubt mehr als Sicherheitsupdates ohne Neustart: "
                + "; ".join(problems)
                + " (Runner überschreibt 50unattended-upgrades nicht)",
                before,
            )

    current = host.read_file(trusted.AUTO_UPGRADES_PATH)
    if current != trusted.AUTO_UPGRADES_CONTENT.encode("utf-8"):
        before["20auto-upgrades"] = "fehlt" if current is None else "abweichend"
        reasons.append(f"{trusted.AUTO_UPGRADES_PATH} {before['20auto-upgrades']}")
        actions.append(f"{trusted.AUTO_UPGRADES_PATH} mit festem Inhalt schreiben")
    else:
        before["20auto-upgrades"] = "Sollinhalt"

    if not actions:
        return _result(SATISFIED, "Paket installiert, 20auto-upgrades entspricht dem Soll, nur Sicherheitsupdates", before)
    return _result(CHANGE, "; ".join(reasons), before, actions)


# Patterns that would allow more than security updates or an automatic reboot.
_POLICY_PATTERNS = (
    (r'Unattended-Upgrade::Automatic-Reboot\s+"(true|1|yes|on)"', "Automatic-Reboot ist aktiviert"),
    (r'-updates"', "Pocket -updates ist erlaubt"),
    (r'-proposed"', "Pocket -proposed ist erlaubt"),
    (r'-backports"', "Pocket -backports ist erlaubt"),
    (r"Unattended-Upgrade::Origins-Pattern", "Origins-Pattern wird verwendet (nicht automatisch prüfbar)"),
)


def unattended_policy_problems(host):
    """Check every apt.conf.d file that configures unattended-upgrades.

    Comments (// and #) are ignored. This is a deliberately small check of
    the Ubuntu defaults, not a full apt.conf parser.
    """
    problems = []
    for name in host.list_dir("/etc/apt/apt.conf.d"):
        if name.startswith("."):
            continue
        raw = host.read_file(f"/etc/apt/apt.conf.d/{name}")
        if raw is None:
            continue
        text = "\n".join(_strip_comment(line) for line in raw.decode("utf-8", "replace").splitlines())
        if "Unattended-Upgrade::" not in text:
            continue
        for pattern, message in _POLICY_PATTERNS:
            if re.search(pattern, text, re.IGNORECASE):
                problems.append(f"{name}: {message}")
    return problems


def _strip_comment(line):
    stripped = line.strip()
    if stripped.startswith("#"):
        return ""
    return line.split("//", 1)[0]


# --- Optional docker group ---------------------------------------------------


def docker_group_user(host):
    """Return (user name, problem). The user comes from SUDO_USER, never from the plan.

    Without sudo (dry-run as a normal user) the current user is shown instead.
    """
    if host.geteuid() == 0:
        name = host.sudo_user()
        if not name:
            return None, "SUDO_USER fehlt; bitte den Runner per sudo aus dem eigenen Konto starten"
    else:
        name = host.current_user_name()
    if not name or not re.fullmatch(USER_NAME_PATTERN, name):
        return None, "Benutzername ist ungültig"
    if name == "root":
        return None, "root wird nicht zur Gruppe docker hinzugefügt"
    uid = host.user_uid(name)
    if uid is None:
        return None, f"Benutzer {name} existiert nicht"
    if uid == 0:
        return None, f"Benutzer {name} hat UID 0 und wird abgelehnt"
    return name, None


def detect_docker_group(host):
    user, problem = docker_group_user(host)
    if problem:
        return _result(BLOCKED, problem, {})
    members = group_members(host, trusted.DOCKER_GROUP)
    before = {"user": user, "member": bool(members and user in members)}
    if members is not None and user in members:
        return _result(SATISFIED, f"{user} ist bereits Mitglied der Gruppe docker", before)
    reason = f"{user} ist nicht Mitglied der Gruppe docker"
    if members is None:
        reason = "Gruppe docker existiert noch nicht (entsteht mit docker-ce)"
    return _result(CHANGE, reason, before, [f"usermod --append --groups docker {user}"])
