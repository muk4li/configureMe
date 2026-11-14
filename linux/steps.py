"""Apply functions for each plan step. Only called by runner.py after
--apply, root check, terminal check, a fresh dry-run and hostname
confirmation.

Every function runs fixed argument lists only. Success is never taken
from an exit code alone: runner.py detects the real state again after
each step.
"""

import detect
import linux_plan
import trusted

APT_TIMEOUT_SECONDS = 1800
# Wait for a running apt-daily/unattended-upgrades instead of failing at once.
APT_LOCK_OPTION = ["-o", "DPkg::Lock::Timeout=300"]
APT_ENV = {"DEBIAN_FRONTEND": "noninteractive"}


class StepError(Exception):
    """A step could not be completed; the message goes into the report."""


def _run(host, argv, what, **kwargs):
    result = host.run(argv, **kwargs)
    if result.returncode != 0:
        _show_error_tail(host, result.stderr)
        raise StepError(f"{what} fehlgeschlagen (Exit-Code {result.returncode})")
    return result


def _show_error_tail(host, stderr):
    """Show the last error lines on the terminal only; the report never gets raw output."""
    lines = [line for line in stderr.splitlines() if line.strip()][-15:]
    if lines:
        host.show("Letzte Fehlerzeilen (nur Terminal, nicht im Bericht):\n  " + "\n  ".join(lines))


def apt_update(host):
    _run(host, ["apt-get", "update", *APT_LOCK_OPTION], "apt-get update", extra_env=APT_ENV, timeout=APT_TIMEOUT_SECONDS)


def apt_install(host, specs):
    # No --allow-unauthenticated, --allow-downgrades or --force-* options, ever.
    _run(
        host,
        ["apt-get", "install", "--yes", *APT_LOCK_OPTION, *specs],
        "apt-get install",
        extra_env=APT_ENV,
        timeout=APT_TIMEOUT_SECONDS,
    )


def apply_step(host, catalog, step_id, docker_group_user=None):
    if step_id == "base-tools":
        names = [package["name"] for package in linux_plan.catalog_step(catalog, step_id)["packages"]]
        apt_update(host)
        apt_install(host, names)
    elif step_id == "docker-apt-repository":
        apply_docker_repository(host)
    elif step_id == "docker-engine":
        packages = linux_plan.catalog_step(catalog, step_id)["packages"]
        apt_update(host)
        apt_install(host, [f"{package['name']}={package['version']}" for package in packages])
    elif step_id == "unattended-upgrades":
        apply_unattended_upgrades(host)
    elif step_id == "docker-group":
        if not docker_group_user:
            raise StepError("kein gültiger Benutzer für die Gruppe docker")
        _run(host, ["usermod", "--append", "--groups", trusted.DOCKER_GROUP, docker_group_user], "usermod")
    else:
        raise ValueError(f"unknown step {step_id}")


def apply_docker_repository(host):
    """Download and check the key BEFORE writing anything, then write key and sources."""
    if host.read_file(trusted.DOCKER_LEGACY_LIST_PATH) is not None:
        raise StepError(f"{trusted.DOCKER_LEGACY_LIST_PATH} existiert; nichts geändert")

    current_key = host.read_file(trusted.DOCKER_KEY_PATH)
    if current_key is None:
        try:
            key = host.fetch_https(trusted.DOCKER_KEY_URL, trusted.DOCKER_KEY_HOST, trusted.DOCKER_KEY_MAX_BYTES)
        except OSError as error:
            raise StepError(f"Schlüssel-Download fehlgeschlagen: {error}") from None
        try:
            fingerprints = detect.key_fingerprints(host, key)
        except detect.DetectionError as error:
            raise StepError(f"Schlüssel nicht prüfbar: {error}; nichts geändert") from None
        if fingerprints != [trusted.DOCKER_KEY_FINGERPRINT]:
            raise StepError(
                "Fingerprint des geladenen Schlüssels weicht ab "
                f"(erwartet genau {trusted.DOCKER_KEY_FINGERPRINT}); nichts geändert"
            )
        host.make_dir(trusted.DOCKER_KEYRING_DIR, 0o755)
        host.write_file(trusted.DOCKER_KEY_PATH, key, 0o644)
    elif detect.key_fingerprints(host, current_key) != [trusted.DOCKER_KEY_FINGERPRINT]:
        raise StepError(f"{trusted.DOCKER_KEY_PATH} enthält einen unerwarteten Schlüssel; nichts geändert")

    wanted = trusted.DOCKER_SOURCES_CONTENT.encode("utf-8")
    if host.read_file(trusted.DOCKER_SOURCES_PATH) != wanted:
        host.write_file(trusted.DOCKER_SOURCES_PATH, wanted, 0o644)
    # Proves that apt accepts the repository and its signature.
    apt_update(host)


def apply_unattended_upgrades(host):
    """Install the package if missing and write only 20auto-upgrades.

    50unattended-upgrades (security only, Automatic-Reboot off by default)
    is never written.
    """
    if detect.installed_versions(host, ["unattended-upgrades"])["unattended-upgrades"] is None:
        apt_update(host)
        apt_install(host, ["unattended-upgrades"])
    wanted = trusted.AUTO_UPGRADES_CONTENT.encode("utf-8")
    if host.read_file(trusted.AUTO_UPGRADES_PATH) != wanted:
        host.write_file(trusted.AUTO_UPGRADES_PATH, wanted, 0o644)
