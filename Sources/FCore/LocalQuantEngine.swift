import Foundation

public enum FLocalQuantFactorKind: String, CaseIterable, Equatable, Sendable {
    case trendStructure
    case movingAverageStructure
    case vwapDeviation
    case shortMomentum
    case meanReversion
    case intradayVolatility
    case volumeAnomaly
    case iopvPremium
}

/// A descriptive measurement. `directionalScore` is a bounded, volatility-
/// normalized factor value; it is not a probability, expected return, or trade.
public struct FLocalQuantFactorObservation: Equatable, Sendable, Identifiable {
    public var id: FLocalQuantFactorKind { kind }
    public let kind: FLocalQuantFactorKind
    public let value: Double?
    public let directionalScore: Int?
    public let observedAt: Date?
    /// Latest completed historical bar used alongside a live quote, when any.
    public let supportingDataAsOf: Date?
    public let source: String?
    public let qualityNote: String?
    public let unavailableReason: String?

    public var isAvailable: Bool { value?.isFinite == true && unavailableReason == nil }
}

public enum FLocalQuantStrategyReadiness: String, Equatable, Sendable {
    case disabledByRegime
    case awaitingQualifiedParameters
    case unavailableRegime
}

public struct FLocalQuantStrategyObservation: Equatable, Sendable, Identifiable {
    public var id: FQuantStrategyKind { strategy }
    public let strategy: FQuantStrategyKind
    public let readiness: FLocalQuantStrategyReadiness
    /// This first local engine slice never grants strategy qualification.
    public let qualified: Bool
    public let reasonCode: String
}

public enum FLocalQuantDisposition: String, Equatable, Sendable {
    case wait
    case noTrade
}

/// Read-only factor assessment. Candidate zones and quantities are deliberately
/// absent until a per-security strategy parameter package has passed NAS
/// validation and the Risk Guard has approved a reviewable plan.
public struct FLocalQuantAssessment: Equatable, Sendable {
    public let securityCode: String
    public let evaluatedAt: Date
    public let quoteTimestamp: Date?
    public let quoteFreshness: FQuoteFreshness
    public let marketRegime: FMarketRegime?
    public let riskLevel: FMarketRiskLevel?
    public let benchmarkIndexCode: String?
    public let benchmarkRegime: FMarketRegime?
    public let benchmarkRiskLevel: FMarketRiskLevel?
    public let benchmarkUnavailableReason: String?
    public let factors: [FLocalQuantFactorObservation]
    public let strategies: [FLocalQuantStrategyObservation]
    public let disposition: FLocalQuantDisposition
    public let reasonCodes: [String]
    public let candidatePlanGenerated: Bool
}

/// Deterministic, per-security factor calculations for local observation.
/// Scores describe relative factor direction only. This engine does not invent
/// entry prices, suggested quantities, or NAS qualification.
public enum FLocalQuantEngine {
    private static let maximumDailyHistoryAge: TimeInterval = 36 * 60 * 60
    private static let maximumDailyBarAge: TimeInterval = 5 * 86_400
    private static let maximumRegimeAge: TimeInterval = 5 * 86_400
    private static let maximumIntradaySampleGap: TimeInterval = 90
    private static let strategies: [FQuantStrategyKind] = [
        .meanReversion, .trendPullback, .vwapDeviation
    ]

