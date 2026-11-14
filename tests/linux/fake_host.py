"""Synthetic Ubuntu 24.04 machine for runner tests.

Everything here is fake: package database, files, groups and command
output are plain Python data. No test runs a real system command.
"""

import types

from linux_test_paths import FIXTURES, REPO_ROOT

import host as host_module
import trusted

RUNNER_FIXTURES = REPO_ROOT / "tests" / "fixtures" / "linux-runner"
SYNTHETIC_CATALOG_BYTES = (FIXTURES / "catalog.synthetic.json").read_bytes()

FAKE_REPO = "/fake/configureMe"
FAKE_CATALOG = f"{FAKE_REPO}/linux/catalog.json"
FAKE_PLAN = f"{FAKE_REPO}/linux/plans/test.json"
FAKE_REPORT_DIR = "/fake/report"
FAKE_COMMIT = "0123456789abcdef0123456789abcdef01234567"
# Text that only appears in raw command output; it must never reach a report.
RAW_OUTPUT_MARKER = "RAW-OUTPUT-MARKER"

OS_RELEASE_NOBLE = (
    'PRETTY_NAME="Ubuntu 24.04.1 LTS"\nNAME="Ubuntu"\nVERSION_ID="24.04"\n'
    "VERSION_CODENAME=noble\nID=ubuntu\nID_LIKE=debian\n"
)

# Synthetic pins of tests/fixtures/linux-plan-v1/catalog.synthetic.json.
SYNTHETIC_PINS = {
    "docker-ce": "5:0.0.1-1~synthetic",
    "docker-ce-cli": "5:0.0.1-1~synthetic",
    "containerd.io": "0.0.1-1~synthetic",
    "docker-buildx-plugin": "0.0.1-1~synthetic",
    "docker-compose-plugin": "0.0.1-1~synthetic",
}


def fake_key(*fingerprints):
    """Bytes the fake gpg understands as a key file with these primary keys."""
    return ("FAKE-KEY:" + ",".join(fingerprints)).encode("ascii")


GOOD_KEY = fake_key(trusted.DOCKER_KEY_FINGERPRINT)


def fresh_ubuntu(plan_fixture="valid-full.json"):
    """State of a fresh Ubuntu Server 24.04 install (server seed: git, curl, gnupg, unattended-upgrades)."""
    files = {
        "/etc/os-release": OS_RELEASE_NOBLE.encode(),
        "/etc/apt/apt.conf.d/50unattended-upgrades": (RUNNER_FIXTURES / "50unattended-upgrades.noble").read_bytes(),
        "/etc/apt/apt.conf.d/20auto-upgrades": (RUNNER_FIXTURES / "20auto-upgrades.noble").read_bytes(),
        "/etc/apt/apt.conf.d/01autoremove": b'APT { NeverAutoRemove { "^linux-.*"; }; };\n',
        FAKE_CATALOG: SYNTHETIC_CATALOG_BYTES,
        FAKE_PLAN: (FIXTURES / plan_fixture).read_bytes(),
        f"{FAKE_REPO}/.git/HEAD": (FAKE_COMMIT + "\n").encode(),
    }
    return types.SimpleNamespace(
        files=files,
        packages={
            "ca-certificates": "20240203",
            "curl": "8.5.0-2ubuntu10.6",
            "git": "1:2.43.0-1ubuntu7.3",
            "gnupg": "2.4.4-2ubuntu17.3",
            "unattended-upgrades": "2.9.1+nmu4ubuntu1",
        },
        groups={"sudo": ["huu"]},
        users={"root": 0, "huu": 1000},
        architecture="amd64",
        python=(3, 12),
        euid=1000,
        sudo_user=None,
        current_user="huu",
        tty=True,
        hostname="huu-server-01",
        answers=[],
        calls=[],
        shown=[],
        written=[],
        # Filled by apply tests: what the fake apt repository can install.
        repository={},
        failing_commands=set(),
        downloaded_key=GOOD_KEY,
    )


def configured_ubuntu(plan_fixture="valid-full.json"):
    """Fresh state after a successful run of the full plan."""
    state = fresh_ubuntu(plan_fixture)
    state.files[trusted.DOCKER_KEY_PATH] = GOOD_KEY
    state.files[trusted.DOCKER_SOURCES_PATH] = trusted.DOCKER_SOURCES_CONTENT.encode()
    state.packages.update(SYNTHETIC_PINS)
    state.groups["docker"] = []
    return state


