import ast
import json
import pathlib
import unittest

import fake_host
from fake_host import FAKE_CATALOG, FAKE_PLAN, FAKE_REPO, FAKE_REPORT_DIR, RAW_OUTPUT_MARKER
from linux_test_paths import FIXTURES, LINUX_DIR

import detect
import report
import runner
import trusted

# Commands that only read state. A dry-run may run nothing else.
READ_ONLY_COMMANDS = {"dpkg", "dpkg-query", "gpg", "getent", "systemctl"}


def dry_run(state, extra_args=()):
    host = fake_host.make_host(state)
    code = runner.main(
        ["--plan", FAKE_PLAN, "--report-dir", FAKE_REPORT_DIR, *extra_args],
        host=host,
        catalog_path=FAKE_CATALOG,
        repo_root=FAKE_REPO,
    )
    saved = state.files.get(f"{FAKE_REPORT_DIR}/{report.REPORT_JSON_NAME}")
    return code, json.loads(saved) if saved else None


def statuses(result):
    return {step["id"]: step["status"] for step in result["steps"]}


class DryRunTests(unittest.TestCase):
    def assert_nothing_changed(self, state):
        written = [path for path, _ in state.written]
        self.assertTrue(all(path.startswith(FAKE_REPORT_DIR + "/") for path in written), written)
        for argv in state.calls:
            self.assertIn(argv[0], READ_ONLY_COMMANDS, argv)

    def test_fresh_server_lists_pending_changes_without_changing_anything(self):
        state = fake_host.fresh_ubuntu()
        code, result = dry_run(state)
        self.assertEqual(code, runner.EXIT_OK)
        self.assertEqual(result["mode"], "dry-run")
        self.assertEqual(result["result"], "changes-pending")
        self.assertEqual(
            statuses(result),
            {
                "base-tools": "already-satisfied",
                "docker-apt-repository": "would-change",
                "docker-engine": "would-change",
                "unattended-upgrades": "already-satisfied",
            },
        )
        self.assert_nothing_changed(state)
        self.assertEqual(state.euid, 1000)  # no root needed

    def test_every_step_has_a_reason(self):
        _, result = dry_run(fake_host.fresh_ubuntu())
        for step in result["steps"]:
            self.assertTrue(step["reason"], step["id"])
        engine = next(step for step in result["steps"] if step["id"] == "docker-engine")
        self.assertIn("docker-ce fehlt → 5:0.0.1-1~synthetic", engine["reason"])

    def test_configured_server_has_nothing_to_do(self):
        state = fake_host.configured_ubuntu()
        code, result = dry_run(state)
        self.assertEqual(code, runner.EXIT_OK)
        self.assertEqual(result["result"], "no-changes")
        self.assertEqual(set(statuses(result).values()), {"already-satisfied"})
        self.assert_nothing_changed(state)

    def test_report_identifies_runner_plan_catalog_and_target(self):
        _, result = dry_run(fake_host.fresh_ubuntu())
        self.assertEqual(result["formatId"], "configureme/linux-runner-report")
        self.assertEqual(result["runner"]["commit"], fake_host.FAKE_COMMIT)
        plan_bytes = (FIXTURES / "valid-full.json").read_bytes()
        self.assertEqual(result["plan"]["sha256"], runner.linux_plan.sha256_hex(plan_bytes))
        self.assertEqual(result["plan"]["file"], "test.json")
        self.assertEqual(result["catalog"]["sha256"], runner.linux_plan.sha256_hex(fake_host.SYNTHETIC_CATALOG_BYTES))
        self.assertEqual(result["target"], {"hostname": "huu-server-01"})
        base = next(step for step in result["steps"] if step["id"] == "base-tools")
        self.assertEqual(base["before"]["git"], "1:2.43.0-1ubuntu7.3")

    def test_report_contains_no_raw_output_or_environment(self):
        state = fake_host.fresh_ubuntu()
        dry_run(state)
        for name in (report.REPORT_JSON_NAME, report.REPORT_TEXT_NAME):
            text = state.files[f"{FAKE_REPORT_DIR}/{name}"].decode()
            self.assertNotIn(RAW_OUTPUT_MARKER, text)
            self.assertNotIn("PATH", text)
            self.assertNotIn("SUDO_USER", text)
        self.assertEqual(
            set(json.loads(state.files[f"{FAKE_REPORT_DIR}/{report.REPORT_JSON_NAME}"])),
            {"formatId", "schemaVersion", "mode", "createdAt", "runner", "plan", "catalog", "target",
             "preflight", "options", "warnings", "steps", "result"},
        )

    def test_text_report_is_printed(self):
        state = fake_host.fresh_ubuntu()
        dry_run(state)
        printed = "\n".join(state.shown)
        self.assertIn("Dry-Run (keine Änderung)", printed)
        self.assertIn("[würde ändern] docker-engine", printed)
        self.assertIn("[bereits erfüllt] base-tools", printed)


