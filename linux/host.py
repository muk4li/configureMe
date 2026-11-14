"""Access to the real system, bundled so tests can swap it for a fake.

Every function the runner uses to look at or change the machine lives in
the namespace returned by real_host(). Tests build the same namespace with
fake functions (tests/linux/fake_host.py), so no test touches the system.

Rules for running commands:
- argv is always a fixed list of strings, never a shell string;
- subprocess never uses shell=True;
- the environment is a small fixed set, nothing is inherited;
- stdin is closed (or carries fixed bytes), so no command can wait for input.
"""

import collections
import datetime
import os
import pwd
import socket
import ssl
import subprocess
import sys
import tempfile
import urllib.error
import urllib.parse
import urllib.request

SAFE_PATH = "/usr/sbin:/usr/bin:/sbin:/bin"
DEFAULT_TIMEOUT_SECONDS = 120

CommandResult = collections.namedtuple("CommandResult", ["returncode", "stdout", "stderr"])

# A plain record of functions; no behaviour of its own.
Host = collections.namedtuple(
    "Host",
    [
        "run",
        "read_file",
        "list_dir",
        "write_file",
        "geteuid",
        "stdio_is_tty",
        "hostname",
        "sudo_user",
        "current_user_name",
        "user_uid",
        "python_version",
        "ask",
        "show",
        "utc_now",
        "fetch_https",
        "make_dir",
    ],
)


def run(argv, extra_env=None, timeout=DEFAULT_TIMEOUT_SECONDS, input_bytes=None):
    """Run one command with a fixed argument list and capture its output.

    input_bytes, if given, is passed on stdin; otherwise stdin is closed.
    """
    if not isinstance(argv, list) or not argv or not all(isinstance(item, str) for item in argv):
        raise ValueError("argv must be a non-empty list of strings")
    env = {"PATH": SAFE_PATH, "LANG": "C.UTF-8", "LC_ALL": "C.UTF-8"}
    env.update(extra_env or {})
    try:
        completed = subprocess.run(
            argv,
            shell=False,
            input=input_bytes,
            stdin=subprocess.DEVNULL if input_bytes is None else None,
            capture_output=True,
            env=env,
            timeout=timeout,
            check=False,
        )
    except FileNotFoundError:
        return CommandResult(127, "", f"{argv[0]}: command not found")
    except subprocess.TimeoutExpired:
        return CommandResult(124, "", f"{argv[0]}: timeout after {timeout} s")
    return CommandResult(
        completed.returncode,
        completed.stdout.decode("utf-8", "replace"),
        completed.stderr.decode("utf-8", "replace"),
    )


def read_file(path):
    """Return the file bytes, or None if the file does not exist."""
    try:
        with open(path, "rb") as handle:
            return handle.read()
    except FileNotFoundError:
        return None


def list_dir(path):
    try:
        return sorted(os.listdir(path))
    except FileNotFoundError:
        return []


def write_file(path, data, mode):
    """Write bytes atomically: temporary file in the same directory, then rename.

    os.replace swaps the directory entry, so an existing symlink at path is
    replaced and never followed.
    """
    directory = os.path.dirname(path) or "."
    descriptor, temporary = tempfile.mkstemp(dir=directory, prefix=".configureme-")
    try:
        with os.fdopen(descriptor, "wb") as handle:
            os.fchmod(handle.fileno(), mode)
            handle.write(data)
            handle.flush()
            os.fsync(handle.fileno())
        os.replace(temporary, path)
    except BaseException:
        if os.path.exists(temporary):
            os.unlink(temporary)
        raise


class _NoRedirect(urllib.request.HTTPRedirectHandler):
    """Refuse every redirect, so the download can never move to another host."""

    def redirect_request(self, req, fp, code, msg, headers, newurl):
        raise urllib.error.HTTPError(req.full_url, code, "Weiterleitung abgelehnt", headers, fp)


def fetch_https(url, allowed_host, max_bytes, timeout=30):
    """Download a small file over HTTPS with certificate and hostname checks.

    Only https:// on exactly allowed_host is accepted; redirects are refused.
    Raises OSError (including urllib errors) on any problem.
    """
    parts = urllib.parse.urlsplit(url)
    if parts.scheme != "https" or parts.hostname != allowed_host or parts.port not in (None, 443):
        raise OSError(f"URL nicht erlaubt: {url}")
    context = ssl.create_default_context()  # verifies certificate and hostname
    opener = urllib.request.build_opener(urllib.request.HTTPSHandler(context=context), _NoRedirect)
    request = urllib.request.Request(url, headers={"User-Agent": "configureMe-linux-runner"})
    with opener.open(request, timeout=timeout) as response:
        if response.status != 200:
            raise OSError(f"HTTP {response.status}")
        final = urllib.parse.urlsplit(response.geturl())
        if final.scheme != "https" or final.hostname != allowed_host:
            raise OSError("Antwort von unerwartetem Host")
        data = response.read(max_bytes + 1)
    if len(data) > max_bytes:
        raise OSError(f"Datei größer als {max_bytes} Byte")
    return data


def make_dir(path, mode):
    """Create one directory with the given mode if it does not exist yet."""
    try:
        os.mkdir(path, mode)
    except FileExistsError:
        if not os.path.isdir(path) or os.path.islink(path):
            raise
        return
    os.chmod(path, mode)  # mkdir mode is reduced by the umask


def user_uid(name):
    """Return the UID of a local user, or None if the user does not exist."""
    try:
        return pwd.getpwnam(name).pw_uid
    except KeyError:
        return None


def current_user_name():
    try:
        return pwd.getpwuid(os.getuid()).pw_name
    except KeyError:
        return None


def stdio_is_tty():
    return sys.stdin.isatty() and sys.stdout.isatty()


def utc_now():
    return datetime.datetime.now(datetime.timezone.utc).replace(microsecond=0).isoformat()


def real_host():
    """Namespace with the real system functions (see module docstring)."""
    return Host(
        run=run,
        read_file=read_file,
        list_dir=list_dir,
        write_file=write_file,
        geteuid=os.geteuid,
        stdio_is_tty=stdio_is_tty,
        hostname=socket.gethostname,
        sudo_user=lambda: os.environ.get("SUDO_USER"),
        current_user_name=current_user_name,
        user_uid=user_uid,
        python_version=lambda: tuple(sys.version_info[:2]),
        ask=input,
        show=print,
        utc_now=utc_now,
        fetch_https=fetch_https,
        make_dir=make_dir,
    )
