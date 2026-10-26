import Foundation

public enum FChartWindow: Equatable, Sendable {
    case liveIntraday
    case historicalIntraday(tradingDate: Date)
    case daily
}

public enum FChartSeries: Equatable, Sendable {
    case minute([FMinuteSample])
    case daily([FDailyBar])

    public var count: Int {
        switch self {
        case let .minute(values): return values.count
        case let .daily(values): return values.count
        }
    }

    public var timestamps: [Date] {
        switch self {
        case let .minute(values): return values.map(\.timestamp)
        case let .daily(values): return values.map(\.tradingDate)
        }
    }
}

public enum FChartDataQuality: Equatable, Sendable {
    case complete
    case partial(reason: String)
    case stale(reason: String)
    case unavailable(reason: String)

    public var statusLabel: String {
        switch self {
        case .complete: return "Complete"
        case .partial(_): return "Partial"
        case .stale(_): return "Stale"
        case .unavailable(_): return "Unavailable"
        }
    }

    fileprivate var reason: String? {
        switch self {
        case .complete: return nil
        case let .partial(reason), let .stale(reason), let .unavailable(reason): return reason
        }
    }
}

/// Common container for live minutes, archived minutes, and daily bars.
/// A non-empty dataset always carries source and retrieval-time metadata.
public struct FChartDataModel: Equatable, Sendable {
    public let securityCode: String
    public let window: FChartWindow
    public let series: FChartSeries?
    public let quality: FChartDataQuality
    public let temporalMetadata: FQuoteTemporalMetadata?

    public init(securityCode: String, window: FChartWindow, series: FChartSeries?,
                quality: FChartDataQuality, temporalMetadata: FQuoteTemporalMetadata?) throws {
        let count = series?.count ?? 0
        let metadata = temporalMetadata
        let hasMetadata = metadata?.source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false &&
            metadata?.fetchedAt != nil
        let ordered = series.map { values in
            zip(values.timestamps, values.timestamps.dropFirst()).allSatisfy { $0.0 < $0.1 }
        } ?? true
        let windowMatchesSeries: Bool
        switch window {
        case .liveIntraday, .historicalIntraday(_):
            if let series {
                if case .minute(_) = series { windowMatchesSeries = true }
                else { windowMatchesSeries = false }
            } else {
                windowMatchesSeries = true
            }
        case .daily:
            if let series {
                if case .daily(_) = series { windowMatchesSeries = true }
                else { windowMatchesSeries = false }
            } else {
                windowMatchesSeries = true
            }
        }
        let qualityMatchesCount: Bool
        switch quality {
        case .unavailable(_):
            qualityMatchesCount = count == 0 && FChartDataQuality.nonBlank(quality.reason)
        case .partial(_), .stale(_):
            qualityMatchesCount = count > 0 && FChartDataQuality.nonBlank(quality.reason)
        case .complete:
            qualityMatchesCount = count > 0
        }
        let liveTimeIsVerified: Bool
        if case .liveIntraday = window, count > 0 {
            liveTimeIsVerified = metadata?.timestampTrust == .verifiedExchangeTimestamp &&
                metadata?.quoteTimestamp == series?.timestamps.last
        } else {
            liveTimeIsVerified = metadata?.quoteTimestamp == nil
        }
        let metadataIsConsistent = metadata.map { value in
            guard let source = value.source, let fetchedAt = value.fetchedAt else { return false }
            return value.isConsistent(source: source, observedAt: value.quoteTimestamp,
                                      capturedAt: fetchedAt)
        } ?? (count == 0)
        guard securityCode.count == 6, securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }),
              windowMatchesSeries, ordered, qualityMatchesCount, metadataIsConsistent,
              (count == 0 || hasMetadata), liveTimeIsVerified else {
            throw FMarketDataError.invalidPayload
        }
        self.securityCode = securityCode
        self.window = window
        self.series = series
        self.quality = quality
        self.temporalMetadata = temporalMetadata
    }
}

public struct FIOPVObservation: Equatable, Sendable {
    public let securityCode: String
    public let value: Decimal?
    public let observedAt: Date?
    public let fetchedAt: Date?
    public let source: String?
    public let quality: FChartDataQuality

