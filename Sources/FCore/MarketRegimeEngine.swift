import Foundation

public enum FMarketRegime: String, Codable, CaseIterable, Equatable, Sendable {
    case bullTrend, bearTrend, range, highVolatility, riskOff, extremeRisk
    case recovery, transition, uncertain, dataUnreliable

    public var displayName: String {
        switch self {
        case .bullTrend: return "上升趋势"
        case .bearTrend: return "下降趋势"
        case .range: return "震荡"
        case .highVolatility: return "高波动"
        case .riskOff: return "风险升高"
        case .extremeRisk: return "极端风险"
        case .recovery: return "修复阶段"
        case .transition: return "趋势转换"
        case .uncertain: return "证据冲突"
        case .dataUnreliable: return "数据不足/不可靠"
        }
    }
}

public enum FMarketRiskLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case r0Normal = 0, r1Elevated = 1, r2High = 2, r3Severe = 3, r4Extreme = 4
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }

    public var displayName: String {
        switch self {
        case .r0Normal: return "R0 正常"
        case .r1Elevated: return "R1 风险升高"
        case .r2High: return "R2 高风险"
        case .r3Severe: return "R3 严重风险"
        case .r4Extreme: return "R4 极端风险"
        }
    }
}

public enum FMarketContextKind: String, Codable, CaseIterable, Hashable, Sendable {
    case chinaAshare, usNasdaq100, japan, korea, hongKong, unclassified

    public var displayName: String {
        switch self {
        case .chinaAshare: return "A股市场"
        case .usNasdaq100: return "美股纳指100"
        case .japan: return "日本市场"
        case .korea: return "韩国市场"
        case .hongKong: return "香港市场"
        case .unclassified: return "对应市场未识别"
        }
    }

    public var requiredBenchmarks: [FMarketBenchmark] {
        switch self {
        case .chinaAshare: return [.sseComposite, .csi300, .csiA500]
        case .usNasdaq100: return [.nasdaq100]
        case .japan: return [.nikkei225]
        case .korea: return [.kospi]
        case .hongKong: return [.hangSeng]
        case .unclassified: return []
        }
    }

    public static func infer(securityCode: String, instrumentName: String? = nil) -> Self {
        let name = (instrumentName ?? "").lowercased()
        if securityCode == "159941" || name.contains("纳指") || name.contains("nasdaq") {
            return .usNasdaq100
        }
        if name.contains("日经") || name.contains("nikkei") || name.contains("日本") { return .japan }
        if name.contains("kospi") || name.contains("韩国") { return .korea }
        if name.contains("恒生") || name.contains("港股") || name.contains("hang seng") { return .hongKong }
        if securityCode == "159352" || name.contains("a500") || name.contains("中证a500") {
            return .chinaAshare
        }
        return .unclassified
    }
}

public enum FMarketBenchmark: String, Codable, CaseIterable, Hashable, Sendable {
    case sseComposite, csi300, csiA500, nasdaq100, sp500, nikkei225, topix, kospi, hangSeng, vix

    public var displayName: String {
        switch self {
        case .sseComposite: return "上证指数"
        case .csi300: return "沪深300"
        case .csiA500: return "中证A500"
        case .nasdaq100: return "纳斯达克100"
        case .sp500: return "标普500"
        case .nikkei225: return "日经225"
        case .topix: return "TOPIX"
        case .kospi: return "韩国KOSPI"
        case .hangSeng: return "恒生指数"
        case .vix: return "VIX"
        }
    }
}

/// Shared primary/secondary/global sensor mapping for one security.
/// Mapping declares relationships only; it never implies a sensor has usable data.
public struct FMarketBenchmarkMapping: Codable, Equatable, Sendable {
    public let securityID: String
    public let market: FMarketContextKind
    public let primaryBenchmark: FMarketBenchmark
    public let secondaryBenchmarks: [FMarketBenchmark]
    public let globalSensors: [FMarketBenchmark]
    public let supportsIOPV: Bool
    public let currency: String
    public let tradingSession: String

