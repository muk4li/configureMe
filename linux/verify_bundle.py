"""Use ONLY from an independently trusted checkout, before executing downloaded code.

No network, process execution or installation. Validates a bounded immutable ZIP snapshot
and optionally writes only its known files into a new directory, without overwrite.
A supplied hash must come from a separate trusted channel; hashes are not signing.
"""
import argparse
import hashlib
import io
import os
from pathlib import Path
import re
import stat
import sys
import zipfile
import linux_plan

PAYLOAD = frozenset({
    "linux/runner.py", "linux/host.py", "linux/detect.py", "linux/linux_plan.py", "linux/report.py",
    "linux/steps.py", "linux/trusted.py", "linux/verify_bundle.py", "linux/catalog.json",
    "schemas/linux-plan-v1.schema.json", "contracts/linux-plan-v1.policy.json", "plan.json", "README.md",
})
FILES = PAYLOAD | {"manifest.json", "SHA256SUMS"}
MAX_ARCHIVE = 4 * 1024 * 1024
MAX_FILE = 1024 * 1024


def digest(data):
    return hashlib.sha256(data).hexdigest()


def verify_bundle(data, expected_sha256):
    if len(data) > MAX_ARCHIVE or not re.fullmatch(r"[0-9a-fA-F]{64}", expected_sha256) or digest(data) != expected_sha256.lower():
        raise ValueError("Archive size/hash refused; an independent expected SHA256 is required")
    with zipfile.ZipFile(io.BytesIO(data)) as archive:
        entries = archive.infolist()
        if len(entries) != len(FILES) or {entry.filename for entry in entries} != FILES:
            raise ValueError("Unexpected, missing or duplicate bundle files")
        if sum(entry.file_size for entry in entries) > MAX_ARCHIVE:
            raise ValueError("Uncompressed bundle exceeds limit")
        contents = {}
        for entry in entries:
            mode = entry.external_attr >> 16
            if entry.is_dir() or stat.S_IFMT(mode) not in (0, stat.S_IFREG) or entry.flag_bits & 1 or entry.file_size > MAX_FILE:
                raise ValueError("Unsafe bundle entry")
            contents[entry.filename] = archive.read(entry)
    manifest = linux_plan.load_strict_json(contents["manifest.json"], 16384, 4)
    if not isinstance(manifest, dict) or set(manifest) != {"formatId", "schemaVersion", "authorization", "releaseApproved", "manualVerificationRequired", "sourceCommit", "sourceClean", "catalogRevision", "files"}:
        raise ValueError("Unexpected manifest fields")
    if manifest["formatId"] != "configureme/linux-bundle" or type(manifest["schemaVersion"]) is not int or manifest["schemaVersion"] != 1 or manifest["authorization"] != "none" or manifest["releaseApproved"] is not False or manifest["manualVerificationRequired"] is not True or manifest["sourceClean"] is not True:
        raise ValueError("Unsupported bundle identity, authority or release claim")
    if not isinstance(manifest["sourceCommit"], str) or not re.fullmatch(r"[a-f0-9]{40,64}", manifest["sourceCommit"]):
        raise ValueError("Missing source commit claim")
    records = manifest["files"]
    if not isinstance(records, list) or len(records) != len(PAYLOAD):
        raise ValueError("Incomplete manifest")
    names = []
    for record in records:
        if not isinstance(record, dict) or set(record) != {"path", "sizeBytes", "sha256"}:
            raise ValueError("Invalid manifest entry")
        name = record["path"]
        if not isinstance(name, str) or name not in PAYLOAD or name in names:
            raise ValueError("Invalid manifest path")
        names.append(name)
        if type(record["sizeBytes"]) is not int or record["sizeBytes"] != len(contents[name]) or record["sha256"] != digest(contents[name]):
            raise ValueError("Payload size/hash mismatch")
    if names != sorted(PAYLOAD) or manifest["catalogRevision"] != digest(contents["linux/catalog.json"]):
        raise ValueError("Manifest order/catalog mismatch")
    expected_sums = "".join(f"{digest(contents[name])}  {name}\n" for name in sorted(FILES - {"SHA256SUMS"}))
    if contents["SHA256SUMS"] != expected_sums.encode("utf-8"):
        raise ValueError("Checksum inventory mismatch")
    trusted_catalog = Path(__file__).with_name("catalog.json").read_bytes()
    if contents["linux/catalog.json"] != trusted_catalog:
        raise ValueError("Bundle catalog differs from the independently trusted checkout; use the matching reviewed source")
    linux_plan.validate_plan_bytes(contents["plan.json"], contents["linux/catalog.json"])
    return contents, manifest


def extract_new(contents, destination):
    target = Path(destination).absolute()
    for parent in (target, *target.parents):
        if parent.is_symlink():
            raise ValueError("Extraction path contains a symlink")
    # mkdir without exist_ok is the no-overwrite boundary. The operator owns parent.
    target.mkdir(mode=0o700)
    for name in sorted(contents):
        output = target / name
        output.parent.mkdir(parents=True, exist_ok=True)
        with output.open("xb") as handle:
            handle.write(contents[name])
        output.chmod(0o600)


def main(argv=None):
    parser = argparse.ArgumentParser(description=__doc__)
    parser.add_argument("archive")
    parser.add_argument("--expected-sha256", required=True, help="From an independent trusted channel, NOT the download header")
    parser.add_argument("--extract-to", help="New nonexisting directory under an operator-owned parent")
    args = parser.parse_args(argv)
    try:
        with open(args.archive, "rb") as handle:
            data = handle.read(MAX_ARCHIVE + 1)
        contents, manifest = verify_bundle(data, args.expected_sha256)
        if args.extract_to:
            extract_new(contents, args.extract_to)
        print(f"Integrity checked; unsigned development source claim {manifest['sourceCommit']}. This grants no installation rights.")
        return 0
    except (OSError, ValueError, KeyError, TypeError, zipfile.BadZipFile, linux_plan.ValidationError) as error:
        print(f"Bundle refused: {type(error).__name__}", file=sys.stderr)
        return 1


if __name__ == "__main__":
    sys.exit(main())
