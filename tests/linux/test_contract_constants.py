"""Schema, policy and Python code must describe the same contract."""

import json
import unittest

from linux_test_paths import LINUX_DIR, REPO_ROOT

import linux_plan
import trusted

SCHEMA = json.loads((REPO_ROOT / "schemas" / "linux-plan-v1.schema.json").read_text())
POLICY = json.loads((REPO_ROOT / "contracts" / "linux-plan-v1.policy.json").read_text())


class ContractConstantTests(unittest.TestCase):
    def test_schema_matches_python_constants(self):
        properties = SCHEMA["properties"]
        self.assertIs(SCHEMA["additionalProperties"], False)
        self.assertEqual(tuple(SCHEMA["required"]), linux_plan.PLAN_KEYS)
        self.assertEqual(tuple(properties), linux_plan.PLAN_KEYS)
        self.assertEqual(properties["formatId"]["const"], linux_plan.PLAN_FORMAT_ID)
        self.assertEqual(properties["schemaVersion"]["const"], linux_plan.PLAN_SCHEMA_VERSION)
        self.assertEqual(properties["authorization"]["const"], linux_plan.PLAN_AUTHORIZATION)
        self.assertEqual(properties["catalogRevision"]["pattern"], linux_plan.CATALOG_REVISION_PATTERN)

        target = properties["target"]
        self.assertIs(target["additionalProperties"], False)
        self.assertEqual(tuple(target["required"]), linux_plan.PLAN_TARGET_KEYS)
        self.assertEqual(target["properties"]["os"]["const"], trusted.TARGET_OS)
        self.assertEqual(target["properties"]["architecture"]["const"], trusted.TARGET_ARCHITECTURE)

        steps = properties["steps"]
        self.assertEqual(tuple(steps["items"]["enum"]), linux_plan.STEP_IDS)
        self.assertIs(steps["uniqueItems"], True)
        self.assertEqual(steps["minItems"], 1)

        options = properties["options"]
        self.assertIs(options["additionalProperties"], False)
        self.assertEqual(tuple(options["required"]), linux_plan.PLAN_OPTION_KEYS)
        self.assertEqual(tuple(options["properties"]), linux_plan.PLAN_OPTION_KEYS)
        self.assertEqual(options["properties"]["addInvokingUserToDockerGroup"]["type"], "boolean")

    def test_policy_matches_python_constants(self):
        self.assertEqual(POLICY["formatId"], linux_plan.PLAN_FORMAT_ID)
        self.assertEqual(POLICY["schemaVersion"], linux_plan.PLAN_SCHEMA_VERSION)
        self.assertEqual(POLICY["maxBytes"], linux_plan.PLAN_MAX_BYTES)
        self.assertEqual(POLICY["maxBytes"], 16384)
        self.assertEqual(POLICY["maxDepth"], linux_plan.PLAN_MAX_DEPTH)
        self.assertEqual(POLICY["target"], {"os": trusted.TARGET_OS, "architecture": trusted.TARGET_ARCHITECTURE})
        self.assertTrue((REPO_ROOT / POLICY["catalogPath"]).is_file())

    def test_catalog_step_order_matches_python(self):
        catalog = json.loads((LINUX_DIR / "catalog.json").read_text())
        self.assertEqual(tuple(step["id"] for step in catalog["steps"]), linux_plan.STEP_IDS)
        self.assertEqual(tuple(trusted.STEP_PACKAGES), linux_plan.STEP_IDS)
        self.assertEqual(tuple(trusted.STEP_SOURCES), linux_plan.STEP_IDS)

    def test_fixed_docker_sources_content_matches_constants(self):
        expected = (
            "Types: deb\n"
            f"URIs: {trusted.DOCKER_REPOSITORY_URI}\n"
            f"Suites: {trusted.DOCKER_SUITE}\n"
            f"Components: {trusted.DOCKER_COMPONENTS}\n"
            f"Architectures: {trusted.TARGET_ARCHITECTURE}\n"
            f"Signed-By: {trusted.DOCKER_KEY_PATH}\n"
        )
        self.assertEqual(trusted.DOCKER_SOURCES_CONTENT, expected)
        self.assertTrue(trusted.DOCKER_KEY_URL.startswith(f"https://{trusted.DOCKER_KEY_HOST}/"))
        self.assertRegex(trusted.DOCKER_KEY_FINGERPRINT, r"^[0-9A-F]{40}$")


if __name__ == "__main__":
    unittest.main()