def make_host(state):
    """Host namespace (see linux/host.py) backed by the fake state."""

    def run(argv, extra_env=None, timeout=None, input_bytes=None):
        state.calls.append(list(argv))
        assert isinstance(argv, list) and all(isinstance(item, str) for item in argv)
        name = argv[0]
        if tuple(argv) in state.failing_commands or name in state.failing_commands:
            return host_module.CommandResult(100, RAW_OUTPUT_MARKER, RAW_OUTPUT_MARKER + " E: failure")
        if name == "dpkg" and argv[1:] == ["--print-architecture"]:
            return host_module.CommandResult(0, state.architecture + "\n", "")
        if name == "dpkg" and argv[1] == "--compare-versions":
            # Good enough for the synthetic versions used in the tests.
            assert argv[3] == "gt"
            return host_module.CommandResult(0 if argv[2] > argv[4] else 1, "", "")
        if name == "dpkg-query":
            return _dpkg_query(state, argv)
        if name == "gpg":
            return _gpg(state, argv, input_bytes)
        if name == "getent" and argv[1] == "group":
            members = state.groups.get(argv[2])
            if members is None:
                return host_module.CommandResult(2, "", "")
            return host_module.CommandResult(0, f"{argv[2]}:x:999:{','.join(members)}\n", "")
        if name == "systemctl" and argv[1:] == ["is-active", "docker.service"]:
            active = "docker-ce" in state.packages
            return host_module.CommandResult(0 if active else 3, "active\n" if active else "inactive\n", "")
        if name == "apt-get":
            return _apt_get(state, argv, extra_env or {})
        if name == "usermod":
            return _usermod(state, argv)
        return host_module.CommandResult(127, "", f"{name}: not in fake")

    def read_file(path):
        return state.files.get(path)

    def list_dir(path):
        prefix = path.rstrip("/") + "/"
        return sorted({key[len(prefix):] for key in state.files if key.startswith(prefix) and "/" not in key[len(prefix):]})

    def write_file(path, data, mode):
        state.written.append((path, mode))
        state.files[path] = bytes(data)

    return host_module.Host(
        run=run,
        read_file=read_file,
        list_dir=list_dir,
        write_file=write_file,
        geteuid=lambda: state.euid,
        stdio_is_tty=lambda: state.tty,
        hostname=lambda: state.hostname,
        sudo_user=lambda: state.sudo_user,
        current_user_name=lambda: state.current_user,
        user_uid=lambda name: state.users.get(name),
        python_version=lambda: state.python,
        ask=lambda prompt: state.answers.pop(0) if state.answers else "",
        show=lambda text: state.shown.append(text),
        utc_now=lambda: "2026-11-14T12:00:00+00:00",
    )


def _dpkg_query(state, argv):
    names = [item for item in argv[1:] if not item.startswith("-")]
    lines = []
    for name in names:
        if name in state.packages:
            lines.append(f"{name}\tii \t{state.packages[name]}")
    code = 0 if len(lines) == len(names) else 1
    return host_module.CommandResult(code, "\n".join(lines) + ("\n" if lines else ""), RAW_OUTPUT_MARKER if code else "")


def _gpg(state, argv, data):
    assert argv[-2:] == ["--show-keys", "--with-colons"] and "--homedir" in argv
    if data is None or not data.startswith(b"FAKE-KEY:"):
        return host_module.CommandResult(2, "", RAW_OUTPUT_MARKER + " gpg: no valid OpenPGP data found")
    lines = []
    for fingerprint in data[len(b"FAKE-KEY:"):].decode().split(","):
        lines.append(f"pub:-:4096:1:{fingerprint[-16:]}:1487788586:::-:::scESC::::::23::0:")
        lines.append(f"fpr:::::::::{fingerprint}:")
        lines.append("uid:-::::1487792064::0000::Synthetic Test Key::::::::::0:")
        lines.append("sub:-:4096:1:7EA0A9C3F273FCD8:1487788586::::::s::::::23:")
        lines.append("fpr:::::::::D3306A018370199E527AE7997EA0A9C3F273FCD8:")
    return host_module.CommandResult(0, "\n".join(lines) + "\n", "")


def _apt_get(state, argv, env):
    assert env.get("DEBIAN_FRONTEND") == "noninteractive"
    assert not any(item.startswith("--allow") or item.startswith("--force") for item in argv)
    if argv[1:] == ["update"]:
        return host_module.CommandResult(0, RAW_OUTPUT_MARKER, "")
    assert argv[1:3] == ["install", "--yes"], argv
    for item in argv[3:]:
        name, _, version = item.partition("=")
        available = state.repository.get(name)
        if available is None or (version and version != available):
            return host_module.CommandResult(100, "", RAW_OUTPUT_MARKER + f" E: no candidate {item}")
    for item in argv[3:]:
        name, _, version = item.partition("=")
        state.packages[name] = state.repository[name]
        if name == "docker-ce":
            state.groups.setdefault("docker", [])
    return host_module.CommandResult(0, RAW_OUTPUT_MARKER, "")


def _usermod(state, argv):
    assert argv[1:4] == ["--append", "--groups", "docker"], argv
    user = argv[4]
    if "docker" not in state.groups:
        return host_module.CommandResult(6, "", "usermod: group 'docker' does not exist")
    state.groups["docker"].append(user)
    return host_module.CommandResult(0, "", "")
