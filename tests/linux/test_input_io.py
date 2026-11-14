"""Only synthetic temporary files; no packages or system configuration."""
import tempfile
import unittest
from pathlib import Path
from unittest.mock import Mock
import linux_test_paths  # noqa: F401
import host
import runner

class InputIOTests(unittest.TestCase):
    def test_local_read_is_bounded(self):
        with tempfile.TemporaryDirectory() as directory:
            path = Path(directory) / "large.json"
            path.write_bytes(b"x" * (host.MAX_READ_BYTES + 1))
            with self.assertRaises(OSError):
                host.read_file(path)
    def test_unreadable_plan_is_controlled_not_a_traceback(self):
        fake = Mock()
        fake.read_file.side_effect = PermissionError("sensitive path")
        plan, catalog, _, _, errors = runner.load_inputs(fake, "plan", "catalog")
        self.assertIsNone(plan)
        self.assertIsNone(catalog)
        self.assertTrue(errors)
        self.assertNotIn("sensitive", str(errors))
