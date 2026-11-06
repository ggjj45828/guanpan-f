import Foundation

/// MACD configuration shared by charts, Local Quant and Advisor context.
public struct FMACDParameters: Equatable, Sendable {
    public let fast: Int
    public let slow: Int
    public let signal: Int

    public init(fast: Int = 12, slow: Int = 26, signal: Int = 9) throws {
        guard fast > 0, slow > fast, signal > 0, fast <= 250, slow <= 500, signal <= 100 else {
            throw FMACDError.invalidParameters
        }
        self.fast = fast
        self.slow = slow
        self.signal = signal
    }

    public static let standard = try! FMACDParameters(fast: 12, slow: 26, signal: 9)
    public static let responsive = try! FMACDParameters(fast: 6, slow: 13, signal: 5)
    /// Number of input bars required before the first complete DIF/DEA point.
    /// With SMA-seeded EMAs, DIF starts at zero-based `slow - 1`; the signal EMA
    /// then needs `signal` DIF observations, so the first point is at
    /// `slow + signal - 2` and the required bar count is one greater.
    public var warmupBars: Int { slow + signal - 1 }
}

public enum FMACDError: Error, Equatable, Sendable {
    case invalidParameters
}

public enum FMACDTimeframe: String, CaseIterable, Equatable, Sendable {
    case daily, weekly, monthly, minutes120, minutes60, minutes30, minutes15, minutes1
}

public struct FMACDInputBar: Equatable, Sendable {
    public let timestamp: Date
    public let close: Double?
    public let volume: Double?
    /// False for an in-progress candle. It may be displayed as provisional, never finalized.
    public let isFinal: Bool

    public init(timestamp: Date, close: Double?, volume: Double? = nil, isFinal: Bool = true) {
        self.timestamp = timestamp
        self.close = close
        self.volume = volume
        self.isFinal = isFinal
    }
}

public struct FMACDPoint: Equatable, Sendable {
    public let inputIndex: Int
    public let timestamp: Date
    public let close: Double
    public let dif: Double
    public let dea: Double
    /// Standard display convention: 2 × (DIF − DEA).
    public let histogram: Double
}

public struct FMACDSeries: Equatable, Sendable {
    public let timeframe: FMACDTimeframe
    public let parameters: FMACDParameters
    public let points: [FMACDPoint]
    public let inputCount: Int
    public let validInputCount: Int
    public let finalized: Bool
    public let reasonCodes: [String]

    public var completeness: Double {
        inputCount == 0 ? 0 : Double(validInputCount) / Double(inputCount)
    }
    public var latest: FMACDPoint? { points.last }
}

