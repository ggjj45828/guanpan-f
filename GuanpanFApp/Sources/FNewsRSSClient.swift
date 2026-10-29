import Foundation

struct FNewsArticle: Codable, Equatable, Sendable, Identifiable {
    var id: String { url }
    let title: String
    let publisher: String
    let url: String
    let publishedAt: Date
}

struct FNewsFeed: Sendable {
    let provider: String
    let fetchedAt: Date
    let articles: [FNewsArticle]
}

enum FNewsRSSClient {
    static let providerName = "Google News RSS 搜索聚合"
    private static let maximumAge: TimeInterval = 24 * 60 * 60

    static func fetch(securityCode: String, searchName: String?, now: Date = Date()) async throws -> FNewsFeed {
        guard securityCode.count == 6, securityCode.allSatisfy(\.isNumber) else {
            throw FNewsError.invalidSecurityCode
        }
        var components = URLComponents(string: "https://news.google.com/rss/search")!
        let terms = [searchName?.trimmingCharacters(in: .whitespacesAndNewlines), securityCode]
            .compactMap { $0 }.filter { !$0.isEmpty && $0 != securityCode }
        let query = terms.isEmpty ? "\(securityCode) ETF" : "\(terms[0]) \(securityCode) ETF"
        components.queryItems = [
            URLQueryItem(name: "q", value: query),
            URLQueryItem(name: "hl", value: "zh-CN"),
            URLQueryItem(name: "gl", value: "CN"),
            URLQueryItem(name: "ceid", value: "CN:zh-Hans")
        ]
        guard let url = components.url else { throw FNewsError.invalidFeedURL }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.setValue("GuanpanMax/1.0", forHTTPHeaderField: "User-Agent")
        request.setValue("application/rss+xml, application/xml, text/xml", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse, (200..<300).contains(http.statusCode) else {
            throw FNewsError.httpStatus((response as? HTTPURLResponse)?.statusCode ?? 0)
        }
        guard data.count <= 1_000_000 else { throw FNewsError.feedTooLarge }
        let parser = FNewsRSSParser(data: data)
        guard parser.parse() else { throw FNewsError.invalidFeed }
        let cutoff = now.addingTimeInterval(-maximumAge)
        var seen = Set<String>()
        let articles = parser.items.compactMap { item -> FNewsArticle? in
            let title = item.title.trimmingCharacters(in: .whitespacesAndNewlines)
            let publisher = item.publisher.trimmingCharacters(in: .whitespacesAndNewlines)
            let link = item.link.trimmingCharacters(in: .whitespacesAndNewlines)
            guard !title.isEmpty, !publisher.isEmpty,
                  let linkURL = URL(string: link), linkURL.scheme?.lowercased() == "https",
                  let publishedAt = parseDate(item.publishedAt),
                  publishedAt >= cutoff, publishedAt <= now,
                  seen.insert(link).inserted else { return nil }
            return FNewsArticle(title: String(title.prefix(300)), publisher: String(publisher.prefix(120)),
                                url: link, publishedAt: publishedAt)
        }.prefix(5)
        return FNewsFeed(provider: providerName, fetchedAt: now, articles: Array(articles))
    }

    private static func parseDate(_ value: String) -> Date? {
        let value = value.trimmingCharacters(in: .whitespacesAndNewlines)
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = TimeZone(secondsFromGMT: 0)
        for format in ["EEE, dd MMM yyyy HH:mm:ss zzz", "EEE, dd MMM yyyy HH:mm zzz"] {
            formatter.dateFormat = format
            if let date = formatter.date(from: value) { return date }
        }
        return ISO8601DateFormatter().date(from: value)
    }
}

private enum FNewsError: LocalizedError {
    case invalidSecurityCode, invalidFeedURL, httpStatus(Int), feedTooLarge, invalidFeed

    var errorDescription: String? {
        switch self {
        case .invalidSecurityCode: return "证券代码无效"
        case .invalidFeedURL: return "新闻查询地址无效"
        case .httpStatus(let status): return "新闻源 HTTP \(status)"
        case .feedTooLarge: return "新闻源响应超出大小限制"
        case .invalidFeed: return "新闻源 RSS 格式无效"
        }
    }
}

private struct FNewsRSSItem {
    var title = ""
    var link = ""
    var publishedAt = ""
    var publisher = ""
}

private final class FNewsRSSParser: NSObject, XMLParserDelegate {
    private let parser: XMLParser
    private var currentItem: FNewsRSSItem?
    private var text = ""
    private(set) var items: [FNewsRSSItem] = []

    init(data: Data) { parser = XMLParser(data: data); super.init(); parser.delegate = self }

    func parse() -> Bool { parser.parse() }

    func parser(_ parser: XMLParser, didStartElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?, attributes attributeDict: [String: String] = [:]) {
        let name = elementName.lowercased()
        if name == "item" { currentItem = FNewsRSSItem() }
        if currentItem != nil { text = "" }
    }

    func parser(_ parser: XMLParser, foundCharacters string: String) { text += string }

    func parser(_ parser: XMLParser, didEndElement elementName: String,
                namespaceURI: String?, qualifiedName qName: String?) {
        guard currentItem != nil else { return }
        let value = text.trimmingCharacters(in: .whitespacesAndNewlines)
        switch elementName.lowercased() {
        case "title": currentItem?.title += value
        case "link": currentItem?.link += value
        case "pubdate": currentItem?.publishedAt += value
        case "source": currentItem?.publisher += value
        case "item":
            if let currentItem { items.append(currentItem) }
            currentItem = nil
        default: break
        }
        text = ""
    }
}

struct FNewsEvidencePayload: Codable {
    let note: String
    let fetchedAt: Date
    let articles: [FNewsArticle]
}
