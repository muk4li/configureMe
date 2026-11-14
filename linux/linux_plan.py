"""Strict validation of configureme/linux-plan v1 and the Linux catalog.

Only the Python standard library is used. Nothing here executes commands
or touches the system; it only reads bytes that the caller passes in.

The plan rules mirror schemas/linux-plan-v1.schema.json and
contracts/linux-plan-v1.policy.json. tests/linux/test_contract_constants.py
checks that the constants below match those files.
"""

import hashlib
import json
import re

import trusted

# --- Plan contract constants -------------------------------------------------

PLAN_FORMAT_ID = "configureme/linux-plan"
PLAN_SCHEMA_VERSION = 1
PLAN_AUTHORIZATION = "none"
PLAN_MAX_BYTES = 16384
PLAN_MAX_DEPTH = 4
PLAN_KEYS = (
    "formatId",
    "schemaVersion",
    "catalogRevision",
    "authorization",
    "target",
    "steps",
    "options",
)
PLAN_TARGET_KEYS = ("os", "architecture")
PLAN_OPTION_KEYS = ("addInvokingUserToDockerGroup",)
CATALOG_REVISION_PATTERN = r"^[0-9a-f]{64}$"

# Step IDs in their fixed catalog order (= execution order).
STEP_IDS = ("base-tools", "docker-apt-repository", "docker-engine", "unattended-upgrades")

# --- Catalog constants -------------------------------------------------------

CATALOG_FORMAT_ID = "configureme/linux-catalog"
CATALOG_SCHEMA_VERSION = 1
CATALOG_MAX_BYTES = 65536
CATALOG_MAX_DEPTH = 6
CATALOG_KEYS = ("formatId", "schemaVersion", "target", "sources", "steps")
CATALOG_TARGET_KEYS = ("os", "codename", "architecture")
CATALOG_STEP_KEYS = ("id", "title", "dependsOn", "packages")
TITLE_MAX_LENGTH = 120

# A Docker pin that has not been checked against the official repository yet.
# The catalog may contain it, the runner refuses to use such a catalog.
PIN_PLACEHOLDER = "UNVERIFIED-PLACEHOLDER"
PIN_PATTERN = r"^(?:[0-9]+:)?[0-9][A-Za-z0-9.+~-]*$"


class ValidationError(Exception):
    """Raised with a list of messages; each message starts with an error code."""

    def __init__(self, messages):
        self.messages = list(messages)
        super().__init__("; ".join(self.messages))

    def codes(self):
        return [message.split(":", 1)[0] for message in self.messages]


def sha256_hex(data):
    return hashlib.sha256(data).hexdigest()


# --- Strict JSON reading ------------------------------------------------------


def nesting_depth(text):
    """Return the deepest object/array nesting level, ignoring strings.

    This runs before json.loads so that deeply nested input is rejected
    without recursion inside the JSON parser.
    """
    depth = 0
    deepest = 0
    in_string = False
    escaped = False
    for char in text:
        if in_string:
            if escaped:
                escaped = False
            elif char == "\\":
                escaped = True
            elif char == '"':
                in_string = False
        elif char == '"':
            in_string = True
        elif char in "[{":
            depth += 1
            deepest = max(deepest, depth)
        elif char in "]}":
            depth -= 1
    return deepest


def _reject_duplicate_keys(pairs):
    result = {}
    for key, value in pairs:
        if key in result:
            raise ValidationError([f"duplicate-key: {key}"])
        result[key] = value
    return result


def _reject_constant(name):
    raise ValidationError([f"invalid-number: {name}"])


def load_strict_json(data, max_bytes, max_depth):
    """Parse bytes as one JSON value with size, depth and duplicate-key limits."""
    if not isinstance(data, bytes):
        raise ValidationError(["invalid-input: bytes expected"])
    if len(data) > max_bytes:
        raise ValidationError([f"too-large: {len(data)} bytes > {max_bytes}"])
    if data.startswith(b"\xef\xbb\xbf"):
        raise ValidationError(["invalid-encoding: byte order mark not allowed"])
    try:
        text = data.decode("utf-8")
    except UnicodeDecodeError:
        raise ValidationError(["invalid-encoding: not UTF-8"]) from None
    depth = nesting_depth(text)
    if depth > max_depth:
        raise ValidationError([f"too-deep: depth {depth} > {max_depth}"])
    try:
        return json.loads(
            text,
            object_pairs_hook=_reject_duplicate_keys,
            parse_constant=_reject_constant,
        )
    except json.JSONDecodeError as error:
        raise ValidationError([f"invalid-json: line {error.lineno} column {error.colno}"]) from None


