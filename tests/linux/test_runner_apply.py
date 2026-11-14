import json
import unittest

import fake_host
from fake_host import FAKE_CATALOG, FAKE_PLAN, FAKE_REPO, FAKE_REPORT_DIR, RAW_OUTPUT_MARKER

import host as host_module
import report
import runner
import trusted

CHANGING_COMMANDS = {"apt-get", "usermod", "fetch_https"}


def with_repository(state):
    """The fake apt repository offers the archive packages and the synthetic Docker pins."""
    state.repository.update(
        {
            "ca-certificates": "20240203",
            "curl": "8.5.0-2ubuntu10.6",
            "git": "1:2.43.0-1ubuntu7.3",
            "gnupg": "2.4.4-2ubuntu17.3",
            "unattended-upgrades": "2.9.1+nmu4ubuntu1",
            **fake_host.SYNTHETIC_PINS,
        }
    )
    return state


def as_sudo(state, answer="huu-server-01"):
    state.euid = 0
    state.sudo_user = "huu"
    state.answers = [answer]
    return state


def apply(state, plan_args=("--apply",)):
    host = fake_host.make_host(state)
    return runner.main(
        ["--plan", FAKE_PLAN, "--report-dir", FAKE_REPORT_DIR, *plan_args],
        host=host,
        catalog_path=FAKE_CATALOG,
        repo_root=FAKE_REPO,
    )


def saved_report(state):
    return json.loads(state.files[f"{FAKE_REPORT_DIR}/{report.REPORT_JSON_NAME}"])


def statuses(result):
    return {step["id"]: step["status"] for step in result["steps"]}


def changing_calls(state):
    return [call for call in state.calls if call[0] in CHANGING_COMMANDS]


def system_writes(state):
    return [path for path, _ in state.written if not path.startswith(FAKE_REPORT_DIR + "/")]


class RefusalTests(unittest.TestCase):
    def assert_unchanged(self, state):
        self.assertEqual(changing_calls(state), [])
        self.assertEqual(system_writes(state), [])

    def test_without_root_apply_is_refused(self):
        state = with_repository(fake_host.fresh_ubuntu())
        state.answers = ["huu-server-01"]
        self.assertEqual(apply(state), runner.EXIT_REFUSED)
        self.assertIn("sudo", "\n".join(state.shown))
        self.assertEqual(state.calls, [])
        self.assert_unchanged(state)

    def test_without_terminal_apply_is_refused(self):
        state = as_sudo(with_repository(fake_host.fresh_ubuntu()))
        state.tty = False
        self.assertEqual(apply(state), runner.EXIT_REFUSED)
        self.assertIn("interaktives Terminal", "\n".join(state.shown))
        self.assertEqual(state.calls, [])
        self.assert_unchanged(state)

    def test_wrong_hostname_aborts_without_change(self):
        state = as_sudo(with_repository(fake_host.fresh_ubuntu()), answer="huu-server-02")
        self.assertEqual(apply(state), runner.EXIT_REFUSED)
        self.assertIn("Hostname stimmt nicht", "\n".join(state.shown))
        self.assert_unchanged(state)

    def test_empty_or_closed_input_aborts(self):
        for answer in ["", " ", "yes", "HUU-SERVER-01"]:
            with self.subTest(answer=answer):
                state = as_sudo(with_repository(fake_host.fresh_ubuntu()), answer=answer)
                self.assertEqual(apply(state), runner.EXIT_REFUSED)
                self.assert_unchanged(state)

        state = as_sudo(with_repository(fake_host.fresh_ubuntu()))
        host = fake_host.make_host(state)

        def closed(prompt):
            raise EOFError

        code = runner.main(
            ["--plan", FAKE_PLAN, "--report-dir", FAKE_REPORT_DIR, "--apply"],
            host=host._replace(ask=closed),
            catalog_path=FAKE_CATALOG,
            repo_root=FAKE_REPO,
        )
        self.assertEqual(code, runner.EXIT_REFUSED)
        self.assert_unchanged(state)

    def test_dry_run_errors_block_apply(self):
        state = as_sudo(with_repository(fake_host.fresh_ubuntu()))
        state.packages["docker.io"] = "24.0.7-0ubuntu4"
        self.assertEqual(apply(state), runner.EXIT_FAILED)
        self.assertEqual(state.answers, ["huu-server-01"])  # never asked
        self.assert_unchanged(state)
        self.assertIn("docker.io", state.packages)

    def test_placeholder_pins_block_apply(self):
        state = as_sudo(with_repository(fake_host.fresh_ubuntu()))
        catalog = json.loads(fake_host.SYNTHETIC_CATALOG_BYTES)
        catalog["steps"][2]["packages"][4]["version"] = "UNVERIFIED-PLACEHOLDER"
        catalog_bytes = json.dumps(catalog).encode()
        plan = json.loads(state.files[FAKE_PLAN])
        plan["catalogRevision"] = runner.linux_plan.sha256_hex(catalog_bytes)
        state.files[FAKE_CATALOG] = catalog_bytes
        state.files[FAKE_PLAN] = json.dumps(plan).encode()
        self.assertEqual(apply(state), runner.EXIT_FAILED)
        self.assert_unchanged(state)


