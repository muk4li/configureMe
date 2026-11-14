"""Runner report as JSON and short text.

The report contains only what the runner decided and observed: commit,
hashes, target, preflight checks, step status with versions before and
after. It never contains environment variables, raw command output or
secrets.
"""

import json
import os

REPORT_FORMAT_ID = "configureme/linux-runner-report"
REPORT_SCHEMA_VERSION = 1
REPORT_JSON_NAME = "linux-runner-report.json"
REPORT_TEXT_NAME = "linux-runner-report.txt"

# Step status values.
SUCCEEDED = "succeeded"
ALREADY_SATISFIED = "already-satisfied"
WOULD_CHANGE = "would-change"  # dry-run only
SKIPPED = "skipped"
FAILED = "failed"

DOCKER_GROUP_WARNING = (
    "Option addInvokingUserToDockerGroup ist true: Mitglieder der Gruppe docker "
    "haben über den Docker-Socket faktisch Root-Rechte."
)


def runner_commit(host, repo_root):
    """Read the checked-out commit from .git without running git.

    Running git as root inside a user's clone is avoided on purpose
    (repository config could run programs). Returns None if unknown.
    """
    head = host.read_file(os.path.join(repo_root, ".git", "HEAD"))
    if head is None:
        return None
    head = head.decode("ascii", "replace").strip()
    if _is_sha(head):
        return head
    if not head.startswith("ref: "):
        return None
    ref = head[5:].strip()
    if ".." in ref or not ref.startswith("refs/"):
        return None
    loose = host.read_file(os.path.join(repo_root, ".git", ref))
    if loose is not None and _is_sha(loose.decode("ascii", "replace").strip()):
        return loose.decode("ascii").strip()
    packed = host.read_file(os.path.join(repo_root, ".git", "packed-refs"))
    for line in (packed or b"").decode("ascii", "replace").splitlines():
        parts = line.split(" ")
        if len(parts) == 2 and parts[1] == ref and _is_sha(parts[0]):
            return parts[0]
    return None


def _is_sha(text):
    return len(text) == 40 and all(char in "0123456789abcdef" for char in text)


def new_report(mode, host, plan_name, plan_sha256, catalog_sha256, commit):
    return {
        "formatId": REPORT_FORMAT_ID,
        "schemaVersion": REPORT_SCHEMA_VERSION,
        "mode": mode,
        "createdAt": host.utc_now(),
        "runner": {"commit": commit},
        "plan": {"file": plan_name, "sha256": plan_sha256},
        "catalog": {"sha256": catalog_sha256},
        "target": {"hostname": host.hostname()},
        "preflight": [],
        "options": {},
        "warnings": [],
        "steps": [],
        "result": None,
    }


def add_step(report, step_id, title, status, reason, before=None, after=None, actions=None):
    report["steps"].append(
        {
            "id": step_id,
            "title": title,
            "status": status,
            "reason": reason,
            "before": before or {},
            "after": after,
            "actions": actions or [],
        }
    )


def to_json_bytes(report):
    return (json.dumps(report, indent=2, ensure_ascii=False) + "\n").encode("utf-8")


_STATUS_TEXT = {
    SUCCEEDED: "erfolgreich",
    ALREADY_SATISFIED: "bereits erfüllt",
    WOULD_CHANGE: "würde ändern",
    SKIPPED: "übersprungen",
    FAILED: "FEHLER",
}


def to_text(report):
    lines = [
        f"configureMe Linux-Runner – {'Dry-Run (keine Änderung)' if report['mode'] == 'dry-run' else 'Apply'}",
        f"Ziel:          {report['target'].get('hostname')}",
        f"Runner-Commit: {report['runner']['commit'] or 'unbekannt'}",
        f"Plan:          {report['plan']['file']} sha256={report['plan']['sha256']}",
        f"Katalog:       sha256={report['catalog']['sha256']}",
    ]
    if report["options"]:
        lines.append(f"Optionen:      {json.dumps(report['options'])}")
    if report["preflight"]:
        lines.append("Vorprüfung:")
        for check in report["preflight"]:
            mark = "ok    " if check["status"] == "passed" else "FEHLER"
            lines.append(f"  [{mark}] {check['check']}: {check['detail']}")
    lines.append("Schritte:")
    for step in report["steps"]:
        lines.append(f"  [{_STATUS_TEXT.get(step['status'], step['status'])}] {step['id']}: {step['reason']}")
        versions = _version_text(step)
        if versions:
            lines.append(f"      {versions}")
        if step["status"] == WOULD_CHANGE:
            for action in step["actions"]:
                lines.append(f"      → {action}")
    for warning in report["warnings"]:
        lines.append(f"WARNUNG: {warning}")
    lines.append(f"Ergebnis: {report['result']}")
    return "\n".join(lines) + "\n"


def _version_text(step):
    before = step.get("before") or {}
    after = step.get("after") or {}
    parts = []
    for key in before:
        old = before.get(key)
        new = after.get(key, old) if after else old
        if new != old:
            parts.append(f"{key}: {old or '–'} → {new or '–'}")
        else:
            parts.append(f"{key}: {old if old not in (None, '') else '–'}")
    return ", ".join(parts)


def write_reports(host, directory, report):
    """Write JSON and text report. Returns the two paths."""
    json_path = os.path.join(directory, REPORT_JSON_NAME)
    text_path = os.path.join(directory, REPORT_TEXT_NAME)
    host.write_file(json_path, to_json_bytes(report), 0o644)
    host.write_file(text_path, to_text(report).encode("utf-8"), 0o644)
    return json_path, text_path
