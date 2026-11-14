"""Make linux/ importable for the tests (python3 -m unittest discover -s tests/linux)."""

import pathlib
import sys

REPO_ROOT = pathlib.Path(__file__).resolve().parents[2]
LINUX_DIR = REPO_ROOT / "linux"
FIXTURES = REPO_ROOT / "tests" / "fixtures" / "linux-plan-v1"

if str(LINUX_DIR) not in sys.path:
    sys.path.insert(0, str(LINUX_DIR))
