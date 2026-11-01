import Foundation

public enum FMarketSessionStatus: String, Codable, Equatable, Sendable {
    case preOpen, continuous, lunchBreak, closed, unknown
}

public enum FQuoteTimeTrust: String, Codable, Equatable, Sendable {
    case verifiedExchangeTimestamp, fetchedAtOnly, unavailable
}

public enum FQuoteFreshness: String, Codable, Equatable, Sendable {
    case fresh, stale, unverified
}

/// Only source labels configured for the app's live security/index quote
/// providers may support a decision-grade quote. Arbitrary non-empty labels
/// remain displayable, but do not pass the shared freshness gate.
public enum FMarketQuoteTrustPolicy {
    public static let tencentMinuteSource = "Tencent Finance minute/query"
    public static let eastmoneyMinuteSource = "Eastmoney push2 实时分钟（Tencent 主源不可用时备用）"
    public static let tencentReferenceSource = "Tencent qt.gtimg.cn"
    public static let sinaIndexSource = "Sina Finance hq.sinajs.cn"
    public static let naverIndexSource = "Naver Finance"
    public static let trustedSources: Set<String> = [
        tencentMinuteSource, eastmoneyMinuteSource, tencentReferenceSource,
        sinaIndexSource, naverIndexSource
    ]

    public static func isTrusted(_ source: String?) -> Bool {
        guard let source else { return false }
        return trustedSources.contains(source.trimmingCharacters(in: .whitespacesAndNewlines))
    }

    public static func isTrustedReferenceSource(_ source: String?) -> Bool {
        source?.trimmingCharacters(in: .whitespacesAndNewlines) == tencentReferenceSource
    }
}

/// NAS transports archived bars, but the client still verifies which upstream
/// provider is allowed to have produced them for the requested market.
public enum FMarketBarTrustPolicy {
    public static let tencentDailySource = "Tencent Finance daily K-line (archived by F NAS)"
    public static let nikkeiDailyCloseSource = "Nikkei Indexes official daily close CSV (personal use)"
    public static let naverKospiDailySource = "Naver Finance KOSPI daily chart (public web endpoint)"
    public static let tencentMinuteArchiveSource = "Tencent Finance minute/query (public web endpoint)"
    public static let eastmoneyMinuteArchiveSource = "Eastmoney push2his 1-minute kline (public web endpoint)"

    public static func isTrustedSecurityDailySource(_ source: String?) -> Bool {
        source?.trimmingCharacters(in: .whitespacesAndNewlines) == tencentDailySource
    }

    public static func isTrustedIndexDailySource(_ source: String?, indexCode: String) -> Bool {
        let expected: String
        switch indexCode {
        case "sh000001", "sz399001", "sh000300", "sh000510", "sz399006", "usNDX", "hkHSI":
            expected = tencentDailySource
        case "int_nikkei":
            expected = nikkeiDailyCloseSource
        case "KOSPI":
            expected = naverKospiDailySource
        default:
            return false
        }
        return source?.trimmingCharacters(in: .whitespacesAndNewlines) == expected
    }

    public static func isTrustedRegimeHistorySource(_ source: String?, marketContext: String) -> Bool {
        if marketContext.hasPrefix("security:") {
            return isTrustedSecurityDailySource(source)
        }
        if marketContext.hasPrefix("index:") {
            return isTrustedIndexDailySource(source, indexCode: String(marketContext.dropFirst("index:".count)))
        }
        switch marketContext {
        case "CN", "US", "HK":
            return source?.trimmingCharacters(in: .whitespacesAndNewlines) == tencentDailySource
        case "JP":
            return source?.trimmingCharacters(in: .whitespacesAndNewlines) == nikkeiDailyCloseSource
        case "KR":
            return source?.trimmingCharacters(in: .whitespacesAndNewlines) == naverKospiDailySource
        default:
            return false
        }
    }

