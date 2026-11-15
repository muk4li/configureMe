"""Bundle manifest checks (CM-043); synthetic files only."""
import hashlib
import json
import unittest

import fake_host
from fake_host import FAKE_CATALOG, FAKE_REPO, FAKE_REPORT_DIR

import bundle_manifest
import report
import runner

COMMIT = "c" * 40
BUNDLE_PLAN = f"{FAKE_REPO}/plan.json"


def sha(data):
    return hashlib.sha256(data).hexdigest()


def make_bundle(state, mutate=None):
    """Turn the fake checkout into a fake bundle: no .git, plan.json + MANIFEST.json."""
    state.files.pop(f"{FAKE_REPO}/.git/HEAD", None)
    state.files[BUNDLE_PLAN] = state.files[fake_host.FAKE_PLAN]
    state.files[f"{FAKE_REPO}/linux/runner.py"] = b"# synthetic runner\n"
    paths = ["linux/catalog.json", "linux/runner.py", "plan.json"]
    manifest = {
        "formatId": "configureme/linux-bundle",
        "schemaVersion": 1,
        "sourceCommit": COMMIT,
        "catalogRevision": sha(state.files[FAKE_CATALOG]),
        "planSha256": sha(state.files[BUNDLE_PLAN]),
        "files": [{"path": path, "sha256": sha(state.files[f"{FAKE_REPO}/{path}"])} for path in paths],
    }
    if mutate:
        mutate(manifest)
    state.files[f"{FAKE_REPO}/MANIFEST.json"] = json.dumps(manifest).encode()
    return manifest


def run(state):
    host = fake_host.make_host(state)
    code = runner.main(["--plan", BUNDLE_PLAN, "--report-dir", FAKE_REPORT_DIR], host=host, catalog_path=FAKE_CATALOG, repo_root=FAKE_REPO)
    return code, json.loads(state.files[f"{FAKE_REPORT_DIR}/{report.REPORT_JSON_NAME}"])


def manifest_failures(result):
    return [check["detail"] for check in result["preflight"] if check["check"] == "bundle-manifest"]


class BundleManifestTests(unittest.TestCase):
    def test_valid_bundle_runs_and_reports_manifest_commit(self):
        state = fake_host.fresh_ubuntu()
        make_bundle(state)
        code, result = run(state)
        self.assertEqual(code, runner.EXIT_OK)
        self.assertEqual(result["runner"]["commit"], COMMIT)
        self.assertEqual(manifest_failures(result), [])

    def test_git_checkout_without_manifest_is_unchanged(self):
        state = fake_host.fresh_ubuntu()
        host = fake_host.make_host(state)
        self.assertEqual(bundle_manifest.verify(host, FAKE_REPO), (None, []))

    def test_changed_file_is_refused(self):
        state = fake_host.fresh_ubuntu()
        make_bundle(state)
        state.files[f"{FAKE_REPO}/linux/runner.py"] = b"# swapped\n"
        code, result = run(state)
        self.assertEqual(code, runner.EXIT_FAILED)
        self.assertIn("Datei verändert: linux/runner.py", manifest_failures(result))
        self.assertEqual(result["steps"], [])

    def test_missing_and_unlisted_files_are_refused(self):
        state = fake_host.fresh_ubuntu()
        make_bundle(state)
        del state.files[f"{FAKE_REPO}/linux/runner.py"]
        state.files[f"{FAKE_REPO}/linux/extra.py"] = b"print('x')\n"
        _, result = run(state)
        failures = manifest_failures(result)
        self.assertIn("Datei fehlt: linux/runner.py", failures)
        self.assertIn("Datei nicht im Manifest: linux/extra.py", failures)

    def test_bad_manifest_fields_are_refused(self):
        cases = {
            "path traversal": lambda m: m["files"].append({"path": "../etc/passwd", "sha256": "0" * 64}),
            "absolute path": lambda m: m["files"].append({"path": "/etc/passwd", "sha256": "0" * 64}),
            "short commit": lambda m: m.update(sourceCommit="abc"),
            "unknown field": lambda m: m.update(command="rm -rf /"),
            "wrong format": lambda m: m.update(formatId="other"),
            "bool version": lambda m: m.update(schemaVersion=True),
            "plan hash": lambda m: m.update(planSha256="0" * 64),
        }
        for name, mutate in cases.items():
            with self.subTest(name):
                state = fake_host.fresh_ubuntu()
                make_bundle(state, mutate)
                code, result = run(state)
                self.assertEqual(code, runner.EXIT_FAILED)
                self.assertTrue(manifest_failures(result), name)

    def test_duplicate_keys_are_refused(self):
        state = fake_host.fresh_ubuntu()
        make_bundle(state)
        raw = state.files[f"{FAKE_REPO}/MANIFEST.json"].decode()
        state.files[f"{FAKE_REPO}/MANIFEST.json"] = raw.replace('"schemaVersion": 1', '"schemaVersion": 1, "schemaVersion": 1').encode()
        _, result = run(state)
        self.assertTrue(manifest_failures(result))


class ToolStepTests(unittest.TestCase):
    def test_tool_steps_are_archive_packages(self):
        import linux_plan, trusted
        for step in trusted.TOOL_STEP_IDS:
            self.assertIn(step, linux_plan.STEP_IDS)
            self.assertEqual(trusted.STEP_SOURCES[step], "ubuntu-archive")
            self.assertEqual(len(trusted.STEP_PACKAGES[step]), 1)
        self.assertEqual(
            [trusted.STEP_PACKAGES[s][0] for s in trusted.TOOL_STEP_IDS],
            ["jq", "python3-venv", "htop", "tmux", "unzip", "rsync", "ncdu", "tree"],
        )


if __name__ == "__main__":
    unittest.main()


class ToolStepRunTests(unittest.TestCase):
    def plan_with_tools(self, state, tools):
        plan = json.loads(state.files[fake_host.FAKE_PLAN])
        plan["steps"] = ["base-tools", *tools]
        plan["options"]["addInvokingUserToDockerGroup"] = False
        state.files[fake_host.FAKE_PLAN] = json.dumps(plan).encode()

    def test_dry_run_and_apply_install_tools_idempotently(self):
        import test_runner_apply as apply_tests
        state = apply_tests.with_repository(fake_host.fresh_ubuntu())
        state.repository.update({"jq": "1.7.1-3build1", "tree": "2.1.1-2"})
        self.plan_with_tools(state, ["tool-jq", "tool-tree"])
        apply_tests.as_sudo(state)
        self.assertEqual(apply_tests.apply(state), runner.EXIT_OK)
        result = apply_tests.saved_report(state)
        self.assertEqual(apply_tests.statuses(result)["tool-jq"], report.SUCCEEDED)
        self.assertEqual(apply_tests.statuses(result)["tool-tree"], report.SUCCEEDED)
        self.assertEqual(state.packages["jq"], "1.7.1-3build1")
        # Second run: nothing left to do.
        state.calls.clear()
        state.euid = 1000
        code, second = run_plan(state)
        self.assertEqual(code, runner.EXIT_OK)
        self.assertEqual(second["result"], "no-changes")


def run_plan(state):
    host = fake_host.make_host(state)
    code = runner.main(["--plan", fake_host.FAKE_PLAN, "--report-dir", FAKE_REPORT_DIR], host=host, catalog_path=FAKE_CATALOG, repo_root=FAKE_REPO)
    return code, json.loads(state.files[f"{FAKE_REPORT_DIR}/{report.REPORT_JSON_NAME}"])
