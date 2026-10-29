import Foundation

struct FNewsArticle: Codable, Equatable, Sendable, Identifiable {
    var id: String { url }
    let title: String
    let summary: String?
    let publisher: String
    let url: String
    let publishedAt: Date
    let relatedSecurities: [FNewsSecurityReference]
}

struct FNewsSecurityReference: Codable, Equatable, Sendable {
    let code: String
    let name: String
}

struct FNewsFeed: Sendable {
    let provider: String
    let fetchedAt: Date
    let articles: [FNewsArticle]

    func articlesAssociated(with securityCode: String) -> [FNewsArticle] {
        articles.filter { $0.relatedSecurities.contains { $0.code == securityCode } }
    }
}

enum FNewsClient {
    // This is a public web endpoint used by Tonghuashun's 7×24 page, not a
    // contracted/licensed API. Keep the provenance visible and fail closed if
    // its response contract changes.
    static let providerName = "同花顺财经 7×24 新闻（公开网页接口）"
    private static let endpointString = "https://news.10jqka.com.cn/tapp/news/push/stock/"
    private static let maximumAge: TimeInterval = 24 * 60 * 60
    private static let maximumResponseBytes = 1_000_000
    private static let maximumArticles = 40

    static func fetchLatest(now: Date = Date()) async throws -> FNewsFeed {
        guard let endpoint = URL(string: endpointString),
              var components = URLComponents(url: endpoint, resolvingAgainstBaseURL: false) else {
            throw FNewsError.invalidFeedURL
        }
        components.queryItems = [
            URLQueryItem(name: "page", value: "1"),
            URLQueryItem(name: "tag", value: ""),
            URLQueryItem(name: "track", value: "website"),
            URLQueryItem(name: "pagesize", value: "40")
        ]
        guard let url = components.url else { throw FNewsError.invalidFeedURL }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("application/json, text/plain, */*", forHTTPHeaderField: "Accept")
        request.setValue("https://news.10jqka.com.cn/realtimenews.html", forHTTPHeaderField: "Referer")
        request.setValue("XMLHttpRequest", forHTTPHeaderField: "X-Requested-With")
        request.setValue("GuanpanMax/1.0", forHTTPHeaderField: "User-Agent")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FNewsError.invalidFeed }
        guard (200..<300).contains(http.statusCode) else { throw FNewsError.httpStatus(http.statusCode) }
        guard data.count <= maximumResponseBytes else { throw FNewsError.feedTooLarge }
        guard let root = try? JSONSerialization.jsonObject(with: data) as? [String: Any],
              scalar(root["code"]) == "200",
              let payload = root["data"] as? [String: Any],
              let rawItems = payload["list"] as? [[String: Any]] else {
            throw FNewsError.invalidFeed
        }

        let cutoff = now.addingTimeInterval(-maximumAge)
        var seen = Set<String>()
        let articles = rawItems.compactMap { item -> FNewsArticle? in
            guard let title = (item["title"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  !title.isEmpty,
                  let rawURL = (item["url"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                  let link = URL(string: rawURL), link.scheme?.lowercased() == "https",
                  let publishedAt = parseTimestamp(item["ctime"]),
                  publishedAt >= cutoff, publishedAt <= now,
                  seen.insert(link.absoluteString).inserted else { return nil }

            let references = (item["stock"] as? [[String: Any]] ?? []).compactMap { stock -> FNewsSecurityReference? in
                guard let codeValue = stock["stockCode"],
                      let name = (stock["name"] as? String)?.trimmingCharacters(in: .whitespacesAndNewlines),
                      !name.isEmpty else { return nil }
                let rawCode = scalar(codeValue)
                guard !rawCode.isEmpty, rawCode.count <= 6, rawCode.allSatisfy(\.isNumber) else { return nil }
                let code = String(repeating: "0", count: 6 - rawCode.count) + rawCode
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
        return FNewsFeed(provider: providerName, fetchedAt: now, articles: Array(articles))
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
        let formatter = ISO8601DateFormatter()
        return formatter.date(from: text)
    }
}

private enum FNewsError: LocalizedError {
    case invalidFeedURL, httpStatus(Int), feedTooLarge, invalidFeed

    var errorDescription: String? {
        switch self {
        case .invalidFeedURL: return "同花顺新闻查询地址无效"
        case .httpStatus(let status): return "同花顺新闻源 HTTP \(status)"
        case .feedTooLarge: return "同花顺新闻响应超出大小限制"
        case .invalidFeed: return "同花顺新闻接口响应格式变化或字段不完整"
        }
    }
}

struct FNewsEvidencePayload: Codable {
    let note: String
    let fetchedAt: Date
    let articles: [FNewsArticle]
}
