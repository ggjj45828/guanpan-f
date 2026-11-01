from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class NewsTrustContractTests(unittest.TestCase):
    def test_shared_provider_identity_and_freshness_gate_are_wired(self):
        core = (ROOT / "Sources/FCore/NewsData.swift").read_text(encoding="utf-8")
        app = (ROOT / "GuanpanFApp/Sources/FNewsClient.swift").read_text(encoding="utf-8")
        advisor = (ROOT / "Sources/FAdvisor/DecisionContext.swift").read_text(encoding="utf-8")
        parser = (ROOT / "Sources/FCore/NewsData.swift").read_text(encoding="utf-8")

        self.assertIn("FNewsTrustPolicy.providerName", app)
        self.assertIn("FNewsFeedParser.parse(data, fetchedAt: now)", app)
        self.assertIn("public enum FNewsFeedParser", parser)
        self.assertIn("publishedAt >= cutoff, publishedAt <= fetchedAt", parser)
        self.assertIn("components.user == nil, components.password == nil", parser)
        self.assertIn("FNewsTrustPolicy.isTrustedProvider(provider)", core)
        self.assertIn("components.scheme?.lowercased() == \"https\"", core)
        self.assertIn("seen.insert(normalizedURL).inserted", core)
        self.assertIn("reference.code.utf8.count == 6", core)
        self.assertIn("reference.code.utf8.allSatisfy({ (48...57).contains($0) })", core)
        self.assertIn("FNewsTrustPolicy.isTrustedProvider(source)", advisor)
        self.assertIn("nonBlank(reference ?? \"\")", advisor)

    def test_news_parser_accepts_only_ascii_security_codes(self):
        parser = (ROOT / "Sources/FCore/NewsData.swift").read_text(encoding="utf-8")
        self.assertIn("rawCode.utf8.allSatisfy({ (48...57).contains($0) })", parser)
        self.assertIn("rawCode.utf8.count", parser)
        acceptance = (ROOT / "Tests/FCoreTests/NewsFeedTests.swift").read_text(encoding="utf-8")
        self.assertIn("testRecentRejectsUnicodeDigitsInRelatedSecurityCodes", acceptance)
        self.assertIn("testParserNormalizesProviderTimestampsCodesAndDuplicateLinks", acceptance)
        self.assertIn("testParserCapsArticleCountAndRejectsOversizeOrInvalidResponse", acceptance)

    def test_news_http_body_is_bounded_while_streaming(self):
        app = (ROOT / "GuanpanFApp/Sources/FNewsClient.swift").read_text(encoding="utf-8")
        self.assertIn("URLSession.shared.bytes(for: request)", app)
        self.assertIn("FNewsFeedParser.maximumResponseBytes", app)
        self.assertIn("for try await byte in bytes", app)
        self.assertIn("throw FNewsError.feedTooLarge", app)
        self.assertNotIn("URLSession.shared.data(for: request)", app)

    def test_empty_successful_news_response_preserves_a_fresh_existing_cache(self):
        app = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
        core = (ROOT / "Sources/FCore/NewsData.swift").read_text(encoding="utf-8")
        tests = (ROOT / "Tests/FCoreTests/NewsFeedTests.swift").read_text(encoding="utf-8")
        self.assertIn("FNewsFeedCachePolicy.replacement(", app)
        self.assertIn("let priorFreshFeed = self.cachedNewsFeed?.recent(at: completedAt)", app)
        self.assertIn("新响应无有效快讯，保留原缓存", app)
        self.assertIn("received.recent(at: now) ?? existing", core)
        self.assertIn("testEmptyOrExpiredResponseRetainsOnlyTheExistingCacheForNormalFreshnessChecks", tests)
        self.assertNotIn("self.cachedNewsFeed = fetchedFeed", app)


if __name__ == "__main__":
    unittest.main()
