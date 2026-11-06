import SwiftUI
import FCore
import FAdvisor

private struct FChartMACDPoint {
    let dif: Double
    let dea: Double
    let histogram: Double
}

/// The App's one renderer for live minutes, NAS archived minutes and daily bars.
/// Inputs remain source-labelled FCore chart models; missing overlays stay absent.
struct FUnifiedSecurityChart: View {
    let model: FChartOverlayModel?
    let height: CGFloat
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.editorial.rawValue
    @AppStorage("guanpan.f.chart.visibleLayers") private var visibleLayerKeysRaw = "ma5,ma10,ma20,ma60,ma250,volume,cost,brokerCost,intradayAverage,previousClose,candidateBuy,candidateSell,iopv"
    @AppStorage("guanpan.f.chart.subchart") private var subchartMode = "volume"
    @State private var zoomScale: CGFloat = 1
    @GestureState private var liveMagnification: CGFloat = 1
    @State private var windowEndOffset = 0
    @State private var dragOriginOffset: Int?
    @State private var selectedTimestamp: Date?
    @State private var crosshairEnabled = false

    private let averagePeriods = [5, 10, 20, 60, 250]
    private let plotLeftInset: CGFloat = 38
    private let plotRightInset: CGFloat = 8
    private var averageColors: [Color] { theme.manifest.tokens.movingAverages }
    private var theme: FHomeTheme { FHomeTheme.selected(themeRaw) }

