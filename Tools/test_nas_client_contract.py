from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class NASClientContractTests(unittest.TestCase):
    def test_legacy_history_fallback_only_runs_when_modern_route_is_missing(self):
        source = (ROOT / "GuanpanFApp/Sources/FNASConnection.swift").read_text(encoding="utf-8")
        start = source.index("    static func fetch(baseAddress: String, securityCode: String,\n                      tradingDate: Date")
        end = source.index("    private static func makeArchive", start)
        implementation = source[start:end]
        fallback_guard = "guard http.statusCode == 404 || http.statusCode == 405 else"
        self.assertIn(fallback_guard, implementation)
        self.assertLess(implementation.index(fallback_guard),
                        implementation.index("return try await fetchLegacyB("))
        self.assertIn("historyUnavailable(modernFailure ??", implementation)
        self.assertNotIn("B 兼容接口也未取得数据", implementation[:implementation.index(fallback_guard)])


if __name__ == "__main__":
    unittest.main()