    public init(securityID: String, market: FMarketContextKind, primaryBenchmark: FMarketBenchmark,
                secondaryBenchmarks: [FMarketBenchmark] = [], globalSensors: [FMarketBenchmark] = [],
                supportsIOPV: Bool, currency: String, tradingSession: String) {
        self.securityID = securityID
        self.market = market
        self.primaryBenchmark = primaryBenchmark
        self.secondaryBenchmarks = Array(Set(secondaryBenchmarks)).filter { $0 != primaryBenchmark }
            .sorted { $0.rawValue < $1.rawValue }
        self.globalSensors = Array(Set(globalSensors)).sorted { $0.rawValue < $1.rawValue }
        self.supportsIOPV = supportsIOPV
        self.currency = currency
        self.tradingSession = tradingSession
    }

    public static func resolve(securityCode: String, instrumentName: String? = nil) -> FMarketBenchmarkMapping? {
        let name = (instrumentName ?? "").lowercased()
        let global: [FMarketBenchmark] = [.sseComposite, .csi300, .csiA500, .nasdaq100, .sp500, .hangSeng, .nikkei225, .topix, .kospi, .vix]
        func mapping(_ market: FMarketContextKind, _ primary: FMarketBenchmark,
                     _ secondary: [FMarketBenchmark], _ currency: String, _ session: String) -> Self {
            Self(securityID: securityCode, market: market, primaryBenchmark: primary,
                 secondaryBenchmarks: secondary, globalSensors: global,
                 supportsIOPV: false, // Enabled only when a verified, fresh IOPV source is wired.
                 currency: currency, tradingSession: session)
        }
        if securityCode == "159941" || name.contains("纳指") || name.contains("nasdaq") {
            return mapping(.usNasdaq100, .nasdaq100, [.sp500], "CNY", "CN-A-share-session")
        }
        if name.contains("日经") || name.contains("nikkei") || name.contains("日本") {
            return mapping(.japan, .nikkei225, [.topix], "CNY", "CN-A-share-session")
        }
        if name.contains("kospi") || name.contains("韩国") {
            return mapping(.korea, .kospi, [], "CNY", "CN-A-share-session")
        }
        if name.contains("恒生") || name.contains("港股") || name.contains("hang seng") {
            return mapping(.hongKong, .hangSeng, [], "CNY", "CN-A-share-session")
        }
        if securityCode == "159352" || name.contains("a500") || name.contains("中证a500") {
            return mapping(.chinaAshare, .csiA500, [.csi300, .sseComposite], "CNY", "CN-A-share-session")
        }
        if name.contains("沪深300") || name.contains("csi 300") {
            return mapping(.chinaAshare, .csi300, [.sseComposite], "CNY", "CN-A-share-session")
        }
        if name.contains("上证") || name.contains("sse") {
            return mapping(.chinaAshare, .sseComposite, [.csi300, .csiA500], "CNY", "CN-A-share-session")
        }
        return nil
    }
}

public enum FGlobalRegime: String, Codable, CaseIterable, Sendable {
    case riskOn, neutral, riskOff, extreme, uncertain

    public var displayName: String {
        switch self {
        case .riskOn: return "全球风险偏好"
        case .neutral: return "全球中性"
        case .riskOff: return "全球风险规避"
        case .extreme: return "全球极端风险"
        case .uncertain: return "全球状态不确定"
        }
    }
}

public struct FIndexRegimeSnapshot: Codable, Equatable, Sendable, Identifiable {
    public var id: String { benchmark.rawValue }
    public let benchmark: FMarketBenchmark
    public let regime: FMarketRegime
    public let riskLevel: FMarketRiskLevel
    public let trend: String
    public let volatility: String
    public let freshness: String
    public let observedAt: Date?
    public let source: String?
    public let available: Bool
    public let unavailableReason: String?
}

public enum FQuantStrategyKind: String, Codable, CaseIterable, Hashable, Sendable {
    case meanReversion, trendPullback, vwapDeviation, maStructure, premiumIOPV
}

