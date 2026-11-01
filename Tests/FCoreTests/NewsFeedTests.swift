import XCTest
@testable import FCore

final class NewsFeedTests: XCTestCase {
    func testParserNormalizesProviderTimestampsCodesAndDuplicateLinks() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let boundaryMilliseconds = NSNumber(value: (now.timeIntervalSince1970 - 24 * 60 * 60) * 1_000)
        let rows: [[String: Any]] = [
            rawArticle(" latest ", url: "https://news.example/article/1", ctime: NSNumber(value: now.timeIntervalSince1970),
                       stock: [["stockCode": 352, "name": "A500"]]),
            rawArticle("boundary", url: "https://news.example/article/2", ctime: boundaryMilliseconds),
            rawArticle("duplicate", url: "https://news.example/article/1", ctime: NSNumber(value: now.timeIntervalSince1970)),
            rawArticle("expired", url: "https://news.example/article/3",
                       ctime: NSNumber(value: now.timeIntervalSince1970 - 24 * 60 * 60 - 1)),
            rawArticle("future", url: "https://news.example/article/4",
                       ctime: NSNumber(value: now.timeIntervalSince1970 + 1)),
            rawArticle("credentials", url: "https://user:pass@news.example/article/5",
                       ctime: NSNumber(value: now.timeIntervalSince1970)),
            rawArticle("insecure", url: "http://news.example/article/6",
                       ctime: NSNumber(value: now.timeIntervalSince1970))
        ]
        let feed = try FNewsFeedParser.parse(try providerResponse(rows), fetchedAt: now)

