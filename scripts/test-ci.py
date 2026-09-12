"""Exercise the private runner's commit gate against an isolated Git history."""

import os
from pathlib import Path
import subprocess
import tempfile
import unittest


GATE = Path(__file__).resolve().parents[1] / "ci/private-build/validate-trusted-commit.sh"


class TrustedCommitTests(unittest.TestCase):
    def setUp(self):
        self.directory = tempfile.TemporaryDirectory(prefix="hello-mini-ci-test-")
        self.addCleanup(self.directory.cleanup)
        self.repo = Path(self.directory.name)
        self.environment = {
            **os.environ,
            "GIT_CONFIG_GLOBAL": os.devnull,
            "GIT_CONFIG_NOSYSTEM": "1",
        }
        self.git("init", "--quiet", "--initial-branch=main")
        self.git("config", "user.name", "CI Test")
        self.git("config", "user.email", "ci-test@example.invalid")
        self.git("commit", "--quiet", "--allow-empty", "-m", "First trusted commit")
        self.first = self.git("rev-parse", "HEAD")
        self.git("commit", "--quiet", "--allow-empty", "-m", "Latest trusted commit")
        self.latest = self.git("rev-parse", "HEAD")
        self.git("update-ref", "refs/remotes/origin/main", self.latest)
        self.git("checkout", "--quiet", "-b", "unmerged")
        self.git("commit", "--quiet", "--allow-empty", "-m", "Untrusted change")
        self.unmerged = self.git("rev-parse", "HEAD")

    def git(self, *arguments):
        return subprocess.run(
            ["git", "-C", str(self.repo), *arguments], check=True,
            capture_output=True, text=True, env=self.environment,
        ).stdout.strip()

    def gate(self, revision):
        return subprocess.run(
            ["bash", str(GATE), str(self.repo), revision],
            capture_output=True, text=True, env=self.environment,
        )

    def test_empty_input_resolves_remote_main(self):
        result = self.gate("")
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.latest)

    def test_older_commit_on_main_is_allowed(self):
        result = self.gate(self.first)
        self.assertEqual(result.returncode, 0, result.stderr)
        self.assertEqual(result.stdout.strip(), self.first)

    def test_unmerged_commit_is_rejected(self):
        self.assertNotEqual(self.gate(self.unmerged).returncode, 0)

    def test_refs_and_shell_text_are_rejected(self):
        for revision in ["main", "refs/pull/1/head", "--help", "$(touch unwanted)", "a" * 41]:
            with self.subTest(revision=revision):
                self.assertNotEqual(self.gate(revision).returncode, 0)
        self.assertFalse((self.repo / "unwanted").exists())

    def test_nonexistent_commit_is_rejected(self):
        self.assertNotEqual(self.gate("0" * 40).returncode, 0)


if __name__ == "__main__":
    unittest.main()