class PreflightTests(unittest.TestCase):
    def assert_preflight_fails(self, state, check):
        code, result = dry_run(state)
        self.assertEqual(code, runner.EXIT_FAILED)
        self.assertEqual(result["result"], "failed")
        failed = [item["check"] for item in result["preflight"] if item["status"] == "failed"]
        self.assertEqual(failed, [check])
        self.assertEqual(set(statuses(result).values()), {"skipped"})

    def test_wrong_ubuntu_release(self):
        state = fake_host.fresh_ubuntu()
        state.files["/etc/os-release"] = b'ID=ubuntu\nVERSION_ID="22.04"\nVERSION_CODENAME=jammy\n'
        self.assert_preflight_fails(state, "operating-system")

    def test_not_ubuntu(self):
        state = fake_host.fresh_ubuntu()
        state.files["/etc/os-release"] = b'ID=debian\nVERSION_ID="12"\nVERSION_CODENAME=bookworm\n'
        self.assert_preflight_fails(state, "operating-system")

    def test_missing_os_release(self):
        state = fake_host.fresh_ubuntu()
        del state.files["/etc/os-release"]
        self.assert_preflight_fails(state, "operating-system")

    def test_wrong_architecture(self):
        state = fake_host.fresh_ubuntu()
        state.architecture = "arm64"
        self.assert_preflight_fails(state, "architecture")

    def test_old_python(self):
        state = fake_host.fresh_ubuntu()
        state.python = (3, 11)
        self.assert_preflight_fails(state, "python-version")

    def test_invalid_plan_is_rejected_before_any_command(self):
        state = fake_host.fresh_ubuntu("invalid-missing-dependency.json")
        code, result = dry_run(state)
        self.assertEqual(code, runner.EXIT_FAILED)
        self.assertIn("missing-dependency", result["preflight"][0]["detail"])
        self.assertEqual(state.calls, [])

    def test_missing_plan_file(self):
        state = fake_host.fresh_ubuntu()
        del state.files[FAKE_PLAN]
        code, result = dry_run(state)
        self.assertEqual(code, runner.EXIT_FAILED)
        self.assertIn("nicht gefunden", result["preflight"][0]["detail"])

    def test_placeholder_pins_are_refused(self):
        state = fake_host.fresh_ubuntu()
        catalog = json.loads(fake_host.SYNTHETIC_CATALOG_BYTES)
        catalog["steps"][2]["packages"][0]["version"] = "UNVERIFIED-PLACEHOLDER"
        catalog_bytes = json.dumps(catalog).encode()
        plan = json.loads(state.files[FAKE_PLAN])
        plan["catalogRevision"] = runner.linux_plan.sha256_hex(catalog_bytes)
        state.files[FAKE_CATALOG] = catalog_bytes
        state.files[FAKE_PLAN] = json.dumps(plan).encode()
        code, result = dry_run(state)
        self.assertEqual(code, runner.EXIT_FAILED)
        self.assertIn("UNVERIFIED-PLACEHOLDER", result["preflight"][0]["detail"])
        self.assertEqual(state.calls, [])


