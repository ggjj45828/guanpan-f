import Foundation

public enum FLocalQuantReadiness: String, Codable, Sendable {
    case unavailable, shadowOnly, riskBlocked
}

public struct FLocalQuantFactor: Codable, Equatable, Sendable, Identifiable {
    public var id: String { key }
    public let key: String
    /// Normalized directional/risk score in [-100, 100].
    public let score: Double?
    public let available: Bool
    public let reason: String
}

public struct FLocalQuantStrategyScore: Codable, Equatable, Sendable, Identifiable {
    public var id: FQuantStrategyKind { strategy }
    public let strategy: FQuantStrategyKind
    /// Shadow opportunity score in [-100, 100]; never an order instruction.
    public let score: Double?
    public let enabledByRegime: Bool
    public let reason: String
}

public struct FLocalQuantAssessment: Codable, Equatable, Sendable {
    public let securityCode: String
    public let evaluatedAt: Date
    public let readiness: FLocalQuantReadiness
    public let quoteTimestamp: Date?
    public let quoteSource: String?
    public let strategyVersion: String?
    public let factors: [FLocalQuantFactor]
    public let strategies: [FLocalQuantStrategyScore]
    public let riskReasons: [String]

    public var summary: String {
        switch readiness {
        case .unavailable: return "本地 Quant 暂不可用"
        case .riskBlocked: return "Risk Guard 阻止候选"
        case .shadowOnly: return "实验评分 · Shadow only · 未通过NAS策略资格验证"
        }
    }
}

