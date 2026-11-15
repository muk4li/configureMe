"""Integrity check for a configureMe Linux bundle (CM-043).

A bundle is a tar.gz produced by the local configureMe portal. It contains
the runner, the catalog, a validated plan and MANIFEST.json listing every
file with its SHA-256. The runner checks the files against the manifest
before anything else and reads the source commit from it (a bundle has no
.git directory).

This proves that the files were not changed or swapped after the portal
created the bundle. It does NOT prove where the bundle came from: the
manifest travels in the same archive. The owner compares the archive hash
shown in the host browser and checks the source commit on GitHub.
"""

import hashlib
import json
import os
import re

MANIFEST_NAME = "MANIFEST.json"
FORMAT_ID = "configureme/linux-bundle"
SCHEMA_VERSION = 1
MAX_MANIFEST_BYTES = 16384
MAX_FILES = 64
MANIFEST_KEYS = ("formatId", "schemaVersion", "sourceCommit", "catalogRevision", "planSha256", "files")
FILE_KEYS = ("path", "sha256")
# Only these locations may appear in a bundle.
ALLOWED_PATH = re.compile(r"^(?:linux/[a-z_]+\.py|linux/catalog\.json|plan\.json|ANLEITUNG\.txt)$")
SHA256 = re.compile(r"^[0-9a-f]{64}$")
COMMIT = re.compile(r"^[0-9a-f]{40}$")


def _reject_duplicates(pairs):
    keys = [key for key, _ in pairs]
    if len(keys) != len(set(keys)):
        raise ValueError("doppelter Schlüssel")
    return dict(pairs)


def verify(host, root):
    """Return (commit, errors). (None, []) means: not a bundle (e.g. a git checkout)."""
    data = host.read_file(os.path.join(root, MANIFEST_NAME))
    if data is None:
        return None, []
    if len(data) > MAX_MANIFEST_BYTES:
        return None, ["MANIFEST.json ist zu groß"]
    try:
        manifest = json.loads(data.decode("utf-8"), object_pairs_hook=_reject_duplicates)
    except (UnicodeDecodeError, ValueError) as error:
        return None, [f"MANIFEST.json ungültig: {error}"]
    if not isinstance(manifest, dict) or tuple(sorted(manifest)) != tuple(sorted(MANIFEST_KEYS)):
        return None, ["MANIFEST.json hat falsche oder fehlende Felder"]
    version = manifest["schemaVersion"]
    if manifest["formatId"] != FORMAT_ID or isinstance(version, bool) or version != SCHEMA_VERSION:
        return None, ["MANIFEST.json: unbekanntes Format oder Version"]
    commit = manifest["sourceCommit"]
    if not isinstance(commit, str) or not COMMIT.match(commit):
        return None, ["MANIFEST.json: sourceCommit ist kein vollständiger Commit-Hash"]
    for key in ("catalogRevision", "planSha256"):
        if not isinstance(manifest[key], str) or not SHA256.match(manifest[key]):
            return None, [f"MANIFEST.json: {key} ist kein SHA-256"]
    files = manifest["files"]
    if not isinstance(files, list) or not 0 < len(files) <= MAX_FILES:
        return None, ["MANIFEST.json: Dateiliste fehlt oder ist zu lang"]

    errors = []
    listed = set()
    for entry in files:
        if not isinstance(entry, dict) or tuple(sorted(entry)) != tuple(sorted(FILE_KEYS)):
            return None, ["MANIFEST.json: ungültiger Dateieintrag"]
        path, expected = entry["path"], entry["sha256"]
        if not isinstance(path, str) or not ALLOWED_PATH.match(path) or path in listed:
            return None, [f"MANIFEST.json: unzulässiger oder doppelter Pfad {path!r}"]
        if not isinstance(expected, str) or not SHA256.match(expected):
            return None, [f"MANIFEST.json: ungültige Prüfsumme für {path}"]
        listed.add(path)
        content = host.read_file(os.path.join(root, *path.split("/")))
        if content is None:
            errors.append(f"Datei fehlt: {path}")
        elif hashlib.sha256(content).hexdigest() != expected:
            errors.append(f"Datei verändert: {path}")

    for name in host.list_dir(os.path.join(root, "linux")):
        if (name.endswith(".py") or name.endswith(".json")) and f"linux/{name}" not in listed:
            errors.append(f"Datei nicht im Manifest: linux/{name}")
    for required in ("linux/catalog.json", "linux/runner.py", "plan.json"):
        if required not in listed:
            errors.append(f"Pflichtdatei nicht im Manifest: {required}")
    catalog = host.read_file(os.path.join(root, "linux", "catalog.json"))
    if catalog is not None and hashlib.sha256(catalog).hexdigest() != manifest["catalogRevision"]:
        errors.append("catalogRevision im Manifest passt nicht zu linux/catalog.json")
    plan = host.read_file(os.path.join(root, "plan.json"))
    if plan is not None and hashlib.sha256(plan).hexdigest() != manifest["planSha256"]:
        errors.append("planSha256 im Manifest passt nicht zu plan.json")
    return commit, errors
