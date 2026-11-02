from __future__ import annotations

import unittest
from pathlib import Path

import yaml


ROOT = Path(__file__).resolve().parents[1]


class IOSAppStructureTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls) -> None:
        cls.spec = yaml.safe_load((ROOT / "GuanpanFApp/project.yml").read_text(encoding="utf-8"))
        cls.app_source = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
        cls.views = (ROOT / "GuanpanFApp/Sources/HomeExperience.swift").read_text(encoding="utf-8")
        cls.nas_client = (ROOT / "GuanpanFApp/Sources/FNASConnection.swift").read_text(encoding="utf-8")

    def test_project_has_app_and_ui_test_target(self) -> None:
        targets = self.spec["targets"]
        self.assertEqual(targets["GuanpanF"]["type"], "application")
        self.assertEqual(targets["GuanpanFAppUITests"]["type"], "bundle.ui-testing")
        self.assertIn({"target": "GuanpanF"}, targets["GuanpanFAppUITests"]["dependencies"])
        self.assertEqual(targets["GuanpanFAppUITests"]["settings"]["base"]["TEST_TARGET_NAME"], "GuanpanF")

    def test_app_scheme_runs_ui_test_target(self) -> None:
        self.assertIn("GuanpanFAppUITests", self.spec["schemes"]["GuanpanF"]["test"]["targets"])

    def test_primary_tabs_have_separate_destinations(self) -> None:
        for label in ("首页", "行情", "AI顾问", "真实资产", "设置"):
            self.assertIn(f'Label("{label}"', self.app_source)
        self.assertIn("MarketOverview(model: model)", self.app_source)
        self.assertIn("AdvisorOverview(model: model)", self.app_source)
        self.assertIn("RealAssetsOverview(model: model)", self.app_source)
        self.assertIn("SettingsOverview(model: model)", self.app_source)

    def test_advisor_input_and_context_states_are_visible(self) -> None:
        self.assertIn("TextField(", self.views)
        self.assertIn('Label(model.isAskingAdvisor ? "分析中" : "发送"', self.views)
        self.assertIn("model.portfolioContextLabel", self.views)
        self.assertIn('accessibilityIdentifier("advisor.ai-key-status")', self.views)
        self.assertIn('accessibilityIdentifier("advisor.context.nas-research")', self.views)
        self.assertIn("历史Quant研究摘要暂不可用", self.app_source)
        self.assertIn('Section("可选同步与数据服务")', self.views)
        self.assertIn('LabeledContent("新闻最近状态", value: model.newsStatus)', self.views)
        self.assertIn("尚未填写 NAS 地址，连接测试还没有开始。", self.views)

    def test_app_only_reads_the_real_ledger_snapshot(self) -> None:
        app_sources = "\n".join(path.read_text(encoding="utf-8") for path in
                                  (ROOT / "GuanpanFApp/Sources").glob("*.swift"))
        self.assertIn("readLedgerSnapshot", app_sources)
        self.assertNotIn("confirmUserFill", app_sources)
        self.assertNotIn("applyConfirmedFill", app_sources)

    def test_nas_connection_has_no_token_setup_and_readiness_is_read_only(self) -> None:
        self.assertNotIn("FNASKeychain", self.nas_client)
        self.assertNotIn('forHTTPHeaderField: "X-Api-Key"', self.nas_client)
        self.assertIn('components.path = "/readyz"', self.nas_client)
        self.assertIn("try await FNASReadinessClient.check", self.app_source)
        self.assertNotIn("settings.nas.token", self.views)


if __name__ == "__main__":
    unittest.main()
