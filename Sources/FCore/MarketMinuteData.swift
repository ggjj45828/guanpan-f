import Foundation

public struct FMinuteSample: Equatable, Sendable, Identifiable {
    public var id: Date { timestamp }
    public let timestamp: Date
    public let price: Decimal
    /// Incremental traded volume when the provider supplies it.
    public let volume: Decimal?

    public init(timestamp: Date, price: Decimal, volume: Decimal? = nil) {
        self.timestamp = timestamp
        self.price = price
        self.volume = volume
    }
}

public struct FDailyBar: Equatable, Sendable, Identifiable {
    public var id: Date { tradingDate }
    public let tradingDate: Date
    public let open: Decimal
    public let close: Decimal
    public let high: Decimal
    public let low: Decimal
    public let volume: Decimal

    public init(tradingDate: Date, open: Decimal, close: Decimal, high: Decimal,
                low: Decimal, volume: Decimal) {
        self.tradingDate = tradingDate
        self.open = open
        self.close = close
        self.high = high
        self.low = low
        self.volume = volume
    }
}

/// Shared overflow-safe incremental moving-average calculation for daily bars.
public enum FDailyMovingAverage {
    public static func values(for bars: [FDailyBar], period: Int) -> [Decimal?] {
        guard period > 0 else { return Array(repeating: nil, count: bars.count) }
        return bars.indices.map { index -> Decimal? in
            guard index + 1 >= period else { return nil }
            let window = bars[(index + 1 - period)...index]
            guard let first = window.first?.close else { return nil }
            var average = first
            for (offset, bar) in window.dropFirst().enumerated() {
                var difference = Decimal.zero
                var current = bar.close
                guard NSDecimalSubtract(&difference, &current, &average, .plain) == .noError else { return nil }
                var adjustment = Decimal.zero
                var delta = difference
                let divisor = Decimal(offset + 2)
                guard NSDecimalDivide(&adjustment, &delta, &divisor, .plain) == .noError else { return nil }
                var updated = Decimal.zero
                guard NSDecimalAdd(&updated, &average, &adjustment, .plain) == .noError else { return nil }
                average = updated
            }
            return average
        }
    }
}

public struct FDailyKlineSnapshot: Equatable, Sendable {
    public let securityCode: String
    public let bars: [FDailyBar]
    public let fetchedAt: Date
    public let source: String
    public let adjustment: String

    public init(securityCode: String, bars: [FDailyBar], fetchedAt: Date,
                source: String, adjustment: String) throws {
        let fetchedAtIsFinite = fetchedAt.timeIntervalSince1970.isFinite
        guard securityCode.count == 6, securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }),
              !bars.isEmpty, bars.count <= 500,
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              adjustment == "不复权", fetchedAtIsFinite,
              zip(bars, bars.dropFirst()).allSatisfy({ $0.0.tradingDate < $0.1.tradingDate }),
              bars.allSatisfy({ bar in
                  bar.tradingDate.timeIntervalSince1970.isFinite && bar.tradingDate <= fetchedAt &&
                  [bar.open, bar.close, bar.high, bar.low, bar.volume].allSatisfy(Self.isFinite) &&
                  bar.low > 0 && bar.volume >= 0 &&
                  bar.high >= max(bar.open, bar.close) && bar.low <= min(bar.open, bar.close) &&
                  bar.high >= bar.low
              }) else { throw FMarketDataError.invalidPayload }
        self.securityCode = securityCode
        self.bars = bars
        self.fetchedAt = fetchedAt
        self.source = source
        self.adjustment = adjustment
    }

    public func movingAverage(period: Int) -> [Decimal?] {
        FDailyMovingAverage.values(for: bars, period: period)
    }

    private static func isFinite(_ value: Decimal) -> Bool {
        value.isFinite
    }
}

public struct FCurrentIntradaySnapshot: Equatable, Sendable {
    public let securityCode: String
    public let samples: [FMinuteSample]
    public let quoteTimestamp: Date
    public let fetchedAt: Date
    public let source: String