/// Deterministic on-device MVP scorer. It records evidence and shadow scores only:
/// without a versioned, NAS-qualified parameter package, it cannot create a trade candidate.
public enum FLocalQuantEngine {
    public static func evaluate(
        securityCode: String,
        quote: FCurrentIntradaySnapshot?,
        daily: FDailyKlineSnapshot?,
        marketRegime: FMarketRegimeAssessment?,
        now: Date = Date(),
        maximumQuoteAge: TimeInterval = 120,
        maximumDailyAge: TimeInterval = 5 * 86_400
    ) -> FLocalQuantAssessment {
        var reasons: [String] = []
        guard let quote, quote.securityCode == securityCode,
              quote.quoteTimestamp <= now, now.timeIntervalSince(quote.quoteTimestamp) >= 0,
              now.timeIntervalSince(quote.quoteTimestamp) <= maximumQuoteAge,
              quote.latestPrice.map({ $0 > 0 }) == true else {
            return unavailable(securityCode, now, "实时行情缺失、过期或标的代码不匹配")
        }
        guard let daily, daily.securityCode == securityCode,
              daily.fetchedAt <= now, now.timeIntervalSince(daily.fetchedAt) <= maximumDailyAge,
              daily.bars.count >= 60,
              let latestDailyObservation = daily.bars.last?.tradingDate,
              latestDailyObservation <= now,
              now.timeIntervalSince(latestDailyObservation) <= maximumDailyAge else {
            return unavailable(securityCode, now, "真实日K缺失、过期或不足60个交易日",
                               quoteTimestamp: quote.quoteTimestamp, quoteSource: quote.source)
        }
        guard let marketRegime,
              marketRegime.primaryBenchmark != nil,
              marketRegime.unavailableBenchmarks.isEmpty,
              marketRegime.marketRegime != nil,
              marketRegime.marketRiskLevel != nil else {
            return unavailable(securityCode, now, "主基准历史或市场Regime不可用",
                               quoteTimestamp: quote.quoteTimestamp, quoteSource: quote.source)
        }
        guard marketRegime.regime != .dataUnreliable,
              marketRegime.marketRegime != .dataUnreliable else {
            return unavailable(securityCode, now, "证券或市场数据质量不可靠",
                               quoteTimestamp: quote.quoteTimestamp, quoteSource: quote.source)
        }
        if marketRegime.marketRiskLevel == .r4Extreme || marketRegime.regime == .extremeRisk {
            reasons.append("市场或证券处于极端风险")
        }
        if !marketRegime.ordinaryTBuyAllowed { reasons.append("当前Regime不允许普通T买策略") }

        let price = NSDecimalNumber(decimal: quote.latestPrice!).doubleValue
        let closes = daily.bars.map { NSDecimalNumber(decimal: $0.close).doubleValue }
        let ma20 = averageTail(closes, count: 20)
        let ma60 = averageTail(closes, count: 60)
        let trend = ma20.flatMap { short in ma60.map { (closes.last! / short - 1) * 100 + (short / $0 - 1) * 100 } }
        let maStructure = ma20.flatMap { short in ma60.map { (short / $0 - 1) * 100 } }
        let recentReturns = zip(closes.suffix(21), closes.suffix(21).dropFirst())
            .compactMap { previous, current -> Double? in previous > 0 ? current / previous - 1 : nil }
        let volatility = standardDeviation(recentReturns)

        let usableSamples = quote.samples.filter {
            $0.timestamp <= quote.quoteTimestamp && $0.price > 0
        }
        let prices = usableSamples.map { NSDecimalNumber(decimal: $0.price).doubleValue }
        let momentum: Double? = prices.count >= 2 ? (prices.last! / prices[max(0, prices.count - 6)] - 1) * 100 : nil
        let weighted = usableSamples.compactMap { sample -> (Double, Double)? in
            guard let volume = sample.volume, volume > 0 else { return nil }
            return (NSDecimalNumber(decimal: sample.price).doubleValue, NSDecimalNumber(decimal: volume).doubleValue)
        }
        let vwap: Double? = {
            guard weighted.count >= 10 else { return nil }
            let volume = weighted.reduce(0) { $0 + $1.1 }
            guard volume > 0 else { return nil }
            return weighted.reduce(0) { $0 + $1.0 * $1.1 } / volume
        }()
        let deviation = vwap.map { price / $0 - 1 }

        let factors = [
            factor("trend_structure", trend.map { clamp($0 * 8) },
                   "日K收盘相对MA20及MA20相对MA60；需要60个真实交易日"),
            factor("ma_structure", maStructure.map { clamp($0 * 20) },
                   "MA20/MA60结构；仅用真实日K"),
            factor("vwap_deviation", deviation.map { clamp(-$0 * 10_000) },
                   vwap == nil ? "分钟成交量样本不足，VWAP不可用" : "真实分钟量价加权VWAP偏离"),
            factor("short_momentum", momentum.map { clamp($0 * 12) },
                   "最近最多6个真实分钟价格样本"),
            factor("mean_reversion", deviation.map { clamp(-$0 * 10_000) },
                   deviation == nil ? "缺少可信分钟VWAP，均值回归因子不可用" : "价格相对日内VWAP的反向偏离"),
            factor("volatility", volatility.map { clamp(50 - $0 * 1_000) },
                   "近20个真实日收益率标准差；分数越低表示波动风险越高"),
            factor("volume_anomaly", nil, "当前行情没有可比时点成交量基线"),
            factor("premium_iopv", nil, "可靠IOPV来源尚未接入")
        ]

        let factorScores = Dictionary(uniqueKeysWithValues: factors.compactMap { item in
            item.score.map { (item.key, $0) }
        })
        let enabled = marketRegime.allowedStrategies
        let meanReversion = factorScores["mean_reversion"].flatMap { reversion in
            factorScores["short_momentum"].map { clamp(reversion * 0.7 - $0 * 0.3) }
        } ?? factorScores["mean_reversion"]
        let trendPullback = factorScores["trend_structure"].flatMap { structure in
            factorScores["vwap_deviation"].map { clamp(structure * 0.65 + $0 * 0.35) }
        } ?? factorScores["trend_structure"]
        let strategyScores: [(FQuantStrategyKind, Double?)] = [
            (.meanReversion, meanReversion),
            (.trendPullback, trendPullback),
            (.vwapDeviation, factorScores["vwap_deviation"])
        ]
        let strategies = strategyScores.map { strategy, score in
            FLocalQuantStrategyScore(strategy: strategy, score: score,
                enabledByRegime: enabled.contains(strategy),
                reason: score == nil ? "构成因子不可用" :
                    (enabled.contains(strategy) ? "Regime允许；当前仅Shadow评分" : "当前Regime未授权此策略"))
        }
        let readiness: FLocalQuantReadiness = reasons.isEmpty ? .shadowOnly : .riskBlocked
        return FLocalQuantAssessment(securityCode: securityCode, evaluatedAt: now,
            readiness: readiness, quoteTimestamp: quote.quoteTimestamp, quoteSource: quote.source,
            strategyVersion: nil, factors: factors, strategies: strategies,
            riskReasons: reasons)
    }

    private static func unavailable(_ code: String, _ now: Date, _ reason: String,
                                    quoteTimestamp: Date? = nil, quoteSource: String? = nil) -> FLocalQuantAssessment {
        FLocalQuantAssessment(securityCode: code, evaluatedAt: now, readiness: .unavailable,
            quoteTimestamp: quoteTimestamp, quoteSource: quoteSource, strategyVersion: nil,
            factors: [], strategies: [], riskReasons: [reason])
    }

    private static func factor(_ key: String, _ score: Double?, _ reason: String) -> FLocalQuantFactor {
        FLocalQuantFactor(key: key, score: score.map(clamp), available: score?.isFinite == true, reason: reason)
    }

    private static func averageTail(_ values: [Double], count: Int) -> Double? {
        guard values.count >= count else { return nil }
        return values.suffix(count).reduce(0, +) / Double(count)
    }

    private static func standardDeviation(_ values: [Double]) -> Double? {
        guard values.count >= 10, values.allSatisfy(\.isFinite) else { return nil }
        let mean = values.reduce(0, +) / Double(values.count)
        let variance = values.reduce(0) { $0 + pow($1 - mean, 2) } / Double(values.count)
        return sqrt(variance)
    }

    private static func clamp(_ value: Double) -> Double {
        guard value.isFinite else { return 0 }
        return min(100, max(-100, value))
    }
}
