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

public enum FQuantStrategyKind: String, Codable, CaseIterable, Hashable, Sendable {
    case meanReversion, trendPullback, vwapDeviation, maStructure, premiumIOPV

    /// Qualification IDs are a wire contract; unknown IDs must not inherit a
    /// regime permission by guesswork.
    public init?(qualificationID: String) {
        switch qualificationID {
        case "meanReversion", "MeanReversion": self = .meanReversion
        case "trendPullback", "TrendPullback": self = .trendPullback
        case "vwapDeviation", "VWAPDeviation": self = .vwapDeviation
        case "maStructure", "MAStructure": self = .maStructure
        case "premiumIOPV", "PremiumIOPV": self = .premiumIOPV
        default: return nil
        }
    }
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

/// Source-qualified advancing/declining counts. Breadth is only used while both
/// the exchange observation and its capture time are fresh for the evaluation.
public struct FMarketRegimeBreadthObservation: Codable, Equatable, Sendable {
    public let market: String
    public let advancingCount: Int64
    public let decliningCount: Int64
    public let observedAt: Date
    public let capturedAt: Date
    public let source: String

    public init(market: String, advancingCount: Int64, decliningCount: Int64,
                observedAt: Date, capturedAt: Date, source: String) {
        self.market = market
        self.advancingCount = advancingCount
        self.decliningCount = decliningCount
        self.observedAt = observedAt
        self.capturedAt = capturedAt
        self.source = source
    }
}

/// An independently sourced index observation used as supporting market-risk
/// evidence. `sessionReturn` is a decimal return (for example, -0.04 = -4%).
public struct FMarketRegimeBenchmarkObservation: Codable, Equatable, Sendable, Identifiable {
    public var id: String { marketCode }
    public let marketContext: String
    public let marketCode: String
    /// Start of the close-to-close return interval. Nil legacy observations are
    /// displayable but cannot count as synchronized multi-index evidence.
    public let sessionStartAt: Date?
    public let observedAt: Date
    public let capturedAt: Date
    public let source: String
    public let sessionReturn: Double

    public init(marketContext: String, marketCode: String, observedAt: Date,
                sessionStartAt: Date? = nil, capturedAt: Date,
                source: String, sessionReturn: Double) {
        self.marketContext = marketContext
        self.marketCode = marketCode
        self.sessionStartAt = sessionStartAt
        self.observedAt = observedAt
        self.capturedAt = capturedAt
        self.source = source
        self.sessionReturn = sessionReturn
    }
}

/// Source-bound relationship between a locally traded security and the market
/// index named by its issuer. This identifies context only; it does not qualify
/// a strategy or make the index regime a substitute for the security's own data.
public struct FMarketIndexSecurityMapping: Equatable, Sendable, Identifiable {
    public var id: String { securityCode }
    public let securityCode: String
    public let indexCode: String
    public let indexName: String
    public let sourceURL: String

    public init(securityCode: String, indexCode: String, indexName: String, sourceURL: String) {
        self.securityCode = securityCode
        self.indexCode = indexCode
        self.indexName = indexName
        self.sourceURL = sourceURL
    }
}

/// Only mappings backed by the issuer's stated benchmark belong here. Unknown
/// funds remain unmapped instead of inheriting a broad market by code or name.
public enum FMarketIndexSecurityMappingRegistry {
    public static let mappings: [FMarketIndexSecurityMapping] = [
        FMarketIndexSecurityMapping(
            securityCode: "159352", indexCode: "sh000510", indexName: "中证A500",
            sourceURL: "https://www.nffund.com/new/personal-financing/detail.html?fundCode=159352&tab=redemption-list"),
        FMarketIndexSecurityMapping(
            securityCode: "159941", indexCode: "usNDX", indexName: "Nasdaq-100",
            sourceURL: "https://www.gffunds.com.cn/funds/?fundcode=159941")
    ]