    public init(securityCode: String, value: Decimal?, observedAt: Date?, fetchedAt: Date?,
                source: String?, quality: FChartDataQuality) throws {
        let unavailable: Bool
        if case .unavailable(_) = quality { unavailable = true } else { unavailable = false }
        let qualityHasReason: Bool
        switch quality {
        case .partial(_), .stale(_): qualityHasReason = FChartDataQuality.nonBlank(quality.reason)
        default: qualityHasReason = true
        }
        let timesOrdered: Bool
        if let observedAt, let fetchedAt { timesOrdered = observedAt <= fetchedAt }
        else { timesOrdered = false }
        let validAvailable = !unavailable && qualityHasReason && value.map { $0 > 0 && !$0.isNaN } == true &&
            timesOrdered && source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false
        let validUnavailable = unavailable && value == nil && observedAt == nil &&
            fetchedAt == nil && source == nil && FChartDataQuality.nonBlank(quality.reason)
        guard securityCode.count == 6, securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }),
              validAvailable || validUnavailable else {
            throw FMarketDataError.invalidPayload
        }
        self.securityCode = securityCode
        self.value = value
        self.observedAt = observedAt
        self.fetchedAt = fetchedAt
        self.source = source
        self.quality = quality
    }
}

public enum FChartOverlayKind: String, Equatable, Sendable {
    case cost, intradayAverage, previousClose, iopv, candidateBuy, candidateSell
}

public struct FChartOverlayPoint: Equatable, Sendable {
    public let timestamp: Date
    public let value: Decimal

    public init(timestamp: Date, value: Decimal) {
        self.timestamp = timestamp
        self.value = value
    }
}

public struct FChartPriceOverlay: Equatable, Sendable {
    public let securityCode: String
    public let kind: FChartOverlayKind
    public let points: [FChartOverlayPoint]
    public let quality: FChartDataQuality
    public let source: String?
    public let fetchedAt: Date?

    public init(securityCode: String, kind: FChartOverlayKind, points: [FChartOverlayPoint], quality: FChartDataQuality,
                source: String?, fetchedAt: Date?) throws {
        let ordered = zip(points, points.dropFirst()).allSatisfy { $0.0.timestamp < $0.1.timestamp }
        let unavailable: Bool
        if case .unavailable(_) = quality { unavailable = true } else { unavailable = false }
        let validUnavailable = unavailable && points.isEmpty && FChartDataQuality.nonBlank(quality.reason)
        let qualityHasReason: Bool
        switch quality {
        case .partial(_), .stale(_): qualityHasReason = FChartDataQuality.nonBlank(quality.reason)
        default: qualityHasReason = true
        }
        let validAvailable = !unavailable && qualityHasReason && !points.isEmpty && ordered &&
            points.allSatisfy { $0.value > 0 && !$0.value.isNaN } &&
            source?.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty == false && fetchedAt != nil
        guard securityCode.count == 6, securityCode.utf8.count == 6,
              securityCode.utf8.allSatisfy({ (48...57).contains($0) }),
              validAvailable || validUnavailable else {
            throw FMarketDataError.invalidPayload
        }
        self.securityCode = securityCode
        self.kind = kind
        self.points = points
        self.quality = quality
        self.source = source
        self.fetchedAt = fetchedAt
    }
}

/// The single overlay container shared by live-minute, archived-minute and
/// daily charts.  It deliberately accepts only source-labelled observations;
/// callers cannot manufacture an IOPV or price line just to make a chart look
/// complete.
public struct FChartOverlayModel: Equatable, Sendable {
    public let chart: FChartDataModel
    public let priceOverlays: [FChartPriceOverlay]
    public let iopv: FIOPVObservation?

    public init(chart: FChartDataModel, priceOverlays: [FChartPriceOverlay] = [],
                iopv: FIOPVObservation? = nil) throws {
        guard priceOverlays.allSatisfy({ $0.securityCode == chart.securityCode }),
              iopv?.securityCode == nil || iopv?.securityCode == chart.securityCode else {
            throw FMarketDataError.invalidPayload
        }
        let duplicateKinds = Dictionary(grouping: priceOverlays, by: \.kind)
            .values.contains { $0.count > 1 }
        guard !duplicateKinds else { throw FMarketDataError.invalidPayload }
        self.chart = chart
        self.priceOverlays = priceOverlays
        self.iopv = iopv
    }