/// Timestamped, observed market data. Inputs after the evaluation as-of time are
/// discarded by the engine, which makes the same API usable for historical replay.
public struct FMarketRegimeBar: Codable, Equatable, Sendable {
    public let timestamp: Date
    public let open: Double?
    public let high: Double?
    public let low: Double?
    public let close: Double
    public let volume: Double?

    public init(timestamp: Date, close: Double, open: Double? = nil, high: Double? = nil,
                low: Double? = nil, volume: Double? = nil) {
        self.timestamp = timestamp
        self.close = close
        self.open = open
        self.high = high
        self.low = low
        self.volume = volume
    }
}

/// A benchmark close-to-close observation with an explicit timestamp and source.
/// Without a timestamped observation, the benchmark is unavailable to the engine.
public struct FMarketBenchmarkObservation: Codable, Equatable, Sendable, Identifiable {
    public var id: String { benchmark.rawValue + "@" + observedAt.timeIntervalSince1970.description }
    public let benchmark: FMarketBenchmark
    public let dailyReturn: Double
    public let observedAt: Date
    public let source: String

    public init(benchmark: FMarketBenchmark, dailyReturn: Double, observedAt: Date, source: String) {
        self.benchmark = benchmark
        self.dailyReturn = dailyReturn
        self.observedAt = observedAt
        self.source = source
    }
}

public struct FMarketRegimeInput: Sendable {
    public let market: String
    public let securityCode: String?
    public let contextKind: FMarketContextKind
    public let asOf: Date
    public let sessionTimeZoneIdentifier: String
    public let sourceUpdatedAt: Date?
    public let source: String?
    public let bars: [FMarketRegimeBar]
    /// Optional breadth as advancers / (advancers + decliners), in 0...1.
    public let breadthRatio: Double?
    /// Returns from separately observed, synchronized benchmarks. Missing
    /// benchmarks remain unavailable and are never synthesized.
    public let synchronizedBenchmarkReturns: [Double]
    public let benchmarkObservations: [FMarketBenchmarkObservation]
    public let benchmarkMapping: FMarketBenchmarkMapping?

    public init(market: String, securityCode: String? = nil,
                contextKind: FMarketContextKind = .unclassified, asOf: Date,
                sessionTimeZoneIdentifier: String = "Asia/Shanghai",
                sourceUpdatedAt: Date?, source: String?, bars: [FMarketRegimeBar],
                breadthRatio: Double? = nil, synchronizedBenchmarkReturns: [Double] = [],
                benchmarkObservations: [FMarketBenchmarkObservation] = [],
                benchmarkMapping: FMarketBenchmarkMapping? = nil) {
        self.market = market
        self.securityCode = securityCode
        self.contextKind = contextKind
        self.asOf = asOf
        self.sessionTimeZoneIdentifier = sessionTimeZoneIdentifier
        self.sourceUpdatedAt = sourceUpdatedAt
        self.source = source
        self.bars = bars
        self.breadthRatio = breadthRatio
        self.synchronizedBenchmarkReturns = synchronizedBenchmarkReturns
        self.benchmarkObservations = benchmarkObservations
        self.benchmarkMapping = benchmarkMapping
    }
}

public struct FMarketRegimeFactor: Codable, Equatable, Sendable, Identifiable {
    public var id: String { key }
    public let key: String
    public let value: Double?
    public let available: Bool
    public let reason: String

    public init(key: String, value: Double?, available: Bool, reason: String) {
        self.key = key
        self.value = value
        self.available = available
        self.reason = reason
    }
}

public struct FMarketRegimeMemory: Codable, Equatable, Sendable {
    public let confirmedRegime: FMarketRegime
    public let confirmedRiskLevel: FMarketRiskLevel
    public let pendingRegime: FMarketRegime?
    public let pendingRegimeSessions: Int
    public let pendingRiskLevel: FMarketRiskLevel?
    public let pendingRiskSessions: Int
    public let lastEvaluationAt: Date