# --- Small type helpers -------------------------------------------------------


def _is_int(value):
    # bool is a subclass of int in Python; JSON true must not count as 1.
    return isinstance(value, int) and not isinstance(value, bool)


def _check_keys(value, path, allowed, errors):
    """Report missing and unknown keys of an object. Returns False if not an object."""
    if not isinstance(value, dict):
        errors.append(f"wrong-type: {path} must be an object")
        return False
    for key in value:
        if key not in allowed:
            errors.append(f"unknown-field: {path}.{key}")
    for key in allowed:
        if key not in value:
            errors.append(f"missing-field: {path}.{key}")
    return True


def _canonical(value):
    return json.dumps(value, sort_keys=True, separators=(",", ":"))


def _check_const(value, expected, path, errors):
    if type(value) is not type(expected) or value != expected:
        errors.append(f"wrong-value: {path} must be {json.dumps(expected)}")


# --- Catalog -----------------------------------------------------------------


def validate_catalog_bytes(catalog_bytes):
    """Validate the catalog file and return the parsed catalog.

    Placeholder pins are allowed here; use placeholder_pins() to find them.
    """
    catalog = load_strict_json(catalog_bytes, CATALOG_MAX_BYTES, CATALOG_MAX_DEPTH)
    errors = []
    if not _check_keys(catalog, "$", CATALOG_KEYS, errors):
        raise ValidationError(errors)

    _check_const(catalog.get("formatId"), CATALOG_FORMAT_ID, "$.formatId", errors)
    _check_const(catalog.get("schemaVersion"), CATALOG_SCHEMA_VERSION, "$.schemaVersion", errors)

    target = catalog.get("target")
    if _check_keys(target, "$.target", CATALOG_TARGET_KEYS, errors):
        _check_const(target.get("os"), trusted.TARGET_OS, "$.target.os", errors)
        _check_const(target.get("codename"), trusted.TARGET_CODENAME, "$.target.codename", errors)
        _check_const(
            target.get("architecture"), trusted.TARGET_ARCHITECTURE, "$.target.architecture", errors
        )

    # Compare as canonical JSON: a plain == would treat true and 1 as equal.
    if _canonical(catalog.get("sources")) != _canonical(trusted.CATALOG_SOURCES):
        errors.append("untrusted-source: $.sources must equal the fixed sources in linux/trusted.py")

    steps = catalog.get("steps")
    if not isinstance(steps, list):
        errors.append("wrong-type: $.steps must be an array")
    else:
        _validate_catalog_steps(steps, errors)

    if errors:
        raise ValidationError(errors)
    return catalog


def _validate_catalog_steps(steps, errors):
    ids = [step.get("id") if isinstance(step, dict) else None for step in steps]
    if tuple(ids) != STEP_IDS:
        errors.append(f"wrong-value: $.steps ids must be {list(STEP_IDS)} in this order")
        return
    seen = []
    for index, step in enumerate(steps):
        path = f"$.steps[{index}]"
        if not _check_keys(step, path, CATALOG_STEP_KEYS, errors):
            continue
        step_id = step["id"]
        title = step.get("title")
        if not isinstance(title, str) or not 0 < len(title) <= TITLE_MAX_LENGTH:
            errors.append(f"wrong-type: {path}.title must be a string of 1..{TITLE_MAX_LENGTH} characters")

        depends = step.get("dependsOn")
        if not isinstance(depends, list) or not all(isinstance(item, str) for item in depends):
            errors.append(f"wrong-type: {path}.dependsOn must be an array of strings")
        else:
            if len(set(depends)) != len(depends):
                errors.append(f"duplicate-item: {path}.dependsOn")
            for dependency in depends:
                # Only earlier steps: keeps the catalog order a valid execution order.
                if dependency not in seen:
                    errors.append(f"invalid-dependency: {path}.dependsOn {dependency} is not an earlier step")
        seen.append(step_id)

        _validate_catalog_packages(step_id, step.get("packages"), f"{path}.packages", errors)


