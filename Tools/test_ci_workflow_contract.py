from pathlib import Path
import ast
import unittest


ROOT = Path(__file__).resolve().parents[1]


class CIWorkflowContractTests(unittest.TestCase):
    def test_repository_python_tests_are_discoverable_by_unittest(self):
        invisible_tests = []
        for path in (ROOT / "Tools").glob("test_*.py"):
            tree = ast.parse(path.read_text(encoding="utf-8"), filename=str(path))
            invisible_tests.extend(
                f"{path.name}:{node.lineno}"
                for node in tree.body
                if isinstance(node, (ast.FunctionDef, ast.AsyncFunctionDef)) and
                node.name.startswith("test_")
            )
        self.assertEqual(invisible_tests, [],
                         "Top-level test functions are skipped by unittest discovery")

    def test_python_nas_changes_trigger_complete_python_test_job(self):
        workflow = (ROOT / ".github/workflows/f-python-nas.yml").read_text(encoding="utf-8")
        for expected in ["'nas/**'", "'Tools/**'", "'GuanpanFApp/**'",
                         "runs-on: ubuntu-latest", "python-version: '3.12'",
                         "python -m pip install --disable-pip-version-check PyYAML",
                         "python -m unittest discover -s Tools -p 'test_*.py'",
                         "python -m compileall -q nas Tools",
                         "python Tools/verify_architecture_boundaries.py"]:
            self.assertIn(expected, workflow)

    def test_continuation_doc_preserves_core_product_redlines(self):
        continuation = (ROOT / "CONTINUATION.md").read_text(encoding="utf-8")
        for requirement in ["never write the real Ledger", "must not synchronously wait for NAS",
                            "Regime confidence is not a price-direction probability",
                            "Limit GitHub Actions to at most two running workflows at once.",
                            "Do not commit or push."]:
            self.assertIn(requirement, continuation)

    def test_ios_workflow_tests_core_builds_both_destinations_and_exports_screenshots(self):
        workflow = (ROOT / ".github/workflows/guanpan-advisor-ios.yml").read_text(encoding="utf-8")
        for expected in ["'GuanpanFApp/**'", "runs-on: macos-15", "swift test",
                         "xcodegen generate --spec project.yml", "generic/platform=iOS",
                         "generic/platform=iOS Simulator", "xcodebuild test",
                         "xcrun xcresulttool export attachments"]:
            self.assertIn(expected, workflow)

    def test_ci_workflows_limit_running_builds_to_one_per_workflow(self):
        for name in ("f-python-nas.yml", "guanpan-advisor-ios.yml"):
            workflow = (ROOT / ".github/workflows" / name).read_text(encoding="utf-8")
            self.assertIn("concurrency:", workflow)
            self.assertIn("group: guanpan-f-${{ github.workflow }}", workflow)
            self.assertIn("cancel-in-progress: false", workflow)


if __name__ == "__main__":
    unittest.main()