    public init(confirmedRegime: FMarketRegime, confirmedRiskLevel: FMarketRiskLevel,
                pendingRegime: FMarketRegime? = nil, pendingRegimeSessions: Int = 0,
                pendingRiskLevel: FMarketRiskLevel? = nil, pendingRiskSessions: Int = 0,
                lastEvaluationAt: Date) {
        self.confirmedRegime = confirmedRegime
        self.confirmedRiskLevel = confirmedRiskLevel
        self.pendingRegime = pendingRegime
        self.pendingRegimeSessions = pendingRegimeSessions
        self.pendingRiskLevel = pendingRiskLevel
        self.pendingRiskSessions = pendingRiskSessions
        self.lastEvaluationAt = lastEvaluationAt
    }
}

public struct FMarketRegimeAssessment: Codable, Equatable, Sendable {
    public let market: String
    public let securityCode: String?
    public let contextKind: FMarketContextKind
    public let requiredBenchmarks: [FMarketBenchmark]
    public let availableBenchmarks: [FMarketBenchmark]
    public let unavailableBenchmarks: [FMarketBenchmark]
    public let secondaryBenchmarks: [FMarketBenchmark]
    public let globalSensors: [FMarketBenchmark]
    public let globalRegime: FGlobalRegime
    public let primaryBenchmark: FMarketBenchmark?
    public let regime: FMarketRegime
    public let riskLevel: FMarketRiskLevel
    /// Evidence-strength score, not a forecast or probability of profit.
    public let confidence: Int
    public let factors: [FMarketRegimeFactor]
    public let reasons: [String]
    public let dataAsOf: Date?
    public let movingAverages: [Int: Double]
    public let return5Sessions: Double?
    public let return20Sessions: Double?
    public let drawdown20Sessions: Double?
    public let realizedVolatility20Sessions: Double?
    public let volumeExpansion: Double?
    public let allowedStrategies: Set<FQuantStrategyKind>
    public let observationOnly: Bool
    public let ordinaryTBuyAllowed: Bool
    public let memory: FMarketRegimeMemory
}

