"""configureMe Linux runner (CM-042) for Ubuntu Server 24.04 amd64.

Usage (on the target machine itself, never through the web portal):

    python3 linux/runner.py --plan linux/plans/huu-server-01.json

The default is a dry-run: it needs no root rights and changes nothing. It
validates plan and catalog, checks the system and lists every step as
"already satisfied" or "would change", with a reason.

    sudo python3 linux/runner.py --plan linux/plans/huu-server-01.json --apply

--apply only works as root (started with sudo; the runner never elevates
itself) and only on an interactive terminal. It repeats the dry-run, asks
for the hostname as confirmation, then runs the steps one after another.
After each step the real state is detected again; only that counts as
success. After a failure the remaining steps are skipped. There is no
rollback and no reboot.

Exit codes: 0 = dry-run finished (changes may be pending) / apply succeeded,
            1 = validation, preflight, detection or a step failed,
            2 = refused or aborted (wrong usage, no root, no terminal,
                hostname not confirmed); nothing was changed.
"""

import sys

if sys.version_info < (3, 12):
    sys.stderr.write("configureMe Linux-Runner benötigt Python 3.12 oder neuer.\n")
    sys.exit(2)

import argparse
import os

import detect
import host as host_module
import linux_plan
import report as report_module
import steps

LINUX_DIR = os.path.dirname(os.path.abspath(__file__))
REPO_ROOT = os.path.dirname(LINUX_DIR)
CATALOG_PATH = os.path.join(LINUX_DIR, "catalog.json")

EXIT_OK = 0
EXIT_FAILED = 1
EXIT_REFUSED = 2

DOCKER_GROUP_STEP = "docker-group"


def parse_args(argv):
    parser = argparse.ArgumentParser(
        prog="runner.py",
        description="configureMe Linux-Runner: Dry-Run (Standard) für einen Linux-Plan v1.",
    )
    parser.add_argument("--plan", required=True, help="Pfad zur Plandatei (configureme/linux-plan v1)")
    parser.add_argument(
        "--report-dir",
        default=".",
        help="Verzeichnis für linux-runner-report.json und .txt (Standard: aktuelles Verzeichnis)",
    )
    parser.add_argument(
        "--apply",
        action="store_true",
        help="Änderungen ausführen (nur als root per sudo, nur im interaktiven Terminal, mit Hostname-Bestätigung)",
    )
    return parser.parse_args(argv)


def load_inputs(host, plan_path, catalog_path):
    """Read and validate plan and catalog. Returns (plan, catalog, plan_bytes, catalog_bytes, errors)."""
    plan_bytes = host.read_file(plan_path)
    catalog_bytes = host.read_file(catalog_path)
    if plan_bytes is None:
        return None, None, b"", catalog_bytes or b"", [f"Plandatei nicht gefunden: {plan_path}"]
    if catalog_bytes is None:
        return None, None, plan_bytes, b"", ["Katalog linux/catalog.json nicht gefunden"]
    try:
        plan, catalog = linux_plan.validate_plan_bytes(plan_bytes, catalog_bytes)
    except linux_plan.ValidationError as error:
        return None, None, plan_bytes, catalog_bytes, [f"Plan/Katalog ungültig: {message}" for message in error.messages]
    placeholders = linux_plan.placeholder_pins(catalog)
    if placeholders:
        return None, None, plan_bytes, catalog_bytes, [
            "Katalog enthält ungeprüfte Docker-Pins (UNVERIFIED-PLACEHOLDER): " + ", ".join(placeholders)
        ]
    return plan, catalog, plan_bytes, catalog_bytes, []


def planned_steps(plan):
    """Step IDs in execution order, plus the optional docker group step."""
    steps = list(plan["steps"])
    if plan["options"]["addInvokingUserToDockerGroup"]:
        steps.append(DOCKER_GROUP_STEP)
    return steps