    public static func mapping(for securityCode: String) -> FMarketIndexSecurityMapping? {
        mappings.first { $0.securityCode == securityCode }
    }
}

public struct FMarketRegimeInput: Sendable {
    public let market: String
    public let securityCode: String?
    public let asOf: Date
    public let sourceUpdatedAt: Date?
    public let source: String?
    public let bars: [FMarketRegimeBar]
    /// Optional timestamped/source-qualified advancing and declining counts.
    public let breadthObservation: FMarketRegimeBreadthObservation?
    /// Identified benchmark observations. The evaluator filters stale, future,
    /// malformed, and duplicate-market inputs before using them.
    public let benchmarkObservations: [FMarketRegimeBenchmarkObservation]

    public init(market: String, securityCode: String? = nil, asOf: Date,
                sourceUpdatedAt: Date?, source: String?, bars: [FMarketRegimeBar],
                breadthObservation: FMarketRegimeBreadthObservation? = nil,
                benchmarkObservations: [FMarketRegimeBenchmarkObservation] = []) {
        self.market = market
        self.securityCode = securityCode
        self.asOf = asOf
        self.sourceUpdatedAt = sourceUpdatedAt
        self.source = source
        self.bars = bars
        self.breadthObservation = breadthObservation
        self.benchmarkObservations = benchmarkObservations
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
    /// Timestamp of the latest market bar used for confirmation. Re-fetching
    /// the same bar must not count as another market session.
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

public struct FMarketRegimeAssessment: Equatable, Sendable {
    public let market: String
    public let securityCode: String?
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
    private static let maximumBenchmarkAge: TimeInterval = 36 * 60 * 60
    private static let maximumBreadthAge: TimeInterval = 2 * 60 * 60
    /// End-of-session observations from the covered Asian and US markets can
    /// differ by several hours. Wider gaps may describe different sessions.
    private static let maximumBenchmarkSynchronizationSpan: TimeInterval = 18 * 60 * 60

    public static func evaluate(_ input: FMarketRegimeInput,
                                previous: FMarketRegimeMemory? = nil,
                                now: Date = Date(),
                                maximumDataAge: TimeInterval = 5 * 86_400) -> FMarketRegimeAssessment {
        let maximumAgeIsValid = maximumDataAge.isFinite && maximumDataAge >= 0
        let previousMemoryIsValid = previous.map(isValidMemory) ?? true
        var priorMemory = previousMemoryIsValid ? previous : nil
        let sourceIsValid = FMarketBarTrustPolicy.isTrustedRegimeHistorySource(
            input.source, marketContext: input.market)
        let sourceTime = input.sourceUpdatedAt
        let sourceIsFresh = maximumAgeIsValid && (sourceTime.map {
            $0 <= input.asOf && $0 <= now && now.timeIntervalSince($0) <= maximumDataAge
        } ?? false)
        let hasInvalidBarTimestamp = input.bars.contains {
            !$0.timestamp.timeIntervalSince1970.isFinite
        }
        let hasInvalidBarValues = input.bars.contains {
            $0.timestamp.timeIntervalSince1970.isFinite &&
            $0.timestamp <= input.asOf && $0.timestamp <= now && !hasValidPriceData($0)
        }
        let bars = input.bars
            .filter { $0.timestamp.timeIntervalSince1970.isFinite &&
                $0.timestamp <= input.asOf && $0.timestamp <= now && hasValidPriceData($0) }
            .sorted { $0.timestamp < $1.timestamp }
        let barsByTimestamp = Dictionary(grouping: bars, by: \.timestamp)
        let hasConflictingDuplicateBars = barsByTimestamp.values.contains { group in
            guard let first = group.first else { return false }
            return group.contains { $0 != first }
        }
        let uniqueBars = barsByTimestamp.values.compactMap { group -> FMarketRegimeBar? in
            guard let first = group.first, group.allSatisfy({ $0 == first }) else { return nil }
            return first
        }.sorted { $0.timestamp < $1.timestamp }
        let closes = uniqueBars.map(\.close)
        let hasIntradayBarSpacing = zip(uniqueBars, uniqueBars.dropFirst()).contains { pair in
            pair.1.timestamp.timeIntervalSince(pair.0.timestamp) < 12 * 60 * 60
        }
        let dailyBarSpacingIsReliable = uniqueBars.count >= 2 && !hasIntradayBarSpacing
        let latestBarTimestamp = uniqueBars.last?.timestamp
        if let memory = priorMemory, let latestBarTimestamp {
            let memoryBarGap = latestBarTimestamp.timeIntervalSince(memory.lastEvaluationAt)
            if memoryBarGap < 0 || memoryBarGap > maximumDataAge {
                // Do not let a dormant or future checkpoint hold the market in
                // an obsolete confirmed regime while new bars are evaluated.
                priorMemory = nil
            }
        }
        let latestBarIsFresh = maximumAgeIsValid && (latestBarTimestamp.map {
            $0 <= input.asOf && $0 <= now && now.timeIntervalSince($0) <= maximumDataAge
        } ?? false)
        let validIdentity = !input.market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        let ma20 = averageTail(closes, count: 20)
        let ma60 = averageTail(closes, count: 60)
        let ma120 = closes.count >= 120 ? averageTail(closes, count: 120) : nil
        let ma250 = closes.count >= 250 ? averageTail(closes, count: 250) : nil
        let ret5 = returnOver(closes, sessions: 5)
        let ret20 = returnOver(closes, sessions: 20)
        let drawdown20 = drawdown(closes, lookback: 20)
        let vol20 = realizedVolatility(closes, count: 20)
        let trendSlope = movingAverageSlope(closes, period: 20, lag: 5)
        let coreFactorsAreReliable = ma20 != nil && ma60 != nil && ret5 != nil && ret20 != nil &&
            drawdown20 != nil && vol20 != nil && trendSlope != nil && dailyBarSpacingIsReliable
        let dataReliable = maximumAgeIsValid && validIdentity && sourceIsValid &&
            sourceIsFresh && latestBarIsFresh && !hasConflictingDuplicateBars && closes.count >= 60 &&
            !hasInvalidBarTimestamp && !hasInvalidBarValues && coreFactorsAreReliable &&
            input.asOf <= now && previousMemoryIsValid &&
            (priorMemory == nil || priorMemory!.lastEvaluationAt <= input.asOf)
        let volumeExpansion = volumeExpansionRatio(uniqueBars)
        let breadth = input.breadthObservation.flatMap {
            qualifiedBreadth($0, market: input.market, asOf: input.asOf,
                             now: now, maximumDataAge: maximumDataAge)
        }
        let qualifiedBenchmarkObservations = qualifiedBenchmarks(input.benchmarkObservations,
                                                                  marketContext: input.market,
                                                                  asOf: input.asOf, now: now,
                                                                  maximumDataAge: maximumDataAge)
        let benchmarkObservations = synchronizedBenchmarks(qualifiedBenchmarkObservations,
                                                            bars: uniqueBars)
        let negativeBenchmarks = benchmarkObservations.filter { $0.sessionReturn <= -0.04 }.count

        let factors = [
            factor("trend_MA20_60", value: ma20.flatMap { a in ma60.map { a / $0 - 1 } },
                   reason: "MA20/MA60排列；至少需要60个有效收盘样本"),
            factor("trend_MA60_250", value: ma60.flatMap { a in ma250.map { a / $0 - 1 } },
                   reason: "MA60/MA250长期结构；至少需要250个有效收盘样本"),
            factor("trend_slope", value: trendSlope,
                   reason: "MA20五个交易日斜率"),
            factor("daily_bar_spacing", value: dailyBarSpacingIsReliable ? 1 : nil,
                   reason: hasIntradayBarSpacing ? "Regime只接受每日收盘数据；存在小于12小时的相邻K线" :
                    (dailyBarSpacingIsReliable ? "相邻历史样本符合每日K线间隔" : "每日K线样本不足")),
            factor("daily_bar_values", value: hasInvalidBarValues ? nil : 1,
                   reason: hasInvalidBarValues ? "有效历史区间含非有限价格、无效成交量或矛盾OHLC" :
                    "有效历史区间价格与可选OHLCV字段通过校验"),
            factor("drawdown_20", value: drawdown20, reason: "近20个交易日相对高点回撤"),
            factor("return_5", value: ret5, reason: "近5个交易日跌速"),
            factor("volatility_20", value: vol20, reason: "近20个交易日实现波动率"),
            factor("volume_expansion", value: volumeExpansion, reason: "近5日与此前15日平均成交量比"),
            factor("market_breadth", value: breadth,
                   reason: breadth == nil ? "来源、时点或样本无效的上涨/下跌家数" : "新鲜上涨家数占比"),
            factor("fresh_benchmarks", value: benchmarkObservations.isEmpty ? nil : Double(negativeBenchmarks),
                   reason: benchmarkObservations.isEmpty ? "带来源和时点的宽基指数观测不可用" : "新鲜且去重后的下跌宽基指数数量")
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

        var hasTimeframeTrendConflict = false
        let candidateRegime: FMarketRegime
        if !dataReliable {
            candidateRegime = .dataUnreliable
        } else if candidateRisk == .r4Extreme {
            candidateRegime = .extremeRisk
        } else if let ret5, let ret20, let ma20, let ma60, let last = closes.last {
            let bullishStructure = last > ma20 && ma20 > ma60 &&
                (trendSlope ?? 0) > 0 && ret20 > 0.02
            let bearishStructure = last < ma20 && ma20 < ma60 && ret20 < -0.02
            let longTermTrendSupportsBull = ma250.map { ma60 > $0 } ?? true
            let longTermTrendSupportsBear = ma250.map { ma60 < $0 } ?? true
            let wasRisky = priorMemory.map {
                [.bearTrend, .riskOff, .extremeRisk].contains($0.confirmedRegime)
            } ?? false
            if wasRisky && ret5 > 0.025 && !bullishStructure {
                candidateRegime = .recovery
            } else if vol20.map({ $0 >= 0.35 }) == true {
                candidateRegime = .highVolatility
            } else if candidateRisk >= .r2High {
                candidateRegime = .riskOff
            } else if bullishStructure && !longTermTrendSupportsBull {
                hasTimeframeTrendConflict = true
                candidateRegime = .transition
            } else if bearishStructure && !longTermTrendSupportsBear {
                hasTimeframeTrendConflict = true
                candidateRegime = .transition
            } else if bullishStructure {
                candidateRegime = priorMemory?.confirmedRegime == .bearTrend ? .transition : .bullTrend
            } else if bearishStructure {
                candidateRegime = priorMemory?.confirmedRegime == .bullTrend ? .transition : .bearTrend
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
        let latestSessionTimestamp = latestBarTimestamp ?? input.asOf
        let isNewSession = priorMemory.map { latestSessionTimestamp > $0.lastEvaluationAt } ?? true
        if priorMemory == nil || candidateRegime == .dataUnreliable || candidateRegime == .extremeRisk ||
            hasTimeframeTrendConflict ||
            candidateRegime == priorMemory?.confirmedRegime {
            confirmedRegime = candidateRegime
            pendingRegime = nil
            pendingRegimeSessions = 0
        } else {
            let count = candidateRegime == priorMemory?.pendingRegime
                ? priorMemory!.pendingRegimeSessions + (isNewSession ? 1 : 0) : 1
            if count >= 3 {
                confirmedRegime = candidateRegime
                pendingRegime = nil
                pendingRegimeSessions = 0
            } else {
                confirmedRegime = priorMemory!.confirmedRegime
                pendingRegime = candidateRegime
                pendingRegimeSessions = count
            }
        }

        let confirmedRisk: FMarketRiskLevel
        let pendingRisk: FMarketRiskLevel?
        let pendingRiskSessions: Int
        if priorMemory == nil || candidateRisk == .r4Extreme || candidateRisk == priorMemory?.confirmedRiskLevel {
            confirmedRisk = candidateRisk
            pendingRisk = nil
            pendingRiskSessions = 0
        } else {
            let count = candidateRisk == priorMemory?.pendingRiskLevel
                ? priorMemory!.pendingRiskSessions + (isNewSession ? 1 : 0) : 1
            if candidateRisk > priorMemory!.confirmedRiskLevel && count >= 2 {
                confirmedRisk = candidateRisk
                pendingRisk = nil
                pendingRiskSessions = 0
            } else if candidateRisk < priorMemory!.confirmedRiskLevel && count >= 3 {
                confirmedRisk = FMarketRiskLevel(rawValue: priorMemory!.confirmedRiskLevel.rawValue - 1) ?? candidateRisk
                pendingRisk = confirmedRisk == candidateRisk ? nil : candidateRisk
                pendingRiskSessions = 0
            } else {
                confirmedRisk = priorMemory!.confirmedRiskLevel
                pendingRisk = candidateRisk
                pendingRiskSessions = count
            }
        }

        let regime: FMarketRegime = !dataReliable ? .dataUnreliable :
            (confirmedRisk == .r4Extreme ? .extremeRisk : confirmedRegime)
        var reasons = reasonList(regime: regime, risk: confirmedRisk, drawdown: drawdown20,
                                 volatility: vol20, breadth: breadth, crashCount: crashCount,
                                 pending: pendingRegime, timeframeConflict: hasTimeframeTrendConflict)
        if hasInvalidBarValues { reasons.append("invalid_daily_bar_values") }
        let usableFactorCount = factors.filter {
            $0.available && !["daily_bar_spacing", "daily_bar_values"].contains($0.key)
        }.count
        let confidence = dataReliable ? min(100, 35 + usableFactorCount * 8) : 0
        let strategies = allowedStrategies(for: regime, riskLevel: confirmedRisk, reliable: dataReliable)
        let memory = FMarketRegimeMemory(
            confirmedRegime: regime, confirmedRiskLevel: confirmedRisk,
            pendingRegime: pendingRegime, pendingRegimeSessions: pendingRegimeSessions,
            pendingRiskLevel: pendingRisk, pendingRiskSessions: pendingRiskSessions,
            lastEvaluationAt: latestSessionTimestamp)

        return FMarketRegimeAssessment(
            market: input.market, securityCode: input.securityCode, regime: regime,
            riskLevel: confirmedRisk, confidence: confidence, factors: factors,
            reasons: reasons, dataAsOf: uniqueBars.last?.timestamp,
            movingAverages: [20: ma20, 60: ma60, 120: ma120, 250: ma250].compactMapValues { $0 },
            return5Sessions: ret5, return20Sessions: ret20, drawdown20Sessions: drawdown20,
            realizedVolatility20Sessions: vol20, volumeExpansion: volumeExpansion,
            allowedStrategies: strategies,
            observationOnly: [.recovery, .transition, .uncertain, .highVolatility, .riskOff, .extremeRisk, .dataUnreliable].contains(regime),
            ordinaryTBuyAllowed: dataReliable && confirmedRisk < .r2High &&
                [.bullTrend, .range].contains(regime),
            memory: memory)
    }

    private static func factor(_ key: String, value: Double?, reason: String) -> FMarketRegimeFactor {
        FMarketRegimeFactor(key: key, value: value, available: value?.isFinite == true, reason: reason)
    }

    private static func hasValidPriceData(_ bar: FMarketRegimeBar) -> Bool {
        guard bar.close.isFinite, bar.close > 0 else { return false }
        if let volume = bar.volume, (!volume.isFinite || volume < 0) { return false }
        let ohlc = [bar.open, bar.high, bar.low]
        let present = ohlc.compactMap { $0 }
        guard present.isEmpty || present.count == ohlc.count,
              present.allSatisfy(\.isFinite) else { return false }
        guard let open = bar.open, let high = bar.high, let low = bar.low else { return true }
        return low > 0 && high >= max(open, bar.close) &&
            low <= min(open, bar.close) && high >= low
    }

    private static func isValidMemory(_ memory: FMarketRegimeMemory) -> Bool {
        let regimeCount = memory.pendingRegimeSessions
        let riskCount = memory.pendingRiskSessions
        return memory.lastEvaluationAt.timeIntervalSince1970.isFinite &&
            (0...2).contains(regimeCount) && (0...2).contains(riskCount) &&
            (memory.pendingRegime == nil
                ? regimeCount == 0
                : memory.pendingRegime != memory.confirmedRegime) &&
            (memory.pendingRiskLevel == nil
                ? riskCount == 0
                : memory.pendingRiskLevel != memory.confirmedRiskLevel)
    }

    private static func qualifiedBenchmarks(
        _ observations: [FMarketRegimeBenchmarkObservation], marketContext: String,
        asOf: Date, now: Date,
        maximumDataAge: TimeInterval
    ) -> [FMarketRegimeBenchmarkObservation] {
        let allowedCodes = permittedBenchmarkCodes(for: marketContext)
        let valid = observations.filter { item in
            item.marketContext == marketContext &&
            allowedCodes.contains(item.marketCode) &&
            !isContextIndex(item.marketCode, marketContext: marketContext) &&
            !item.marketContext.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            !item.marketCode.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty &&
            FMarketRegimeEvidenceTrustPolicy.isTrustedBenchmarkSource(item.source,
                                                                       indexCode: item.marketCode) &&
            item.sessionStartAt.map {
                $0.timeIntervalSince1970.isFinite && $0 < item.observedAt &&
                $0 <= item.capturedAt && $0 <= asOf && $0 <= now
            } == true &&
            item.sessionReturn.isFinite && (-1...1).contains(item.sessionReturn) &&
            item.observedAt <= asOf && item.observedAt <= now &&
            item.capturedAt >= item.observedAt && item.capturedAt <= asOf && item.capturedAt <= now &&
            asOf.timeIntervalSince(item.observedAt) <= min(maximumDataAge, maximumBenchmarkAge) &&
            now.timeIntervalSince(item.observedAt) <= min(maximumDataAge, maximumBenchmarkAge) &&
            now.timeIntervalSince(item.capturedAt) <= min(maximumDataAge, maximumBenchmarkAge)
        }
        let groupedByMarket = Dictionary(grouping: valid, by: \.marketCode)
        let latestByMarket: [FMarketRegimeBenchmarkObservation] = groupedByMarket.compactMap { entry
            -> FMarketRegimeBenchmarkObservation? in
            let candidates = entry.value
            guard let newestObservationAt = candidates.map({ $0.observedAt }).max() else { return nil }
            let newest = candidates.filter { $0.observedAt == newestObservationAt }
            guard Set(newest.map(\.sessionReturn)).count == 1,
                  Set(newest.compactMap(\.sessionStartAt)).count == 1 else { return nil }
            return newest.max { $0.capturedAt < $1.capturedAt }
        }
        guard let earliest = latestByMarket.map(\.observedAt).min(),
              let latest = latestByMarket.map(\.observedAt).max(),
              latest.timeIntervalSince(earliest) <= maximumBenchmarkSynchronizationSpan,
              let earliestStart = latestByMarket.compactMap(\.sessionStartAt).min(),
              let latestStart = latestByMarket.compactMap(\.sessionStartAt).max(),
              latestStart.timeIntervalSince(earliestStart) <= maximumBenchmarkSynchronizationSpan else {
            return []
        }
        return latestByMarket.sorted { $0.marketCode < $1.marketCode }
    }
    private static func synchronizedBenchmarks(_ observations: [FMarketRegimeBenchmarkObservation],
                                               bars: [FMarketRegimeBar])
        -> [FMarketRegimeBenchmarkObservation] {
        guard bars.count >= 2, let previous = bars.dropLast().last, let latest = bars.last else { return [] }
        return observations.filter { observation in
            guard let sessionStartAt = observation.sessionStartAt else { return false }
            return abs(observation.observedAt.timeIntervalSince(latest.timestamp)) <=
                    maximumBenchmarkSynchronizationSpan &&
                abs(sessionStartAt.timeIntervalSince(previous.timestamp)) <=
                    maximumBenchmarkSynchronizationSpan
        }
    }
    private static func permittedBenchmarkCodes(for marketContext: String) -> Set<String> {
        let identity = marketContext.hasPrefix("index:") ? String(marketContext.dropFirst("index:".count)) : marketContext
        switch identity {
        case "CN", "sh000001", "sz399001", "sh000300", "sh000510", "sz399006":
            return ["sh000001", "sz399001", "sh000300", "sh000510", "sz399006"]
        case "US", "usNDX": return ["usNDX"]
        case "HK", "hkHSI": return ["hkHSI"]
        case "JP", "int_nikkei": return ["int_nikkei"]
        case "KR", "KOSPI": return ["KOSPI"]
        default: return []
        }
    }
    private static func isContextIndex(_ indexCode: String, marketContext: String) -> Bool {
        guard marketContext.hasPrefix("index:") else { return false }
        return String(marketContext.dropFirst("index:".count)) == indexCode
    }
    private static func qualifiedBreadth(
        _ observation: FMarketRegimeBreadthObservation, market: String,
        asOf: Date, now: Date,
        maximumDataAge: TimeInterval
    ) -> Double? {
        let (total, overflow) = observation.advancingCount.addingReportingOverflow(observation.decliningCount)
        let maximumAge = min(maximumDataAge, maximumBreadthAge)
        guard !overflow, observation.advancingCount >= 0, observation.decliningCount >= 0, total > 0,
              !market.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty,
              observation.market == market,
              FMarketRegimeEvidenceTrustPolicy.isTrustedBreadthSource(observation.source,
                                                                       market: observation.market),
              observation.observedAt.timeIntervalSince1970.isFinite,
              observation.capturedAt.timeIntervalSince1970.isFinite,
              observation.observedAt <= observation.capturedAt,
              observation.observedAt <= asOf, observation.observedAt <= now,
              observation.capturedAt <= asOf, observation.capturedAt <= now,
              asOf.timeIntervalSince(observation.observedAt) <= maximumAge,
              now.timeIntervalSince(observation.observedAt) <= maximumAge,
              now.timeIntervalSince(observation.capturedAt) <= maximumAge else { return nil }
        let ratio = Double(observation.advancingCount) / Double(total)
        return ratio.isFinite && (0...1).contains(ratio) ? ratio : nil
    }
    private static func averageTail(_ values: [Double], count: Int) -> Double? {
        guard values.count >= count else { return nil }
        let tail = values.suffix(count)
        guard let first = tail.first, first.isFinite, first > 0 else { return nil }
        var result = first
        for (offset, value) in tail.dropFirst().enumerated() {
            guard value.isFinite, value > 0 else { return nil }
            result += (value - result) / Double(offset + 2)
            guard result.isFinite else { return nil }
        }
        return result.isFinite && result > 0 ? result : nil
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
        let volumes = bars.suffix(20).compactMap(\.volume)
        guard volumes.count == 20, volumes.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        let prior = volumes.prefix(15)
        let recent = volumes.suffix(5)
        // Divide before summing so large but finite provider values do not
        // overflow only because of intermediate accumulation.
        let baseline = prior.reduce(0) { $0 + $1 / 15 }
        let recentAverage = recent.reduce(0) { $0 + $1 / 5 }
        guard baseline.isFinite, baseline > 0, recentAverage.isFinite else { return nil }
        let ratio = recentAverage / baseline
        return ratio.isFinite ? ratio : nil
    }
    public static func allowedStrategies(for regime: FMarketRegime,
                                         riskLevel: FMarketRiskLevel,
                                         reliable: Bool = true) -> Set<FQuantStrategyKind> {
        guard reliable, riskLevel < .r3Severe else { return [] }
        switch regime {
        case .bullTrend: return [.trendPullback, .maStructure, .vwapDeviation]
        case .range: return [.meanReversion, .vwapDeviation]
        case .bearTrend: return [.maStructure]
        case .highVolatility: return [.maStructure]
        case .recovery, .transition: return [.maStructure]
        case .riskOff, .extremeRisk, .uncertain, .dataUnreliable: return []
        }
    }
    private static func reasonList(regime: FMarketRegime, risk: FMarketRiskLevel,
                                   drawdown: Double?, volatility: Double?, breadth: Double?,
                                   crashCount: Int, pending: FMarketRegime?,
                                   timeframeConflict: Bool) -> [String] {
        var result = ["regime_\(regime.rawValue)", "risk_R\(risk.rawValue)"]
        if timeframeConflict { result.append("short_long_trend_conflict") }
        if let drawdown, drawdown <= -0.10 { result.append("drawdown_deteriorating") }
        // `realizedVolatility` is annualized; keep this explanation aligned
        // with the R1 elevated-risk threshold used by the classifier.
        if let volatility, volatility >= 0.25 { result.append("volatility_expanded") }
        if let breadth, breadth <= 0.30 { result.append("market_breadth_weak") }
        if crashCount >= 2 { result.append("multiple_independent_crash_factors_\(crashCount)") }
        if let pending { result.append("regime_confirmation_pending_\(pending.rawValue)") }
        if regime == .dataUnreliable { result.append("insufficient_or_stale_market_data") }
        return result
    }
}