def _validate_catalog_packages(step_id, packages, path, errors):
    expected_names = trusted.STEP_PACKAGES[step_id]
    pinned = trusted.STEP_SOURCES[step_id] == "docker-apt-repository"
    if not isinstance(packages, list):
        errors.append(f"wrong-type: {path} must be an array")
        return
    names = []
    for index, package in enumerate(packages):
        item_path = f"{path}[{index}]"
        allowed = ("name", "version") if pinned else ("name",)
        if not _check_keys(package, item_path, allowed, errors):
            continue
        names.append(package.get("name"))
        if pinned:
            version = package.get("version")
            if not isinstance(version, str) or not (
                version == PIN_PLACEHOLDER or re.fullmatch(PIN_PATTERN, version)
            ):
                errors.append(f"invalid-pin: {item_path}.version must be an exact Debian version")
    if tuple(names) != expected_names:
        errors.append(f"wrong-value: {path} names must be {list(expected_names)}")


def placeholder_pins(catalog):
    """Return 'step/package' for every Docker pin that is still a placeholder."""
    result = []
    for step in catalog["steps"]:
        for package in step["packages"]:
            if package.get("version") == PIN_PLACEHOLDER:
                result.append(f"{step['id']}/{package['name']}")
    return result


def catalog_step(catalog, step_id):
    for step in catalog["steps"]:
        if step["id"] == step_id:
            return step
    raise KeyError(step_id)


# --- Plan --------------------------------------------------------------------


def validate_plan_bytes(plan_bytes, catalog_bytes):
    """Validate a plan against the catalog. Returns (plan, catalog).

    Dependencies are checked against the catalog. A missing dependency is an
    error; the validator never adds steps on its own.
    """
    catalog = validate_catalog_bytes(catalog_bytes)
    plan = load_strict_json(plan_bytes, PLAN_MAX_BYTES, PLAN_MAX_DEPTH)
    errors = []
    if not _check_keys(plan, "$", PLAN_KEYS, errors):
        raise ValidationError(errors)

    _check_const(plan.get("formatId"), PLAN_FORMAT_ID, "$.formatId", errors)
    if "schemaVersion" in plan and not (
        _is_int(plan["schemaVersion"]) and plan["schemaVersion"] == PLAN_SCHEMA_VERSION
    ):
        errors.append(f"wrong-value: $.schemaVersion must be {PLAN_SCHEMA_VERSION}")
    _check_const(plan.get("authorization"), PLAN_AUTHORIZATION, "$.authorization", errors)

    revision = plan.get("catalogRevision")
    if "catalogRevision" in plan:
        if not isinstance(revision, str) or not re.fullmatch(CATALOG_REVISION_PATTERN, revision):
            errors.append("wrong-type: $.catalogRevision must be 64 lowercase hex characters")
        elif revision != sha256_hex(catalog_bytes):
            errors.append("catalog-mismatch: $.catalogRevision is not the SHA-256 of the catalog file")

    target = plan.get("target")
    if "target" in plan and _check_keys(target, "$.target", PLAN_TARGET_KEYS, errors):
        _check_const(target.get("os"), trusted.TARGET_OS, "$.target.os", errors)
        _check_const(target.get("architecture"), trusted.TARGET_ARCHITECTURE, "$.target.architecture", errors)

    steps = plan.get("steps")
    if "steps" in plan:
        _validate_plan_steps(steps, catalog, errors)

    options = plan.get("options")
    if "options" in plan and _check_keys(options, "$.options", PLAN_OPTION_KEYS, errors):
        group = options.get("addInvokingUserToDockerGroup")
        if "addInvokingUserToDockerGroup" in options and not isinstance(group, bool):
            errors.append("wrong-type: $.options.addInvokingUserToDockerGroup must be a boolean")
        if group is True and isinstance(steps, list) and "docker-engine" not in steps:
            errors.append("missing-dependency: $.options.addInvokingUserToDockerGroup needs step docker-engine")

    if errors:
        raise ValidationError(errors)
    return plan, catalog


def _validate_plan_steps(steps, catalog, errors):
    if not isinstance(steps, list) or not all(isinstance(item, str) for item in steps):
        errors.append("wrong-type: $.steps must be an array of strings")
        return
    if not steps:
        errors.append("wrong-value: $.steps must not be empty")
        return
    if len(set(steps)) != len(steps):
        errors.append("duplicate-item: $.steps")
        return
    unknown = [step for step in steps if step not in STEP_IDS]
    if unknown:
        errors.append(f"unknown-step: $.steps {unknown}")
        return
    if steps != [step for step in STEP_IDS if step in steps]:
        errors.append(f"wrong-order: $.steps must follow the catalog order {list(STEP_IDS)}")
    for step_id in steps:
        for dependency in catalog_step(catalog, step_id)["dependsOn"]:
            if dependency not in steps:
                errors.append(f"missing-dependency: $.steps {step_id} needs {dependency}")
