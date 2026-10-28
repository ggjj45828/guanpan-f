import Foundation
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
    case notReady(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "NAS 地址无效；请填写 http(s)://主机:8788。"
        case let .notReady(status): return "NAS 已响应，但服务未就绪：\(status)"
        case .invalidResponse: return "NAS 返回了无法识别的就绪状态。"
        }
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
              components.path.isEmpty || components.path == "/" || components.path == "/readyz" else { return nil }
        components.path = "/readyz"
        return components.url
    }

    static func check(baseAddress: String) async throws -> String {
        guard let url = validateAddress(baseAddress) else { throw FNASConnectionError.invalidAddress }
        // Allow slower public tunnel hops more time than a typical LAN request.
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")

        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FNASConnectionError.invalidResponse }
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

    static func connectionHint(for error: Error) -> String {
        guard let urlError = error as? URLError else { return error.localizedDescription }
        switch urlError.code {
        case .cannotFindHost, .dnsLookupFailed:
            return "找不到 NAS 主机。请核对地址，并确认 iPhone 与 NAS 在同一局域网或已连接 VPN。"
        case .cannotConnectToHost:
            return "无法建立到 NAS 的连接。请核对穿透域名和 8788 端口映射；如果是局域网地址，请确认观盘max 已获本地网络权限。"
        case .timedOut:
            return "连接 NAS 超时（等待 20 秒仍未收到响应）。请检查穿透链路或 NAS 容器响应。"
        case .networkConnectionLost:
            return "连接 NAS 时网络中断。请检查手机当前网络和穿透链路后重试。"
        case .appTransportSecurityRequiresSecureConnection:
            return "iOS 阻止了不安全的远程 HTTP 连接。远程 NAS 请配置 HTTPS，或通过可信 VPN 连接。"
        case .secureConnectionFailed, .serverCertificateUntrusted, .serverCertificateHasUnknownRoot,
             .serverCertificateHasBadDate, .clientCertificateRejected:
            return "NAS 的 HTTPS 证书校验失败。请检查穿透域名与证书是否匹配、有效并受 iOS 信任。"
        default:
            return "NAS 网络请求失败：\(urlError.localizedDescription)"
        }
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

    static func fetch(baseAddress: String, securityCode: String,
                      tradingDate: Date, timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current) async throws -> FNASArchivedIntraday {
        guard let readinessURL = FNASReadinessClient.validateAddress(baseAddress),
              var components = URLComponents(url: readinessURL, resolvingAgainstBaseURL: false) else {
            throw FNASConnectionError.invalidAddress
        }
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
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FNASConnectionError.invalidResponse }
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