    public static func evaluate(quote: FCurrentIntradaySnapshot,
                                dailyHistory: FDailyKlineSnapshot?,
                                regime: FMarketRegimeAssessment?,
                                iopv: FIOPVObservation?,
                                sessionStatus: FMarketSessionStatus,
                                mappedBenchmarkRegime: FMarketRegimeAssessment? = nil,
                                mappedBenchmarkFetchedAt: Date? = nil,
                                mappedBenchmarkIndexCode: String? = nil,
                                now: Date = Date()) -> FLocalQuantAssessment {
        let code = quote.securityCode
        let freshness = quote.freshness(at: now)
        let quoteIsUsable = freshness == .fresh && sessionStatus == .continuous
        let validDaily = dailyHistory.flatMap { history -> FDailyKlineSnapshot? in
            guard let latestBar = history.bars.last else { return nil }
            guard history.securityCode == code,
                  FMarketBarTrustPolicy.isTrustedSecurityDailySource(history.source),
                  history.fetchedAt <= now,
                  now.timeIntervalSince(history.fetchedAt) <= maximumDailyHistoryAge,
                  latestBar.tradingDate <= now,
                  now.timeIntervalSince(latestBar.tradingDate) <= maximumDailyBarAge else { return nil }
            return history
        }
        let validRegime = regime.flatMap { assessment -> FMarketRegimeAssessment? in
            let lastEvaluation = assessment.memory.lastEvaluationAt
            guard let dataAsOf = assessment.dataAsOf,
                  dataAsOf.timeIntervalSince1970.isFinite,
                  dataAsOf <= lastEvaluation,
                  dataAsOf <= now,
                  now.timeIntervalSince(dataAsOf) <= maximumRegimeAge,
                  (0...100).contains(assessment.confidence) else { return nil }
            guard assessment.market == "security:\(code)", assessment.securityCode == code,
                  assessment.regime != .dataUnreliable,
                  lastEvaluation <= now,
                  now.timeIntervalSince(lastEvaluation) <= maximumRegimeAge else { return nil }
            return assessment
        }
        let requiredBenchmarkMapping = FMarketIndexSecurityMappingRegistry.mapping(for: code)
        let validBenchmark = requiredBenchmarkMapping.flatMap { mapping -> FMarketRegimeAssessment? in
            guard mappedBenchmarkIndexCode == mapping.indexCode,
                  let assessment = mappedBenchmarkRegime,
                  let fetchedAt = mappedBenchmarkFetchedAt,
                  assessment.market == "index:\(mapping.indexCode)", assessment.securityCode == nil,
                  assessment.regime != .dataUnreliable,
                  (0...100).contains(assessment.confidence),
                  let dataAsOf = assessment.dataAsOf,
                  dataAsOf.timeIntervalSince1970.isFinite,
                  dataAsOf <= assessment.memory.lastEvaluationAt,
                  dataAsOf <= fetchedAt,
                  fetchedAt <= now, dataAsOf <= now,
                  now.timeIntervalSince(fetchedAt) <= maximumRegimeAge,
                  now.timeIntervalSince(dataAsOf) <= maximumRegimeAge,
                  assessment.memory.lastEvaluationAt <= fetchedAt,
                  assessment.memory.lastEvaluationAt <= now else { return nil }
            return assessment
        }
        let validIOPV = iopv.flatMap { observation -> FIOPVObservation? in
            guard observation.securityCode == code,
                  let value = observation.value, value.isFinite, value > 0,
                  let observedAt = observation.observedAt, let fetchedAt = observation.fetchedAt,
                  let source = observation.source,
                  source == FMarketQuoteTrustPolicy.tencentReferenceSource,
                  isComplete(observation.quality),
                  observedAt <= fetchedAt, fetchedAt <= now,
                  now.timeIntervalSince(observedAt) <= 90,
                  !source.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty else { return nil }
            return observation
        }

        let closes = validDaily?.bars.compactMap { double($0.close) } ?? []
        let dailyVolatility = returnVolatility(closes.suffix(21))
        let currentPrice = quoteIsUsable ? quote.latestPrice.flatMap(double) : nil
        let vwap = quoteIsUsable ? volumeWeightedAverage(quote.samples) : nil
        let vwapQualityNote = quoteIsUsable ? volumeCoverageNote(quote.samples) : nil
        let recentSamples = quoteIsUsable ? recentConsecutiveSamples(quote.samples) : []
        let minutePrices = recentSamples.compactMap { double($0.price) }
        let minuteVolatility = returnVolatility(minutePrices.suffix(21))

        let factors = [
            factor(.trendStructure, value: trendValue(current: currentPrice, bars: validDaily?.bars,
                                                       periods: [20, 60, 250]),
                   scale: dailyVolatility, at: quote.quoteTimestamp,
                   supportingDataAsOf: validDaily?.bars.last?.tradingDate,
                   source: combinedSource(quoteIsUsable ? quote.source : nil, validDaily?.source),
                   unavailable: validDaily == nil ? "新鲜证券日K不可用" : "趋势均线或波动尺度不足"),
            factor(.movingAverageStructure, value: movingAverageStructure(bars: validDaily?.bars),
                   scale: dailyVolatility, at: validDaily?.bars.last?.tradingDate,
                   source: validDaily?.source,
                   unavailable: validDaily == nil ? "新鲜证券日K不可用" : "均线结构或波动尺度不足"),
            factor(.vwapDeviation, value: currentPrice.flatMap { price in
                vwap.map { price / $0 - 1 }
            }, scale: minuteVolatility, at: quote.quoteTimestamp, source: quote.source,
                   qualityNote: vwapQualityNote,
                   unavailable: !quoteIsUsable ? "实时行情过期或不在连续交易时段" : "分钟成交量不足，无法计算VWAP"),
            factor(.shortMomentum, value: returnOverLastSamples(minutePrices, count: 5),
                   scale: minuteVolatility, at: quote.quoteTimestamp, source: quote.source,
                   unavailable: !quoteIsUsable ? "实时行情过期或不在连续交易时段" : "短周期分钟样本不足或时间间隔过大"),
            factor(.meanReversion, value: meanReversionValue(minutePrices),
                   scale: minuteVolatility, at: quote.quoteTimestamp, source: quote.source,
                   unavailable: !quoteIsUsable ? "实时行情过期或不在连续交易时段" : "分钟价格样本不足或时间间隔过大"),
            factor(.intradayVolatility, value: minuteVolatility, scale: nil,
                   at: quote.quoteTimestamp, source: quote.source,
                   unavailable: !quoteIsUsable ? "实时行情过期或不在连续交易时段" : "分钟收益样本不足或时间间隔过大"),
            factor(.volumeAnomaly, value: volumeAnomaly(recentSamples), scale: nil,
                   at: quote.quoteTimestamp, source: quote.source,
                   unavailable: !quoteIsUsable ? "实时行情过期或不在连续交易时段" : "20个连续有效分钟成交量不足"),
            factor(.iopvPremium, value: currentPrice.flatMap { price in
                validIOPV?.value.flatMap { iopvValue in double(iopvValue).map { price / $0 - 1 } }
            }, scale: nil, at: validIOPV?.observedAt, source: validIOPV?.source,
                   unavailable: validIOPV == nil ? "IOPV缺失、过期或质量未通过" : "ETF价格不可用")
        ]

        let strategies = strategies.map { strategy -> FLocalQuantStrategyObservation in
            guard let validRegime else {
                return .init(strategy: strategy, readiness: .unavailableRegime, qualified: false,
                             reasonCode: "security_regime_unavailable")
            }
            if validRegime.riskLevel >= .r3Severe {
                return .init(strategy: strategy, readiness: .disabledByRegime, qualified: false,
                             reasonCode: "security_regime_severe_risk")
            }
            if requiredBenchmarkMapping != nil && validBenchmark == nil {
                return .init(strategy: strategy, readiness: .unavailableRegime, qualified: false,
                             reasonCode: "mapped_benchmark_unavailable")
            }
            if let validBenchmark,
               (validBenchmark.riskLevel >= .r3Severe ||
                [.riskOff, .extremeRisk, .dataUnreliable].contains(validBenchmark.regime)) {
                return .init(strategy: strategy, readiness: .disabledByRegime, qualified: false,
                             reasonCode: "mapped_benchmark_severe_risk")
            }
            if let validBenchmark, !validBenchmark.allowedStrategies.contains(strategy) {
                return .init(strategy: strategy, readiness: .disabledByRegime, qualified: false,
                             reasonCode: "mapped_benchmark_disallows_strategy")
            }
            guard validRegime.allowedStrategies.contains(strategy) else {
                return .init(strategy: strategy, readiness: .disabledByRegime, qualified: false,
                             reasonCode: "strategy_disabled_by_regime")
            }
            return .init(strategy: strategy, readiness: .awaitingQualifiedParameters,
                         qualified: false, reasonCode: "nas_strategy_parameters_not_qualified")
        }

        var reasons: [String] = []
        if freshness != .fresh { reasons.append("quote_not_fresh") }
        if sessionStatus != .continuous { reasons.append("market_not_in_continuous_session") }
        if validRegime == nil { reasons.append("security_regime_unavailable") }
        if let validRegime, validRegime.riskLevel >= .r3Severe {
            reasons.append("security_regime_severe_risk")
        }
        if let mapping = requiredBenchmarkMapping, validBenchmark == nil {
            reasons.append("mapped_benchmark_unavailable:\(mapping.indexCode)")
        }
        if let validBenchmark,
           (validBenchmark.riskLevel >= .r3Severe ||
            [.riskOff, .extremeRisk, .dataUnreliable].contains(validBenchmark.regime)) {
            reasons.append("mapped_benchmark_severe_risk")
        }
        if strategies.allSatisfy({ $0.readiness != .awaitingQualifiedParameters }) {
            reasons.append("no_regime_permitted_strategy")
        } else {
            reasons.append("nas_strategy_parameters_not_qualified")
        }
        return FLocalQuantAssessment(
            securityCode: code, evaluatedAt: now, quoteTimestamp: quote.quoteTimestamp,
            quoteFreshness: freshness, marketRegime: validRegime?.regime,
            riskLevel: validRegime?.riskLevel,
            benchmarkIndexCode: requiredBenchmarkMapping?.indexCode,
            benchmarkRegime: validBenchmark?.regime,
            benchmarkRiskLevel: validBenchmark?.riskLevel,
            benchmarkUnavailableReason: requiredBenchmarkMapping != nil && validBenchmark == nil
                ? "mapped_benchmark_unavailable" : nil,
            factors: factors, strategies: strategies,
            disposition: quoteIsUsable && validRegime != nil &&
                (requiredBenchmarkMapping == nil || validBenchmark != nil) ? .noTrade : .wait,
            reasonCodes: reasons, candidatePlanGenerated: false)
    }