/// Deterministic, multi-factor state classifier. It reports unavailable factors
/// explicitly, confirms ordinary state changes over multiple sessions, and
/// escalates R4 immediately when several independent crash-risk signals agree.
public enum FMarketRegimeEngine {
    public static func evaluate(_ input: FMarketRegimeInput,
                                previous: FMarketRegimeMemory? = nil,
                                now: Date = Date(),
                                maximumDataAge: TimeInterval = 5 * 86_400) -> FMarketRegimeAssessment {
        let sourceIsValid = input.source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let sourceTime = input.sourceUpdatedAt
        let sourceIsFresh = sourceTime.map {
            $0 <= input.asOf && $0 <= now && now.timeIntervalSince($0) <= maximumDataAge
        } ?? false
        let bars = input.bars
            .filter { $0.timestamp <= input.asOf && $0.timestamp <= now && $0.close.isFinite && $0.close > 0 }
            .sorted { $0.timestamp < $1.timestamp }
        let uniqueBars = Dictionary(bars.map { ($0.timestamp, $0) }, uniquingKeysWith: { _, latest in latest })
            .values.sorted { $0.timestamp < $1.timestamp }
        let closes = uniqueBars.map(\.close)
        let validIdentity = !input.market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let dataReliable = validIdentity && sourceIsValid && sourceIsFresh && closes.count >= 60 &&
            input.asOf <= now && (previous == nil || previous!.lastEvaluationAt <= input.asOf)

        let ma20 = averageTail(closes, count: 20)
        let ma60 = averageTail(closes, count: 60)
        let ma120 = closes.count >= 120 ? averageTail(closes, count: 120) : nil
        let ma250 = closes.count >= 250 ? averageTail(closes, count: 250) : nil
        let ret5 = returnOver(closes, sessions: 5)
        let ret20 = returnOver(closes, sessions: 20)
        let drawdown20 = drawdown(closes, lookback: 20)
        let vol20 = realizedVolatility(closes, count: 20)
        let volumeExpansion = volumeExpansionRatio(uniqueBars)
        let breadth = input.breadthRatio.flatMap { $0.isFinite && (0...1).contains($0) ? $0 : nil }
        let freshBenchmarkObservations = input.benchmarkObservations.filter { item in
            item.dailyReturn.isFinite &&
            !item.source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            item.observedAt <= input.asOf && item.observedAt <= now &&
            now.timeIntervalSince(item.observedAt) <= maximumDataAge
        }
        let observedReturns = Dictionary(freshBenchmarkObservations.map { ($0.benchmark, $0.dailyReturn) },
                                         uniquingKeysWith: { _, latest in latest })
        let marketBenchmarkReturns = Array(observedReturns.values)
        let benchmarkReturns = input.synchronizedBenchmarkReturns.filter(\.isFinite) + marketBenchmarkReturns
        let negativeBenchmarks = benchmarkReturns.filter { $0 <= -0.04 }.count
        let mapping = input.benchmarkMapping
        let primaryBenchmark = mapping?.primaryBenchmark
        let requiredBenchmarks = primaryBenchmark.map { [$0] } ?? input.contextKind.requiredBenchmarks
        let availableBenchmarks = requiredBenchmarks.filter { observedReturns[$0]?.isFinite == true }
        let unavailableBenchmarks = requiredBenchmarks.filter { observedReturns[$0]?.isFinite != true }
        let marketContextComplete = mapping != nil && input.contextKind != .unclassified && unavailableBenchmarks.isEmpty
        let secondaryBenchmarks = mapping?.secondaryBenchmarks ?? []
        let globalSensors = mapping?.globalSensors ?? []
        let allMappedSensors = Set(requiredBenchmarks + secondaryBenchmarks + globalSensors)
        let unavailableMappedSensors = allMappedSensors.filter { observedReturns[$0]?.isFinite != true }.sorted { $0.rawValue < $1.rawValue }
        let synchronizedReadings = freshBenchmarkObservations
            .filter { globalSensors.contains($0.benchmark) && $0.benchmark != .vix }
        let globalAnchor = synchronizedReadings.map(\.observedAt).max()
        let globalWindow = synchronizedReadings.filter { item in
            guard let globalAnchor else { return false }
            return globalAnchor.timeIntervalSince(item.observedAt) <= 48 * 60 * 60
        }
        let regionalGroups: [[FMarketBenchmark]] = [
            [.sseComposite, .csi300, .csiA500],
            [.nasdaq100, .sp500],
            [.hangSeng],
            [.nikkei225, .topix],
            [.kospi]
        ]
        let regionalReturns: [Double] = regionalGroups.compactMap { group in
            let values = globalWindow.filter { group.contains($0.benchmark) }.map(\.dailyReturn)
            guard !values.isEmpty else { return nil }
            return values.reduce(0, +) / Double(values.count)
        }
        let deterioratingRegions = regionalReturns.filter { $0 <= -0.04 }.count
        let stronglyDeterioratingRegions = regionalReturns.filter { $0 <= -0.06 }.count
        let improvingRegions = regionalReturns.filter { $0 >= 0.02 }.count
        let globalRegime: FGlobalRegime = {
            guard regionalReturns.count >= 2 else { return .uncertain }
            if stronglyDeterioratingRegions >= 4 { return .extreme }
            if deterioratingRegions >= 3 { return .riskOff }
            if improvingRegions >= 3 { return .riskOn }
            return .neutral
        }()

        let factors = [
            factor("trend_MA20_60", value: ma20.flatMap { a in ma60.map { a / $0 - 1 } },
                   reason: "MA20/MA60排列；至少需要60个有效收盘样本"),
            factor("trend_slope", value: movingAverageSlope(closes, period: 20, lag: 5),
                   reason: "MA20五个交易日斜率"),
            factor("drawdown_20", value: drawdown20, reason: "近20个交易日相对高点回撤"),
            factor("return_5", value: ret5, reason: "近5个交易日跌速"),
            factor("volatility_20", value: vol20, reason: "近20个交易日实现波动率"),
            factor("volume_expansion", value: volumeExpansion, reason: "近5日与此前15日平均成交量比"),
            factor("market_breadth", value: breadth, reason: breadth == nil ? "上涨/下跌家数不可用" : "上涨家数占比"),
            factor("synchronized_benchmarks", value: benchmarkReturns.isEmpty ? nil : Double(negativeBenchmarks),
                   reason: benchmarkReturns.isEmpty ? "同步宽基指数数据不可用" : "同步下跌宽基指数数量")
        ]

        let crashSignals = [
            ret5.map { $0 <= -0.07 } ?? false,
            drawdown20.map { $0 <= -0.14 } ?? false,
            vol20.map { $0 >= 0.35 } ?? false,
            volumeExpansion.map { $0 >= 1.8 } ?? false,
            breadth.map { $0 <= 0.30 } ?? false,
            negativeBenchmarks >= 2
        ]
        let crashCount = crashSignals.filter { $0 }.count
        let candidateRisk: FMarketRiskLevel
        if crashCount >= 3 { candidateRisk = .r4Extreme }
        else if crashCount >= 2 { candidateRisk = .r3Severe }
        else if crashCount == 1 { candidateRisk = .r2High }
        else if (ret5.map { $0 <= -0.035 } ?? false) || (vol20.map { $0 >= 0.25 } ?? false) {
            candidateRisk = .r1Elevated
        } else { candidateRisk = .r0Normal }

        let candidateRegime: FMarketRegime
        if !dataReliable {
            candidateRegime = .dataUnreliable
        } else if candidateRisk == .r4Extreme {
            candidateRegime = .extremeRisk
        } else if let ret5, let ret20, let ma20, let ma60, let last = closes.last {
            let bullishStructure = last > ma20 && ma20 > ma60 &&
                (movingAverageSlope(closes, period: 20, lag: 5) ?? 0) > 0 && ret20 > 0.02
            let bearishStructure = last < ma20 && ma20 < ma60 && ret20 < -0.02
            let wasRisky = previous.map {
                [.bearTrend, .riskOff, .extremeRisk].contains($0.confirmedRegime)
            } ?? false
            if wasRisky && ret5 > 0.025 && !bullishStructure {
                candidateRegime = .recovery
            } else if vol20.map({ $0 >= 0.35 }) == true {
                candidateRegime = .highVolatility
            } else if candidateRisk >= .r2High {
                candidateRegime = .riskOff
            } else if bullishStructure {
                candidateRegime = previous?.confirmedRegime == .bearTrend ? .transition : .bullTrend
            } else if bearishStructure {
                candidateRegime = previous?.confirmedRegime == .bullTrend ? .transition : .bearTrend
            } else if abs(ret20) < 0.04 && abs(last / ma20 - 1) < 0.04 {
                candidateRegime = .range
            } else if abs(ret5) > 0.04 || abs(ret20) > 0.08 {
                candidateRegime = .transition
            } else {
                candidateRegime = .uncertain
            }
        } else {
            candidateRegime = .uncertain
        }

        let confirmedRegime: FMarketRegime
        let pendingRegime: FMarketRegime?
        let pendingRegimeSessions: Int
        var sessionCalendar = Calendar(identifier: .gregorian)
        sessionCalendar.timeZone = TimeZone(identifier: input.sessionTimeZoneIdentifier) ?? .gmt
        let evaluationSession = sessionCalendar.startOfDay(for: input.asOf)
        let previousSession = previous.map { sessionCalendar.startOfDay(for: $0.lastEvaluationAt) }
        let isNewSession = previousSession.map { $0 < evaluationSession } ?? true
        if previous == nil || candidateRegime == .dataUnreliable || candidateRegime == .extremeRisk ||
            candidateRegime == previous?.confirmedRegime {
            confirmedRegime = candidateRegime
            pendingRegime = nil
            pendingRegimeSessions = 0
        } else {
            let count = candidateRegime == previous?.pendingRegime
                ? previous!.pendingRegimeSessions + (isNewSession ? 1 : 0) : 1
            if count >= 3 {
                confirmedRegime = candidateRegime
                pendingRegime = nil
                pendingRegimeSessions = 0
            } else {
                confirmedRegime = previous!.confirmedRegime
                pendingRegime = candidateRegime
                pendingRegimeSessions = count
            }
        }

        let confirmedRisk: FMarketRiskLevel
        let pendingRisk: FMarketRiskLevel?
        let pendingRiskSessions: Int
        if previous == nil || candidateRisk == .r4Extreme || candidateRisk == previous?.confirmedRiskLevel {
            confirmedRisk = candidateRisk
            pendingRisk = nil
            pendingRiskSessions = 0
        } else {
            let count = candidateRisk == previous?.pendingRiskLevel
                ? previous!.pendingRiskSessions + (isNewSession ? 1 : 0) : 1
            if candidateRisk > previous!.confirmedRiskLevel && count >= 2 {
                confirmedRisk = candidateRisk
                pendingRisk = nil
                pendingRiskSessions = 0
            } else if candidateRisk < previous!.confirmedRiskLevel && count >= 3 {
                confirmedRisk = FMarketRiskLevel(rawValue: previous!.confirmedRiskLevel.rawValue - 1) ?? candidateRisk
                pendingRisk = confirmedRisk == candidateRisk ? nil : candidateRisk
                pendingRiskSessions = 0
            } else {
                confirmedRisk = previous!.confirmedRiskLevel
                pendingRisk = candidateRisk
                pendingRiskSessions = count
            }
        }

        let regime: FMarketRegime = !dataReliable ? .dataUnreliable :
            (confirmedRisk == .r4Extreme ? .extremeRisk : confirmedRegime)
        let reasons = reasonList(regime: regime, risk: confirmedRisk, drawdown: drawdown20,
                                 volatility: vol20, breadth: breadth, crashCount: crashCount,
                                 pending: pendingRegime)
        let benchmarkReasons = input.contextKind == .unclassified
            ? ["market_context_unclassified"]
            : unavailableBenchmarks.map { "benchmark_unavailable_\($0.rawValue)" }
        let usableFactorCount = factors.filter(\.available).count
        let confidence = dataReliable ? min(100, 35 + usableFactorCount * 8) : 0
        let strategies = strategyPolicy(regime: regime, risk: confirmedRisk, reliable: dataReliable, global: globalRegime)
        let memory = FMarketRegimeMemory(
            confirmedRegime: regime, confirmedRiskLevel: confirmedRisk,
            pendingRegime: pendingRegime, pendingRegimeSessions: pendingRegimeSessions,
            pendingRiskLevel: pendingRisk, pendingRiskSessions: pendingRiskSessions,
            lastEvaluationAt: input.asOf)

        return FMarketRegimeAssessment(
            market: input.market, securityCode: input.securityCode,
            contextKind: input.contextKind, requiredBenchmarks: requiredBenchmarks,
            availableBenchmarks: availableBenchmarks, unavailableBenchmarks: unavailableBenchmarks,
            secondaryBenchmarks: secondaryBenchmarks, globalSensors: globalSensors,
            globalRegime: globalRegime, primaryBenchmark: primaryBenchmark, regime: regime,
            riskLevel: confirmedRisk, confidence: confidence, factors: factors,
            reasons: reasons + benchmarkReasons + unavailableMappedSensors.map { "sensor_unavailable_\($0.rawValue)" },
            dataAsOf: uniqueBars.last?.timestamp,
            movingAverages: [20: ma20, 60: ma60, 120: ma120, 250: ma250].compactMapValues { $0 },
            return5Sessions: ret5, return20Sessions: ret20, drawdown20Sessions: drawdown20,
            realizedVolatility20Sessions: vol20, volumeExpansion: volumeExpansion,
            allowedStrategies: marketContextComplete ? strategies : [],
            observationOnly: !marketContextComplete ||
                [.recovery, .transition, .uncertain, .highVolatility, .riskOff, .extremeRisk, .dataUnreliable].contains(regime),
            ordinaryTBuyAllowed: dataReliable && marketContextComplete && confirmedRisk < .r2High &&
                ![.riskOff, .extreme].contains(globalRegime) &&
                [.bullTrend, .range].contains(regime),
            memory: memory)
    }