class StepDetectionTests(unittest.TestCase):
    def step(self, state, step_id):
        _, result = dry_run(state)
        return next(step for step in result["steps"] if step["id"] == step_id), result

    def test_missing_base_tool_would_be_installed(self):
        state = fake_host.fresh_ubuntu()
        del state.packages["gnupg"]
        step, _ = self.step(state, "base-tools")
        self.assertEqual(step["status"], "would-change")
        self.assertIn("gnupg", step["reason"])

    def test_conflicting_package_is_an_error_and_not_removed(self):
        state = fake_host.fresh_ubuntu()
        state.packages["docker.io"] = "24.0.7-0ubuntu4"
        state.packages["podman-docker"] = "4.9.3"
        step, result = self.step(state, "docker-engine")
        self.assertEqual(step["status"], "failed")
        self.assertIn("docker.io", step["reason"])
        self.assertIn("podman-docker", step["reason"])
        self.assertEqual(result["result"], "failed")
        self.assertIn("docker.io", state.packages)

    def test_conflict_list_follows_docker_documentation(self):
        self.assertEqual(
            set(trusted.DOCKER_CONFLICTING_PACKAGES),
            {"docker.io", "docker-compose", "docker-compose-v2", "docker-doc", "docker-buildx", "podman-docker", "containerd", "runc"},
        )

    def test_other_docker_version_would_change(self):
        state = fake_host.configured_ubuntu()
        state.packages["docker-ce"] = "5:0.0.0-1~synthetic"
        step, _ = self.step(state, "docker-engine")
        self.assertEqual(step["status"], "would-change")
        self.assertIn("docker-ce 5:0.0.0-1~synthetic → 5:0.0.1-1~synthetic", step["reason"])

    def test_newer_docker_version_than_pin_blocks(self):
        state = fake_host.configured_ubuntu()
        state.packages["docker-compose-plugin"] = "0.0.2-1~synthetic"
        step, _ = self.step(state, "docker-engine")
        self.assertEqual(step["status"], "failed")
        self.assertIn("Downgrade nur manuell", step["reason"])

    def test_inactive_docker_service_is_reported(self):
        state = fake_host.configured_ubuntu()
        state.failing_commands.add(("systemctl", "is-active", "docker.service"))
        step, _ = self.step(state, "docker-engine")
        self.assertEqual(step["status"], "failed")
        self.assertIn("docker.service", step["reason"])

    def test_key_with_wrong_fingerprint_blocks(self):
        state = fake_host.configured_ubuntu()
        state.files[trusted.DOCKER_KEY_PATH] = fake_host.fake_key("0" * 40)
        step, _ = self.step(state, "docker-apt-repository")
        self.assertEqual(step["status"], "failed")
        self.assertIn("nicht genau den erwarteten Schlüssel", step["reason"])

    def test_key_file_with_additional_key_blocks(self):
        state = fake_host.configured_ubuntu()
        state.files[trusted.DOCKER_KEY_PATH] = fake_host.fake_key(trusted.DOCKER_KEY_FINGERPRINT, "1" * 40)
        step, _ = self.step(state, "docker-apt-repository")
        self.assertEqual(step["status"], "failed")

    def test_unreadable_key_blocks(self):
        state = fake_host.configured_ubuntu()
        state.files[trusted.DOCKER_KEY_PATH] = b"not a key"
        step, _ = self.step(state, "docker-apt-repository")
        self.assertEqual(step["status"], "failed")
        self.assertIn("Zustand nicht ermittelbar", step["reason"])

    def test_sources_must_be_byte_identical(self):
        state = fake_host.configured_ubuntu()
        state.files[trusted.DOCKER_SOURCES_PATH] = trusted.DOCKER_SOURCES_CONTENT.replace("\n", "\r\n").encode()
        step, _ = self.step(state, "docker-apt-repository")
        self.assertEqual(step["status"], "would-change")
        self.assertIn("abweichend", step["reason"])

    def test_legacy_docker_list_blocks(self):
        state = fake_host.fresh_ubuntu()
        state.files[trusted.DOCKER_LEGACY_LIST_PATH] = b"deb https://download.docker.com/linux/ubuntu noble stable\n"
        step, _ = self.step(state, "docker-apt-repository")
        self.assertEqual(step["status"], "failed")

    def test_ubuntu_default_unattended_config_is_security_only(self):
        state = fake_host.fresh_ubuntu()
        self.assertEqual(detect.unattended_policy_problems(fake_host.make_host(state)), [])

    def test_updates_pocket_blocks(self):
        state = fake_host.fresh_ubuntu()
        path = "/etc/apt/apt.conf.d/50unattended-upgrades"
        state.files[path] = state.files[path].replace(
            b'//\t"${distro_id}:${distro_codename}-updates";', b'\t"${distro_id}:${distro_codename}-updates";'
        )
        step, _ = self.step(state, "unattended-upgrades")
        self.assertEqual(step["status"], "failed")
        self.assertIn("-updates", step["reason"])

    def test_automatic_reboot_in_other_file_blocks(self):
        state = fake_host.fresh_ubuntu()
        state.files["/etc/apt/apt.conf.d/52local"] = b'Unattended-Upgrade::Automatic-Reboot "true";\n'
        step, _ = self.step(state, "unattended-upgrades")
        self.assertEqual(step["status"], "failed")
        self.assertIn("Automatic-Reboot", step["reason"])

    def test_disabled_auto_upgrades_would_change(self):
        state = fake_host.fresh_ubuntu()
        state.files[trusted.AUTO_UPGRADES_PATH] = (
            b'APT::Periodic::Update-Package-Lists "0";\nAPT::Periodic::Unattended-Upgrade "0";\n'
        )
        step, _ = self.step(state, "unattended-upgrades")
        self.assertEqual(step["status"], "would-change")
        self.assertIn("20auto-upgrades abweichend", step["reason"])

    def test_removed_package_with_config_counts_as_missing(self):
        state = fake_host.fresh_ubuntu()
        host = fake_host.make_host(state)
        original = host.run

        def run(argv, **kwargs):
            if argv[0] == "dpkg-query":
                return runner.host_module.CommandResult(0, "curl\trc \t8.5.0\n", "")
            return original(argv, **kwargs)

        self.assertEqual(detect.installed_versions(host._replace(run=run), ["curl"]), {"curl": None})


