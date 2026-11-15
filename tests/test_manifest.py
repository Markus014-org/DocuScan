import unittest
from scripts.refresh_testflight_manifest import beta_state_ready, latest_group_build, version_key


class ManifestTests(unittest.TestCase):
    def test_version_key(self):
        self.assertGreater(version_key("1.10"), version_key("1.9"))

    def test_group_builds_only_ready(self):
        builds = [
            {"id": "early", "attributes": {"version": "8", "uploadedDate": "2026-11-15T00:00:00Z", "processingState": "VALID", "expired": False}},
            {"id": "pending", "attributes": {"version": "9", "uploadedDate": "2026-11-15T01:00:00Z", "processingState": "PROCESSING", "expired": False}},
            {"id": "expired", "attributes": {"version": "7", "uploadedDate": "2026-11-15T02:00:00Z", "processingState": "VALID", "expired": True}},
        ]
        self.assertEqual(latest_group_build(builds)["id"], "early")

    def test_beta_availability(self):
        detail = {"attributes": {"internalBuildState": "IN_BETA_TESTING", "externalBuildState": "WAITING_FOR_BETA_REVIEW"}}
        self.assertTrue(beta_state_ready(detail, True))
        self.assertFalse(beta_state_ready(detail, False))

    def test_empty(self):
        self.assertIsNone(latest_group_build([]))


if __name__ == '__main__':
    unittest.main()