    var body: some View {
        GeometryReader { proxy in
            if let model, let series = model.chart.series, series.count > 0 {
                let timestamps = series.timestamps
                let count = timestamps.count
                let displayedZoomScale = min(max(zoomScale * liveMagnification, 1), 12)
                let visibleCount = min(count, max(2, Int(CGFloat(count) / displayedZoomScale)))
                let maxOffset = max(count - visibleCount, 0)
                let end = count - min(windowEndOffset, maxOffset)
                let start = max(0, end - visibleCount)
                let visibleRange = start..<end
                let minuteDomain = minuteDisplayDomain(series: series, range: visibleRange,
                                                       zoomScale: displayedZoomScale, window: model.chart.window)
                let visibleTimes = Set(visibleRange.map { timestamps[$0] })
                let selectedIndex = selectedTimestamp.flatMap { timestamp in
                    visibleRange.first(where: { timestamps[$0] == timestamp })
                }
                let interaction = try? FChartInteractionModel(
                    visibleRange: visibleRange, selectedIndex: selectedIndex,
                    zoomScale: Double(displayedZoomScale), crosshairEnabled: crosshairEnabled,
                    presentation: .inline, pointCount: count)
                let selectedAveragePeriods = Set(averagePeriods.filter { visibleLayerKeys.contains("ma\($0)") })
                let displayModel = modelWithVisibleOverlays(model)
                let priceRange = displayModel.priceRange(interaction: interaction,
                                                         visibleMovingAveragePeriods: selectedAveragePeriods)
                let averages = movingAverages(for: series)
                let macd = macdValues(for: series)

                let compact = height < 240
                VStack(alignment: .leading, spacing: compact ? 3 : 9) {
                    if compact {
                        compactHeader(model: model, window: model.chart.window)
                    } else {
                        chartHeader(model: model, series: series, selectedIndex: selectedIndex)
                        layerControls(for: model, averages: averages, range: visibleRange)
                    }
                    Canvas { context, size in
                        draw(model: displayModel, series: series, range: visibleRange,
                             visibleTimes: visibleTimes, averages: averages,
                             priceRange: priceRange, minuteDomain: minuteDomain, selectedIndex: selectedIndex,
                             visibleLayers: visibleLayerKeys, macd: macd, subchartMode: subchartMode,
                             context: &context, size: size)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(SpatialTapGesture().onEnded { value in
                        selectedTimestamp = timestamps[nearestIndex(
                            at: value.location.x, width: proxy.size.width,
                            series: series, range: visibleRange, minuteDomain: minuteDomain)]
                        crosshairEnabled = true
                    })
                    // Allow the parent detail ScrollView to scroll when the user starts a
                    // vertical swipe over the chart; chart-specific pan/crosshair state is
                    // updated simultaneously and remains constrained to the chart data.
                    .simultaneousGesture(DragGesture(minimumDistance: 8).onChanged { value in
                        // Vertical swipes belong to the surrounding detail ScrollView.
                        // Chart interaction is limited to deliberate horizontal drags.
                        let horizontal = abs(value.translation.width)
                        let vertical = abs(value.translation.height)
                        guard horizontal > vertical * 1.15 else { return }
                        if crosshairEnabled {
                            selectedTimestamp = timestamps[nearestIndex(
                                at: value.location.x, width: proxy.size.width,
                                series: series, range: visibleRange, minuteDomain: minuteDomain)]
                        } else if zoomScale > 1.01 {
                            if dragOriginOffset == nil { dragOriginOffset = windowEndOffset }
                            let shift = Int((value.translation.width / max(proxy.size.width, 1)) *
                                            CGFloat(max(visibleRange.count, 1)))
                            windowEndOffset = min(max((dragOriginOffset ?? windowEndOffset) - shift, 0), maxOffset)
                        }
                    }.onEnded { _ in dragOriginOffset = nil })
                    .simultaneousGesture(
                        MagnificationGesture()
                            .updating($liveMagnification) { value, state, _ in state = value }
                            .onEnded { value in
                                let next = min(max(zoomScale * value, 1), 12)
                                zoomScale = next
                                let nextVisible = min(count, max(2, Int(CGFloat(count) / next)))
                                windowEndOffset = next <= 1.01 ? 0 : min(windowEndOffset, max(count - nextVisible, 0))
                            }
                    )
                    .simultaneousGesture(LongPressGesture(minimumDuration: 0.35).onEnded { _ in
                        crosshairEnabled = true
                    })
                    if !compact {
                        HStack {
                            Text(unavailableOverlaySummary(model))
                                .lineLimit(1).minimumScaleFactor(0.75)
                            Spacer()
                            Text(timestampLabel(timestamps[start], window: model.chart.window))
                            Text("—").foregroundStyle(theme.manifest.tokens.secondaryForeground)
                            Text(timestampLabel(timestamps[end - 1], window: model.chart.window))
                            Button(crosshairEnabled ? "退出十字" : "十字") {
                                crosshairEnabled.toggle()
                                if !crosshairEnabled { selectedTimestamp = nil }
                            }
                            .font(.caption2.weight(.semibold)).buttonStyle(.bordered).controlSize(.mini)
                        }
                        .font(.caption2)
                        .foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    }
                }
            } else {
                Text("当前图表数据不可用；不会补造价格或曲线。")
                    .font(.caption).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: height + expandedMACDHeight)
        // Give the plot the full width available from the detail page. The old
        // nested card and 10pt inset consumed space without adding chart meaning.
        .padding(.vertical, 2)
        .accessibilityElement(children: .ignore)
        .accessibilityLabel("统一证券图表")
        .accessibilityValue("绘图区高度 \(Int(height)) pt")
        .accessibilityHint("双指缩放；放大后拖动平移；长按或点击十字按钮后拖动查看数据点。")
    }

    private var expandedMACDHeight: CGFloat {
        guard subchartMode == "macd",
              let series = model?.chart.series,
              isDaily(series), series.count >= 26 else { return 0 }
        return 38
    }

    @ViewBuilder
    private func layerControls(for model: FChartOverlayModel, averages: [[Decimal?]], range: Range<Int>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 5) {
                // Keep VOL/MACD visible first on phone widths; the prior order
                // placed it after every MA and hid the indicator selector off-screen.
                subchartPicker(for: model.chart.series)
                if case .daily = model.chart.window {
                    ForEach(Array(averagePeriods.enumerated()), id: \.element) { index, period in
                        let ready = averages[index].dropFirst(range.lowerBound).prefix(range.count).contains { $0 != nil }
                        layerButton("MA\(period)", key: "ma\(period)", color: averageColors[index], available: ready)
                    }
                    layerButton("成交量", key: "volume", color: theme.manifest.tokens.secondaryForeground, available: true)
                }
                ForEach(model.priceOverlays, id: \.kind.rawValue) { overlay in
                    layerButton(overlayTitle(overlay.kind), key: layerKey(overlay.kind),
                                color: overlayColor(overlay.kind), available: !isUnavailable(overlay.quality))
                }
                if let iopv = model.liveIOPV {
                    layerButton("IOPV参考", key: "iopv", color: overlayColor(.iopv), available: !isUnavailable(iopv.quality))
                } else if case .liveIntraday = model.chart.window {
                    Text("IOPV 不可用").font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    @ViewBuilder
    private func subchartPicker(for series: FChartSeries?) -> some View {
        HStack(spacing: 2) {
            if case .daily? = series {
                subchartButton("VOL", mode: "volume")
            }
            subchartButton("MACD", mode: "macd")
                .disabled(!macdAvailable(for: series))
        }
        .padding(2)
        .background(theme.manifest.tokens.secondaryForeground.opacity(0.08), in: Capsule())
        .frame(minHeight: 24)
    }

    private func subchartButton(_ title: String, mode: String) -> some View {
        Button { subchartMode = mode } label: {
            Text(title).font(.system(size: 9, weight: .semibold, design: .monospaced))
                .foregroundStyle(subchartMode == mode ? theme.manifest.tokens.foreground : theme.manifest.tokens.secondaryForeground)
                .padding(.horizontal, 8).padding(.vertical, 4)
                .background(subchartMode == mode ? theme.manifest.tokens.surface : .clear, in: Capsule())
        }
        .buttonStyle(.plain)
    }

    private func macdAvailable(for series: FChartSeries?) -> Bool {
        (series?.count ?? 0) >= 26
    }

    private func macdValues(for series: FChartSeries) -> [FChartMACDPoint] {
        let prices: [Double]
        switch series {
        case let .minute(samples): prices = samples.map { NSDecimalNumber(decimal: $0.price).doubleValue }
        case let .daily(bars): prices = bars.map { NSDecimalNumber(decimal: $0.close).doubleValue }
        }
        guard !prices.isEmpty else { return [] }
        func ema(_ values: [Double], period: Int) -> [Double] {
            let alpha = 2.0 / Double(period + 1)
            var result: [Double] = []
            result.reserveCapacity(values.count)
            for value in values {
                result.append(result.last.map { alpha * value + (1 - alpha) * $0 } ?? value)
            }
            return result
        }
        let fast = ema(prices, period: 12)
        let slow = ema(prices, period: 26)
        let dif = zip(fast, slow).map { $0.0 - $0.1 }
        let dea = ema(dif, period: 9)
        return zip(dif, dea).map { FChartMACDPoint(dif: $0.0, dea: $0.1, histogram: 2 * ($0.0 - $0.1)) }
    }

    private func movingAverages(for series: FChartSeries) -> [[Decimal?]] {
        guard case let .daily(bars) = series else { return [] }
        return averagePeriods.map { FDailyMovingAverage.values(for: bars, period: $0) }
    }

    private func chartHeader(model: FChartOverlayModel, series: FChartSeries,
                             selectedIndex: Int?) -> some View {
        let quality = model.chart.quality
        let statusColor: Color = {
            switch quality {
            case .complete: return theme.manifest.tokens.accent
            case .partial: return theme.manifest.tokens.partial
            case .stale: return theme.manifest.tokens.risk
            case .unavailable: return theme.manifest.tokens.unavailable
            }
        }()
        let activeIndex = selectedIndex ?? max(0, series.count - 1)
        return VStack(alignment: .leading, spacing: 5) {
            HStack(alignment: .firstTextBaseline, spacing: 8) {
                Text(chartTitle(model.chart.window)).font(.subheadline.weight(.semibold))
                Spacer(minLength: 4)
                Text(qualityLabel(quality))
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(statusColor)
                    .padding(.horizontal, 8).padding(.vertical, 4)
                    .background(statusColor.opacity(0.10), in: Capsule())
            }
            HStack(alignment: .bottom, spacing: 12) {
                VStack(alignment: .leading, spacing: 2) {
                    Text(isDaily(series) ? "收盘" : "最新")
                        .font(.caption2).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                    Text(primaryValue(series: series, index: activeIndex))
                        .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(selectionTimestamp(series: series, index: activeIndex))
                    if let source = model.chart.temporalMetadata?.source { Text(source) }
                }
                .font(.system(size: 9)).foregroundStyle(theme.manifest.tokens.secondaryForeground)
                .lineLimit(1).truncationMode(.middle)
            }
            if isDaily(series) {
                Text(selectionText(series: series, index: activeIndex))
                    .font(.system(size: 9, design: .monospaced)).foregroundStyle(theme.ink.opacity(0.82))
                    .lineLimit(1).minimumScaleFactor(0.7)
            }
        }
        .accessibilityElement(children: .combine)
    }

    private func compactHeader(model: FChartOverlayModel, window: FChartWindow) -> some View {
        HStack(spacing: 5) {
            Text(chartTitle(window)).font(.system(size: 10, weight: .semibold))
            Spacer(minLength: 4)
            Text(qualityLabel(model.chart.quality))
                .font(.system(size: 8, weight: .semibold))
                .foregroundStyle(qualityColor(model.chart.quality))
        }
    }

    private func chartTitle(_ window: FChartWindow) -> String {
        switch window {
        case .liveIntraday: return "实时分时"
        case let .historicalIntraday(tradingDate):
            return "历史分时 · \(tradingDate.formatted(.dateTime.year().month().day()))"
        case .daily: return "日 K"
        }
    }

    private func qualityLabel(_ quality: FChartDataQuality) -> String {
        switch quality {
        case .complete: return "完整"
        case .partial(_): return "部分"
        case .stale(_): return "过期"
        case .unavailable(_): return "不可用"
        }
    }

    private func qualityColor(_ quality: FChartDataQuality) -> Color {
        switch quality {
        case .complete: return theme.manifest.tokens.accent
        case .partial(_): return theme.manifest.tokens.partial
        case .stale(_): return theme.manifest.tokens.risk
        case .unavailable(_): return theme.manifest.tokens.unavailable
        }
    }

    private func nearestIndex(at locationX: CGFloat, width: CGFloat,
                              series: FChartSeries, range: Range<Int>,
                              minuteDomain: ClosedRange<Double>) -> Int {
        guard !range.isEmpty else { return 0 }
        let left = plotLeftInset
        let right = plotRightInset
        let plotWidth = max(1, width - left - right)
        let fraction = min(max((locationX - left) / plotWidth, 0), 1)
        switch series {
        case .daily:
            return min(range.upperBound - 1,
                       range.lowerBound + Int((fraction * CGFloat(range.count)).rounded(.down)))
        case let .minute(samples):
            let target = minuteDomain.lowerBound + Double(fraction) *
                (minuteDomain.upperBound - minuteDomain.lowerBound)
            return range.min(by: {
                abs(sessionMinute(samples[$0].timestamp) - target) <
                    abs(sessionMinute(samples[$1].timestamp) - target)
            }) ?? range.lowerBound
        }
    }

    private func sessionMinute(_ date: Date) -> Double {
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        let parts = calendar.dateComponents([.hour, .minute], from: date)
        let minute = Double((parts.hour ?? 9) * 60 + (parts.minute ?? 30))
        if minute <= 570 { return 0 }
        if minute <= 690 { return minute - 570 }
        if minute < 780 { return 120 }
        if minute <= 900 { return 120 + minute - 780 }
        return 240
    }

    private func minuteDisplayDomain(series: FChartSeries, range: Range<Int>,
                                     zoomScale: CGFloat, window: FChartWindow) -> ClosedRange<Double> {
        guard case let .minute(samples) = series, !range.isEmpty else { return 0...240 }
        if zoomScale > 1.01 {
            let visibleMinutes = range.map { sessionMinute(samples[$0].timestamp) }
            let first = visibleMinutes.min() ?? 0
            let last = visibleMinutes.max() ?? first + 1
            return first...max(first + 1, last)
        }
        guard case .liveIntraday = window,
              let latest = samples.last?.timestamp else { return 0...252 }

        let timeZone = TimeZone(identifier: "Asia/Shanghai") ?? .current
        var calendar = Calendar(identifier: .gregorian)
        calendar.timeZone = timeZone
        let now = Date()
        guard calendar.isDate(latest, inSameDayAs: now) else { return 0...252 }
        let session = FMainlandTradingCalendar.status(at: now, timeZone: timeZone)
        guard session == .continuous || session == .lunchBreak else { return 0...252 }

        // Expand the live plot only through the observed trading session. This
        // keeps the first minutes readable instead of pinning them to 1% of a
        // full-day axis. Lunch is compressed consistently with sessionMinute.
        let observedEnd = sessionMinute(latest)
        let sessionEnd = session == .lunchBreak ? 120 : observedEnd
        return 0...max(sessionEnd, 1)
    }

    private func intradayClockLabel(_ sessionMinute: Double) -> String {
        let minute = Int(sessionMinute.rounded())
        let clockMinute = minute <= 120 ? 570 + minute : 780 + minute - 120
        return String(format: "%02d:%02d", clockMinute / 60, clockMinute % 60)
    }

    private func draw(model: FChartOverlayModel, series: FChartSeries, range: Range<Int>,
                      visibleTimes: Set<Date>, averages: [[Decimal?]], priceRange: ClosedRange<Decimal>?,
                      minuteDomain: ClosedRange<Double>,
                      selectedIndex: Int?, visibleLayers: Set<String>, macd: [FChartMACDPoint],
                      subchartMode: String,
                      context: inout GraphicsContext, size: CGSize) {
        guard let priceRange, range.count > 0 else { return }
        let low = NSDecimalNumber(decimal: priceRange.lowerBound).doubleValue
        let high = NSDecimalNumber(decimal: priceRange.upperBound).doubleValue
        // Reserve only the space needed for 3-decimal price labels; the old
        // 54pt gutter visibly squeezed the plot on phone screens.
        let leftAxis = plotLeftInset
        let rightInset = plotRightInset
        let topInset: CGFloat = 8
        let bottomAxis: CGFloat = 24
        let showVolume = isDaily(series) && subchartMode == "volume" && visibleLayers.contains("volume")
        let showMACD = subchartMode == "macd" && macd.count >= 26
        let subchartHeight: CGFloat = showMACD
            ? max(42, max(0, size.height - 38) * 0.22) + 38
            : (showVolume ? max(42, size.height * 0.22) : 0)
        let subchartTop = size.height - bottomAxis - subchartHeight
        let priceTop = topInset
        let priceBottom = subchartTop - ((showVolume || showMACD) ? 8 : 0)
        let priceHeight = max(priceBottom - priceTop, 1)
        let plotWidth = max(size.width - leftAxis - rightInset, 1)
        let span = max(high - low, 0.000001)
        func y(_ value: Decimal) -> CGFloat {
            priceTop + priceHeight * (1 - CGFloat((NSDecimalNumber(decimal: value).doubleValue - low) / span))
        }
        func x(_ index: Int) -> CGFloat {
            let fraction: CGFloat
            switch series {
            case .daily:
                fraction = (CGFloat(index - range.lowerBound) + 0.5) / CGFloat(max(range.count, 1))
            case let .minute(samples):
                fraction = CGFloat((sessionMinute(samples[index].timestamp) - minuteDomain.lowerBound) /
                                   max(minuteDomain.upperBound - minuteDomain.lowerBound, 1))
            }
            return leftAxis + min(max(fraction, 0), 1) * plotWidth
        }
        // Cost and other timestamp overlays commonly have one point per bar.
        // Avoid rescanning the whole series for every overlay point while the
        // Canvas is redrawn during pinch/drag gestures.
        var indexByTimestamp: [Date: Int] = [:]
        indexByTimestamp.reserveCapacity(series.timestamps.count)
        for index in series.timestamps.indices {
            indexByTimestamp[series.timestamps[index]] = index
        }
        for step in 0...4 {
            let fraction = Double(step) / 4
            let lineY = priceTop + priceHeight * CGFloat(fraction)
            var grid = Path(); grid.move(to: CGPoint(x: leftAxis, y: lineY)); grid.addLine(to: CGPoint(x: size.width - rightInset, y: lineY))
            context.stroke(grid, with: .color(theme.manifest.tokens.secondaryForeground.opacity(0.12)), lineWidth: 1)
            let value = high - span * fraction
            let label = Text(String(format: "%.3f", value)).font(.system(size: 9, design: .monospaced))
                .foregroundColor(theme.manifest.tokens.secondaryForeground)
            context.draw(label, at: CGPoint(x: leftAxis - 4, y: lineY), anchor: .trailing)
        }
        var axis = Path(); axis.move(to: CGPoint(x: leftAxis, y: priceTop)); axis.addLine(to: CGPoint(x: leftAxis, y: size.height - bottomAxis))
        context.stroke(axis, with: .color(theme.manifest.tokens.secondaryForeground.opacity(0.18)), lineWidth: 1)
        switch series {
        case let .minute(samples):
            var path = Path()
            var previousSessionMinute: Double?
            for index in range {
                let timestamp = samples[index].timestamp
                let point = CGPoint(x: x(index), y: y(samples[index].price))
                let minute = sessionMinute(timestamp)
                if let previousSessionMinute, minute - previousSessionMinute <= 2.5 {
                    path.addLine(to: point)
                } else {
                    // Leave real coverage gaps visible; never draw an invented
                    // straight bridge through missing minutes or the lunch break.
                    path.move(to: point)
                }
                previousSessionMinute = minute
            }
            context.stroke(path, with: .color(theme.accent), style: StrokeStyle(lineWidth: 0.78, lineCap: .round, lineJoin: .round))
            let standardTicks: [(Double, String)] = [(0, "09:30"), (60, "10:30"), (120, "11:30 / 13:00"),
                                                    (180, "14:00"), (210, "14:30"), (240, "15:00")]
            var ticks = standardTicks.filter { $0.0 >= minuteDomain.lowerBound && $0.0 <= minuteDomain.upperBound }
            if ticks.isEmpty || ticks.first?.0 != minuteDomain.lowerBound {
                ticks.insert((minuteDomain.lowerBound, intradayClockLabel(minuteDomain.lowerBound)), at: 0)
            }
            if let lastTick = ticks.last, abs(lastTick.0 - minuteDomain.upperBound) > 0.5 {
                ticks.append((minuteDomain.upperBound, intradayClockLabel(minuteDomain.upperBound)))
            }
            if ticks.count > 2 {
                // Select labels by their rendered distance, not by array stride.
                // A stride can keep both 14:30 and 15:00 at the right edge, where
                // the two labels collide on an iPhone-width plot.
                let domainWidth = max(minuteDomain.upperBound - minuteDomain.lowerBound, 1)
                // Leave room for localized labels on narrower iPhones. The
                // chart still draws every tick mark; only text labels are thinned.
                let minimumLabelSpacing: CGFloat = 52
                var spacedTicks = [ticks[0]]
                for item in ticks.dropFirst().dropLast() {
                    guard let previous = spacedTicks.last else { continue }
                    let distance = CGFloat((item.0 - previous.0) / domainWidth) * plotWidth
                    if distance >= minimumLabelSpacing { spacedTicks.append(item) }
                }
                if let last = ticks.last {
                    if let previous = spacedTicks.last, spacedTicks.count > 1 {
                        let distance = CGFloat((last.0 - previous.0) / domainWidth) * plotWidth
                        if distance < minimumLabelSpacing { spacedTicks.removeLast() }
                    }
                    spacedTicks.append(last)
                }
                ticks = spacedTicks
            }
            for (index, item) in ticks.enumerated() {
                let tickX = leftAxis + CGFloat((item.0 - minuteDomain.lowerBound) /
                                               max(minuteDomain.upperBound - minuteDomain.lowerBound, 1)) * plotWidth
                var tick = Path(); tick.move(to: CGPoint(x: tickX, y: priceBottom)); tick.addLine(to: CGPoint(x: tickX, y: priceBottom + 3))
                context.stroke(tick, with: .color(theme.manifest.tokens.secondaryForeground.opacity(0.35)), lineWidth: 1)
                let anchor: UnitPoint = index == 0 ? .leading : (index == ticks.count - 1 ? .trailing : .center)
                context.draw(Text(item.1).font(.system(size: 9, design: .monospaced))
                                .foregroundColor(theme.manifest.tokens.secondaryForeground),
                             at: CGPoint(x: tickX, y: size.height - 8), anchor: anchor)
            }
        case let .daily(bars):
            let volumes = range.map { NSDecimalNumber(decimal: bars[$0].volume).doubleValue }
            let maxVolume = max(volumes.max() ?? 0, 1)
            for index in range {
                let bar = bars[index]
                let centerX = x(index)
                let stepX = plotWidth / CGFloat(max(range.count, 1))
                let rising = bar.close >= bar.open
                let tokens = theme.manifest.tokens
                let color: Color = rising ? tokens.positive : tokens.negative
                var wick = Path(); wick.move(to: CGPoint(x: centerX, y: y(bar.high))); wick.addLine(to: CGPoint(x: centerX, y: y(bar.low)))
                context.stroke(wick, with: .color(color), lineWidth: 1)
                let top = min(y(bar.open), y(bar.close))
                let body = CGRect(x: centerX - max(stepX * 0.27, 0.6), y: top,
                                  width: max(stepX * 0.54, 1), height: max(abs(y(bar.open) - y(bar.close)), 1))
                context.fill(Path(body), with: .color(color.opacity(0.85)))
                if showVolume {
                    let volume = NSDecimalNumber(decimal: bar.volume).doubleValue
                    let barHeight = (subchartHeight - 4) * CGFloat(volume / maxVolume)
                    let volumeBar = CGRect(x: centerX - max(stepX * 0.3, 0.6),
                                           y: subchartTop + 2 + subchartHeight - 4 - barHeight,
                                           width: max(stepX * 0.6, 1), height: barHeight)
                    context.fill(Path(volumeBar), with: .color(color.opacity(0.55)))
                }
            }
            if showVolume {
                var divider = Path(); divider.move(to: CGPoint(x: leftAxis, y: subchartTop)); divider.addLine(to: CGPoint(x: size.width - rightInset, y: subchartTop))
                context.stroke(divider, with: .color(theme.manifest.tokens.secondaryForeground.opacity(0.2)), lineWidth: 1)
                context.draw(Text("VOL").font(.system(size: 8, weight: .medium))
                                .foregroundColor(theme.manifest.tokens.secondaryForeground),
                            at: CGPoint(x: 3, y: subchartTop + subchartHeight / 2), anchor: .leading)
            }
            let desiredTickCount = min(5, max(2, Int(plotWidth / 74)))
            let tickCount = min(desiredTickCount, range.count)
            if tickCount > 0 {
                for tick in 0..<tickCount {
                    let index = range.lowerBound + (range.count - 1) * tick / max(tickCount - 1, 1)
                    let date = bars[index].tradingDate
                    let label = date.formatted(.dateTime.month(.abbreviated).day())
                    let anchor: UnitPoint = tick == 0 ? .leading : (tick == tickCount - 1 ? .trailing : .center)
                    context.draw(Text(label).font(.system(size: 8))
                                    .foregroundColor(theme.manifest.tokens.secondaryForeground),
                                at: CGPoint(x: x(index), y: size.height - 8), anchor: anchor)
                }
            }
            for (seriesIndex, values) in averages.enumerated() {
                guard visibleLayers.contains("ma\(averagePeriods[seriesIndex])") else { continue }
                var path = Path(); var started = false
                for index in range {
                    guard let value = values[index] else { started = false; continue }
                    let point = CGPoint(x: x(index), y: y(value))
                    if started { path.addLine(to: point) } else { path.move(to: point); started = true }
                }
                context.stroke(path, with: .color(averageColors[seriesIndex]), lineWidth: 0.72)
            }
        }
        if showMACD {
            let visibleValues = range.flatMap { [macd[$0].dif, macd[$0].dea, macd[$0].histogram] }
            let extent = max(visibleValues.map(abs).max() ?? 0, 0.000001)
            let centerY = subchartTop + subchartHeight / 2
            func macdY(_ value: Double) -> CGFloat {
                centerY - CGFloat(value / extent) * (subchartHeight * 0.43)
            }
            var baseline = Path(); baseline.move(to: CGPoint(x: leftAxis, y: centerY)); baseline.addLine(to: CGPoint(x: size.width - rightInset, y: centerY))
            context.stroke(baseline, with: .color(theme.manifest.tokens.secondaryForeground.opacity(0.25)), lineWidth: 0.7)
            var difPath = Path(); var deaPath = Path()
            for index in range {
                let point = macd[index]
                let centerX = x(index)
                let barWidth = max(plotWidth / CGFloat(max(range.count, 1)) * 0.56, 1)
                let bar = CGRect(x: centerX - barWidth / 2, y: min(centerY, macdY(point.histogram)),
                                 width: barWidth, height: max(abs(centerY - macdY(point.histogram)), 0.7))
                context.fill(Path(bar), with: .color((point.histogram >= 0 ? theme.manifest.tokens.positive : theme.manifest.tokens.negative).opacity(0.7)))
                let difPoint = CGPoint(x: centerX, y: macdY(point.dif))
                let deaPoint = CGPoint(x: centerX, y: macdY(point.dea))
                if index == range.lowerBound { difPath.move(to: difPoint); deaPath.move(to: deaPoint) }
                else { difPath.addLine(to: difPoint); deaPath.addLine(to: deaPoint) }
            }
            context.stroke(difPath, with: .color(averageColors[0]), lineWidth: 0.8)
            context.stroke(deaPath, with: .color(averageColors[1]), lineWidth: 0.8)
            context.draw(Text("MACD").font(.system(size: 8, weight: .medium))
                            .foregroundColor(theme.manifest.tokens.secondaryForeground),
                         at: CGPoint(x: size.width - rightInset - 4, y: subchartTop + 7), anchor: .trailing)
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
                path.move(to: CGPoint(x: leftAxis, y: lineY)); path.addLine(to: CGPoint(x: size.width - rightInset, y: lineY))
                context.stroke(path, with: .color(overlayColor(overlay.kind)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                context.draw(Text(overlayTitle(overlay.kind)).font(.caption2.bold()).foregroundColor(overlayColor(overlay.kind)),
                            at: CGPoint(x: leftAxis + 30, y: max(8, lineY - 8)))
            } else {
                let matching = overlay.points.filter { visibleTimes.contains($0.timestamp) }
                for point in matching {
                    guard let index = indexByTimestamp[point.timestamp], range.contains(index) else { continue }
                    let pointX = x(index)
                    let stepX = plotWidth / CGFloat(max(range.count, 1))
                    path.move(to: CGPoint(x: pointX, y: y(point.value)))
                    path.addLine(to: CGPoint(x: min(pointX + stepX, size.width - rightInset), y: y(point.value)))
                }
                context.stroke(path, with: .color(overlayColor(overlay.kind)), style: StrokeStyle(lineWidth: 1.0, dash: [3, 2]))
            }
        }
        if visibleLayers.contains("iopv"), let observation = model.liveIOPV,
           !isUnavailable(observation.quality), let value = observation.value {
            let lineY = y(value)
            var iopvPath = Path()
            iopvPath.move(to: CGPoint(x: leftAxis, y: lineY))
            iopvPath.addLine(to: CGPoint(x: size.width - rightInset, y: lineY))
            context.stroke(iopvPath, with: .color(overlayColor(.iopv)),
                           style: StrokeStyle(lineWidth: 1.0, dash: [2, 3]))
            context.draw(Text("IOPV参考").font(.system(size: 8, weight: .semibold))
                            .foregroundColor(overlayColor(.iopv)),
                         at: CGPoint(x: leftAxis + 24, y: max(priceTop + 7, lineY - 7)))
        }
        if let selectedIndex, range.contains(selectedIndex) {
            let cursorX = x(selectedIndex)
            var cursor = Path(); cursor.move(to: CGPoint(x: cursorX, y: priceTop)); cursor.addLine(to: CGPoint(x: cursorX, y: size.height - bottomAxis))
            context.stroke(cursor, with: .color(theme.manifest.tokens.secondaryForeground.opacity(0.8)),
                           style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
        }
    }

    private func selectionText(series: FChartSeries, index: Int) -> String {
        switch series {
        case .minute: return ""
        case let .daily(bars):
            let bar = bars[index]
            return "开 \(bar.open)  高 \(bar.high)  低 \(bar.low)  收 \(bar.close)  量 \(bar.volume)"
        }
    }

    private func primaryValue(series: FChartSeries, index: Int) -> String {
        let value: Decimal
        switch series {
        case let .minute(samples): value = samples[index].price
        case let .daily(bars): value = bars[index].close
        }
        return "¥\(NSDecimalNumber(decimal: value).stringValue)"
    }

    private func selectionTimestamp(series: FChartSeries, index: Int) -> String {
        switch series {
        case let .minute(samples):
            return samples[index].timestamp.formatted(date: .omitted, time: .shortened)
        case let .daily(bars):
            return bars[index].tradingDate.formatted(.dateTime.year().month().day())
        }
    }

    private func timestampLabel(_ timestamp: Date, window: FChartWindow) -> String {
        switch window {
        case .daily:
            return timestamp.formatted(.dateTime.month(.abbreviated).day())
        case .liveIntraday, .historicalIntraday(_):
            return timestamp.formatted(date: .omitted, time: .shortened)
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
        case .cost: return "本轮成本"
        case .brokerCost: return "券商成本"
        case .intradayAverage: return "量价均价"
        case .previousClose: return "前收"
        case .iopv: return "当前IOPV参考"
        case .candidateBuy: return "B 候选"
        case .candidateSell: return "S 候选"
        }
    }
    private func overlayColor(_ kind: FChartOverlayKind) -> Color {
        switch kind {
        case .cost: return theme.manifest.tokens.episodeCost
        case .brokerCost: return theme.manifest.tokens.brokerCost
        case .intradayAverage: return theme.manifest.tokens.intradayAverage
        case .previousClose: return theme.manifest.tokens.secondaryForeground
        case .iopv: return theme.manifest.tokens.iopv
        case .candidateBuy: return theme.manifest.tokens.buyPoint
        case .candidateSell: return theme.manifest.tokens.sellPoint
        }
    }

    private var visibleLayerKeys: Set<String> {
        Set(visibleLayerKeysRaw.split(separator: ",").map(String.init))
    }

    private func toggleLayer(_ key: String) {
        var updated = visibleLayerKeys
        if updated.contains(key) { updated.remove(key) } else { updated.insert(key) }
        visibleLayerKeysRaw = updated.sorted().joined(separator: ",")
    }

    private func layerButton(_ title: String, key: String, color: Color, available: Bool) -> some View {
        let active = visibleLayerKeys.contains(key)
        return Button { toggleLayer(key) } label: {
            HStack(spacing: 3) {
                Circle().fill(color).frame(width: 4, height: 4)
                Text(title).font(.system(size: 8, weight: .medium, design: .monospaced))
                Image(systemName: active ? "eye" : "eye.slash")
                    .font(.system(size: 7, weight: .semibold))
            }
            .foregroundStyle(available
                ? (active ? color : theme.manifest.tokens.secondaryForeground)
                : theme.manifest.tokens.secondaryForeground.opacity(0.5))
            .padding(.horizontal, 5).padding(.vertical, 1)
            .background(active ? color.opacity(0.07) : Color.clear, in: Capsule())
            .frame(minHeight: 24)
            .contentShape(Rectangle())
        }
        .buttonStyle(.plain)
        .disabled(!available)
        .accessibilityLabel("\(title)\(!available ? "不可用" : active ? "已显示，点击隐藏" : "已隐藏，点击显示")")
    }

    private func layerKey(_ kind: FChartOverlayKind) -> String {
        switch kind {
        case .cost: return "cost"
        case .brokerCost: return "brokerCost"
        case .intradayAverage: return "intradayAverage"
        case .previousClose: return "previousClose"
        case .iopv: return "iopv"
        case .candidateBuy: return "candidateBuy"
        case .candidateSell: return "candidateSell"
        }
    }

    private func modelWithVisibleOverlays(_ model: FChartOverlayModel) -> FChartOverlayModel {
        let overlays = model.priceOverlays.filter { visibleLayerKeys.contains(layerKey($0.kind)) }
        let iopv = visibleLayerKeys.contains("iopv") ? model.liveIOPV : nil
        return (try? FChartOverlayModel(chart: model.chart, priceOverlays: overlays, iopv: iopv)) ?? model
    }

    private func unavailableOverlaySummary(_ model: FChartOverlayModel) -> String {
        if case .daily = model.chart.window { return "IOPV仅实时快照，无历史序列" }
        var unavailable: [String] = []
        if !model.priceOverlays.contains(where: { $0.kind == .intradayAverage && !isUnavailable($0.quality) }) {
            unavailable.append("均价不可用")
        }
        if !model.priceOverlays.contains(where: { $0.kind == .previousClose && !isUnavailable($0.quality) }) {
            unavailable.append("前收不可用")
        }
        if case .liveIntraday = model.chart.window {
            if model.liveIOPV.map({ isUnavailable($0.quality) }) != false { unavailable.append("IOPV不可用") }
        } else {
            unavailable.append("IOPV仅实时快照，无历史序列")
        }
        if let average = model.priceOverlays.first(where: {
            $0.kind == .intradayAverage && !isUnavailable($0.quality)
        }) {
            switch average.quality {
            case .partial(let reason), .stale(let reason): unavailable.append(reason)
            default: unavailable.append("量价均价按分钟收盘价加权，非官方VWAP")
            }
        }
        return unavailable.joined(separator: " · ")
    }
}

private struct FChartSurfaceModifier: ViewModifier {
    let theme: FHomeTheme

    @ViewBuilder
    func body(content: Content) -> some View {
        let shape = RoundedRectangle(cornerRadius: theme.surfaceTreatment == .terminal || theme.surfaceTreatment == .minimal ? 8 : 16)
        switch theme.surfaceTreatment {
        case .terminal, .minimal:
            content.background(theme.background.opacity(0.97), in: shape)
                .overlay(alignment: .bottom) { Rectangle().fill(theme.accent.opacity(0.55)).frame(height: 1) }
        case .glass, .orbit:
            content.background(.ultraThinMaterial, in: shape)
                .overlay(shape.stroke(.white.opacity(0.32), lineWidth: 1))
                .shadow(color: theme.accent.opacity(0.14), radius: 14, y: 7)
        case .ink:
            content.background(theme.background.opacity(0.86), in: shape)
                .overlay(alignment: .leading) { Rectangle().fill(theme.accent).frame(width: 2) }
        case .magazine:
            content.background(theme.background.opacity(0.90), in: shape)
                .overlay(alignment: .top) { Rectangle().fill(theme.accent.opacity(0.75)).frame(height: 1) }
        default:
            content.background(.regularMaterial, in: shape)
                .overlay(shape.stroke(theme.accent.opacity(0.12), lineWidth: 1))
        }
    }
}

enum FChartPresentationBuilder {
    static func live(_ snapshot: FCurrentIntradaySnapshot?, holding: FHomeHolding?,
                     candidate: FCandidateRecommendation?, ledgerCapturedAt: Date?,
                     reference: FTencentMarketReference? = nil) -> FChartOverlayModel? {
        guard let snapshot else { return nil }
        let validReference = reference.flatMap { $0.hasTrustedTimestamp(at: Date()) ? $0 : nil }
        let now = Date()
        let session = FMainlandTradingCalendar.status(at: now)
        let metadata = snapshot.temporalMetadata(marketSessionStatus: session)
        let freshness = metadata.freshness(at: now)
        let quality: FChartDataQuality
        switch session {
        case .continuous:
            switch freshness {
            case .fresh: quality = .complete
            case .stale: quality = .stale(reason: "超过2分钟未更新")
            case .unverified: quality = .stale(reason: "行情时间未验证或来自未来")
            }
        case .lunchBreak:
            quality = .stale(reason: "午间休市；展示最后有效分钟")
        case .preOpen:
            quality = .stale(reason: "开盘前；展示上次有效分钟")
        case .closed:
            quality = .stale(reason: "已收盘或休市；展示最后有效分钟")
        case .unknown:
            quality = .partial(reason: "当前交易日历未覆盖；行情时段未验证")
        }
        guard let chart = try? FChartDataModel(securityCode: snapshot.securityCode, window: .liveIntraday,
                                               series: .minute(snapshot.samples), quality: quality,
                                               temporalMetadata: metadata) else { return nil }
        return makeOverlay(chart: chart, holding: holding, candidate: candidate,
                           capturedAt: ledgerCapturedAt, reference: validReference,
                           previousClose: validReference.map { ($0.previousClose, $0.source, $0.fetchedAt) })
    }

    static func historical(_ archive: FNASArchivedIntraday?, holding: FHomeHolding?,
                           ledgerCapturedAt: Date?, daily: FDailyKlineSnapshot? = nil) -> FChartOverlayModel? {
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
        let date = chart.series?.timestamps.first ?? archive.samples[0].timestamp
        let priorBar = daily?.bars.last(where: { $0.tradingDate < date })
        let previousClose = priorBar.map { ($0.close, daily?.source ?? "腾讯日K前一交易日收盘", daily?.fetchedAt ?? Date()) }
        return makeOverlay(chart: chart, holding: holding, candidate: nil,
                           capturedAt: ledgerCapturedAt, reference: nil, previousClose: previousClose)
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
        return makeOverlay(chart: chart, holding: holding, candidate: candidate,
                           capturedAt: ledgerCapturedAt, reference: nil, previousClose: nil)
    }

    private static func makeOverlay(chart: FChartDataModel, holding: FHomeHolding?,
                                    candidate: FCandidateRecommendation?, capturedAt: Date?,
                                    reference: FTencentMarketReference?,
                                    previousClose: (Decimal, String, Date)?) -> FChartOverlayModel? {
        var overlays: [FChartPriceOverlay] = []
        if case .minute(let samples) = chart.series, !samples.isEmpty {
            var cumulativeAmount = Decimal.zero
            var cumulativeVolume = Decimal.zero
            var weightedPoints: [FChartOverlayPoint] = []
            for sample in samples {
                guard let volume = sample.volume, volume > 0 else { continue }
                cumulativeAmount += sample.price * volume
                cumulativeVolume += volume
                if cumulativeVolume > 0 {
                    weightedPoints.append(FChartOverlayPoint(timestamp: sample.timestamp,
                                                              value: cumulativeAmount / cumulativeVolume))
                }
            }
            let unknownVolumeCount = samples.filter { $0.volume == nil }.count
            if !weightedPoints.isEmpty,
               let average = try? FChartPriceOverlay(
                securityCode: chart.securityCode, kind: .intradayAverage,
                points: weightedPoints,
                quality: .partial(reason: "按分钟收盘价×可用分钟量加权；非官方VWAP；成交量未知 \(unknownVolumeCount) 点"),
                source: "Tencent minute/query volume deltas · weighted minute closes",
                fetchedAt: chart.temporalMetadata?.fetchedAt) {
                overlays.append(average)
            }
        }
        if let previousClose, let timestamps = chart.series?.timestamps, !timestamps.isEmpty {
            let points = timestamps.map { FChartOverlayPoint(timestamp: $0, value: previousClose.0) }
            if let previous = try? FChartPriceOverlay(securityCode: chart.securityCode,
                                                       kind: .previousClose, points: points,
                                                       quality: .complete, source: previousClose.1,
                                                       fetchedAt: previousClose.2) {
                overlays.append(previous)
            }
        }
        if let holding, holding.instrumentCode == chart.securityCode, holding.units > 0,
           let capturedAt, let timestamps = chart.series?.timestamps, !timestamps.isEmpty {
            let unitCost = holding.bookCost / Decimal(holding.units)
            let points = timestamps.map { FChartOverlayPoint(timestamp: $0, value: unitCost) }
            if let cost = try? FChartPriceOverlay(securityCode: chart.securityCode, kind: .cost,
                                                  points: points, quality: .complete,
                                                  source: "F Real Ledger confirmed cost", fetchedAt: capturedAt) {
                overlays.append(cost)
            }
            if let brokerCost = holding.brokerDisplayCostPerUnit,
               let updatedAt = holding.brokerDisplayCostUpdatedAt {
                let points = timestamps.map { FChartOverlayPoint(timestamp: $0, value: brokerCost) }
                if let broker = try? FChartPriceOverlay(
                    securityCode: chart.securityCode, kind: .brokerCost, points: points,
                    quality: .complete, source: "用户录入的券商展示成本", fetchedAt: updatedAt) {
                    overlays.append(broker)
                }
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
        let iopv: FIOPVObservation?
        if let reference, reference.providerInstrumentType == "ETF", let value = reference.iopv,
           reference.hasFreshIOPV(at: Date()) {
            iopv = try? FIOPVObservation(securityCode: chart.securityCode, value: value,
                                         observedAt: reference.observedAt, fetchedAt: reference.fetchedAt,
                                         source: reference.source,
                                         quality: .partial(reason: "腾讯实时ETF IOPV快照；不是历史IOPV序列"))
        } else {
            iopv = try? FIOPVObservation(securityCode: chart.securityCode, value: nil,
                                         observedAt: nil, fetchedAt: nil, source: nil,
                                         quality: .unavailable(reason: "腾讯报价未提供新鲜、可验证的当前ETF IOPV"))
        }
        return try? FChartOverlayModel(chart: chart, priceOverlays: overlays, iopv: iopv)
    }
}


