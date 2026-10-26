import Foundation
import Security
import FCore

struct FNASArchivedIntraday: Equatable, Sendable {
    let securityCode: String
    let tradingDate: String
    let coverageStatus: String
    let coverageSummary: String
    let sourceSummary: String
    let fetchedAt: Date
    let samples: [FMinuteSample]
}

enum FNASConnectionError: Error, LocalizedError {
    case invalidAddress
    case missingToken
    case invalidToken
    case unauthorized
    case notReady(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "NAS 地址无效；请填写 http(s)://主机:8788。"
        case .missingToken: return "尚未保存 NAS API Token。"
        case .invalidToken: return "NAS API Token 至少需要 32 个 UTF-8 字节。"
        case .unauthorized: return "NAS 拒绝访问；请核对 API Token。"
        case let .notReady(status): return "NAS 已响应，但服务未就绪：\(status)"
        case .invalidResponse: return "NAS 返回了无法识别的就绪状态。"
        }
    }
}

enum FNASKeychain {
    private static let service = "com.guanpan.advisor.f.nas"
    private static let account = "minute-archive-api-token"

    static func save(token: String) throws {
        let value = token.trimmingCharacters(in: .whitespacesAndNewlines)
        guard value.utf8.count >= 32 else { throw FNASConnectionError.invalidToken }
        let key = [kSecClass as String: kSecClassGenericPassword,
                   kSecAttrService as String: service,
                   kSecAttrAccount as String: account] as [String: Any]
        let attributes = [kSecValueData as String: Data(value.utf8),
                          kSecAttrAccessible as String: kSecAttrAccessibleAfterFirstUnlockThisDeviceOnly]

        let status = SecItemCopyMatching(key as CFDictionary, nil)
        if status == errSecSuccess {
            let updateStatus = SecItemUpdate(key as CFDictionary, attributes as CFDictionary)
            guard updateStatus == errSecSuccess else { throw FNASConnectionError.invalidResponse }
        } else if status == errSecItemNotFound {
            var item = key
            attributes.forEach { item[$0.key] = $0.value }
            let addStatus = SecItemAdd(item as CFDictionary, nil)
            guard addStatus == errSecSuccess else { throw FNASConnectionError.invalidResponse }
        } else {
            throw FNASConnectionError.invalidResponse
        }
    }

    static func readToken() throws -> String {
        let query = [kSecClass as String: kSecClassGenericPassword,
                     kSecAttrService as String: service,
                     kSecAttrAccount as String: account,
                     kSecReturnData as String: true,
                     kSecMatchLimit as String: kSecMatchLimitOne] as [String: Any]
        var result: CFTypeRef?
        let status = SecItemCopyMatching(query as CFDictionary, &result)
        guard status == errSecSuccess, let data = result as? Data,
              let token = String(data: data, encoding: .utf8), token.utf8.count >= 32 else {
            throw FNASConnectionError.missingToken
        }
        return token
    }
}

enum FNASReadinessClient {
    private struct ReadyResponse: Decodable {
        let status: String
        let archive: String
        let configuredMarkets: [String]
    }

    static func validateAddress(_ text: String) -> URL? {
        guard var components = URLComponents(string: text.trimmingCharacters(in: .whitespacesAndNewlines)),
              let scheme = components.scheme?.lowercased(), ["http", "https"].contains(scheme),
              components.host?.isEmpty == false,
              components.user == nil, components.password == nil,
              components.query == nil, components.fragment == nil,
              components.path.isEmpty || components.path == "/" else { return nil }
        components.path = "/readyz"
        return components.url
    }

    static func check(baseAddress: String, token: String) async throws -> String {
        guard let url = validateAddress(baseAddress) else { throw FNASConnectionError.invalidAddress }
        guard token.utf8.count >= 32 else { throw FNASConnectionError.invalidToken }
        var request = URLRequest(url: url, timeoutInterval: 8)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FNASConnectionError.invalidResponse }
        if http.statusCode == 401 { throw FNASConnectionError.unauthorized }
        guard (200..<300).contains(http.statusCode),
              let body = try? JSONDecoder().decode(ReadyResponse.self, from: data) else {
            let status = (try? JSONDecoder().decode(ReadyResponse.self, from: data).status) ?? "HTTP \(http.statusCode)"
            throw FNASConnectionError.notReady(status)
        }
        guard body.status == "ready", body.archive == "ok" else {
            throw FNASConnectionError.notReady(body.status)
        }
        return "NAS 已就绪 · \(body.configuredMarkets.joined(separator: ", "))"
    }
}

