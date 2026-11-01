import Foundation

public enum FNewsFeedParseError: Error, Equatable {
    case responseTooLarge
    case invalidResponse
}

/// Parses the public Tonghuashun 7×24 JSON response into bounded, untrusted news
/// evidence. Freshness and provider identity are checked again when the feed is consumed.
public enum FNewsFeedParser {
    public static let maximumResponseBytes = 1_000_000
    private static let maximumAge: TimeInterval = 24 * 60 * 60
    private static let maximumArticles = 40

    public static func parse(_ data: Data, fetchedAt: Date) throws -> FNewsFeed {
        guard fetchedAt.timeIntervalSince1970.isFinite else { throw FNewsFeedParseError.invalidResponse }
        guard data.count <= maximumResponseBytes else { throw FNewsFeedParseError.responseTooLarge }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              scalar(root["code"]) == "200",
              let payload = root["data"] as? [String: Any],
              let rawItems = payload["list"] as? [[String: Any]] else {
            throw FNewsFeedParseError.invalidResponse
        }

        let cutoff = fetchedAt.addingTimeInterval(-maximumAge)
        var seen = Set<String>()
        let articles = rawItems.compactMap { item -> FNewsArticle? in
            guard let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty,
                  let rawURL = (item["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let components = URLComponents(string: rawURL),
                  components.scheme?.lowercased() == "https",
                  let host = components.host, !host.isEmpty,
                  components.user == nil, components.password == nil,
                  let link = components.url,
                  let publishedAt = parseTimestamp(item["ctime"]),
                  publishedAt >= cutoff, publishedAt <= fetchedAt,
                  seen.insert(link.absoluteString).inserted else { return nil }

            let references = (item["stock"] as? [[String: Any]] ?? []).compactMap { stock -> FNewsSecurityReference? in
                guard let codeValue = stock["stockCode"],
                      let name = (stock["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { return nil }
                let rawCode = scalar(codeValue)
                guard !rawCode.isEmpty, rawCode.utf8.count <= 6,
                      rawCode.utf8.allSatisfy({ (48...57).contains($0) }) else { return nil }
                let code = String(repeating: "0", count: 6 - rawCode.utf8.count) + rawCode
                return FNewsSecurityReference(code: code, name: String(name.prefix(100)))
            }
            let publisher = (item["source"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            let summary = (item["digest"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines)
            return FNewsArticle(title: String(title.prefix(300)),
                                summary: summary.flatMap { $0.isEmpty ? nil : String($0.prefix(500)) },
                                publisher: publisher.flatMap { $0.isEmpty ? nil : String($0.prefix(120)) } ?? "同花顺财经",
                                url: link.absoluteString, publishedAt: publishedAt,
                                relatedSecurities: references)
        }.prefix(maximumArticles)
        return FNewsFeed(provider: FNewsTrustPolicy.providerName, fetchedAt: fetchedAt,
                         articles: Array(articles))
    }

    private static func scalar(_ value: Any?) -> String {
        if let value = value as? String { return value }
        if let value = value as? NSNumber { return value.stringValue }
        return ""
    }

    private static func parseTimestamp(_ value: Any?) -> Date? {
        if let number = value as? NSNumber {
            let raw = number.doubleValue
            guard raw.isFinite, raw > 0 else { return nil }
            return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1_000 : raw)
        }
        guard let text = value as? String else { return nil }
        if let raw = Double(text), raw.isFinite, raw > 0 {
            return Date(timeIntervalSince1970: raw > 10_000_000_000 ? raw / 1_000 : raw)
        }
        return ISO8601DateFormatter().date(from: text)
    }
}

public enum FNewsTrustPolicy {
    public static let providerName = "同花顺财经 7×24 新闻（公开网页接口）"

    public static func isTrustedProvider(_ provider: String) -> Bool {
        provider.trimmingCharacters(in: .whitespacesAndNewlines) == providerName
    }
}

public struct FNewsArticle: Codable, Equatable, Sendable, Identifiable {
    public var id: String { url }
    public let title: String
    public let summary: String?
    public let publisher: String
    public let url: String
    public let publishedAt: Date
    public let relatedSecurities: [FNewsSecurityReference]

    public init(title: String, summary: String?, publisher: String, url: String,
                publishedAt: Date, relatedSecurities: [FNewsSecurityReference]) {
        self.title = title
        self.summary = summary
        self.publisher = publisher
        self.url = url
        self.publishedAt = publishedAt
        self.relatedSecurities = relatedSecurities
    }
}

public struct FNewsSecurityReference: Codable, Equatable, Sendable {
    public let code: String
    public let name: String

    public init(code: String, name: String) {
        self.code = code
        self.name = name
    }
}

public struct FNewsFeed: Sendable {
    public let provider: String
    public let fetchedAt: Date
    public let articles: [FNewsArticle]

    public init(provider: String, fetchedAt: Date, articles: [FNewsArticle]) {
        self.provider = provider
        self.fetchedAt = fetchedAt
        self.articles = articles
    }

    public func articlesAssociated(with securityCode: String) -> [FNewsArticle] {
        articles.filter { $0.relatedSecurities.contains { $0.code == securityCode } }
    }

    public func recent(at now: Date, maximumAge: TimeInterval = 24 * 60 * 60) -> FNewsFeed? {
        guard FNewsTrustPolicy.isTrustedProvider(provider),
              maximumAge.isFinite, maximumAge >= 0,
              now.timeIntervalSince1970.isFinite, fetchedAt.timeIntervalSince1970.isFinite,
              fetchedAt <= now, now.timeIntervalSince(fetchedAt) <= maximumAge else { return nil }
        let cutoff = now.addingTimeInterval(-maximumAge)
        var seen = Set<String>()
        let recentArticles = articles.filter { article in
            guard !article.title.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  let components = URLComponents(string: article.url),
                  components.scheme?.lowercased() == "https",
                  let host = components.host, !host.isEmpty,
                  components.user == nil, components.password == nil,
                  article.publishedAt >= cutoff, article.publishedAt <= fetchedAt,
                  let normalizedURL = components.url?.absoluteString,
                  seen.insert(normalizedURL).inserted else { return false }
            return article.relatedSecurities.allSatisfy { reference in
                reference.code.utf8.count == 6 &&
                    reference.code.utf8.allSatisfy({ (48...57).contains($0) }) &&
                    !reference.name.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
            }
        }
        guard !recentArticles.isEmpty else { return nil }
        return FNewsFeed(provider: provider, fetchedAt: fetchedAt, articles: recentArticles)
    }
}

/// A successful HTTP response with no usable articles is not sufficient reason
/// to erase a still-fresh in-memory news cache. Expired cache data is preserved
/// only as storage; normal consumers must still pass `recent(at:)`.
public enum FNewsFeedCachePolicy {
    public static func replacement(existing: FNewsFeed?, received: FNewsFeed,
                                   at now: Date) -> FNewsFeed? {
        received.recent(at: now) ?? existing
    }
}
