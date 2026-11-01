import XCTest
@testable import FCore

final class MarketQuoteCacheTests: XCTestCase {
    func testAtomicallySavedQuoteCanBeRestoredWithOriginalTimestamps() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let quote = try snapshot(code: "159352", at: now)
        let cache = try FMarketQuoteCache(directory: directory)

        try await cache.save(quote, now: now)
        let restored = await cache.loadAll(at: now)

        XCTAssertEqual(restored, [quote])
        XCTAssertEqual(restored.first?.quoteTimestamp, quote.quoteTimestamp)
        XCTAssertEqual(restored.first?.fetchedAt, quote.fetchedAt)
    }

    func testExpiredAndFutureQuotesAreNeverRestored() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cache = try FMarketQuoteCache(directory: directory)
        let quote = try snapshot(code: "159352", at: now)
        try await cache.save(quote, now: now)

        let expired = await cache.loadAll(at: now.addingTimeInterval(FMarketQuoteCache.maximumAge + 1))
        XCTAssertTrue(expired.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            directory.appendingPathComponent("quote-159352.json").path))
        let future = try snapshot(code: "159941", at: now.addingTimeInterval(1))
        try await cache.save(future, now: now)
        let afterFutureSave = await cache.loadAll(at: now)
        XCTAssertFalse(afterFutureSave.contains { $0.securityCode == "159941" })
    }

    func testCorruptOrWrongVersionCacheRecordIsIgnored() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let cache = try FMarketQuoteCache(directory: directory)
        try Data("{not-json".utf8).write(to: directory.appendingPathComponent("quote-159352.json"))
        let wrongVersion: [String: Any] = [
            "schemaVersion": 2,
            "securityCode": "159941",
            "samples": [["timestamp": 1_799_999_940.0, "price": 1.2, "volume": 100]],
            "quoteTimestamp": 1_799_999_940.0,
            "fetchedAt": 1_800_000_000.0,
            "source": "test-provider"
        ]
        let wrongVersionData = try JSONSerialization.data(withJSONObject: wrongVersion)
        try wrongVersionData.write(to: directory.appendingPathComponent("quote-159941.json"))

        let loaded = await cache.loadAll(at: Date(timeIntervalSince1970: 1_800_000_000))
        XCTAssertTrue(loaded.isEmpty)
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            directory.appendingPathComponent("quote-159352.json").path))
        XCTAssertFalse(FileManager.default.fileExists(atPath:
            directory.appendingPathComponent("quote-159941.json").path))
    }

    func testLateOlderSaveCannotReplaceTheNewestQuote() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cache = try FMarketQuoteCache(directory: directory)
        let older = try snapshot(code: "159352", at: now.addingTimeInterval(-10))
        let newer = try snapshot(code: "159352", at: now)

        try await cache.save(newer, now: now)
        try await cache.save(older, now: now)

        let restored = await cache.loadAll(at: now)
        XCTAssertEqual(restored.first, newer)
    }

    func testLaterFetchWithOlderExchangeTimestampCannotReplaceNewerQuote() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cache = try FMarketQuoteCache(directory: directory)
        let newerExchangeQuote = try snapshot(code: "159352", at: now.addingTimeInterval(-10))
        let delayedOldQuote = try snapshot(code: "159352", at: now,
                                           quoteTimestamp: now.addingTimeInterval(-120))

        try await cache.save(newerExchangeQuote, now: now)
        try await cache.save(delayedOldQuote, now: now)

        let restored = await cache.loadAll(at: now)
        XCTAssertEqual(restored.first, newerExchangeQuote,
                       "交易所行情时点优先于更晚的HTTP抓取时点")
    }

    func testCachePrunesBeyondItsSecurityLimit() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let cache = try FMarketQuoteCache(directory: directory)
        for index in 0...250 {
            let code = String(format: "%06d", index)
            try await cache.save(snapshot(code: code, at: now), now: now)
        }

        let restored = await cache.loadAll(at: now)
        XCTAssertLessThanOrEqual(restored.count, 250)
        XCTAssertTrue(restored.contains { $0.securityCode == "000250" })
        let files = try FileManager.default.contentsOfDirectory(atPath: directory.path)
        XCTAssertLessThanOrEqual(files.count, 250)
    }

    func testCacheIgnoresDirectoriesAndSymbolicLinksNamedLikeRecords() async throws {
        let directory = try makeTemporaryDirectory()
        defer { try? FileManager.default.removeItem(at: directory) }
        let outsideTarget = directory.deletingLastPathComponent()
            .appendingPathComponent("FMarketQuoteCacheTarget-\(UUID().uuidString)")
        defer { try? FileManager.default.removeItem(at: outsideTarget) }
        try Data("keep".utf8).write(to: outsideTarget)

        let nestedDirectory = directory.appendingPathComponent("quote-159352.json", isDirectory: true)
        try FileManager.default.createDirectory(at: nestedDirectory, withIntermediateDirectories: true)
        let symbolicLink = directory.appendingPathComponent("quote-159941.json")
        try FileManager.default.createSymbolicLink(at: symbolicLink, withDestinationURL: outsideTarget)

        let cache = try FMarketQuoteCache(directory: directory)
        let restored = await cache.loadAll(at: Date(timeIntervalSince1970: 1_800_000_000))

        XCTAssertTrue(restored.isEmpty)
        XCTAssertTrue(FileManager.default.fileExists(atPath: nestedDirectory.path))
        XCTAssertTrue(FileManager.default.fileExists(atPath: symbolicLink.path))
        XCTAssertEqual(try Data(contentsOf: outsideTarget), Data("keep".utf8))
    }

    private func makeTemporaryDirectory() throws -> URL {
        let directory = FileManager.default.temporaryDirectory
            .appendingPathComponent("FMarketQuoteCacheTests-\(UUID().uuidString)", isDirectory: true)
        try FileManager.default.createDirectory(at: directory, withIntermediateDirectories: true)
        return directory
    }

    private func snapshot(code: String, at fetchedAt: Date,
                          quoteTimestamp: Date? = nil) throws -> FCurrentIntradaySnapshot {
        let timestamp = quoteTimestamp ?? fetchedAt.addingTimeInterval(-60)
        return try FCurrentIntradaySnapshot(
            securityCode: code,
            samples: [FMinuteSample(timestamp: timestamp, price: 1.234, volume: 1_000)],
            quoteTimestamp: timestamp, fetchedAt: fetchedAt,
            source: FMarketQuoteTrustPolicy.tencentMinuteSource)
    }
}