    public var latestPrice: Decimal? { samples.last?.price }

    public func temporalMetadata(marketSessionStatus: FMarketSessionStatus = .unknown) -> FQuoteTemporalMetadata {
        FQuoteTemporalMetadata(quoteTimestamp: quoteTimestamp, fetchedAt: fetchedAt, source: source,
                               timestampTrust: .verifiedExchangeTimestamp,
                               marketSessionStatus: marketSessionStatus)
    }

    public func freshness(at now: Date) -> FQuoteFreshness {
        temporalMetadata().freshness(at: now)
    }

    public init(securityCode: String, samples: [FMinuteSample], quoteTimestamp: Date,
                fetchedAt: Date, source: String) throws {
        let timesAreFinite = quoteTimestamp.timeIntervalSince1970.isFinite &&
            fetchedAt.timeIntervalSince1970.isFinite
        guard securityCode.count == 6, securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }),
              !samples.isEmpty, !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              quoteTimestamp == samples.last?.timestamp, quoteTimestamp <= fetchedAt,
              timesAreFinite,
              zip(samples, samples.dropFirst()).allSatisfy({ $0.timestamp < $1.timestamp }),
              samples.allSatisfy({ sample in
                  sample.timestamp.timeIntervalSince1970.isFinite && sample.timestamp <= fetchedAt &&
                  Self.isFinite(sample.price) && sample.price > 0 &&
                  (sample.volume.map { Self.isFinite($0) && $0 >= 0 } ?? true)
              }) else {
            throw FMarketDataError.invalidPayload
        }
        self.securityCode = securityCode
        self.samples = samples
        self.quoteTimestamp = quoteTimestamp
        self.fetchedAt = fetchedAt
        self.source = source
    }

    private static func isFinite(_ value: Decimal) -> Bool {
        value.isFinite
    }
}

public enum FMarketDataError: Error, Equatable, Sendable, LocalizedError {
    case invalidSecurityCode
    case invalidPayload
    case staleOrWrongSession
    case noUsableSamples
    case noUsableDailyBars

    public var errorDescription: String? {
        switch self {
        case .invalidSecurityCode: return "证券代码格式不受支持"
        case .invalidPayload: return "行情源响应格式无效"
        case .staleOrWrongSession: return "行情源没有返回当前交易日数据"
        case .noUsableSamples: return "行情源没有返回可用分钟点"
        case .noUsableDailyBars: return "日 K 行情源没有返回可用交易日数据"
        }
    }
}

/// Parses Tencent's text quote wrapper and verifies that the provider echoed
/// the exact requested symbol before any returned fields are consumed.
public enum FTencentTextQuoteParser {
    public static func fields(_ data: Data, expectedSymbol: String) throws -> [String] {
        guard !expectedSymbol.isEmpty,
              let text = String(data: data, encoding: .utf8) else {
            throw FMarketDataError.invalidPayload
        }
        let pattern = #"v_([A-Za-z0-9]+)="([^"]*)""#
        guard let regex = try? NSRegularExpression(pattern: pattern),
              let match = regex.firstMatch(in: text, range: NSRange(text.startIndex..., in: text)),
              let symbolRange = Range(match.range(at: 1), in: text),
              String(text[symbolRange]) == expectedSymbol,
              let bodyRange = Range(match.range(at: 2), in: text) else {
            throw FMarketDataError.invalidPayload
        }
        return text[bodyRange].split(separator: "~", omittingEmptySubsequences: false).map(String.init)
    }
}

/// Strict parser for the same current-session Tencent minute response used by
/// the NAS adapter. It does not turn a fetchedAt value into an exchange time.
public enum FTencentMinuteParser {
    public static let source = FMarketQuoteTrustPolicy.tencentMinuteSource

