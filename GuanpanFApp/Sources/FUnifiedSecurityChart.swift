import SwiftUI
import FCore
import FAdvisor

/// The App's one renderer for live minutes, NAS archived minutes and daily bars.
/// Inputs remain source-labelled FCore chart models; missing overlays stay absent.
struct FUnifiedSecurityChart: View {
    let model: FChartOverlayModel?
    let height: CGFloat
    @State private var zoomScale: CGFloat = 1
    @State private var windowEndOffset = 0
    @State private var dragOriginOffset: Int?
    @State private var selectedTimestamp: Date?
    @State private var crosshairEnabled = false

    private let averagePeriods = [5, 10, 20, 60, 250]
    private let averageColors: [Color] = [.orange, .blue, .purple, .teal, .pink]

    var body: some View {
        GeometryReader { proxy in
            if let model, let series = model.chart.series, series.count > 0 {
                let timestamps = series.timestamps
                let count = timestamps.count
                let visibleCount = min(count, max(2, Int(CGFloat(count) / zoomScale)))
                let maxOffset = max(count - visibleCount, 0)
                let end = count - min(windowEndOffset, maxOffset)
                let start = max(0, end - visibleCount)
                let visibleRange = start..<end
                let visibleTimes = Set(visibleRange.map { timestamps[$0] })
                let selectedIndex = selectedTimestamp.flatMap { timestamp in
                    visibleRange.first(where: { timestamps[$0] == timestamp })
                }
                let interaction = try? FChartInteractionModel(
                    visibleRange: visibleRange, selectedIndex: selectedIndex,
                    zoomScale: Double(zoomScale), crosshairEnabled: crosshairEnabled,
                    presentation: .inline, pointCount: count)
                let priceRange = model.priceRange(interaction: interaction)
                let averages = movingAverages(for: series)

                VStack(alignment: .leading, spacing: 5) {
                    legend(for: model, averages: averages, range: visibleRange)
                    Canvas { context, size in
                        draw(model: model, series: series, range: visibleRange,
                             visibleTimes: visibleTimes, averages: averages,
                             priceRange: priceRange, selectedIndex: selectedIndex,
                             context: &context, size: size)
                    }
                    .contentShape(Rectangle())
                    .simultaneousGesture(SpatialTapGesture().onEnded { value in
                        let local = Double(value.location.x / max(proxy.size.width, 1))
                        let offset = min(max(Int(local * Double(visibleRange.count)), 0),
                                         max(visibleRange.count - 1, 0))
                        selectedTimestamp = timestamps[start + offset]
                        crosshairEnabled = true
                    })
                    // Allow the parent detail ScrollView to scroll when the user starts a
                    // vertical swipe over the chart; chart-specific pan/crosshair state is
                    // updated simultaneously and remains constrained to the chart data.
                    .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { value in
                        if crosshairEnabled {
                            let local = Double(value.location.x / max(proxy.size.width, 1))
                            let index = min(max(Int((local * Double(visibleRange.count)).rounded(.down)), 0),
                                            max(visibleRange.count - 1, 0))
                            if visibleRange.contains(start + index) {
                                selectedTimestamp = timestamps[start + index]
                            }
                        } else if zoomScale > 1.01 {
                            if dragOriginOffset == nil { dragOriginOffset = windowEndOffset }
                            let shift = Int((value.translation.width / max(proxy.size.width, 1)) *
                                            CGFloat(max(visibleRange.count, 1)))
                            windowEndOffset = min(max((dragOriginOffset ?? windowEndOffset) - shift, 0), maxOffset)
                        }
                    }.onEnded { _ in dragOriginOffset = nil })
                    .simultaneousGesture(MagnificationGesture().onEnded { value in
                        let next = min(max(zoomScale * value, 1), 12)
                        zoomScale = next
                        let nextVisible = min(count, max(2, Int(CGFloat(count) / next)))
                        windowEndOffset = next <= 1.01 ? 0 : min(windowEndOffset, max(count - nextVisible, 0))
                    })
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                        crosshairEnabled = true
                    })
                    HStack {
                        Text(timestamps[start].formatted(date: .abbreviated, time: .shortened))
                        Spacer()
                        if let selectedIndex {
                            Text(selectionText(series: series, index: selectedIndex))
                                .fontWeight(.semibold)
                        }
                        Spacer()
                        Text(timestamps[end - 1].formatted(date: .abbreviated, time: .shortened))
                    }
                    .font(.caption2.monospacedDigit())
                    .foregroundStyle(.secondary)
                    HStack {
                        Text("均价线：Unavailable · 前收线：Unavailable · IOPV：Unavailable")
                        Spacer()
                        Button(crosshairEnabled ? "退出十字" : "十字") {
                            crosshairEnabled.toggle()
                            if !crosshairEnabled { selectedTimestamp = nil }
                        }
                        .font(.caption2)
                        .buttonStyle(.bordered)
                        .controlSize(.mini)
                    }
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                }
            } else {
                Text("当前图表数据不可用；不会补造价格或曲线。")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: height)
        .padding(10)
        .background(.regularMaterial, in: RoundedRectangle(cornerRadius: 14))
        .accessibilityLabel("统一证券图表")
        .accessibilityHint("双指缩放；放大后拖动平移；长按或点击十字按钮后拖动查看数据点。")
    }

    @ViewBuilder
    private func legend(for model: FChartOverlayModel, averages: [[Decimal?]], range: Range<Int>) -> some View {
        HStack(spacing: 8) {
            if case .daily = model.chart.window {
                ForEach(Array(averagePeriods.enumerated()), id: \.element) { index, period in
                    let ready = averages[index].dropFirst(range.lowerBound).prefix(range.count).contains { $0 != nil }
                    Label("MA\(period)", systemImage: "line.diagonal")
                        .foregroundStyle(ready ? averageColors[index] : Color.secondary.opacity(0.5))
                }
                Label("成交量", systemImage: "chart.bar")
                    .foregroundStyle(.secondary)
            }
            ForEach(model.priceOverlays, id: \.kind.rawValue) { overlay in
                Label(overlayTitle(overlay.kind), systemImage: overlay.kind == .candidateBuy ? "arrowtriangle.up.fill" :
                      overlay.kind == .candidateSell ? "arrowtriangle.down.fill" : "line.diagonal")
                    .foregroundStyle(overlayColor(overlay.kind))
            }
            if model.iopv == nil { Label("IOPV Unavailable", systemImage: "minus.circle").foregroundStyle(.secondary) }
        }
        .font(.caption2.monospaced())
        .lineLimit(1)
        .minimumScaleFactor(0.75)
    }

    private func movingAverages(for series: FChartSeries) -> [[Decimal?]] {
        guard case let .daily(bars) = series else { return [] }
        return averagePeriods.map { period in
            bars.indices.map { index in
                guard index + 1 >= period else { return nil }
                let values = bars[(index + 1 - period)...index]
                return values.reduce(Decimal.zero) { $0 + $1.close } / Decimal(period)
            }
        }
    }

    private func draw(model: FChartOverlayModel, series: FChartSeries, range: Range<Int>,
                      visibleTimes: Set<Date>, averages: [[Decimal?]], priceRange: ClosedRange<Decimal>?,
                      selectedIndex: Int?, context: inout GraphicsContext, size: CGSize) {
        guard let priceRange, range.count > 0 else { return }
        let low = NSDecimalNumber(decimal: priceRange.lowerBound).doubleValue
        let high = NSDecimalNumber(decimal: priceRange.upperBound).doubleValue
        let priceHeight = isDaily(series) ? size.height * 0.74 : size.height
        let volumeHeight = max(size.height - priceHeight, 0)
        let span = max(high - low, 0.000001)
        func y(_ value: Decimal) -> CGFloat {
            priceHeight * (1 - CGFloat((NSDecimalNumber(decimal: value).doubleValue - low) / span))
        }
        for step in 0...3 {
            let lineY = priceHeight * CGFloat(step) / 3
            var grid = Path(); grid.move(to: CGPoint(x: 0, y: lineY)); grid.addLine(to: CGPoint(x: size.width, y: lineY))
            context.stroke(grid, with: .color(.secondary.opacity(0.12)), lineWidth: 1)
        }
        let stepX = size.width / CGFloat(max(range.count, 1))
        switch series {
        case let .minute(samples):
            var path = Path()
            for index in range {
                let point = CGPoint(x: stepX * (CGFloat(index - range.lowerBound) + 0.5), y: y(samples[index].price))
                if index == range.lowerBound { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(.accentColor), style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round))
        case let .daily(bars):
            let volumes = range.map { NSDecimalNumber(decimal: bars[$0].volume).doubleValue }
            let maxVolume = max(volumes.max() ?? 0, 1)
            for index in range {
                let bar = bars[index]
                let x = stepX * (CGFloat(index - range.lowerBound) + 0.5)
                let rising = bar.close >= bar.open
                let color: Color = rising ? .red : .green
                var wick = Path(); wick.move(to: CGPoint(x: x, y: y(bar.high))); wick.addLine(to: CGPoint(x: x, y: y(bar.low)))
                context.stroke(wick, with: .color(color), lineWidth: 1)
                let top = min(y(bar.open), y(bar.close))
                let body = CGRect(x: x - max(stepX * 0.27, 0.6), y: top,
                                  width: max(stepX * 0.54, 1), height: max(abs(y(bar.open) - y(bar.close)), 1))
                context.fill(Path(body), with: .color(color.opacity(0.85)))
                let volume = NSDecimalNumber(decimal: bar.volume).doubleValue
                let volumeBar = CGRect(x: x - max(stepX * 0.3, 0.6),
                                       y: priceHeight + volumeHeight * (1 - CGFloat(volume / maxVolume)),
                                       width: max(stepX * 0.6, 1), height: volumeHeight * CGFloat(volume / maxVolume))
                context.fill(Path(volumeBar), with: .color(color.opacity(0.55)))
            }
            for (seriesIndex, values) in averages.enumerated() {
                var path = Path(); var started = false
                for index in range {
                    guard let value = values[index] else { started = false; continue }
                    let point = CGPoint(x: stepX * (CGFloat(index - range.lowerBound) + 0.5), y: y(value))
                    if started { path.addLine(to: point) } else { path.move(to: point); started = true }
                }
                context.stroke(path, with: .color(averageColors[seriesIndex]), lineWidth: 1)
            }
        }
        for overlay in model.priceOverlays where !isUnavailable(overlay.quality) {
            if (overlay.kind == .candidateBuy || overlay.kind == .candidateSell),
               let timestamp = overlay.points.first?.timestamp, !visibleTimes.contains(timestamp) {
                continue
            }
            guard let value = overlay.points.first?.value else { continue }
            var path = Path()
            let lineY = y(value)
            if overlay.kind == .candidateBuy || overlay.kind == .candidateSell {
                path.move(to: CGPoint(x: 0, y: lineY)); path.addLine(to: CGPoint(x: size.width, y: lineY))
                context.stroke(path, with: .color(overlayColor(overlay.kind)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                context.draw(Text(overlayTitle(overlay.kind)).font(.caption2.bold()).foregroundColor(overlayColor(overlay.kind)),
                            at: CGPoint(x: 30, y: max(8, lineY - 8)))
            } else {
                let matching = overlay.points.filter { visibleTimes.contains($0.timestamp) }
                for point in matching {
                    guard let index = series.timestamps.firstIndex(of: point.timestamp), range.contains(index) else { continue }
                    let x = stepX * (CGFloat(index - range.lowerBound) + 0.5)
                    path.move(to: CGPoint(x: x, y: y(point.value)))
                    path.addLine(to: CGPoint(x: x + stepX, y: y(point.value)))
                }
                context.stroke(path, with: .color(overlayColor(overlay.kind)), style: StrokeStyle(lineWidth: 1.3, dash: [3, 2]))
            }
        }
        if let selectedIndex, range.contains(selectedIndex) {
            let x = stepX * (CGFloat(selectedIndex - range.lowerBound) + 0.5)
            var cursor = Path(); cursor.move(to: CGPoint(x: x, y: 0)); cursor.addLine(to: CGPoint(x: x, y: size.height))
            context.stroke(cursor, with: .color(.secondary.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    private func selectionText(series: FChartSeries, index: Int) -> String {
        switch series {
        case let .minute(samples): return "¥\(NSDecimalNumber(decimal: samples[index].price).stringValue)"
        case let .daily(bars):
            let bar = bars[index]
            return "开 \(bar.open) 高 \(bar.high) 低 \(bar.low) 收 \(bar.close) 量 \(bar.volume)"
        }
    }

    private func isDaily(_ series: FChartSeries) -> Bool {
        if case .daily = series { return true }; return false
    }
    private func isUnavailable(_ quality: FChartDataQuality) -> Bool {
        if case .unavailable = quality { return true }; return false
    }
    private func overlayTitle(_ kind: FChartOverlayKind) -> String {
        switch kind {
        case .cost: return "真实成本"
        case .intradayAverage: return "均价"
        case .previousClose: return "前收"
        case .iopv: return "IOPV"
        case .candidateBuy: return "B 候选"
        case .candidateSell: return "S 候选"
        }
    }
    private func overlayColor(_ kind: FChartOverlayKind) -> Color {
        switch kind {
        case .cost: return .orange
        case .intradayAverage: return .purple
        case .previousClose: return .gray
        case .iopv: return .cyan
        case .candidateBuy: return .green
        case .candidateSell: return .red
        }
    }
}

enum FChartPresentationBuilder {
    static func live(_ snapshot: FCurrentIntradaySnapshot?, holding: FHomeHolding?,
                     candidate: FCandidateRecommendation?, ledgerCapturedAt: Date?) -> FChartOverlayModel? {
        guard let snapshot else { return nil }
        let session = FMainlandTradingCalendar.status(at: Date())
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: snapshot.quoteTimestamp,
                                              fetchedAt: snapshot.fetchedAt, source: snapshot.source,
                                              timestampTrust: .verifiedExchangeTimestamp,
                                              marketSessionStatus: session)
        let quality: FChartDataQuality = session == .continuous &&
            Date().timeIntervalSince(snapshot.quoteTimestamp) > 300 ? .stale(reason: "超过5分钟未更新") : .complete
        guard let chart = try? FChartDataModel(securityCode: snapshot.securityCode, window: .liveIntraday,
                                               series: .minute(snapshot.samples), quality: quality,
                                               temporalMetadata: metadata) else { return nil }
        return makeOverlay(chart: chart, holding: holding, candidate: candidate, capturedAt: ledgerCapturedAt)
    }

    static func historical(_ archive: FNASArchivedIntraday?, holding: FHomeHolding?,
                           ledgerCapturedAt: Date?) -> FChartOverlayModel? {
        guard let archive, !archive.samples.isEmpty else { return nil }
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: archive.fetchedAt,
                                              source: archive.sourceSummary,
                                              timestampTrust: .fetchedAtOnly, marketSessionStatus: .closed)
        let status = archive.coverageStatus.lowercased()
        let quality: FChartDataQuality = status == "complete" ? .complete :
            (status.contains("stale") ? .stale(reason: archive.coverageSummary) : .partial(reason: archive.coverageSummary))
        guard let chart = try? FChartDataModel(securityCode: archive.securityCode,
                                               window: .historicalIntraday(tradingDate: archive.samples[0].timestamp),
                                               series: .minute(archive.samples), quality: quality,
                                               temporalMetadata: metadata) else { return nil }
        return makeOverlay(chart: chart, holding: holding, candidate: nil, capturedAt: ledgerCapturedAt)
    }

    static func daily(_ snapshot: FDailyKlineSnapshot?, holding: FHomeHolding?,
                      candidate: FCandidateRecommendation?, ledgerCapturedAt: Date?) -> FChartOverlayModel? {
        guard let snapshot else { return nil }
        let metadata = FQuoteTemporalMetadata(quoteTimestamp: nil, fetchedAt: snapshot.fetchedAt,
                                              source: snapshot.source,
                                              timestampTrust: .fetchedAtOnly, marketSessionStatus: .closed)
        guard let chart = try? FChartDataModel(securityCode: snapshot.securityCode, window: .daily,
                                               series: .daily(snapshot.bars), quality: .complete,
                                               temporalMetadata: metadata) else { return nil }
        return makeOverlay(chart: chart, holding: holding, candidate: candidate, capturedAt: ledgerCapturedAt)
    }

    private static func makeOverlay(chart: FChartDataModel, holding: FHomeHolding?,
                                    candidate: FCandidateRecommendation?, capturedAt: Date?) -> FChartOverlayModel? {
        var overlays: [FChartPriceOverlay] = []
        if let holding, holding.instrumentCode == chart.securityCode, holding.units > 0,
           let capturedAt, let timestamps = chart.series?.timestamps, !timestamps.isEmpty {
            let unitCost = holding.bookCost / Decimal(holding.units)
            let points = timestamps.map { FChartOverlayPoint(timestamp: $0, value: unitCost) }
            if let cost = try? FChartPriceOverlay(securityCode: chart.securityCode, kind: .cost,
                                                  points: points, quality: .complete,
                                                  source: "F Real Ledger confirmed cost", fetchedAt: capturedAt) {
                overlays.append(cost)
            }
        }
        if let candidate, candidate.instrumentCode == chart.securityCode,
           let limit = candidate.limitPrice, limit > 0,
           candidate.action == .buy || candidate.action == .sell,
           let timestamp = chart.series?.timestamps.last {
            let kind: FChartOverlayKind = candidate.action == .buy ? .candidateBuy : .candidateSell
            if let marker = try? FChartPriceOverlay(securityCode: chart.securityCode, kind: kind,
                                                   points: [FChartOverlayPoint(timestamp: timestamp, value: limit)],
                                                   quality: .complete,
                                                   source: "AI Candidate Plan \(candidate.id)", fetchedAt: Date()) {
                overlays.append(marker)
            }
        }
        return try? FChartOverlayModel(chart: chart, priceOverlays: overlays,
                                       iopv: try? FIOPVObservation(securityCode: chart.securityCode,
                                                                   value: nil, observedAt: nil, fetchedAt: nil,
                                                                   source: nil,
                                                                   quality: .unavailable(reason: "没有可靠 IOPV 数据源")))
    }
}