        XCTAssertEqual(feed.articles.map(\.title), ["latest", "boundary"])
        XCTAssertEqual(feed.articles[0].relatedSecurities,
                       [FNewsSecurityReference(code: "000352", name: "A500")])
        let boundaryDelta = feed.articles[1].publishedAt.timeIntervalSince(
            now.addingTimeInterval(-24 * 60 * 60))
        XCTAssertEqual(boundaryDelta, 0, accuracy: 0.001)
        XCTAssertEqual(feed.recent(at: now)?.articles.count, 2)
    }

    func testParserCapsArticleCountAndRejectsOversizeOrInvalidResponse() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let rows = (0..<45).map { index in
            rawArticle("news-\(index)", url: "https://news.example/\(index)",
                       ctime: NSNumber(value: now.timeIntervalSince1970))
        }
        let feed = try FNewsFeedParser.parse(try providerResponse(rows), fetchedAt: now)
        XCTAssertEqual(feed.articles.count, 40)

        XCTAssertThrowsError(try FNewsFeedParser.parse(Data(repeating: 0x20, count: 1_000_001), fetchedAt: now)) {
            XCTAssertEqual($0 as? FNewsFeedParseError, .responseTooLarge)
        }
        XCTAssertThrowsError(try FNewsFeedParser.parse(Data("{}".utf8), fetchedAt: now)) {
            XCTAssertEqual($0 as? FNewsFeedParseError, .invalidResponse)
        }
    }

    func testEmptyOrExpiredResponseRetainsOnlyTheExistingCacheForNormalFreshnessChecks() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let existing = FNewsFeed(provider: FNewsTrustPolicy.providerName,
                                 fetchedAt: now.addingTimeInterval(-60),
                                 articles: [article("cached", at: now.addingTimeInterval(-60))])
        let empty = try FNewsFeedParser.parse(try providerResponse([]), fetchedAt: now)
        let replacement = FNewsFeedCachePolicy.replacement(existing: existing, received: empty, at: now)

        XCTAssertEqual(replacement?.recent(at: now)?.articles.map(\.title), ["cached"])

        let expiredResponse = FNewsFeed(provider: FNewsTrustPolicy.providerName,
            fetchedAt: now.addingTimeInterval(-25 * 60 * 60),
            articles: [article("old", at: now.addingTimeInterval(-25 * 60 * 60))])
        let retainedExpired = FNewsFeedCachePolicy.replacement(
            existing: expiredResponse, received: empty, at: now)
        XCTAssertNil(retainedExpired?.recent(at: now))
        XCTAssertNil(FNewsFeedCachePolicy.replacement(existing: nil, received: empty, at: now))
    }

    func testRecentKeepsOnlyArticlesInsideTheFreshnessWindow() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let feed = FNewsFeed(provider: FNewsTrustPolicy.providerName, fetchedAt: now, articles: [
            article("current", at: now),
            article("boundary", at: now.addingTimeInterval(-24 * 60 * 60)),
            article("expired", at: now.addingTimeInterval(-24 * 60 * 60 - 1)),
            article("future", at: now.addingTimeInterval(1))
        ])

        let recent = try XCTUnwrap(feed.recent(at: now))
        XCTAssertEqual(recent.articles.map(\.title), ["current", "boundary"])
        XCTAssertEqual(recent.fetchedAt, now)
    }

    func testRecentRejectsFutureOrExpiredFetchTime() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = article("current", at: now)
        XCTAssertNil(FNewsFeed(provider: FNewsTrustPolicy.providerName, fetchedAt: now.addingTimeInterval(1),
                               articles: [item]).recent(at: now))
        XCTAssertNil(FNewsFeed(provider: FNewsTrustPolicy.providerName, fetchedAt: now.addingTimeInterval(-24 * 60 * 60 - 1),
                               articles: [item]).recent(at: now))
    }

    func testRecentRejectsArticlesDatedAfterTheFeedFetch() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let fetchedAt = now.addingTimeInterval(-10)
        let futureArticle = article("after-fetch", at: now.addingTimeInterval(-1))
        let feed = FNewsFeed(provider: FNewsTrustPolicy.providerName, fetchedAt: fetchedAt, articles: [futureArticle])
        XCTAssertNil(feed.recent(at: now))
    }

    func testRecentRejectsEmptyAndInvalidFreshnessWindow() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let feed = FNewsFeed(provider: FNewsTrustPolicy.providerName, fetchedAt: now, articles: [article("current", at: now)])
        XCTAssertNil(feed.recent(at: now, maximumAge: -1))
        XCTAssertNil(feed.recent(at: now, maximumAge: .infinity))
        XCTAssertNil(FNewsFeed(provider: FNewsTrustPolicy.providerName, fetchedAt: now, articles: []).recent(at: now))
    }

    func testRecentRejectsUnknownProviderAndDeduplicatesArticleLinks() throws {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let item = article("current", at: now)
        XCTAssertNil(FNewsFeed(provider: "unverified-news-source", fetchedAt: now,
                               articles: [item]).recent(at: now))

        let recent = try XCTUnwrap(FNewsFeed(provider: FNewsTrustPolicy.providerName,
                                             fetchedAt: now, articles: [item, item]).recent(at: now))
        XCTAssertEqual(recent.articles.count, 1)
    }

    func testRecentRejectsUnicodeDigitsInRelatedSecurityCodes() {
        let now = Date(timeIntervalSince1970: 1_800_000_000)
        let article = FNewsArticle(title: "market update", summary: nil, publisher: "test",
            url: "https://example.invalid/news", publishedAt: now,
            relatedSecurities: [FNewsSecurityReference(code: "１２３４５６", name: "fake code")])
        let feed = FNewsFeed(provider: FNewsTrustPolicy.providerName, fetchedAt: now,
                             articles: [article])

        XCTAssertNil(feed.recent(at: now), "证券代码必须是六位ASCII数字")
    }

    private func article(_ title: String, at date: Date) -> FNewsArticle {
        FNewsArticle(title: title, summary: nil, publisher: "test",
                     url: "https://example.invalid/\(title)", publishedAt: date,
                     relatedSecurities: [])
    }

    private func rawArticle(_ title: String, url: String, ctime: Any,
                            stock: [[String: Any]] = []) -> [String: Any] {
        ["title": title, "url": url, "ctime": ctime, "stock": stock,
         "source": "publisher", "digest": "summary"]
    }

    private func providerResponse(_ rows: [[String: Any]]) throws -> Data {
        try JSONSerialization.data(withJSONObject: ["code": 200, "data": ["list": rows]])
    }
}
