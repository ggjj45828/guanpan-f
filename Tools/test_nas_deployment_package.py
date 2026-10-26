from __future__ import annotations

import sys
import tempfile
import unittest
import zipfile
import subprocess
from pathlib import Path

import yaml

sys.path.insert(0, str(Path(__file__).resolve().parent))
from build_nas_deployment_package import build_package


class NASDeploymentPackageTests(unittest.TestCase):
    def setUp(self) -> None:
        self.temporary = tempfile.TemporaryDirectory()
        self.package = Path(self.temporary.name) / "nas.zip"
        build_package(self.package)
        self.archive = zipfile.ZipFile(self.package)
        self.names = set(self.archive.namelist())

    def tearDown(self) -> None:
        self.archive.close()
        self.temporary.cleanup()

    def test_compose_and_dockerfile_are_at_project_root(self) -> None:
        self.assertIn("compose.yml", self.names)
        self.assertIn("Dockerfile", self.names)
        self.assertIn("nas/fminute/server.py", self.names)
        self.assertIn("nas/docker-entrypoint.sh", self.names)
        self.assertNotIn("nas/compose.yml", self.names)
        self.assertNotIn("nas/Dockerfile", self.names)

    def test_package_contains_importable_python_packages(self) -> None:
        self.assertIn("nas/__init__.py", self.names)
        self.assertIn("nas/fminute/__init__.py", self.names)
        with tempfile.TemporaryDirectory() as extracted:
            self.archive.extractall(extracted)
            subprocess.run(
                [sys.executable, "-c", "import nas.fminute.server; import nas.fminute.runtime"],
                cwd=extracted, check=True, capture_output=True, text=True,
            )

    def test_compose_build_paths_resolve_from_project_root(self) -> None:
        compose = yaml.safe_load(self.archive.read("compose.yml"))
        self.assertEqual(compose["name"], "guanpan-f")
        build = compose["services"]["f-minute-archive"]["build"]
        self.assertEqual(build, {"context": ".", "dockerfile": "Dockerfile"})

    def test_data_volume_has_persistent_project_relative_default(self) -> None:
        compose = yaml.safe_load(self.archive.read("compose.yml"))
        volume = compose["services"]["f-minute-archive"]["volumes"][0]
        self.assertEqual(volume, "${F_MINUTE_DATA_DIR:-./data}:/data")

    def test_api_token_and_security_list_remain_explicit_requirements(self) -> None:
        compose = self.archive.read("compose.yml").decode("utf-8")
        self.assertIn("${F_MINUTE_API_TOKEN:?", compose)
        self.assertIn("${F_MINUTE_SECURITIES:?", compose)
        example = self.archive.read(".env.example").decode("utf-8")
        self.assertIn("F_MINUTE_DATA_DIR=./data", example)
        deploy_doc = self.archive.read("DEPLOYMENT.md").decode("utf-8")
        self.assertIn("guanpan-f", deploy_doc)

    def test_package_excludes_python_bytecode(self) -> None:
        self.assertFalse(any("__pycache__" in name or name.endswith(".pyc")
                             for name in self.names))

    def test_data_permission_bootstrap_drops_to_service_user(self) -> None:
        dockerfile = self.archive.read("Dockerfile").decode("utf-8")
        entrypoint = self.archive.read("nas/docker-entrypoint.sh").decode("utf-8")
        self.assertIn("setpriv --reuid=10001 --regid=10001 --clear-groups", entrypoint)
        self.assertIn("chown 10001:10001 /data", entrypoint)
        self.assertEqual(entrypoint.splitlines()[0], "#!/bin/sh")
        self.assertNotIn("\r", entrypoint)
        self.assertIn('ENTRYPOINT ["/usr/local/bin/f-minute-entrypoint"]', dockerfile)
        self.assertIn("head -n 1 /usr/local/bin/f-minute-entrypoint | grep -qx '#!/bin/sh'", dockerfile)


if __name__ == "__main__":
    unittest.main()