    private static func factor(_ key: String, value: Double?, reason: String) -> FMarketRegimeFactor {
        FMarketRegimeFactor(key: key, value: value, available: value?.isFinite == true, reason: reason)
    }
    private static func averageTail(_ values: [Double], count: Int) -> Double? {
        guard values.count >= count else { return nil }
        let tail = values.suffix(count)
        let result = tail.reduce(0, +) / Double(count)
        return result.isFinite ? result : nil
    }
    private static func returnOver(_ values: [Double], sessions: Int) -> Double? {
        guard values.count > sessions, let last = values.last else { return nil }
        let base = values[values.count - sessions - 1]
        let result = last / base - 1
        return result.isFinite ? result : nil
    }
    private static func drawdown(_ values: [Double], lookback: Int) -> Double? {
        guard values.count >= lookback, let last = values.last else { return nil }
        guard let peak = values.suffix(lookback).max(), peak > 0 else { return nil }
        return last / peak - 1
    }
    private static func realizedVolatility(_ values: [Double], count: Int) -> Double? {
        guard values.count > count else { return nil }
        let sample = Array(values.suffix(count + 1))
        let returns = zip(sample.dropLast(), sample.dropFirst()).map { current, prior in current / prior - 1 }
        guard !returns.isEmpty else { return nil }
        let mean = returns.reduce(0, +) / Double(returns.count)
        let variance = returns.map { pow($0 - mean, 2) }.reduce(0, +) / Double(returns.count)
        let result = sqrt(variance) * sqrt(252)
        return result.isFinite ? result : nil
    }
    private static func movingAverageSlope(_ values: [Double], period: Int, lag: Int) -> Double? {
        guard values.count >= period + lag,
              let current = averageTail(values, count: period) else { return nil }
        let prior = Array(values.dropLast(lag))
        guard let previous = averageTail(prior, count: period), previous > 0 else { return nil }
        return current / previous - 1
    }
    private static func volumeExpansionRatio(_ bars: [FMarketRegimeBar]) -> Double? {
        guard bars.count >= 20 else { return nil }
        let recent = bars.suffix(5).compactMap(\.volume)
        let prior = bars.suffix(20).dropLast(5).compactMap(\.volume)
        guard recent.count == 5, prior.count == 15 else { return nil }
        let baseline = prior.reduce(0, +) / 15
        guard baseline > 0 else { return nil }
        return (recent.reduce(0, +) / 5) / baseline
    }
    private static func strategyPolicy(regime: FMarketRegime, risk: FMarketRiskLevel,
                                       reliable: Bool, global: FGlobalRegime) -> Set<FQuantStrategyKind> {
        guard reliable, risk < .r4Extreme else { return [] }
        var allowed: Set<FQuantStrategyKind>
        switch regime {
        case .bullTrend: allowed = [.trendPullback, .maStructure, .vwapDeviation]
        case .range: allowed = [.meanReversion, .vwapDeviation]
        case .bearTrend: allowed = [.maStructure]
        case .highVolatility: allowed = [.maStructure]
        case .recovery, .transition: allowed = [.maStructure]
        case .riskOff, .extremeRisk, .uncertain, .dataUnreliable: allowed = []
        }
        if [.riskOff, .extreme].contains(global) {
            allowed.subtract([.meanReversion, .vwapDeviation])
        }
        return allowed
    }
    private static func reasonList(regime: FMarketRegime, risk: FMarketRiskLevel,
                                   drawdown: Double?, volatility: Double?, breadth: Double?,
                                   crashCount: Int, pending: FMarketRegime?) -> [String] {
        var result = ["regime_\(regime.rawValue)", "risk_R\(risk.rawValue)"]
        if let drawdown, drawdown <= -0.10 { result.append("drawdown_deteriorating") }
        if let volatility, volatility >= 0.035 { result.append("volatility_expanded") }
        if let breadth, breadth <= 0.30 { result.append("market_breadth_weak") }
        if crashCount >= 2 { result.append("multiple_independent_crash_factors_\(crashCount)") }
        if let pending { result.append("regime_confirmation_pending_\(pending.rawValue)") }
        if regime == .dataUnreliable { result.append("insufficient_or_stale_market_data") }
        return result
    }
}