def step_title(catalog, step_id):
    if step_id == DOCKER_GROUP_STEP:
        return "Aufrufenden Benutzer (SUDO_USER) zur Gruppe docker hinzufügen"
    return linux_plan.catalog_step(catalog, step_id)["title"]


def detect_any(host, catalog, step_id):
    """Detect one step, including the optional docker group step."""
    if step_id == DOCKER_GROUP_STEP:
        try:
            return detect.detect_docker_group(host)
        except detect.DetectionError as error:
            return {"state": detect.BLOCKED, "reason": f"Zustand nicht ermittelbar: {error}", "before": {}, "actions": []}
    return detect.detect_step(host, catalog, step_id)


def run_dry_run(host, plan, catalog, report):
    """Fill report steps from detection. Returns True if nothing is blocked."""
    ok = True
    for step_id in planned_steps(plan):
        found = detect_any(host, catalog, step_id)
        if found["state"] == detect.SATISFIED:
            status = report_module.ALREADY_SATISFIED
        elif found["state"] == detect.CHANGE:
            status = report_module.WOULD_CHANGE
        else:
            status = report_module.FAILED
            ok = False
        report_module.add_step(
            report,
            step_id,
            step_title(catalog, step_id),
            status,
            found["reason"],
            before=found["before"],
            actions=found["actions"],
        )
    return ok


def prepare(host, args, catalog_path, repo_root, mode):
    """Validate inputs and run preflight. Returns (report, plan, catalog, ok)."""
    plan, catalog, plan_bytes, catalog_bytes, errors = load_inputs(host, args.plan, catalog_path)
    report = report_module.new_report(
        mode,
        host,
        os.path.basename(args.plan),
        linux_plan.sha256_hex(plan_bytes),
        linux_plan.sha256_hex(catalog_bytes),
        report_module.runner_commit(host, repo_root),
    )
    if errors:
        for message in errors:
            report["preflight"].append({"check": "plan-and-catalog", "status": "failed", "detail": message})
        return report, None, None, False
    report["preflight"].append({"check": "plan-and-catalog", "status": "passed", "detail": "Plan und Katalog gültig, Docker-Pins gesetzt"})
    report["options"] = dict(plan["options"])
    if plan["options"]["addInvokingUserToDockerGroup"]:
        report["warnings"].append(report_module.DOCKER_GROUP_WARNING)

    checks = detect.preflight_checks(host)
    report["preflight"].extend(checks)
    if any(check["status"] == "failed" for check in checks):
        for step_id in planned_steps(plan):
            report_module.add_step(
                report, step_id, step_title(catalog, step_id), report_module.SKIPPED, "Vorprüfung fehlgeschlagen"
            )
        return report, plan, catalog, False
    return report, plan, catalog, True


def finish(host, args, report, result):
    report["result"] = result
    text = report_module.to_text(report)
    host.show(text)
    try:
        json_path, text_path = report_module.write_reports(host, args.report_dir, report)
        host.show(f"Bericht: {json_path} und {text_path}")
    except OSError as error:
        host.show(f"Bericht konnte nicht geschrieben werden: {error.strerror}")


