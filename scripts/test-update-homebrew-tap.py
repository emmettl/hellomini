"""Verify tap publication guards without network or credentials."""
import base64
import importlib.util
import json
from pathlib import Path
import unittest
from unittest.mock import patch

SPEC = importlib.util.spec_from_file_location("tap", Path(__file__).with_name("update-homebrew-tap.py"))
tap = importlib.util.module_from_spec(SPEC)
SPEC.loader.exec_module(tap)


class TapTests(unittest.TestCase):
    def test_updates_only_version_and_checksum(self):
        original = tap.TEMPLATE.read_text()
        updated = tap.updated_cask(original, "0.9.0", "a" * 64)
        self.assertIn('version "0.9.0"', updated)
        self.assertIn('sha256 "' + 'a' * 64 + '"', updated)
        self.assertIn('depends_on macos: ">= :tahoe"', updated)
        with self.assertRaises(ValueError):
            tap.updated_cask(original + '\n  version "1.0.0"', "0.9.0", "a" * 64)

    def test_unpublished_or_prerelease_never_downloads(self):
        for draft, pre in [(True, False), (False, True)]:
            with patch.object(tap, "gh", return_value=json.dumps(
                    {"tagName": "v0.8.0", "isDraft": draft, "isPrerelease": pre})) as gh:
                with self.assertRaises(ValueError):
                    tap.published_sha256("0.8.0")
                self.assertEqual(gh.call_count, 1)

    def test_published_zip_must_match_checksum(self):
        metadata = {"version": "0.8.0", "sha256": "a" * 64, "architecture": "arm64",
                    "minimumMacOS": "26.0", "notarized": True, "signing": "Developer ID Application"}
        def fake(*args, stdin=None):
            if args[:2] == ("release", "view"):
                return json.dumps({"tagName": "v0.8.0", "isDraft": False, "isPrerelease": False})
            pattern = args[args.index("--pattern") + 1]
            if pattern.endswith(".sha256"):
                return "a" * 64 + "  Hello-Mini-0.8.0-macos-arm64.zip\n"
            if pattern.endswith(".json"):
                return json.dumps(metadata)
            Path(args[args.index("--output") + 1]).write_bytes(b"wrong archive")
            return ""
        with patch.object(tap, "gh", side_effect=fake):
            with self.assertRaisesRegex(ValueError, "ZIP does not match"):
                tap.published_sha256("0.8.0")

    def test_update_is_concurrency_guarded_and_create_omits_sha(self):
        for blob in [None, "existing-sha"]:
            with patch.object(tap, "gh") as gh:
                tap.commit("cask content", blob, "0.8.0")
                body = json.loads(gh.call_args.kwargs["stdin"])
                self.assertEqual(base64.b64decode(body["content"]), b"cask content")
                self.assertEqual(body.get("sha"), blob)


if __name__ == "__main__":
    unittest.main()