class ApplyTests(unittest.TestCase):
    def minimal_server(self):
        state = with_repository(fake_host.fresh_ubuntu())
        del state.packages["gnupg"]
        del state.packages["unattended-upgrades"]
        del state.files[trusted.AUTO_UPGRADES_PATH]
        return as_sudo(state)

    def test_full_apply_then_second_run_does_nothing(self):
        state = self.minimal_server()
        self.assertEqual(apply(state), runner.EXIT_OK)
        result = saved_report(state)
        self.assertEqual(result["mode"], "apply")
        self.assertEqual(result["result"], "succeeded")
        self.assertEqual(set(statuses(result).values()), {"succeeded"})

        # Resulting state is exactly the fixed target state.
        self.assertEqual(state.files[trusted.DOCKER_KEY_PATH], fake_host.GOOD_KEY)
        self.assertEqual(state.files[trusted.DOCKER_SOURCES_PATH], trusted.DOCKER_SOURCES_CONTENT.encode())
        self.assertEqual(state.files[trusted.AUTO_UPGRADES_PATH], trusted.AUTO_UPGRADES_CONTENT.encode())
        for name, version in fake_host.SYNTHETIC_PINS.items():
            self.assertEqual(state.packages[name], version)
        self.assertIn((trusted.DOCKER_KEY_PATH, 0o644), state.written)
        self.assertIn((trusted.DOCKER_KEYRING_DIR, 0o755), state.written)
        self.assertNotIn("/etc/apt/apt.conf.d/50unattended-upgrades", system_writes(state))

        # Idempotence: second apply finds nothing to do and changes nothing.
        state.calls.clear()
        state.written.clear()
        state.answers = ["huu-server-01"]
        self.assertEqual(apply(state), runner.EXIT_OK)
        self.assertEqual(changing_calls(state), [])
        self.assertEqual(system_writes(state), [])
        self.assertEqual(state.answers, ["huu-server-01"])  # no confirmation needed
        self.assertEqual(set(statuses(saved_report(state)).values()), {"already-satisfied"})

        # And a plain dry-run as normal user says the same.
        state.euid = 1000
        state.sudo_user = None
        self.assertEqual(apply(state, plan_args=()), runner.EXIT_OK)
        result = saved_report(state)
        self.assertEqual(result["result"], "no-changes")
        self.assertEqual(set(statuses(result).values()), {"already-satisfied"})

    def test_report_has_versions_before_and_after(self):
        state = self.minimal_server()
        apply(state)
        engine = next(step for step in saved_report(state)["steps"] if step["id"] == "docker-engine")
        self.assertIsNone(engine["before"]["docker-ce"])
        self.assertEqual(engine["after"]["docker-ce"], "5:0.0.1-1~synthetic")
        base = next(step for step in saved_report(state)["steps"] if step["id"] == "base-tools")
        self.assertIsNone(base["before"]["gnupg"])
        self.assertEqual(base["after"]["gnupg"], "2.4.4-2ubuntu17.3")

    def test_apt_is_called_with_fixed_arguments_and_exact_docker_pins(self):
        state = self.minimal_server()
        apply(state)
        apt_calls = [call for call in state.calls if call[0] == "apt-get"]
        for call in apt_calls:
            self.assertFalse(any(item.startswith(("--allow", "--force")) for item in call), call)
        docker_install = [call for call in apt_calls if "docker-ce=5:0.0.1-1~synthetic" in call]
        self.assertEqual(len(docker_install), 1)
        self.assertEqual(
            docker_install[0][5:],
            [f"{name}={version}" for name, version in fake_host.SYNTHETIC_PINS.items()],
        )

    def test_report_contains_no_raw_output(self):
        state = self.minimal_server()
        state.downloaded_key = None
        apply(state)
        for name in (report.REPORT_JSON_NAME, report.REPORT_TEXT_NAME):
            self.assertNotIn(RAW_OUTPUT_MARKER, state.files[f"{FAKE_REPORT_DIR}/{name}"].decode())

    def test_fingerprint_mismatch_aborts_without_change(self):
        state = self.minimal_server()
        state.packages["gnupg"] = "2.4.4-2ubuntu17.3"  # base-tools satisfied, repository is the first change
        state.downloaded_key = fake_host.fake_key("A" * 40)
        self.assertEqual(apply(state), runner.EXIT_FAILED)
        result = saved_report(state)
        self.assertEqual(statuses(result)["docker-apt-repository"], "failed")
        step = next(step for step in result["steps"] if step["id"] == "docker-apt-repository")
        self.assertIn("Fingerprint", step["reason"])
        self.assertIn("nichts geändert", step["reason"])
        self.assertEqual(system_writes(state), [])
        self.assertNotIn(trusted.DOCKER_KEY_PATH, state.files)
        self.assertNotIn(trusted.DOCKER_SOURCES_PATH, state.files)
        self.assertEqual([call for call in state.calls if call[0] == "apt-get"], [])

    def test_additional_key_in_download_is_rejected(self):
        state = self.minimal_server()
        state.downloaded_key = fake_host.fake_key(trusted.DOCKER_KEY_FINGERPRINT, "B" * 40)
        self.assertEqual(apply(state), runner.EXIT_FAILED)
        self.assertNotIn(trusted.DOCKER_KEY_PATH, state.files)

    def test_failure_in_step_two_skips_the_rest(self):
        state = self.minimal_server()
        state.downloaded_key = None  # network failure while loading the key
        self.assertEqual(apply(state), runner.EXIT_FAILED)
        result = saved_report(state)
        self.assertEqual(result["result"], "failed")
        self.assertEqual(
            statuses(result),
            {
                "base-tools": "succeeded",
                "docker-apt-repository": "failed",
                "docker-engine": "skipped",
                "unattended-upgrades": "skipped",
            },
        )
        self.assertNotIn("docker-ce", state.packages)
        self.assertNotIn("unattended-upgrades", state.packages)
        # No rollback: the successful first step stays.
        self.assertIn("gnupg", state.packages)

    def test_failing_apt_command_is_reported_as_failed(self):
        state = self.minimal_server()
        state.failing_commands.add("apt-get")
        self.assertEqual(apply(state), runner.EXIT_FAILED)
        result = saved_report(state)
        self.assertEqual(statuses(result)["base-tools"], "failed")
        self.assertIn("Exit-Code 100", result["steps"][0]["reason"])
        self.assertTrue(any(RAW_OUTPUT_MARKER in text for text in state.shown))  # terminal only

    def test_success_needs_the_detected_state_not_only_exit_code(self):
        state = self.minimal_server()
        state.failing_commands.add(("systemctl", "is-active", "docker.service"))
        self.assertEqual(apply(state), runner.EXIT_FAILED)
        result = saved_report(state)
        step = next(step for step in result["steps"] if step["id"] == "docker-engine")
        self.assertEqual(step["status"], "failed")
        self.assertIn("Nachprüfung", step["reason"])
        self.assertEqual(statuses(result)["unattended-upgrades"], "skipped")

    def test_no_reboot_and_no_removal(self):
        state = self.minimal_server()
        apply(state)
        for call in state.calls:
            self.assertNotIn(call[0], {"reboot", "shutdown", "systemctl reboot"})
            self.assertNotIn("remove", call)
            self.assertNotIn("purge", call)


