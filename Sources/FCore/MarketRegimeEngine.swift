import Foundation

public enum FMarketRegime: String, Codable, CaseIterable, Equatable, Sendable {
    case bullTrend, bearTrend, range, highVolatility, riskOff, extremeRisk
    case recovery, transition, uncertain, dataUnreliable
}

public enum FMarketRiskLevel: Int, Codable, CaseIterable, Comparable, Sendable {
    case r0Normal = 0, r1Elevated = 1, r2High = 2, r3Severe = 3, r4Extreme = 4
    public static func < (lhs: Self, rhs: Self) -> Bool { lhs.rawValue < rhs.rawValue }
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

public struct FMarketRegimeInput: Sendable {
    public let market: String
    public let securityCode: String?
    public let asOf: Date
    public let sourceUpdatedAt: Date?
    public let source: String?
    public let bars: [FMarketRegimeBar]
    /// Optional breadth as advancers / (advancers + decliners), in 0...1.
    public let breadthRatio: Double?
    /// Returns from separately observed, synchronized benchmarks. Missing
    /// benchmarks remain unavailable and are never synthesized.
    public let synchronizedBenchmarkReturns: [Double]

    public init(market: String, securityCode: String? = nil, asOf: Date,
                sourceUpdatedAt: Date?, source: String?, bars: [FMarketRegimeBar],
                breadthRatio: Double? = nil, synchronizedBenchmarkReturns: [Double] = []) {
        self.market = market
        self.securityCode = securityCode
        self.asOf = asOf
        self.sourceUpdatedAt = sourceUpdatedAt
        self.source = source
        self.bars = bars
        self.breadthRatio = breadthRatio
        self.synchronizedBenchmarkReturns = synchronizedBenchmarkReturns
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
        let benchmarkReturns = input.synchronizedBenchmarkReturns.filter(\.isFinite)
        let negativeBenchmarks = benchmarkReturns.filter { $0 <= -0.04 }.count

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
        let isNewSession = previous.map { input.asOf > $0.lastEvaluationAt } ?? true
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
        let usableFactorCount = factors.filter(\.available).count
        let confidence = dataReliable ? min(100, 35 + usableFactorCount * 8) : 0
        let strategies = strategyPolicy(regime: regime, risk: confirmedRisk, reliable: dataReliable)
        let memory = FMarketRegimeMemory(
            confirmedRegime: regime, confirmedRiskLevel: confirmedRisk,
            pendingRegime: pendingRegime, pendingRegimeSessions: pendingRegimeSessions,
            pendingRiskLevel: pendingRisk, pendingRiskSessions: pendingRiskSessions,
            lastEvaluationAt: input.asOf)

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
                                       reliable: Bool) -> Set<FQuantStrategyKind> {
        guard reliable, risk < .r4Extreme else { return [] }
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