class DockerGroupDryRunTests(unittest.TestCase):
    def test_option_false_adds_no_step_and_no_warning(self):
        _, result = dry_run(fake_host.fresh_ubuntu())
        self.assertNotIn("docker-group", statuses(result))
        self.assertEqual(result["warnings"], [])
        self.assertEqual(result["options"], {"addInvokingUserToDockerGroup": False})

    def test_option_true_warns_and_previews_current_user(self):
        state = fake_host.configured_ubuntu("valid-docker-group.json")
        code, result = dry_run(state)
        self.assertEqual(code, runner.EXIT_OK)
        self.assertEqual(statuses(result)["docker-group"], "would-change")
        self.assertEqual(result["warnings"], [report.DOCKER_GROUP_WARNING])
        self.assertIn("root-", "\n".join(state.shown).replace("Root-", "root-"))

    def test_root_is_refused(self):
        state = fake_host.configured_ubuntu("valid-docker-group.json")
        state.current_user = "root"
        state.euid = 0
        state.sudo_user = "root"
        _, result = dry_run(state)
        self.assertEqual(statuses(result)["docker-group"], "failed")

    def test_sudo_without_sudo_user_is_refused(self):
        state = fake_host.configured_ubuntu("valid-docker-group.json")
        state.euid = 0
        _, result = dry_run(state)
        self.assertEqual(statuses(result)["docker-group"], "failed")
        step = next(step for step in result["steps"] if step["id"] == "docker-group")
        self.assertIn("SUDO_USER", step["reason"])

    def test_existing_member_is_satisfied(self):
        state = fake_host.configured_ubuntu("valid-docker-group.json")
        state.groups["docker"] = ["huu"]
        _, result = dry_run(state)
        self.assertEqual(statuses(result)["docker-group"], "already-satisfied")


