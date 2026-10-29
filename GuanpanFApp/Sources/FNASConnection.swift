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
    case historyUnavailable(String)
    case invalidResponse

    var errorDescription: String? {
        switch self {
        case .invalidAddress: return "NAS 地址无效；请填写 http(s)://主机:8788。"
        case let .notReady(status): return "NAS 已响应，但服务未就绪：\(status)"
        case let .historyUnavailable(reason): return "NAS 历史分钟读取失败：\(reason)"
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
            let status: String?
            let expectedCount: Int?
            let observedCount: Int?
            let missingTimestamps: [String]?
            let qualityPassed: Bool?

            private enum CodingKeys: String, CodingKey { case status, expectedCount, observedCount, missingTimestamps, qualityPassed }
            init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                status = try? values.decodeIfPresent(String.self, forKey: .status)
                expectedCount = try? values.decodeIfPresent(Int.self, forKey: .expectedCount)
                observedCount = try? values.decodeIfPresent(Int.self, forKey: .observedCount)
                missingTimestamps = try? values.decodeIfPresent([String].self, forKey: .missingTimestamps)
                qualityPassed = try? values.decodeIfPresent(Bool.self, forKey: .qualityPassed)
            }
        }
        struct Bar: Decodable {
            let timestamp: String
            let price: Decimal
            let securityCode: String?
            let market: String?
            let tradingDate: String?
            let source: String?
            let fetchedAt: String?
            let minuteVolume: Decimal?

            private enum CodingKeys: String, CodingKey { case timestamp, price, securityCode, market, tradingDate, source, fetchedAt, minuteVolume, volume }
            init(from decoder: Decoder) throws {
                let values = try decoder.container(keyedBy: CodingKeys.self)
                timestamp = try values.decode(String.self, forKey: .timestamp)
                securityCode = try? values.decodeIfPresent(String.self, forKey: .securityCode)
                market = try? values.decodeIfPresent(String.self, forKey: .market)
                tradingDate = try? values.decodeIfPresent(String.self, forKey: .tradingDate)
                if let numeric = try? values.decode(Decimal.self, forKey: .price) {
                    price = numeric
                } else if let text = try? values.decode(String.self, forKey: .price),
                          let numeric = Decimal(string: text, locale: Locale(identifier: "en_US_POSIX")) {
                    price = numeric
                } else {
                    throw DecodingError.dataCorruptedError(forKey: .price, in: values,
                                                           debugDescription: "price must be numeric")
                }
                source = try? values.decodeIfPresent(String.self, forKey: .source)
                fetchedAt = try? values.decodeIfPresent(String.self, forKey: .fetchedAt)
                minuteVolume = (try? values.decodeIfPresent(Decimal.self, forKey: .minuteVolume)) ??
                    (try? values.decodeIfPresent(Decimal.self, forKey: .volume)) ?? nil
            }
        }
        let securityCode: String
        let market: String
        let tradingDate: String
        let status: String?
        let coverage: Coverage?
        let bars: [Bar]

        private enum CodingKeys: String, CodingKey {
            case securityCode, security_code, market, tradingDate, trading_date, status, coverage, bars
        }
        init(from decoder: Decoder) throws {
            let values = try decoder.container(keyedBy: CodingKeys.self)
            if let value = try? values.decode(String.self, forKey: .securityCode) {
                securityCode = value
            } else if let value = try? values.decode(Int.self, forKey: .securityCode) {
                // Some NAS deployments serialize a numeric-only security code as JSON number.
                securityCode = String(value)
            } else if let value = try? values.decode(String.self, forKey: .security_code) {
                securityCode = value
            } else if let value = try? values.decode(Int.self, forKey: .security_code) {
                securityCode = String(value)
            } else {
                throw DecodingError.dataCorruptedError(forKey: .securityCode, in: values,
                                                       debugDescription: "securityCode must be a string or integer")
            }
            market = try values.decode(String.self, forKey: .market)
            tradingDate = (try? values.decode(String.self, forKey: .tradingDate)) ??
                (try values.decode(String.self, forKey: .trading_date))
            status = (try? values.decodeIfPresent(String.self, forKey: .status)) ?? "partial"
            coverage = try? values.decodeIfPresent(Coverage.self, forKey: .coverage)
            let hasBars = values.contains(.bars)
            let barsAreNull = hasBars ? try values.decodeNil(forKey: .bars) : true
            if !hasBars || barsAreNull {
                bars = []
            } else {
                // Do not silently turn malformed bar rows into an empty archive. The caller
                // needs the response-shape diagnostic so a valid HTTP 200 is not masked by
                // the legacy endpoint's unrelated 404.
                bars = try values.decode([Bar].self, forKey: .bars)
            }
        }
    }

    // B's Frozen NAS contract predates F's coverage-aware endpoint. It is a
    // read-only compatibility fallback; its rows do not carry quality or fetch
    // timestamps, so they must never be presented as Complete research data.
    private struct LegacyBResponse: Decodable {
        struct Bar: Decodable {
            let timestamp: String
            let price: String
            let volume: String?
            let iopv: String?
        }
        let code: String
        let day: String
        let source: String
        let rows: [Bar]
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
        var modernFailure: String?
        if (200..<300).contains(http.statusCode),
           let body = try? JSONDecoder().decode(Response.self, from: data),
           body.securityCode == securityCode, body.market.uppercased() == "CN", body.tradingDate == dateText {
            let archive = try makeArchive(body: body, securityCode: securityCode, dateText: dateText,
                                          timeZone: timeZone)
            if !archive.samples.isEmpty { return archive }
            // A valid F response with an explicit empty coverage state is a
            // data-availability result, not an API/connection failure. Keep
            // Missing visible to the user instead of probing an unrelated
            // legacy route and turning HTTP 200 + Missing into a false error.
            let status = (body.status ?? "partial").lowercased()
            if ["missing", "not-a-session", "out_of_provider_coverage",
                "permanent_unavailable", "retryable"].contains(status) {
                return archive
            }
            modernFailure = "F 历史接口已响应，但该证券/日期没有归档分钟点（\(body.status ?? "partial")）"
        } else {
            modernFailure = Self.responseFailure(data: data, response: http,
                                                 expectedSecurityCode: securityCode,
                                                 expectedTradingDate: dateText)
        }
        do {
            return try await fetchLegacyB(baseURL: baseAddress, securityCode: securityCode,
                                          dateText: dateText, timeZone: timeZone)
        } catch {
            throw FNASConnectionError.historyUnavailable("\(modernFailure ?? "F 历史接口不可用")；B 兼容接口也未取得数据：\(error.localizedDescription)")
        }
    }

    private static func makeArchive(body: Response, securityCode: String, dateText: String,
                                    timeZone: TimeZone) throws -> FNASArchivedIntraday {
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
            guard (bar.securityCode == nil || bar.securityCode == securityCode),
                  (bar.market == nil || bar.market == "CN"),
                  (bar.tradingDate == nil || bar.tradingDate == dateText) else { return nil }
            guard let stamp = parseTimestamp(bar.timestamp), stamp >= dayStart, stamp < dayEnd,
                  bar.price > 0 else { return nil }
            if let fetchedAtText = bar.fetchedAt,
               let fetchedAt = parseTimestamp(fetchedAtText), fetchedAt < stamp { return nil }
            return FMinuteSample(timestamp: stamp, price: bar.price, volume: bar.minuteVolume)
        }.sorted { $0.timestamp < $1.timestamp }
        let unique = Dictionary(samples.map { ($0.timestamp, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = unique.keys.sorted().compactMap { unique[$0] }
        let discardedCount = body.bars.count - ordered.count
        let reportedStatus = (body.status ?? "partial").lowercased()
        let missingProvenance = body.bars.contains { bar in
            bar.source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty != false ||
            bar.fetchedAt.flatMap(parseTimestamp) == nil
        }
        let effectiveStatus = (discardedCount > 0 || missingProvenance || body.coverage == nil) && reportedStatus == "complete"
            ? "partial" : (body.status ?? "partial")
        let coverage = body.coverage
        let coverageSummary: String
        if let coverage {
            let expected = coverage.expectedCount.map { "\($0)" } ?? "未知"
            let observed = coverage.observedCount ?? ordered.count
            let missing = coverage.missingTimestamps?.count
            let quality = coverage.qualityPassed.map { $0 ? " · 质量合格" : " · 质量未达标" } ?? ""
            let discarded = discardedCount > 0 ? " · 客户端剔除 \(discardedCount) 条无效/重复记录" : ""
            let provenance = missingProvenance ? " · 来源/采集时间缺失，降为Partial" : ""
            coverageSummary = "\(effectiveStatus) · \(observed)/\(expected) 点 · 缺失 \(missing.map { "\($0)" } ?? "未知") 点\(quality)\(discarded)\(provenance)"
        } else {
            coverageSummary = "\(effectiveStatus) · NAS未提供完整度统计"
        }
        let sources = Array(Set(body.bars.compactMap(\.source))).sorted().joined(separator: ", ")
        return FNASArchivedIntraday(securityCode: securityCode, tradingDate: dateText,
                                    coverageStatus: effectiveStatus, coverageSummary: coverageSummary,
                                    sourceSummary: sources.isEmpty ? "无有效来源" : sources,
                                    fetchedAt: Date(),
                                    samples: ordered)
    }

    private static func fetchLegacyB(baseURL: String, securityCode: String, dateText: String,
                                     timeZone: TimeZone) async throws -> FNASArchivedIntraday {
        guard let readyURL = FNASReadinessClient.validateAddress(baseURL),
              var components = URLComponents(url: readyURL, resolvingAgainstBaseURL: false) else {
            throw FNASConnectionError.invalidAddress
        }
        components.path = "/v1/market/minute/\(securityCode)"
        components.queryItems = [URLQueryItem(name: "day", value: dateText)]
        guard let url = components.url else { throw FNASConnectionError.invalidAddress }
        var request = URLRequest(url: url, timeoutInterval: 20)
        request.httpMethod = "GET"
        request.setValue("application/json", forHTTPHeaderField: "Accept")
        let (data, response) = try await URLSession.shared.data(for: request)
        guard let http = response as? HTTPURLResponse else { throw FNASConnectionError.invalidResponse }
        guard (200..<300).contains(http.statusCode),
              let body = try? JSONDecoder().decode(LegacyBResponse.self, from: data),
              body.code == securityCode, body.day == dateText,
              !body.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else {
            throw FNASConnectionError.historyUnavailable(Self.responseFailure(data: data, response: http,
                                                                                expectedSecurityCode: securityCode,
                                                                                expectedTradingDate: dateText))
        }
        var dayFormatter = DateFormatter()
        dayFormatter.locale = Locale(identifier: "en_US_POSIX")
        dayFormatter.timeZone = timeZone
        dayFormatter.dateFormat = "yyyy-MM-dd"
        guard let dayStart = dayFormatter.date(from: dateText) else {
            throw FNASConnectionError.invalidResponse
        }
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        guard let dayEnd = calendar.date(byAdding: .day, value: 1, to: dayStart) else {
            throw FNASConnectionError.invalidResponse
        }
        let samples = body.rows.compactMap { row -> FMinuteSample? in
            guard let stamp = parseTimestamp(row.timestamp), stamp >= dayStart, stamp < dayEnd,
                  let price = Decimal(string: row.price, locale: Locale(identifier: "en_US_POSIX")),
                  price > 0 else { return nil }
            let volume = row.volume.flatMap { Decimal(string: $0, locale: Locale(identifier: "en_US_POSIX")) }
            return FMinuteSample(timestamp: stamp, price: price, volume: volume)
        }
        let unique = Dictionary(samples.map { ($0.timestamp, $0) }, uniquingKeysWith: { first, _ in first })
        let ordered = unique.keys.sorted().compactMap { unique[$0] }
        guard !ordered.isEmpty else {
            throw FNASConnectionError.historyUnavailable("B 接口有响应，但没有该日期可用的分钟点")
        }
        return FNASArchivedIntraday(
            securityCode: securityCode, tradingDate: dateText,
            coverageStatus: "legacy-unassessed",
            coverageSummary: "\(ordered.count) 个真实分钟点 · B 兼容接口未提供完整度、质量和采集时间；完整性/新鲜度未知",
            sourceSummary: "B NAS 归档 · \(body.source)", fetchedAt: Date(), samples: ordered)
    }

    private static func responseFailure(data: Data, response: HTTPURLResponse,
                                        expectedSecurityCode: String? = nil,
                                        expectedTradingDate: String? = nil) -> String {
        let contentType = response.value(forHTTPHeaderField: "Content-Type") ?? "未知 Content-Type"
        if contentType.localizedCaseInsensitiveContains("text/html") {
            return "HTTP \(response.statusCode) 返回了网页而非分钟 JSON（\(contentType)）；可能是 API 路径未映射到 NAS 服务"
        }
        if let object = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            if let message = object["error"] as? String, !message.isEmpty {
                return "HTTP \(response.statusCode)：\(String(message.prefix(180)))"
            }
            var problems: [String] = []
            let returnedCode = object["securityCode"] ?? object["security_code"]
            if let expectedSecurityCode, let returnedCode,
               Self.jsonScalar(returnedCode) != expectedSecurityCode {
                problems.append("证券代码期望 \(expectedSecurityCode)，实际 \(Self.jsonScalar(returnedCode))")
            } else if expectedSecurityCode != nil, returnedCode == nil {
                problems.append("缺少 securityCode")
            }
            if let expectedTradingDate, let returnedDate = object["tradingDate"] ?? object["trading_date"] {
                if Self.jsonScalar(returnedDate) != expectedTradingDate {
                    problems.append("交易日期望 \(expectedTradingDate)，实际 \(Self.jsonScalar(returnedDate))")
                }
            } else if expectedTradingDate != nil {
                problems.append("缺少 tradingDate")
            }
            if let market = object["market"] {
                if Self.jsonScalar(market).uppercased() != "CN" {
                    problems.append("市场期望 CN，实际 \(Self.jsonScalar(market))")
                }
            } else {
                problems.append("缺少 market")
            }
            if let bars = object["bars"] as? [[String: Any]], let first = bars.first {
                let barKeys = Set(first.keys)
                if !(barKeys.contains("timestamp") && barKeys.contains("price")) {
                    problems.append("bars首条缺少 timestamp/price（实际字段：\(barKeys.sorted().joined(separator: ", "))）")
                } else if !(first["timestamp"] is String) ||
                            (!(first["price"] is String) && !(first["price"] is NSNumber)) {
                    problems.append("bars首条 timestamp/price 类型不兼容")
                }
            } else if let rawBars = object["bars"], !(rawBars is NSNull), !(rawBars is [Any]) {
                problems.append("bars应为数组，实际类型不符")
            }
            let reason = problems.isEmpty
                ? "响应内容无法解码为历史分钟记录"
                : problems.joined(separator: "；")
            return "HTTP \(response.statusCode) 历史分钟响应校验失败：\(reason)（顶层字段：\(object.keys.sorted().joined(separator: ", "))）"
        }
        return "HTTP \(response.statusCode) 响应格式不是可识别的历史分钟 JSON（\(contentType)）"
    }

    private static func jsonScalar(_ value: Any) -> String {
        if let string = value as? String { return string }
        if let number = value as? NSNumber { return number.stringValue }
        if value is NSNull { return "null" }
        return String(describing: type(of: value))
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