def apply(host, args, catalog_path, repo_root):
    """--apply: checks, fresh dry-run, hostname confirmation, then serial steps."""
    if host.geteuid() != 0:
        host.show("--apply braucht Root-Rechte. Bitte mit sudo starten; der Runner erhöht sich nicht selbst.")
        return EXIT_REFUSED
    if not host.stdio_is_tty():
        host.show("--apply braucht ein interaktives Terminal für die Bestätigung. Abgebrochen, nichts geändert.")
        return EXIT_REFUSED

    # 1. Fresh dry-run, shown to the operator.
    preview, plan, catalog, ok = prepare(host, args, catalog_path, repo_root, "dry-run")
    if ok and not run_dry_run(host, plan, catalog, preview):
        ok = False
    preview["result"] = "failed" if not ok else None
    if not ok:
        finish(host, args, preview, "failed")
        host.show("Dry-Run zeigt Fehler. Apply abgebrochen, nichts geändert.")
        return EXIT_FAILED
    pending = [step["id"] for step in preview["steps"] if step["status"] == report_module.WOULD_CHANGE]
    if not pending:
        finish(host, args, preview, "no-changes")
        host.show("Alle Schritte sind bereits erfüllt. Nichts zu tun.")
        return EXIT_OK
    preview["result"] = "changes-pending"
    host.show(report_module.to_text(preview))

    # 2. Confirmation by typing the hostname of this machine.
    hostname = host.hostname()
    host.show(f"Es werden {len(pending)} Schritt(e) als root ausgeführt: {', '.join(pending)}.")
    try:
        answer = host.ask("Zur Bestätigung den Hostnamen dieses Systems eingeben: ")
    except EOFError:
        answer = ""
    if answer.strip() != hostname:
        host.show("Hostname stimmt nicht. Abgebrochen, nichts geändert.")
        return EXIT_REFUSED

    # 3. Serial execution with detection after every step.
    report = report_module.new_report(
        "apply", host, preview["plan"]["file"], preview["plan"]["sha256"], preview["catalog"]["sha256"], preview["runner"]["commit"]
    )
    report["preflight"] = preview["preflight"]
    report["options"] = preview["options"]
    report["warnings"] = preview["warnings"]
    group_user = None
    if DOCKER_GROUP_STEP in planned_steps(plan):
        group_user, _ = detect.docker_group_user(host)

    failed = False
    for planned in preview["steps"]:
        step_id = planned["id"]
        title = planned["title"]
        if failed:
            report_module.add_step(report, step_id, title, report_module.SKIPPED, "vorheriger Schritt fehlgeschlagen", before=planned["before"])
            continue
        if planned["status"] == report_module.ALREADY_SATISFIED:
            report_module.add_step(report, step_id, title, report_module.ALREADY_SATISFIED, planned["reason"], before=planned["before"], after=planned["before"])
            continue
        host.show(f"→ {step_id} …")
        try:
            steps.apply_step(host, catalog, step_id, docker_group_user=group_user)
        except (steps.StepError, detect.DetectionError, OSError) as error:
            after = detect_any(host, catalog, step_id)["before"]
            report_module.add_step(report, step_id, title, report_module.FAILED, str(error), before=planned["before"], after=after)
            failed = True
            continue
        check = detect_any(host, catalog, step_id)
        if check["state"] == detect.SATISFIED:
            report_module.add_step(report, step_id, title, report_module.SUCCEEDED, check["reason"], before=planned["before"], after=check["before"])
        else:
            report_module.add_step(
                report, step_id, title, report_module.FAILED, f"Nachprüfung: {check['reason']}", before=planned["before"], after=check["before"]
            )
            failed = True

    finish(host, args, report, "failed" if failed else "succeeded")
    if any(step["id"] == DOCKER_GROUP_STEP and step["status"] == report_module.SUCCEEDED for step in report["steps"]):
        host.show("Hinweis: Die Gruppenmitgliedschaft gilt erst nach erneutem Anmelden.")
    return EXIT_FAILED if failed else EXIT_OK


def main(argv=None, host=None, catalog_path=CATALOG_PATH, repo_root=REPO_ROOT):
    host = host or host_module.real_host()
    args = parse_args(argv)

    if args.apply:
        return apply(host, args, catalog_path, repo_root)

    report, plan, catalog, ok = prepare(host, args, catalog_path, repo_root, "dry-run")
    if not ok:
        finish(host, args, report, "failed")
        return EXIT_FAILED
    if not run_dry_run(host, plan, catalog, report):
        finish(host, args, report, "failed")
        return EXIT_FAILED
    pending = any(step["status"] == report_module.WOULD_CHANGE for step in report["steps"])
    finish(host, args, report, "changes-pending" if pending else "no-changes")
    return EXIT_OK


if __name__ == "__main__":
    sys.exit(main())
