import Foundation
import FCore

enum FNewsClient {
    // This is a public web endpoint used by Tonghuashun's 7×24 page, not a
    // contracted/licensed API. Keep the provenance visible and fail closed if
    // its response contract changes.
    static let providerName = FNewsTrustPolicy.providerName
    private static let endpointString = "https://news.10jqka.com.cn/tapp/news/push/stock/"

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

        let (bytes, response) = try await URLSession.shared.bytes(for: request)
        guard let http = response as? HTTPURLResponse else { throw FNewsError.invalidFeed }
        guard (200..<300).contains(http.statusCode) else { throw FNewsError.httpStatus(http.statusCode) }
        if http.expectedContentLength > Int64(FNewsFeedParser.maximumResponseBytes) {
            throw FNewsError.feedTooLarge
        }
        var data = Data()
        if http.expectedContentLength > 0 {
            data.reserveCapacity(min(Int(http.expectedContentLength), FNewsFeedParser.maximumResponseBytes))
        }
        do {
            for try await byte in bytes {
                guard data.count < FNewsFeedParser.maximumResponseBytes else {
                    throw FNewsError.feedTooLarge
                }
                data.append(byte)
            }
        } catch let error as FNewsError {
            throw error
        }
        do {
            return try FNewsFeedParser.parse(data, fetchedAt: now)
        } catch FNewsFeedParseError.responseTooLarge {
            throw FNewsError.feedTooLarge
        } catch {
            throw FNewsError.invalidFeed
        }
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