    private static func factor(_ kind: FLocalQuantFactorKind, value: Double?, scale: Double?,
                               at timestamp: Date?, supportingDataAsOf: Date? = nil,
                               source: String?, qualityNote: String? = nil, unavailable: String)
        -> FLocalQuantFactorObservation {
        guard let value, value.isFinite else {
            return .init(kind: kind, value: nil, directionalScore: nil, observedAt: nil,
                         supportingDataAsOf: nil, source: nil, qualityNote: qualityNote,
                         unavailableReason: unavailable)
        }
        let score: Int?
        if let scale, scale.isFinite, scale > 0 {
            let z = value / scale
            guard z.isFinite else {
                return .init(kind: kind, value: nil, directionalScore: nil, observedAt: nil,
                             supportingDataAsOf: nil, source: nil, qualityNote: qualityNote,
                             unavailableReason: "标准化因子超出可表示范围")
            }
            let bounded = z / (1 + abs(z))
            score = Int((bounded * 100).rounded())
        } else {
            score = nil
        }
        return .init(kind: kind, value: value, directionalScore: score, observedAt: timestamp,
                     supportingDataAsOf: supportingDataAsOf, source: source,
                     qualityNote: qualityNote, unavailableReason: nil)
    }

    private static func combinedSource(_ sources: String?...) -> String? {
        let values = sources.compactMap { source -> String? in
            guard let source else { return nil }
            let normalized = source.trimmingCharacters(in: .whitespacesAndNewlines)
            return normalized.isEmpty ? nil : normalized
        }
        return values.isEmpty ? nil : values.joined(separator: " + ")
    }