    public static func isTrustedMinuteArchiveSource(_ source: String?) -> Bool {
        guard let source else { return false }
        return [tencentMinuteArchiveSource, eastmoneyMinuteArchiveSource]
            .contains(source.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Provider labels permitted to contribute to Market Regime evidence. Breadth
/// remains disabled until a production source is explicitly configured.
public enum FMarketRegimeEvidenceTrustPolicy {
    private static let verifiedBreadthSourcesByMarket: [String: Set<String>] = [:]

    public static func isTrustedBenchmarkSource(_ source: String, indexCode: String) -> Bool {
        let expected: String
        switch indexCode {
        case "sh000001", "sz399001", "sh000300", "sh000510", "sz399006", "usNDX", "hkHSI":
            expected = FMarketBarTrustPolicy.tencentDailySource
        case "int_nikkei":
            expected = FMarketBarTrustPolicy.nikkeiDailyCloseSource
        case "KOSPI":
            expected = FMarketBarTrustPolicy.naverKospiDailySource
        default:
            return false
        }
        return source.trimmingCharacters(in: .whitespacesAndNewlines) == expected
    }

    public static func isTrustedBreadthSource(_ source: String, market: String) -> Bool {
        // No exchange breadth provider has passed source, timestamp, and coverage
        // verification yet. A nonempty caller supplied label is not evidence.
        guard let verifiedSources = verifiedBreadthSourcesByMarket[market] else { return false }
        return verifiedSources.contains(source.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Sources permitted to support NAS minute-research evidence. This is kept
/// separate from live-quote trust because archived provider labels differ.
public enum FResearchSourceTrustPolicy {
    public static let tencentMinuteSource = "Tencent Finance minute/query (public web endpoint)"
    public static let eastmoneyMinuteSource = "Eastmoney push2his 1-minute kline (public web endpoint)"
    public static let trustedSources: Set<String> = [tencentMinuteSource, eastmoneyMinuteSource]

    public static func isTrusted(_ source: String) -> Bool {
        trustedSources.contains(source.trimmingCharacters(in: .whitespacesAndNewlines))
    }
}

/// Keeps exchange time and local retrieval time distinct. A display label never
/// presents fetchedAt as if it were an exchange timestamp.
public struct FQuoteTemporalMetadata: Codable, Equatable, Sendable {
    /// Shared maximum age for treating a verified live quote as current.
    public static let defaultMaximumAge: TimeInterval = 120

    public let quoteTimestamp: Date?
    public let fetchedAt: Date?
    public let source: String?
    public let timestampTrust: FQuoteTimeTrust
    public let marketSessionStatus: FMarketSessionStatus

    public init(quoteTimestamp: Date?, fetchedAt: Date?, source: String?,
                timestampTrust: FQuoteTimeTrust, marketSessionStatus: FMarketSessionStatus) {
        self.quoteTimestamp = quoteTimestamp
        self.fetchedAt = fetchedAt
        self.source = source
        self.timestampTrust = timestampTrust
        self.marketSessionStatus = marketSessionStatus
    }

    public func freshness(at now: Date, maximumAge: TimeInterval = defaultMaximumAge) -> FQuoteFreshness {
        guard maximumAge.isFinite, maximumAge >= 0,
              timestampTrust == .verifiedExchangeTimestamp,
              let quoteTimestamp, let fetchedAt,
              FMarketQuoteTrustPolicy.isTrusted(source),
              quoteTimestamp <= fetchedAt, fetchedAt <= now, quoteTimestamp <= now,
              quoteTimestamp.timeIntervalSince1970.isFinite,
              fetchedAt.timeIntervalSince1970.isFinite else { return .unverified }
        return now.timeIntervalSince(quoteTimestamp) <= maximumAge ? .fresh : .stale
    }

    public func isConsistent(source: String, observedAt: Date?, capturedAt: Date) -> Bool {
        guard self.source == source,
              !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              capturedAt.timeIntervalSince1970.isFinite else { return false }
        switch timestampTrust {
        case .verifiedExchangeTimestamp:
            guard let quoteTimestamp, let fetchedAt, observedAt == quoteTimestamp else { return false }
            return quoteTimestamp.timeIntervalSince1970.isFinite &&
                fetchedAt.timeIntervalSince1970.isFinite &&
                quoteTimestamp <= fetchedAt && fetchedAt <= capturedAt
        case .fetchedAtOnly:
            guard quoteTimestamp == nil, observedAt == nil, let fetchedAt else { return false }
            return fetchedAt.timeIntervalSince1970.isFinite && fetchedAt <= capturedAt
        case .unavailable:
            return quoteTimestamp == nil && fetchedAt == nil && observedAt == nil
        }
    }

    public func displayLabel(timeZone: TimeZone) -> String {
        let hasSource = source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        if timestampTrust == .verifiedExchangeTimestamp, hasSource,
           let quoteTimestamp, let fetchedAt,
           quoteTimestamp.timeIntervalSince1970.isFinite,
           fetchedAt.timeIntervalSince1970.isFinite, quoteTimestamp <= fetchedAt {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = timeZone
            formatter.dateFormat = "M月d日 HH:mm:ss"
            let time = formatter.string(from: quoteTimestamp)
            let label = marketSessionStatus == .closed ? "已收盘 · \(time)" : "行情时间 · \(time)"
            return FMarketQuoteTrustPolicy.isTrusted(source) ? label : "\(label) · 来源未验证"
        }
        if timestampTrust == .fetchedAtOnly, hasSource, let fetchedAt,
           fetchedAt.timeIntervalSince1970.isFinite {
            let formatter = DateFormatter()
            formatter.locale = Locale(identifier: "zh_CN")
            formatter.timeZone = timeZone
            formatter.dateFormat = "HH:mm:ss"
            return "获取于 \(formatter.string(from: fetchedAt)) · 行情时间未验证"
        }
        return "时间未验证/来源未提供时间"
    }
}

/// Validates rendered centers once after zoom, rotation, and layout transforms.
/// Reuse this value during gestures so each hit-test remains logarithmic.
public struct FChartRenderedXCoordinates: Equatable, Sendable {
    fileprivate let centers: [Double]

    public init?(centers: [Double]) {
        guard !centers.isEmpty, centers.allSatisfy(\.isFinite),
              zip(centers, centers.dropFirst()).allSatisfy({ $0 < $1 }) else { return nil }
        self.centers = centers
    }
}

/// Uses validated rendered x-centers. Binary search keeps repeated hit-testing
/// bounded for large series, including during drag gestures.
public enum FChartHitTesting {
    public static func nearestPointIndex(tapX: Double, renderedCenters: [Double],
                                         hitRadius: Double) -> Int? {
        guard let coordinates = FChartRenderedXCoordinates(centers: renderedCenters) else { return nil }
        return nearestPointIndex(tapX: tapX, coordinates: coordinates, hitRadius: hitRadius)
    }

    public static func nearestPointIndex(tapX: Double,
                                         coordinates: FChartRenderedXCoordinates,
                                         hitRadius: Double) -> Int? {
        let renderedCenters = coordinates.centers
        guard tapX.isFinite, hitRadius.isFinite, hitRadius >= 0 else { return nil }
        var low = 0
        var high = renderedCenters.count
        while low < high {
            let middle = low + (high - low) / 2
            if renderedCenters[middle] < tapX { low = middle + 1 } else { high = middle }
        }
        let candidates = [low - 1, low].filter { renderedCenters.indices.contains($0) }
        guard candidates.allSatisfy({
            guard renderedCenters[$0].isFinite else { return false }
            let orderedBefore = $0 == 0 || renderedCenters[$0 - 1] < renderedCenters[$0]
            let orderedAfter = $0 + 1 == renderedCenters.count || renderedCenters[$0] < renderedCenters[$0 + 1]
            return orderedBefore && orderedAfter
        }) else { return nil }
        guard let bestDistance = candidates.map({ abs(renderedCenters[$0] - tapX) }).min(),
              bestDistance <= hitRadius else { return nil }
        let best = candidates.filter { abs(abs(renderedCenters[$0] - tapX) - bestDistance) < 1e-9 }
        return best.count == 1 ? best[0] : nil
    }
}

public enum FDividendYieldPreferenceMode: String, Codable, Equatable, Sendable {
    case automaticAI, customMinimum
}

/// Four percent is an optional reference in automatic mode, never an eligibility
/// gate. A hard minimum exists only when the user explicitly selects custom mode.
public struct FDividendYieldPreference: Codable, Equatable, Sendable {
    public let mode: FDividendYieldPreferenceMode
    public let referenceYield: Decimal
    public let customMinimumYield: Decimal?

    public init(mode: FDividendYieldPreferenceMode = .automaticAI,
                referenceYield: Decimal = Decimal(string: "0.04")!,
                customMinimumYield: Decimal? = nil) {
        self.mode = mode
        self.referenceYield = referenceYield
        self.customMinimumYield = customMinimumYield
    }

    public func validate() throws {
        guard referenceYield.isFinite, referenceYield >= 0, referenceYield <= 1,
              customMinimumYield.map({ $0.isFinite && $0 >= 0 && $0 <= 1 }) ?? true,
              mode != .customMinimum || customMinimumYield != nil else {
            throw FDividendYieldPreferenceError.invalidPreference
        }
    }

    public func passesCustomMinimum(currentYield: Decimal?) -> Bool {
        guard mode == .customMinimum, let customMinimumYield else { return true }
        guard let currentYield, currentYield.isFinite else { return false }
        return currentYield >= customMinimumYield
    }
}

public enum FDividendYieldPreferenceError: Error, Equatable, Sendable {
    case invalidPreference
}