/// Deterministic MACD implementation. EMA is seeded with the arithmetic mean of the first
/// `period` valid closes; a missing/invalid bar breaks the run and restarts warm-up. No gaps
/// are silently bridged. DIF/DEA are emitted only after their respective seeds are complete.
public enum FMACDEngine {
    public static func calculate(bars: [FMACDInputBar], timeframe: FMACDTimeframe,
                                 parameters: FMACDParameters = .standard) -> FMACDSeries {
        guard bars.allSatisfy({ $0.timestamp.timeIntervalSince1970.isFinite }),
              zip(bars, bars.dropFirst()).allSatisfy({ $0.0.timestamp < $0.1.timestamp }) else {
            return FMACDSeries(timeframe: timeframe, parameters: parameters, points: [],
                               inputCount: bars.count, validInputCount: 0, finalized: false,
                               reasonCodes: ["macd_bar_timeline_invalid"])
        }
        var points: [FMACDPoint] = []
        var closeRun: [Double] = []
        var difRun: [Double] = []
        var fastEMA: Double?
        var slowEMA: Double?
        var signalEMA: Double?
        var validCount = 0
        var numericalFailure = false
        let fastAlpha = 2.0 / Double(parameters.fast + 1)
        let slowAlpha = 2.0 / Double(parameters.slow + 1)
        let signalAlpha = 2.0 / Double(parameters.signal + 1)

        for (index, bar) in bars.enumerated() {
            guard let close = bar.close, close.isFinite, close > 0,
                  bar.timestamp.timeIntervalSince1970.isFinite else {
                closeRun.removeAll(keepingCapacity: true)
                difRun.removeAll(keepingCapacity: true)
                fastEMA = nil; slowEMA = nil; signalEMA = nil
                continue
            }
            validCount += 1
            closeRun.append(close)
            if fastEMA == nil {
                if closeRun.count >= parameters.fast {
                    fastEMA = stableMean(closeRun.suffix(parameters.fast))
                }
            } else {
                fastEMA = fastAlpha * close + (1 - fastAlpha) * fastEMA!
            }
            if slowEMA == nil {
                if closeRun.count >= parameters.slow {
                    slowEMA = stableMean(closeRun.suffix(parameters.slow))
                }
            } else {
                slowEMA = slowAlpha * close + (1 - slowAlpha) * slowEMA!
            }
            guard let fast = fastEMA, let slow = slowEMA else { continue }
            let dif = fast - slow
            guard fast.isFinite, slow.isFinite, dif.isFinite else {
                numericalFailure = true
                closeRun.removeAll(keepingCapacity: true)
                difRun.removeAll(keepingCapacity: true)
                fastEMA = nil; slowEMA = nil; signalEMA = nil
                continue
            }
            difRun.append(dif)
            if signalEMA == nil {
                if difRun.count >= parameters.signal {
                    signalEMA = stableMean(difRun.suffix(parameters.signal))
                }
            } else {
                signalEMA = signalAlpha * dif + (1 - signalAlpha) * signalEMA!
            }
            guard let dea = signalEMA else { continue }
            let histogram = 2 * (dif - dea)
            guard dea.isFinite, histogram.isFinite else {
                numericalFailure = true
                closeRun.removeAll(keepingCapacity: true)
                difRun.removeAll(keepingCapacity: true)
                fastEMA = nil; slowEMA = nil; signalEMA = nil
                continue
            }
            points.append(FMACDPoint(inputIndex: index, timestamp: bar.timestamp, close: close,
                                     dif: dif, dea: dea, histogram: histogram))
        }
        return FMACDSeries(timeframe: timeframe, parameters: parameters, points: points,
                           inputCount: bars.count, validInputCount: validCount,
                           finalized: bars.last?.isFinal == true && points.last?.inputIndex == bars.count - 1,
                           reasonCodes: (points.isEmpty ? ["macd_warmup_or_history_insufficient"] : []) +
                            (numericalFailure ? ["macd_non_finite_intermediate_rejected"] : []))
    }

    private static func stableMean<S: Sequence>(_ values: S) -> Double? where S.Element == Double {
        var mean = 0.0
        var count = 0
        for value in values {
            count += 1
            mean += (value - mean) / Double(count)
            guard mean.isFinite else { return nil }
        }
        return count > 0 ? mean : nil
    }
}

public enum FMACDTrend: String, Equatable, Sendable {
    case bullishImproving, shortTermRebound, neutral, weakening, bearish
    case oversoldButUnconfirmed, conflictingSignals, dataInsufficient
}

public enum FMACDCross: String, Equatable, Sendable { case none, golden, death }

public struct FMACDTimeframeAssessment: Equatable, Sendable {
    public let timeframe: FMACDTimeframe
    public let trend: FMACDTrend
    public let difAboveZero: Bool?
    public let deaAboveZero: Bool?
    public let histogramIncreasing: Bool?
    public let histogramExpanding: Bool?
    public let cross: FMACDCross
    public let signalConfirmed: Bool
    public let dataQuality: Double
    public let reasonCodes: [String]
}

public struct FMultiTimeframeMACDAssessment: Equatable, Sendable {
    public let daily: FMACDTimeframeAssessment
    public let intraday: FMACDTimeframeAssessment?
    public let relationship: String
    public let reasonCodes: [String]
}