class HelperTests(unittest.TestCase):
    def test_os_release_parsing(self):
        values = detect.parse_os_release('ID=ubuntu\nVERSION_ID="24.04"\n# comment\nNAME=\'Ubuntu\'\n')
        self.assertEqual(values, {"ID": "ubuntu", "VERSION_ID": "24.04", "NAME": "Ubuntu"})

    def test_primary_fingerprints_ignore_subkeys(self):
        output = (
            "pub:-:4096:1:8D81803C0EBFCD88:1:::-:::scESC::::::23::0:\n"
            "fpr:::::::::9DC858229FC7DD38854AE2D88D81803C0EBFCD88:\n"
            "sub:-:4096:1:7EA0A9C3F273FCD8:1::::::s::::::23:\n"
            "fpr:::::::::D3306A018370199E527AE7997EA0A9C3F273FCD8:\n"
        )
        self.assertEqual(detect.parse_primary_fingerprints(output), ["9DC858229FC7DD38854AE2D88D81803C0EBFCD88"])

    def test_runner_commit_from_branch_and_packed_refs(self):
        state = fake_host.fresh_ubuntu()
        host = fake_host.make_host(state)
        state.files[f"{FAKE_REPO}/.git/HEAD"] = b"ref: refs/heads/main\n"
        state.files[f"{FAKE_REPO}/.git/packed-refs"] = ("# pack-refs\n" + "a" * 40 + " refs/heads/main\n").encode()
        self.assertEqual(report.runner_commit(host, FAKE_REPO), "a" * 40)
        state.files[f"{FAKE_REPO}/.git/refs/heads/main"] = ("b" * 40 + "\n").encode()
        self.assertEqual(report.runner_commit(host, FAKE_REPO), "b" * 40)
        state.files[f"{FAKE_REPO}/.git/HEAD"] = b"ref: ../../etc/passwd\n"
        self.assertIsNone(report.runner_commit(host, FAKE_REPO))


class StaticSafetyTests(unittest.TestCase):
    def test_no_shell_execution_in_runner_code(self):
        """Every shell= keyword must be the literal False; no os.system/os.popen/eval/exec."""
        for path in sorted(pathlib.Path(LINUX_DIR).glob("*.py")):
            tree = ast.parse(path.read_text(), filename=path.name)
            for node in ast.walk(tree):
                if not isinstance(node, ast.Call):
                    continue
                with self.subTest(file=path.name, line=node.lineno):
                    for keyword in node.keywords:
                        if keyword.arg == "shell":
                            self.assertIsInstance(keyword.value, ast.Constant)
                            self.assertIs(keyword.value.value, False)
                    name = ast.unparse(node.func)
                    self.assertNotIn(name, {"os.system", "os.popen", "eval", "exec", "os.execv", "os.execvp"})

    def test_subprocess_only_in_host_module(self):
        users = [path.name for path in pathlib.Path(LINUX_DIR).glob("*.py") if "subprocess" in path.read_text()]
        self.assertEqual(users, ["host.py"])

    def test_only_standard_library_imports(self):
        allowed_local = {path.stem for path in pathlib.Path(LINUX_DIR).glob("*.py")}
        import sys

        for path in sorted(pathlib.Path(LINUX_DIR).glob("*.py")):
            for line in path.read_text().splitlines():
                stripped = line.strip()
                if stripped.startswith("import ") or stripped.startswith("from "):
                    module = stripped.split()[1].split(".")[0]
                    with self.subTest(file=path.name, module=module):
                        self.assertTrue(module in sys.stdlib_module_names or module in allowed_local, module)


if __name__ == "__main__":
    unittest.main()