    /// Returns the price range for the current viewport.  Candle high/low,
    /// minute price, and every available overlay participate together, so a
    /// real cost, average-price, previous-close or IOPV line cannot be pushed
    /// outside the visible vertical range.  Unavailable data contributes no
    /// synthetic value.
    public func priceRange(interaction: FChartInteractionModel? = nil) -> ClosedRange<Decimal>? {
        let timestamps = chart.series?.timestamps ?? []
        let visibleIndices: Range<Int>
        if let range = interaction?.visibleRange, range.upperBound <= timestamps.count {
            visibleIndices = range
        } else {
            visibleIndices = 0..<timestamps.count
        }
        let visibleTimes = Set(visibleIndices.compactMap { timestamps[safe: $0] })
        var values = basePrices(indices: visibleIndices)
        for overlay in priceOverlays {
            guard !overlay.isUnavailable else { continue }
            values += overlay.points
                .filter { visibleTimes.isEmpty || visibleTimes.contains($0.timestamp) }
                .map(\.value)
        }
        if let iopv, iopv.isAvailable, let value = iopv.value {
            values.append(value)
        }
        guard let low = values.min(), let high = values.max() else { return nil }
        let span = high - low
        let padding = max(span / 20, max(abs(low), abs(high)) / 10_000)
        return (low - padding)...(high + padding)
    }

    private func basePrices(indices: Range<Int>) -> [Decimal] {
        guard let series = chart.series else { return [] }
        switch series {
        case let .minute(samples):
            return indices.compactMap { samples[safe: $0]?.price }
        case let .daily(bars):
            let candleValues = indices.flatMap { index -> [Decimal] in
                guard let bar = bars[safe: index] else { return [] }
                return [bar.low, bar.high]
            }
            let movingAverages = [5, 10, 20, 60, 250].flatMap { period in
                indices.compactMap { index -> Decimal? in
                    guard index + 1 >= period else { return nil }
                    let window = bars[(index + 1 - period)...index]
                    return window.reduce(Decimal.zero) { $0 + $1.close } / Decimal(period)
                }
            }
            return candleValues + movingAverages
        }
    }
}

private extension FChartPriceOverlay {
    var isUnavailable: Bool {
        if case .unavailable = quality { return true }
        return false
    }
}

private extension FIOPVObservation {
    var isAvailable: Bool {
        if case .unavailable = quality { return false }
        return value != nil
    }
}

public enum FChartPresentation: String, Equatable, Sendable {
    case inline
    case landscapeFullscreen
}

/// Platform-neutral interaction state; SwiftUI gestures should update this
/// value rather than maintaining chart-specific selection rules per screen.
public struct FChartInteractionModel: Equatable, Sendable {
    public let visibleRange: Range<Int>?
    public let selectedIndex: Int?
    public let zoomScale: Double
    public let crosshairEnabled: Bool
    public let presentation: FChartPresentation

    public init(visibleRange: Range<Int>?, selectedIndex: Int?, zoomScale: Double,
                crosshairEnabled: Bool, presentation: FChartPresentation, pointCount: Int) throws {
        let validRange = visibleRange.map { $0.lowerBound >= 0 && $0.upperBound <= pointCount && !$0.isEmpty } ?? true
        let validSelection = selectedIndex.map { index in
            guard let visibleRange else { return false }
            return visibleRange.contains(index)
        } ?? true
        guard pointCount >= 0, validRange, validSelection,
              zoomScale.isFinite, zoomScale >= 1, zoomScale <= 32 else {
            throw FMarketDataError.invalidPayload
        }
        self.visibleRange = visibleRange
        self.selectedIndex = selectedIndex
        self.zoomScale = zoomScale
        self.crosshairEnabled = crosshairEnabled
        self.presentation = presentation
    }
}

private extension FChartDataQuality {
    static func nonBlank(_ value: String?) -> Bool {
        guard let value else { return false }
        return !value.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
    }
}

private extension Collection {
    subscript(safe index: Index) -> Element? {
        indices.contains(index) ? self[index] : nil
    }
}