    public static func symbol(for securityCode: String) throws -> String {
        guard securityCode.count == 6, securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }),
              let prefix = securityCode.first else {
            throw FMarketDataError.invalidSecurityCode
        }
        if "569".contains(prefix) { return "sh" + securityCode }
        if "0123".contains(prefix) { return "sz" + securityCode }
        throw FMarketDataError.invalidSecurityCode
    }

    public static func parse(_ data: Data, securityCode: String, fetchedAt: Date,
                             timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current)
        throws -> FCurrentIntradaySnapshot {
        let symbol = try symbol(for: securityCode)
        let text = String(decoding: data, as: UTF8.self)
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}"), firstBrace <= lastBrace else {
            throw FMarketDataError.invalidPayload
        }
        let objectData = Data(text[firstBrace...lastBrace].utf8)
        guard let root = try JSONSerialization.jsonObject(with: objectData) as? [String: Any],
              let dataNode = root["data"] as? [String: Any],
              let instrumentNode = dataNode[symbol] as? [String: Any],
              let node = instrumentNode["data"] as? [String: Any],
              let dateText = node["date"] as? String, dateText.count == 8,
              let rows = (node["data"] as? [String]) ?? (node["items"] as? [String]) else {
            throw FMarketDataError.invalidPayload
        }

        var formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        formatter.dateFormat = "yyyyMMdd HHmm"
        guard let localDay = formatter.date(from: dateText + " 1200") else {
            throw FMarketDataError.invalidPayload
        }
        let fetchedDay = Calendar(identifier: .gregorian).dateComponents(in: timeZone, from: fetchedAt)
        let responseDay = Calendar(identifier: .gregorian).dateComponents(in: timeZone, from: localDay)
        guard responseDay.year == fetchedDay.year,
              responseDay.month == fetchedDay.month, responseDay.day == fetchedDay.day else {
            throw FMarketDataError.staleOrWrongSession
        }

        struct ParsedRow {
            let timestamp: Date
            let sourceIndex: Int
            let isOpeningAuction: Bool
            let price: Decimal?
            let cumulativeVolume: Decimal?
        }
        let parsedRows = rows.enumerated().compactMap { index, row -> ParsedRow? in
            let fields = row.split(whereSeparator: \.isWhitespace)
            guard fields.count >= 2, fields[0].count == 4,
                  fields[0].allSatisfy(\.isNumber),
                  let stamp = formatter.date(from: dateText + " " + String(fields[0])),
                  stamp <= fetchedAt else { return nil }
            let price = Decimal(string: String(fields[1]), locale: Locale(identifier: "en_US_POSIX"))
            let minuteLabel = String(fields[0])
            // Provider payloads can contain auction, lunch, or after-hours
            // observations. Only admit regular-session rows into live charts
            // and quant factors; 09:30 is separately excluded as the auction.
            guard FMainlandTradingCalendar.isContinuousSessionTime(at: stamp, timeZone: timeZone) else {
                return nil
            }
            let cumulativeVolume = fields.count > 2
                ? Decimal(string: String(fields[2]), locale: Locale(identifier: "en_US_POSIX")) : nil
            return ParsedRow(timestamp: stamp, sourceIndex: index,
                             isOpeningAuction: minuteLabel == "0930",
                             price: price.flatMap { $0 > 0 ? $0 : nil },
                             cumulativeVolume: cumulativeVolume.flatMap { $0 >= 0 ? $0 : nil })
        }.sorted {
            $0.timestamp == $1.timestamp ? $0.sourceIndex < $1.sourceIndex : $0.timestamp < $1.timestamp
        }

        var points: [Date: (price: Decimal, volume: Decimal?)] = [:]
        var previousCumulativeVolume: Decimal?
        for row in parsedRows {
            // Opening-auction values are not regular-session minute bars or a
            // safe baseline for incremental volume. Begin deltas at the first
            // regular observation instead.
            guard !row.isOpeningAuction else { continue }
            let minuteVolume: Decimal?
            if let cumulativeVolume = row.cumulativeVolume {
                if let previousCumulativeVolume {
                    let delta = cumulativeVolume - previousCumulativeVolume
                    // A cumulative counter reset is not a zero-volume minute.
                    // Keep the price point, but make volume-dependent factors
                    // fail closed for this observation.
                    minuteVolume = delta.isFinite && delta >= 0 ? delta : nil
                } else {
                    minuteVolume = nil
                }
                previousCumulativeVolume = cumulativeVolume
            } else {
                minuteVolume = nil
                // A missing/invalid cumulative counter breaks continuity. Do
                // not attribute the next multi-minute delta to one minute.
                previousCumulativeVolume = nil
            }
            guard let price = row.price else { continue }
            points[row.timestamp] = (price, minuteVolume)
        }
        let samples = points.keys.sorted().compactMap { stamp in
            points[stamp].map { FMinuteSample(timestamp: stamp, price: $0.price, volume: $0.volume) }
        }
        guard let latest = samples.last?.timestamp else { throw FMarketDataError.noUsableSamples }
        if FMainlandTradingCalendar.status(at: fetchedAt, timeZone: timeZone) == .continuous,
           fetchedAt.timeIntervalSince(latest) > 300 {
            throw FMarketDataError.staleOrWrongSession
        }
        return try FCurrentIntradaySnapshot(securityCode: securityCode, samples: samples,
                                            quoteTimestamp: latest, fetchedAt: fetchedAt, source: source)
    }
}

