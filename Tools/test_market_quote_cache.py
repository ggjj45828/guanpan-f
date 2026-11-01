from pathlib import Path
import unittest


ROOT = Path(__file__).resolve().parents[1]


class MarketQuoteCacheContractTests(unittest.TestCase):
    @classmethod
    def setUpClass(cls):
        cls.cache = (ROOT / "Sources/FCore/MarketQuoteCache.swift").read_text(encoding="utf-8")
        cls.tests = (ROOT / "Tests/FCoreTests/MarketQuoteCacheTests.swift").read_text(encoding="utf-8")
        cls.app = (ROOT / "GuanpanFApp/Sources/GuanpanFApp.swift").read_text(encoding="utf-8")
        cls.guard = (ROOT / "Sources/FAdvisor/DecisionContext.swift").read_text(encoding="utf-8")

    def test_cache_is_bounded_versioned_atomic_and_revalidates_snapshot(self):
        for contract in (
            "schemaVersion == 1",
            "maximumRecords = 250",
            "maximumRecordBytes = 512_000",
            "samples.count <= 500",
            "now.timeIntervalSince(fetchedAt) <= maximumAge",
            "try data.write(to: destination, options: .atomic)",
            "try? fileManager.removeItem(at: url)",
            "FCurrentIntradaySnapshot(securityCode: securityCode",
            "existing.quoteTimestamp > snapshot.quoteTimestamp",
            "existing.fetchedAt > snapshot.fetchedAt",
            "isRegularFile == true && values.isSymbolicLink != true",
        ):
            self.assertIn(contract, self.cache)

    def test_restored_quote_is_labeled_as_cache_and_advisor_rechecks_freshness(self):
        self.assertIn("FMarketQuoteCache(", self.app)
        self.assertIn("restoreCachedMarketQuotes(from:", self.app)
        self.assertIn("本机缓存 · 仅供离线查看", self.app)
        self.assertIn("本机离线缓存不可用", self.app)
        self.assertIn("try await marketQuoteCache.save(snapshot)", self.app)
        self.assertIn("current.quoteTimestamp > snapshot.quoteTimestamp", self.app)
        self.assertIn("current.fetchedAt >= snapshot.fetchedAt", self.app)
        self.assertIn("保留本机最近报价供离线查看", self.app)
        self.assertIn("context.freshQuote(for: code, at: now)", self.guard)
        self.assertIn("quoteTemporalMetadata.freshness(at: now) == .fresh", self.guard)

    def test_cache_acceptance_covers_corrupt_stale_and_out_of_order_cases(self):
        for test_name in (
            "testAtomicallySavedQuoteCanBeRestoredWithOriginalTimestamps",
            "testExpiredAndFutureQuotesAreNeverRestored",
            "testCorruptOrWrongVersionCacheRecordIsIgnored",
            "testLateOlderSaveCannotReplaceTheNewestQuote",
            "testLaterFetchWithOlderExchangeTimestampCannotReplaceNewerQuote",
            "testCachePrunesBeyondItsSecurityLimit",
            "testCacheIgnoresDirectoriesAndSymbolicLinksNamedLikeRecords",
        ):
            self.assertIn(test_name, self.tests)


if __name__ == "__main__":
    unittest.main()