class DockerGroupApplyTests(unittest.TestCase):
    def test_sudo_user_is_added_with_warning(self):
        state = as_sudo(with_repository(fake_host.configured_ubuntu("valid-docker-group.json")))
        self.assertEqual(apply(state), runner.EXIT_OK)
        self.assertIn(["usermod", "--append", "--groups", "docker", "huu"], state.calls)
        result = saved_report(state)
        self.assertEqual(statuses(result)["docker-group"], "succeeded")
        self.assertEqual(result["warnings"], [report.DOCKER_GROUP_WARNING])
        self.assertIn("erneutem Anmelden", "\n".join(state.shown))

    def test_root_as_sudo_user_blocks_apply(self):
        state = as_sudo(with_repository(fake_host.configured_ubuntu("valid-docker-group.json")))
        state.sudo_user = "root"
        self.assertEqual(apply(state), runner.EXIT_FAILED)
        self.assertEqual(changing_calls(state), [])

    def test_option_false_never_touches_groups(self):
        state = as_sudo(with_repository(fake_host.fresh_ubuntu()))
        apply(state)
        self.assertFalse(any(call[0] == "usermod" for call in state.calls))


class RealHostSafetyTests(unittest.TestCase):
    """Checks of linux/host.py that need no network and change nothing."""

    def test_fetch_refuses_other_scheme_host_or_port_before_connecting(self):
        for url in [
            "http://download.docker.com/linux/ubuntu/gpg",
            "https://example.invalid/linux/ubuntu/gpg",
            "https://download.docker.com.example.invalid/gpg",
            "https://download.docker.com:8443/linux/ubuntu/gpg",
        ]:
            with self.subTest(url=url):
                with self.assertRaises(OSError):
                    host_module.fetch_https(url, trusted.DOCKER_KEY_HOST, 1024)

    def test_run_rejects_shell_strings(self):
        with self.assertRaises(ValueError):
            host_module.run("apt-get update")

    def test_run_does_not_inherit_environment(self):
        result = host_module.run(["env"])
        names = sorted(line.split("=", 1)[0] for line in result.stdout.splitlines())
        self.assertEqual(names, ["LANG", "LC_ALL", "PATH"])


if __name__ == "__main__":
    unittest.main()
