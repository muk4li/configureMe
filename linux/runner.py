"""configureMe Linux runner (CM-042) for Ubuntu Server 24.04 amd64.

Usage (on the target machine itself, never through the web portal):

    python3 linux/runner.py --plan linux/plans/huu-server-01.json

The default is a dry-run: it needs no root rights and changes nothing. It
validates plan and catalog, checks the system and lists every step as
"already satisfied" or "would change", with a reason.

Exit codes: 0 = dry-run finished (changes may be pending),
            1 = validation, preflight or detection failed,
            2 = refused (wrong usage or missing preconditions).
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
    parser.add_argument("--apply", action="store_true", help="Änderungen ausführen (noch nicht implementiert)")
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


def main(argv=None, host=None, catalog_path=CATALOG_PATH, repo_root=REPO_ROOT):
    host = host or host_module.real_host()
    args = parse_args(argv)

    if args.apply:
        host.show("--apply ist in dieser Version noch nicht implementiert. Nur Dry-Run möglich.")
        return EXIT_REFUSED

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