/// Compares only supplied, real timeframe series. The caller is responsible for source,
/// coverage and session validation; a missing timeframe stays unavailable.
public enum FMultiTimeframeMACDAnalyzer {
    public static func assess(_ series: FMACDSeries, maEvidenceAvailable: Bool? = nil,
                              volumeEvidenceAvailable: Bool? = nil) -> FMACDTimeframeAssessment {
        let points = series.points
        guard let last = points.last, points.count >= 2 else {
            return .init(timeframe: series.timeframe, trend: .dataInsufficient,
                         difAboveZero: nil, deaAboveZero: nil, histogramIncreasing: nil,
                         histogramExpanding: nil, cross: .none, signalConfirmed: false,
                         dataQuality: series.completeness, reasonCodes: ["macd_warmup_or_history_insufficient"])
        }
        let previous = points[points.count - 2]
        guard last.inputIndex == previous.inputIndex + 1 else {
            return .init(timeframe: series.timeframe, trend: .dataInsufficient,
                         difAboveZero: last.dif > 0, deaAboveZero: last.dea > 0,
                         histogramIncreasing: nil, histogramExpanding: nil, cross: .none,
                         signalConfirmed: false, dataQuality: series.completeness,
                         reasonCodes: ["macd_gap_between_latest_points"])
        }
        let increasing = last.histogram > previous.histogram
        let expanding = abs(last.histogram) > abs(previous.histogram)
        let cross: FMACDCross = previous.dif <= previous.dea && last.dif > last.dea ? .golden :
            (previous.dif >= previous.dea && last.dif < last.dea ? .death : .none)
        let trend: FMACDTrend
        // MA and volume are separately reported evidence. Their presence does not
        // upgrade a technical state into an efficacy claim or a trade strategy.
        if increasing && last.dif > last.dea {
            trend = last.dif < 0 ? .shortTermRebound : .bullishImproving
        } else if !increasing && last.dif > last.dea {
            trend = .weakening
        } else if last.dif < 0 && last.dea < 0 && !increasing {
            trend = .bearish
        } else {
            trend = .neutral
        }
        var reasons = ["macd_calculated_from_real_bars"] + series.reasonCodes
        if cross == .golden { reasons.append("dif_crossed_above_dea") }
        if cross == .death { reasons.append("dif_crossed_below_dea") }
        if !series.finalized { reasons.append("latest_bar_provisional") }
        if maEvidenceAvailable == nil { reasons.append("ma_evidence_unavailable") }
        if volumeEvidenceAvailable == nil { reasons.append("volume_evidence_unavailable") }
        if maEvidenceAvailable == true { reasons.append("ma_alignment_is_descriptive_evidence_only") }
        if volumeEvidenceAvailable == true { reasons.append("volume_state_is_descriptive_evidence_only") }
        return .init(timeframe: series.timeframe, trend: trend,
                     difAboveZero: last.dif > 0, deaAboveZero: last.dea > 0,
                     histogramIncreasing: increasing, histogramExpanding: expanding,
                     cross: cross, signalConfirmed: series.finalized,
                     dataQuality: series.completeness, reasonCodes: reasons)
    }

    public static func combine(daily: FMACDSeries, intraday: FMACDSeries?) -> FMultiTimeframeMACDAssessment {
        let dailyResult = assess(daily)
        let intradayResult = intraday.map { assess($0) }
        let relationship: String
        if let intradayResult {
            if dailyResult.trend == intradayResult.trend {
                relationship = "日线与\(intradayResult.timeframe.rawValue)信号一致"
            } else if intradayResult.trend == .bullishImproving || intradayResult.trend == .shortTermRebound {
                relationship = "短期动能改善，中期趋势待确认"
            } else {
                relationship = "多周期信号冲突，等待更多证据"
            }
        } else {
            relationship = "仅有日线数据；短周期不可用"
        }
        return .init(daily: dailyResult, intraday: intradayResult, relationship: relationship,
                     reasonCodes: intradayResult == nil ? ["intraday_timeframe_unavailable"] : [])
    }
}

