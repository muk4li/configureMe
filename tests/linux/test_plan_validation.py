import json
import unittest

from linux_test_paths import FIXTURES, LINUX_DIR

import linux_plan
import trusted

SYNTHETIC_CATALOG = (FIXTURES / "catalog.synthetic.json").read_bytes()
REAL_CATALOG = (LINUX_DIR / "catalog.json").read_bytes()


def rejected_codes(plan_bytes, catalog_bytes=SYNTHETIC_CATALOG):
    try:
        linux_plan.validate_plan_bytes(plan_bytes, catalog_bytes)
    except linux_plan.ValidationError as error:
        return error.codes()
    return None


class FixtureTests(unittest.TestCase):
    def test_valid_fixtures_are_accepted(self):
        files = sorted(FIXTURES.glob("valid-*.json"))
        self.assertGreaterEqual(len(files), 3)
        for path in files:
            with self.subTest(path.name):
                plan, _ = linux_plan.validate_plan_bytes(path.read_bytes(), SYNTHETIC_CATALOG)
                self.assertEqual(plan["formatId"], "configureme/linux-plan")

    def test_invalid_fixtures_are_rejected_with_expected_code(self):
        expected = json.loads((FIXTURES / "expected-errors.json").read_text())
        files = sorted(path.name for path in FIXTURES.glob("invalid-*.json"))
        self.assertEqual(files, sorted(expected))
        for name in files:
            with self.subTest(name):
                codes = rejected_codes((FIXTURES / name).read_bytes())
                self.assertIsNotNone(codes, f"{name} was accepted")
                self.assertIn(expected[name], codes)

    def test_fixtures_are_bound_to_the_synthetic_catalog_only(self):
        # The synthetic pins must never validate against the real catalog.
        codes = rejected_codes((FIXTURES / "valid-full.json").read_bytes(), REAL_CATALOG)
        self.assertEqual(codes, ["catalog-mismatch"])


class RealPlanTests(unittest.TestCase):
    def test_huu_server_01_plan_matches_real_catalog(self):
        plan_bytes = (LINUX_DIR / "plans" / "huu-server-01.json").read_bytes()
        plan, _ = linux_plan.validate_plan_bytes(plan_bytes, REAL_CATALOG)
        self.assertEqual(plan["catalogRevision"], linux_plan.sha256_hex(REAL_CATALOG))
        self.assertEqual(plan["steps"], list(linux_plan.STEP_IDS))
        # Owner decision 3 (2026-11-14): no docker group for huu-server-01.
        self.assertIs(plan["options"]["addInvokingUserToDockerGroup"], False)

    def test_plan_files_use_lf_only(self):
        for path in [LINUX_DIR / "catalog.json", *sorted((LINUX_DIR / "plans").glob("*.json"))]:
            with self.subTest(path.name):
                self.assertNotIn(b"\r", path.read_bytes())


class LimitTests(unittest.TestCase):
    def padded(self, size):
        base = (FIXTURES / "valid-full.json").read_bytes().rstrip(b"\n")
        return base[:-1] + b" " * (size - len(base)) + b"}"

    def test_plan_at_size_limit_is_accepted(self):
        data = self.padded(linux_plan.PLAN_MAX_BYTES)
        self.assertEqual(len(data), linux_plan.PLAN_MAX_BYTES)
        self.assertIsNone(rejected_codes(data))

    def test_plan_over_size_limit_is_rejected(self):
        data = self.padded(linux_plan.PLAN_MAX_BYTES + 1)
        self.assertEqual(rejected_codes(data), ["too-large"])

    def test_deep_nesting_is_rejected_before_parsing(self):
        data = b"[" * 5000 + b"]" * 5000
        self.assertEqual(rejected_codes(data[: linux_plan.PLAN_MAX_BYTES]), ["too-deep"])

    def test_brackets_inside_strings_do_not_count(self):
        self.assertEqual(linux_plan.nesting_depth('{"a": "[[[[[[\\"{{{{"}'), 1)

    def test_non_utf8_is_rejected(self):
        self.assertEqual(rejected_codes(b'{"formatId": "\xff"}'), ["invalid-encoding"])


