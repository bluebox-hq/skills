"""Runs .github/scripts/check_plugin_version.py against throwaway repositories."""

import json
import os
import subprocess
import sys
import tempfile
import unittest
from pathlib import Path

ROOT = Path(__file__).resolve().parents[2]
SCRIPT = ROOT / ".github" / "scripts" / "check_plugin_version.py"
MANIFEST = ".claude-plugin/plugin.json"
# A git hook or `rebase --exec` exports these, and they would point every call at the outer repo.
for key in ("GIT_DIR", "GIT_WORK_TREE", "GIT_INDEX_FILE", "GIT_OBJECT_DIRECTORY", "GIT_COMMON_DIR"):
    os.environ.pop(key, None)
ENV = {**os.environ, "GIT_AUTHOR_NAME": "t", "GIT_AUTHOR_EMAIL": "t@example.com",
       "GIT_COMMITTER_NAME": "t", "GIT_COMMITTER_EMAIL": "t@example.com",
       "GIT_CONFIG_GLOBAL": os.devnull, "GIT_CONFIG_NOSYSTEM": "1"}


def manifest(version=None):
    data = {"name": "bluebox"} if version is None else {"name": "bluebox", "version": version}
    return json.dumps(data, indent=2) + "\n"


class CheckPluginVersionTest(unittest.TestCase):
    def setUp(self):
        tmp = tempfile.TemporaryDirectory()
        self.addCleanup(tmp.cleanup)
        self.repo = Path(tmp.name)
        self.git("init", "-q", "-b", "main")
        self.commit({MANIFEST: manifest("1.0.0"), "hooks/hook.sh": "echo 1\n", ".mcp.json": "{}\n",
                     "README.md": "readme\n", "skills/a/SKILL.md": "a\n"})
        self.base = self.git("rev-parse", "HEAD").strip()

    def git(self, *args):
        return subprocess.run(["git", "-C", str(self.repo), *args], check=True, capture_output=True, text=True,
                              encoding="utf-8", env=ENV, stdin=subprocess.DEVNULL).stdout

    def commit(self, files, removed=()):
        for rel, text in files.items():
            path = self.repo / rel
            path.parent.mkdir(parents=True, exist_ok=True)
            path.write_text(text, encoding="utf-8")
        for rel in removed:
            self.git("rm", "-q", rel)
        self.git("add", "-A")
        self.git("commit", "-q", "-m", "c")

    def check(self):
        head = self.git("rev-parse", "HEAD").strip()
        return subprocess.run([sys.executable, str(SCRIPT), "--repo", str(self.repo), "--base", self.base,
                               "--head", head], capture_output=True, text=True, encoding="utf-8",
                              stdin=subprocess.DEVNULL, check=False)

    def test_a_plugin_change_without_a_new_version_fails(self):
        cases = {
            "manifest": {MANIFEST: manifest("1.0.0").replace("bluebox", "bluebox-x")},
            "hook script": {"hooks/hook.sh": "echo 2\n"},
            "new hook file": {"hooks/nudges.yaml": "nudges: []\n"},
            "MCP config": {".mcp.json": '{"a": 1}\n'},
            "marketplace": {".claude-plugin/marketplace.json": "{}\n"},
        }
        for label, files in cases.items():
            with self.subTest(label):
                self.git("reset", "-q", "--hard", self.base)
                self.commit(files)
                result = self.check()
                self.assertEqual(result.returncode, 1, result.stdout)
                self.assertIn(next(iter(files)), result.stdout)

    def test_a_removed_version_fails(self):
        self.commit({MANIFEST: manifest(), "hooks/hook.sh": "echo 2\n"})
        self.assertEqual(self.check().returncode, 1)

    def test_a_removed_hook_file_without_a_new_version_fails(self):
        self.commit({}, removed=["hooks/hook.sh"])
        self.assertEqual(self.check().returncode, 1)

    def test_a_plugin_change_with_a_new_version_passes(self):
        self.commit({MANIFEST: manifest("1.0.1"), "hooks/hook.sh": "echo 2\n"})
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("1.0.0 -> 1.0.1", result.stdout)

    def test_a_first_version_passes(self):
        self.git("reset", "-q", "--hard", self.base)
        self.commit({MANIFEST: manifest()})
        self.base = self.git("rev-parse", "HEAD").strip()
        self.commit({MANIFEST: manifest("1.0.0"), "hooks/hook.sh": "echo 2\n"})
        self.assertEqual(self.check().returncode, 0)

    def test_a_change_outside_the_plugin_passes(self):
        self.commit({"README.md": "new readme\n", "skills/a/SKILL.md": "b\n"})
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout)

    def test_main_moving_ahead_is_not_counted_as_the_pull_request(self):
        self.git("checkout", "-q", "-b", "pr")
        self.commit({"README.md": "pr readme\n"})
        self.git("checkout", "-q", "main")
        self.commit({"hooks/hook.sh": "echo 3\n"})
        self.base = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", "-q", "pr")
        self.assertEqual(self.check().returncode, 0, "only the pull request's own changes count")

    def branch_off_then_bump_main(self):
        self.git("checkout", "-q", "-b", "pr")
        self.git("checkout", "-q", "main")
        self.commit({MANIFEST: manifest("2.0.0")})
        self.base = self.git("rev-parse", "HEAD").strip()
        self.git("checkout", "-q", "pr")

    def test_a_hook_change_relying_on_a_version_bump_already_on_main_fails(self):
        self.branch_off_then_bump_main()
        self.commit({"hooks/hook.sh": "echo 2\n"})
        self.assertEqual(self.check().returncode, 1)

    def test_a_new_version_equal_to_the_one_now_on_main_fails(self):
        self.branch_off_then_bump_main()
        self.commit({MANIFEST: manifest("2.0.0"), "hooks/hook.sh": "echo 2\n"})
        self.assertEqual(self.check().returncode, 1)

    def test_a_new_version_past_the_one_now_on_main_passes(self):
        self.branch_off_then_bump_main()
        self.commit({MANIFEST: manifest("2.0.1"), "hooks/hook.sh": "echo 2\n"})
        result = self.check()
        self.assertEqual(result.returncode, 0, result.stdout)
        self.assertIn("2.0.0 -> 2.0.1", result.stdout)


if __name__ == "__main__":
    unittest.main()