    private static func trendValue(current: Double?, bars: [FDailyBar]?, periods: [Int]) -> Double? {
        guard let current, let bars else { return nil }
        let averages = periods.compactMap { period -> Double? in
            guard let average = FDailyMovingAverage.values(for: bars, period: period).last.flatMap({ $0 }) else {
                return nil
            }
            return double(average).flatMap { $0 > 0 ? current / $0 - 1 : nil }
        }
        // A single moving average cannot describe a trend structure. Require
        // at least two independently available horizons (for example MA20/60).
        guard averages.count >= 2 else { return nil }
        let result = averages.reduce(0, +) / Double(averages.count)
        return result.isFinite ? result : nil
    }

    private static func movingAverageStructure(bars: [FDailyBar]?) -> Double? {
        guard let bars else { return nil }
        func latest(_ period: Int) -> Double? {
            guard let value = FDailyMovingAverage.values(for: bars, period: period).last.flatMap({ $0 }) else {
                return nil
            }
            return double(value)
        }
        let pairs = [(latest(5), latest(20)), (latest(20), latest(60)), (latest(60), latest(250))]
        let deviations = pairs.compactMap { short, long -> Double? in
            guard let short, let long, long > 0 else { return nil }
            let value = short / long - 1
            return value.isFinite ? value : nil
        }
        guard !deviations.isEmpty else { return nil }
        let result = deviations.reduce(0, +) / Double(deviations.count)
        return result.isFinite ? result : nil
    }

    private static func volumeWeightedAverage(_ samples: [FMinuteSample]) -> Double? {
        guard samples.count >= 20 else { return nil }
        let weightedSamples = samples.compactMap { sample -> (price: Double, volume: Double)? in
            guard let volume = sample.volume.flatMap(double), volume >= 0,
                  let price = double(sample.price) else { return nil }
            return (price, volume)
        }
        // The first Tencent observation has no safe volume delta, and an
        // occasional counter reset also leaves volume unknown. Exclude those
        // points, but fail closed when more than 10% of the session is missing.
        let minimumKnownVolumeSamples = Int(ceil(Double(samples.count) * 0.9))
        guard weightedSamples.count >= minimumKnownVolumeSamples else { return nil }
        var weighted = 0.0
        var volumeTotal = 0.0
        for sample in weightedSamples {
            let product = sample.price * sample.volume
            guard product.isFinite else { return nil }
            weighted += product
            volumeTotal += sample.volume
            guard weighted.isFinite, volumeTotal.isFinite else { return nil }
        }
        guard volumeTotal > 0 else { return nil }
        let result = weighted / volumeTotal
        return result.isFinite && result > 0 ? result : nil
    }