def edited_catalog(change):
    catalog = json.loads(SYNTHETIC_CATALOG)
    change(catalog)
    return json.dumps(catalog).encode()


def catalog_codes(catalog_bytes):
    try:
        linux_plan.validate_catalog_bytes(catalog_bytes)
    except linux_plan.ValidationError as error:
        return error.codes()
    return None


class CatalogTests(unittest.TestCase):
    def test_real_and_synthetic_catalogs_are_valid(self):
        self.assertIsNone(catalog_codes(REAL_CATALOG))
        self.assertIsNone(catalog_codes(SYNTHETIC_CATALOG))

    def test_changed_fingerprint_is_untrusted(self):
        def change(catalog):
            catalog["sources"]["docker-apt-repository"]["keyFingerprint"] = "0" * 40

        self.assertEqual(catalog_codes(edited_catalog(change)), ["untrusted-source"])

    def test_changed_repository_uri_is_untrusted(self):
        def change(catalog):
            catalog["sources"]["docker-apt-repository"]["uri"] = "https://example.invalid/linux/ubuntu"

        self.assertEqual(catalog_codes(edited_catalog(change)), ["untrusted-source"])

    def test_number_instead_of_boolean_is_untrusted(self):
        def change(catalog):
            catalog["sources"]["ubuntu-archive"]["pinned"] = 0

        self.assertEqual(catalog_codes(edited_catalog(change)), ["untrusted-source"])

    def test_extra_package_is_rejected(self):
        def change(catalog):
            catalog["steps"][0]["packages"].append({"name": "netcat-openbsd"})

        self.assertIn("wrong-value", catalog_codes(edited_catalog(change)))

    def test_pin_on_ubuntu_archive_package_is_rejected(self):
        def change(catalog):
            catalog["steps"][0]["packages"][0]["version"] = "1.0"

        self.assertIn("unknown-field", catalog_codes(edited_catalog(change)))

    def test_missing_docker_pin_is_rejected(self):
        def change(catalog):
            del catalog["steps"][2]["packages"][0]["version"]

        self.assertIn("missing-field", catalog_codes(edited_catalog(change)))

    def test_version_range_is_not_a_pin(self):
        for bad in [">= 5:1.0", "5:*", "", "latest", "5:1.0 -o APT::x=1"]:
            with self.subTest(bad):

                def change(catalog, bad=bad):
                    catalog["steps"][2]["packages"][0]["version"] = bad

                self.assertIn("invalid-pin", catalog_codes(edited_catalog(change)))

    def test_dependency_on_later_step_is_rejected(self):
        def change(catalog):
            catalog["steps"][0]["dependsOn"] = ["docker-engine"]

        self.assertIn("invalid-dependency", catalog_codes(edited_catalog(change)))

    def test_unknown_step_field_is_rejected(self):
        def change(catalog):
            catalog["steps"][1]["command"] = "curl"

        self.assertIn("unknown-field", catalog_codes(edited_catalog(change)))

    def test_reordered_steps_are_rejected(self):
        def change(catalog):
            catalog["steps"].reverse()

        self.assertIn("wrong-value", catalog_codes(edited_catalog(change)))

    def test_placeholder_pins_are_reported(self):
        catalog = linux_plan.validate_catalog_bytes(SYNTHETIC_CATALOG)
        self.assertEqual(linux_plan.placeholder_pins(catalog), [])

        def change(catalog):
            catalog["steps"][2]["packages"][1]["version"] = linux_plan.PIN_PLACEHOLDER

        catalog = linux_plan.validate_catalog_bytes(edited_catalog(change))
        self.assertEqual(linux_plan.placeholder_pins(catalog), ["docker-engine/docker-ce-cli"])

    def test_catalog_package_names_match_trusted_code(self):
        catalog = linux_plan.validate_catalog_bytes(REAL_CATALOG)
        for step in catalog["steps"]:
            names = tuple(package["name"] for package in step["packages"])
            self.assertEqual(names, trusted.STEP_PACKAGES[step["id"]])


if __name__ == "__main__":
    unittest.main()