enum FNASHistoricalMinuteClient {
    private struct Response: Decodable {
        struct Coverage: Decodable {
            let status: String
            let expectedCount: Int?
            let observedCount: Int?
            let missingTimestamps: [String]?
            let qualityPassed: Bool?
        }
        struct Bar: Decodable {
            let timestamp: String
            let price: Decimal
            let source: String
            let fetchedAt: String
        }
        let securityCode: String
        let market: String
        let tradingDate: String
        let status: String
        let coverage: Coverage?
        let bars: [Bar]
    }

    static func fetch(baseAddress: String, token: String, securityCode: String,
                      tradingDate: Date, timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current) async throws -> FNASArchivedIntraday {
        guard let readinessURL = FNASReadinessClient.validateAddress(baseAddress),
              var components = URLComponents(url: readinessURL, resolvingAgainstBaseURL: false) else {
            throw FNASConnectionError.invalidAddress
        }
        guard token.utf8.count >= 32 else { throw FNASConnectionError.invalidToken }
        let dateText = dayString(tradingDate, timeZone: timeZone)
        components.path = "/api/v1/minute-history"
        components.queryItems = [
            URLQueryItem(name: "securityCode", value: securityCode),
            URLQueryItem(name: "market", value: "CN"),
            URLQueryItem(name: "tradingDate", value: dateText),
            URLQueryItem(name: "minimumQuality", value: "80")
        ]
        guard let url = components.url else { throw FNASConnectionError.invalidAddress }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue(token, forHTTPHeaderField: "X-Api-Key")
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FNASConnectionError.invalidResponse }
        if http.statusCode == 401 { throw FNASConnectionError.unauthorized }
        guard (200..<300).contains(http.statusCode), let body = try? JSONDecoder().decode(Response.self, from: data),
              body.securityCode == securityCode, body.market == "CN", body.tradingDate == dateText else {
            throw FNASConnectionError.notReady("历史分时查询失败（HTTP \(http.statusCode)）")
        }
        var formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd HH:mm"
        guard let dayStart = formatter.date(from: dateText + " 00:00") else {
            throw FNASConnectionError.invalidResponse
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw FNASConnectionError.invalidResponse
        }
        let samples = body.bars.compactMap { bar -> FMinuteSample? in
            guard let stamp = parseTimestamp(bar.timestamp), stamp >= dayStart, stamp < dayEnd,
                  let fetchedAt = parseTimestamp(bar.fetchedAt), fetchedAt >= stamp,
                  !bar.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
                  bar.price > 0 else { return nil }
            return FMinuteSample(timestamp: stamp, price: bar.price)
        }.sorted { $0.timestamp < $1.timestamp }
        let unique = Dictionary(samples.map { ($0.timestamp, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = unique.keys.sorted().compactMap { unique[$0] }
        let coverage = body.coverage
        let coverageSummary: String
        if let coverage {
            let expected = coverage.expectedCount.map { "\($0)" } ?? "未知"
            let observed = coverage.observedCount ?? ordered.count
            let missing = coverage.missingTimestamps?.count
            let quality = coverage.qualityPassed.map { $0 ? " · 质量合格" : " · 质量未达标" } ?? ""
            coverageSummary = "\(body.status) · \(observed)/\(expected) 点 · 缺失 \(missing.map { "\($0)" } ?? "未知") 点\(quality)"
        } else {
            coverageSummary = "\(body.status) · NAS未提供完整度统计"
        }
        let sources = Array(Set(body.bars.map(\.source))).sorted().joined(separator: ", ")
        return FNASArchivedIntraday(securityCode: securityCode, tradingDate: dateText,
                                    coverageStatus: body.status, coverageSummary: coverageSummary,
                                    sourceSummary: sources.isEmpty ? "无有效来源" : sources,
                                    fetchedAt: Date(),
                                    samples: ordered)
    }

    private static func dayString(_ value: Date, timeZone: TimeZone) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.dateFormat = "yyyy-MM-dd"
        return formatter.string(from: value)
    }

    private static func parseTimestamp(_ value: String) -> Date? {
        let fractional = ISO8601DateFormatter()
        fractional.formatOptions = [.withInternetDateTime, .withFractionalSeconds]
        if let date = fractional.date(from: value) { return date }
        let standard = ISO8601DateFormatter()
        return standard.date(from: value)
    }
}