    private static func volumeCoverageNote(_ samples: [FMinuteSample]) -> String? {
        guard !samples.isEmpty else { return nil }
        let knownVolumeSamples = samples.filter { sample in
            guard let volume = sample.volume.flatMap(double) else { return false }
            return volume >= 0
        }.count
        guard knownVolumeSamples < samples.count else { return nil }
        let coveragePercent = knownVolumeSamples * 100 / samples.count
        return "VWAP仅使用已知成交量点：\(knownVolumeSamples)/\(samples.count)（\(coveragePercent)%）；未知量点已忽略"
    }

    /// Short-horizon factors must not treat gaps in archived/provider samples as
    /// adjacent minutes. VWAP remains session-wide and is calculated separately.
    private static func recentConsecutiveSamples(_ samples: [FMinuteSample]) -> [FMinuteSample] {
        let window = Array(samples.suffix(20))
        guard window.count == 20,
              zip(window, window.dropFirst()).allSatisfy({
                  let gap = $1.timestamp.timeIntervalSince($0.timestamp)
                  return gap.isFinite && gap > 0 && gap <= maximumIntradaySampleGap
              }) else { return [] }
        return window
    }

    private static func returnOverLastSamples(_ prices: [Double], count: Int) -> Double? {
        guard prices.count >= count, let first = prices.suffix(count).first,
              let last = prices.last, first > 0 else { return nil }
        let result = last / first - 1
        return result.isFinite ? result : nil
    }

    private static func meanReversionValue(_ prices: [Double]) -> Double? {
        let window = Array(prices.suffix(20))
        guard window.count >= 5, let current = window.last, current > 0 else { return nil }
        guard let mean = safeAverage(window), mean > 0 else { return nil }
        let result = mean / current - 1
        return result.isFinite ? result : nil
    }

    private static func volumeAnomaly(_ samples: [FMinuteSample]) -> Double? {
        guard samples.count >= 20 else { return nil }
        let window = Array(samples.suffix(20))
        let volumes = window.compactMap { $0.volume.flatMap(double) }
        guard volumes.count == 20, volumes.allSatisfy({ $0.isFinite && $0 >= 0 }) else { return nil }
        guard let baseline = safeAverage(Array(volumes.prefix(15))),
              let recent = safeAverage(Array(volumes.suffix(5))),
              baseline > 0 else { return nil }
        let ratio = recent / baseline
        guard ratio.isFinite, ratio > 0 else { return nil }
        let result = ratio - 1
        return result.isFinite ? result : nil
    }

    private static func returnVolatility<S: Collection>(_ values: S) -> Double?
        where S.Element == Double {
        let prices = Array(values)
        guard prices.count >= 3 else { return nil }
        var returns: [Double] = []
        for (previous, current) in zip(prices, prices.dropFirst()) {
            guard previous > 0 else { return nil }
            let value = current / previous - 1
            guard value.isFinite else { return nil }
            returns.append(value)
        }
        let mean = returns.reduce(0, +) / Double(returns.count)
        guard mean.isFinite else { return nil }
        let squared = returns.map { ($0 - mean) * ($0 - mean) }
        guard squared.allSatisfy(\.isFinite) else { return nil }
        let variance = squared.reduce(0, +) / Double(squared.count)
        // A flat but valid price series has zero realized volatility. Keep that
        // observation available; callers that need volatility as a divisor
        // already require a strictly positive scale.
        guard variance.isFinite, variance >= 0 else { return nil }
        let result = sqrt(variance)
        return result.isFinite && result >= 0 ? result : nil
    }

    private static func double(_ value: Decimal) -> Double? {
        let result = NSDecimalNumber(decimal: value).doubleValue
        return result.isFinite ? result : nil
    }

    private static func isComplete(_ quality: FChartDataQuality) -> Bool {
        if case .complete = quality { return true }
        return false
    }

    private static func safeAverage(_ values: [Double]) -> Double? {
        guard !values.isEmpty, values.allSatisfy(\.isFinite) else { return nil }
        let divisor = Double(values.count)
        var average = 0.0
        for value in values {
            average += value / divisor
            guard average.isFinite else { return nil }
        }
        return average
    }
}