/// Parses Tencent's daily K-line response without mixing adjusted prices into
/// overlays that are compared with the user's real ledger cost.
public enum FTencentDailyKlineParser {
    public static let source = "Tencent Finance daily K-line"

    public static func parse(_ data: Data, securityCode: String, fetchedAt: Date,
                             timeZone: TimeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current)
        throws -> FDailyKlineSnapshot {
        let symbol = try FTencentMinuteParser.symbol(for: securityCode)
        let text = String(decoding: data, as: UTF8.self)
        guard let firstBrace = text.firstIndex(of: "{"),
              let lastBrace = text.lastIndex(of: "}"), firstBrace <= lastBrace else {
            throw FMarketDataError.invalidPayload
        }
        let objectData = Data(text[firstBrace...lastBrace].utf8)
        guard let root = try JSONSerialization.jsonObject(with: objectData) as? [String: Any],
              let dataNode = root["data"] as? [String: Any],
              let instrument = dataNode[symbol] as? [String: Any],
              let rows = instrument["day"] as? [[Any]], !rows.isEmpty else {
            throw FMarketDataError.noUsableDailyBars
        }
        let formatter = DateFormatter()
        formatter.locale = Locale(identifier: "en_US_POSIX")
        formatter.timeZone = timeZone
        formatter.calendar = Calendar(identifier: .gregorian)
        formatter.isLenient = false
        formatter.dateFormat = "yyyy-MM-dd"
        let bars = rows.compactMap { row -> FDailyBar? in
            guard row.count >= 6,
                  let dateText = row[0] as? String,
                  let date = formatter.date(from: dateText),
                  let open = Self.decimal(row[1]), let close = Self.decimal(row[2]),
                  let high = Self.decimal(row[3]), let low = Self.decimal(row[4]),
                  let volume = Self.decimal(row[5]) else { return nil }
            return FDailyBar(tradingDate: date, open: open, close: close,
                             high: high, low: low, volume: volume)
        }.sorted { $0.tradingDate < $1.tradingDate }
        guard !bars.isEmpty else { throw FMarketDataError.noUsableDailyBars }
        return try FDailyKlineSnapshot(securityCode: securityCode, bars: bars,
                                       fetchedAt: fetchedAt, source: source, adjustment: "不复权")
    }

    private static func decimal(_ value: Any) -> Decimal? {
        if let text = value as? String {
            return Decimal(string: text, locale: Locale(identifier: "en_US_POSIX"))
        }
        if let number = value as? NSNumber {
            return Decimal(string: number.stringValue, locale: Locale(identifier: "en_US_POSIX"))
        }
        return nil
    }
}
