import SwiftUI
import FCore
import FAdvisor

/// The App's one renderer for live minutes, NAS archived minutes and daily bars.
/// Inputs remain source-labelled FCore chart models; missing overlays stay absent.
struct FUnifiedSecurityChart: View {
    let model: FChartOverlayModel?
    let height: CGFloat
    @AppStorage("guanpan.f.homeTheme") private var themeRaw = FHomeTheme.editorial.rawValue
    @AppStorage("guanpan.f.chart.visibleLayers") private var visibleLayerKeysRaw = "ma5,ma10,ma20,ma60,ma250,volume,cost,brokerCost,intradayAverage,previousClose,candidateBuy,candidateSell,iopv"
    @State private var zoomScale: CGFloat = 1
    @State private var windowEndOffset = 0
    @State private var dragOriginOffset: Int?
    @State private var selectedTimestamp: Date?
    @State private var crosshairEnabled = false

    private let averagePeriods = [5, 10, 20, 60, 250]
    private let averageColors: [Color] = [.orange, .blue, .purple, .teal, .pink]
    private var theme: FHomeTheme { FHomeTheme(rawValue: themeRaw) ?? .editorial }

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
                let selectedAveragePeriods = Set(averagePeriods.filter { visibleLayerKeys.contains("ma\($0)") })
                let displayModel = modelWithVisibleOverlays(model)
                let priceRange = displayModel.priceRange(interaction: interaction,
                                                         visibleMovingAveragePeriods: selectedAveragePeriods)
                let averages = movingAverages(for: series)

                let compact = height < 180
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
                             priceRange: priceRange, selectedIndex: selectedIndex,
                             visibleLayers: visibleLayerKeys,
                             context: &context, size: size)
                    }
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
                    .contentShape(Rectangle())
                    .simultaneousGesture(SpatialTapGesture().onEnded { value in
                        selectedTimestamp = timestamps[nearestIndex(
                            at: value.location.x, width: proxy.size.width,
                            series: series, range: visibleRange)]
                        crosshairEnabled = true
                    })
                    // Allow the parent detail ScrollView to scroll when the user starts a
                    // vertical swipe over the chart; chart-specific pan/crosshair state is
                    // updated simultaneously and remains constrained to the chart data.
                    .simultaneousGesture(DragGesture(minimumDistance: 4).onChanged { value in
                        if crosshairEnabled {
                            selectedTimestamp = timestamps[nearestIndex(
                                at: value.location.x, width: proxy.size.width,
                                series: series, range: visibleRange)]
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
                    if !compact {
                        HStack {
                            Text(unavailableOverlaySummary(model))
                                .lineLimit(1).minimumScaleFactor(0.75)
                            Spacer()
                            Text(timestampLabel(timestamps[start], window: model.chart.window))
                            Text("—").foregroundStyle(.tertiary)
                            Text(timestampLabel(timestamps[end - 1], window: model.chart.window))
                            Button(crosshairEnabled ? "退出十字" : "十字") {
                                crosshairEnabled.toggle()
                                if !crosshairEnabled { selectedTimestamp = nil }
                            }
                            .font(.caption2.weight(.semibold)).buttonStyle(.bordered).controlSize(.mini)
                        }
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    }
                }
            } else {
                Text("当前图表数据不可用；不会补造价格或曲线。")
                    .font(.caption).foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, maxHeight: .infinity)
            }
        }
        .frame(height: height)
        .padding(10)
        .modifier(FChartSurfaceModifier(theme: theme))
        .accessibilityLabel("统一证券图表")
        .accessibilityHint("双指缩放；放大后拖动平移；长按或点击十字按钮后拖动查看数据点。")
    }

    @ViewBuilder
    private func layerControls(for model: FChartOverlayModel, averages: [[Decimal?]], range: Range<Int>) -> some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                if case .daily = model.chart.window {
                    ForEach(Array(averagePeriods.enumerated()), id: \.element) { index, period in
                        let ready = averages[index].dropFirst(range.lowerBound).prefix(range.count).contains { $0 != nil }
                        layerButton("MA\(period)", key: "ma\(period)", color: averageColors[index], available: ready)
                    }
                    layerButton("成交量", key: "volume", color: .secondary, available: true)
                }
                ForEach(model.priceOverlays, id: \.kind.rawValue) { overlay in
                    layerButton(overlayTitle(overlay.kind), key: layerKey(overlay.kind),
                                color: overlayColor(overlay.kind), available: !isUnavailable(overlay.quality))
                }
                if let iopv = model.iopv {
                    layerButton("IOPV", key: "iopv", color: overlayColor(.iopv), available: !isUnavailable(iopv.quality))
                } else {
                    Text("IOPV 不可用").font(.caption2).foregroundStyle(.tertiary)
                }
            }
            .fixedSize(horizontal: true, vertical: false)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
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

    private func chartHeader(model: FChartOverlayModel, series: FChartSeries,
                             selectedIndex: Int?) -> some View {
        let quality = model.chart.quality
        let statusColor: Color = {
            switch quality {
            case .complete: return .green
            case .partial: return .orange
            case .stale: return .red
            case .unavailable: return .secondary
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
                        .font(.caption2).foregroundStyle(.secondary)
                    Text(primaryValue(series: series, index: activeIndex))
                        .font(.system(size: 25, weight: .semibold, design: .rounded).monospacedDigit())
                        .foregroundStyle(theme.ink).lineLimit(1).minimumScaleFactor(0.8)
                }
                Spacer(minLength: 4)
                VStack(alignment: .trailing, spacing: 3) {
                    Text(selectionTimestamp(series: series, index: activeIndex))
                    if let source = model.chart.temporalMetadata?.source { Text(source) }
                }
                .font(.system(size: 9)).foregroundStyle(.secondary)
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
        case .complete: return .green
        case .partial(_): return .orange
        case .stale(_): return .red
        case .unavailable(_): return .secondary
        }
    }

    private func nearestIndex(at locationX: CGFloat, width: CGFloat,
                              series: FChartSeries, range: Range<Int>) -> Int {
        guard !range.isEmpty else { return 0 }
        let left: CGFloat = 54
        let right: CGFloat = 8
        let plotWidth = max(1, width - left - right)
        let fraction = min(max((locationX - left) / plotWidth, 0), 1)
        switch series {
        case .daily:
            return min(range.upperBound - 1,
                       range.lowerBound + Int((fraction * CGFloat(range.count)).rounded(.down)))
        case let .minute(samples):
            let target = Double(fraction) * 252
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
        if minute < 780 { return 120 + Double(minute - 690) / 90 * 12 }
        if minute <= 900 { return 132 + minute - 780 }
        return 252
    }

    private func draw(model: FChartOverlayModel, series: FChartSeries, range: Range<Int>,
                      visibleTimes: Set<Date>, averages: [[Decimal?]], priceRange: ClosedRange<Decimal>?,
                      selectedIndex: Int?, visibleLayers: Set<String>,
                      context: inout GraphicsContext, size: CGSize) {
        guard let priceRange, range.count > 0 else { return }
        let low = NSDecimalNumber(decimal: priceRange.lowerBound).doubleValue
        let high = NSDecimalNumber(decimal: priceRange.upperBound).doubleValue
        let leftAxis: CGFloat = 54
        let rightInset: CGFloat = 8
        let topInset: CGFloat = 8
        let bottomAxis: CGFloat = 24
        let showVolume = isDaily(series) && visibleLayers.contains("volume")
        let volumeHeight: CGFloat = showVolume ? max(34, size.height * 0.19) : 0
        let volumeTop = size.height - bottomAxis - volumeHeight
        let priceTop = topInset
        let priceBottom = volumeTop - (showVolume ? 8 : 0)
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
                fraction = CGFloat(sessionMinute(samples[index].timestamp) / 252)
            }
            return leftAxis + min(max(fraction, 0), 1) * plotWidth
        }
        for step in 0...4 {
            let fraction = Double(step) / 4
            let lineY = priceTop + priceHeight * CGFloat(fraction)
            var grid = Path(); grid.move(to: CGPoint(x: leftAxis, y: lineY)); grid.addLine(to: CGPoint(x: size.width - rightInset, y: lineY))
            context.stroke(grid, with: .color(.secondary.opacity(0.12)), lineWidth: 1)
            let value = high - span * fraction
            let label = Text(String(format: "%.3f", value)).font(.system(size: 9, design: .monospaced)).foregroundColor(.secondary)
            context.draw(label, at: CGPoint(x: leftAxis - 4, y: lineY), anchor: .trailing)
        }
        var axis = Path(); axis.move(to: CGPoint(x: leftAxis, y: priceTop)); axis.addLine(to: CGPoint(x: leftAxis, y: size.height - bottomAxis))
        context.stroke(axis, with: .color(.secondary.opacity(0.18)), lineWidth: 1)
        switch series {
        case let .minute(samples):
            var path = Path()
            for index in range {
                let point = CGPoint(x: x(index), y: y(samples[index].price))
                if index == range.lowerBound { path.move(to: point) } else { path.addLine(to: point) }
            }
            context.stroke(path, with: .color(theme.accent), style: StrokeStyle(lineWidth: 2.2, lineCap: .round, lineJoin: .round))
            let ticks: [(Double, String)] = [(0, "09:30"), (60, "10:30"), (120, "11:30"), (132, "13:00"), (192, "14:00"), (252, "15:00")]
            for (minute, label) in ticks {
                let tickX = leftAxis + CGFloat(minute / 252) * plotWidth
                var tick = Path(); tick.move(to: CGPoint(x: tickX, y: priceBottom)); tick.addLine(to: CGPoint(x: tickX, y: priceBottom + 3))
                context.stroke(tick, with: .color(.secondary.opacity(0.35)), lineWidth: 1)
                context.draw(Text(label).font(.system(size: 8, design: .monospaced)).foregroundColor(.secondary),
                            at: CGPoint(x: tickX, y: size.height - 8))
            }
        case let .daily(bars):
            let volumes = range.map { NSDecimalNumber(decimal: bars[$0].volume).doubleValue }
            let maxVolume = max(volumes.max() ?? 0, 1)
            for index in range {
                let bar = bars[index]
                let centerX = x(index)
                let stepX = plotWidth / CGFloat(max(range.count, 1))
                let rising = bar.close >= bar.open
                let color: Color = rising ? .red : .green
                var wick = Path(); wick.move(to: CGPoint(x: centerX, y: y(bar.high))); wick.addLine(to: CGPoint(x: centerX, y: y(bar.low)))
                context.stroke(wick, with: .color(color), lineWidth: 1)
                let top = min(y(bar.open), y(bar.close))
                let body = CGRect(x: centerX - max(stepX * 0.27, 0.6), y: top,
                                  width: max(stepX * 0.54, 1), height: max(abs(y(bar.open) - y(bar.close)), 1))
                context.fill(Path(body), with: .color(color.opacity(0.85)))
                if showVolume {
                    let volume = NSDecimalNumber(decimal: bar.volume).doubleValue
                    let barHeight = (volumeHeight - 4) * CGFloat(volume / maxVolume)
                    let volumeBar = CGRect(x: centerX - max(stepX * 0.3, 0.6),
                                           y: volumeTop + 2 + volumeHeight - 4 - barHeight,
                                           width: max(stepX * 0.6, 1), height: barHeight)
                    context.fill(Path(volumeBar), with: .color(color.opacity(0.55)))
                }
            }
            if showVolume {
                var divider = Path(); divider.move(to: CGPoint(x: leftAxis, y: volumeTop)); divider.addLine(to: CGPoint(x: size.width - rightInset, y: volumeTop))
                context.stroke(divider, with: .color(.secondary.opacity(0.2)), lineWidth: 1)
                context.draw(Text("VOL").font(.system(size: 8, weight: .medium)).foregroundColor(.secondary),
                            at: CGPoint(x: 3, y: volumeTop + volumeHeight / 2), anchor: .leading)
            }
            let tickCount = min(5, range.count)
            if tickCount > 0 {
                for tick in 0..<tickCount {
                    let index = range.lowerBound + (range.count - 1) * tick / max(tickCount - 1, 1)
                    let date = bars[index].tradingDate
                    let label = date.formatted(.dateTime.month(.abbreviated).day())
                    context.draw(Text(label).font(.system(size: 8)).foregroundColor(.secondary),
                                at: CGPoint(x: x(index), y: size.height - 8))
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
                path.move(to: CGPoint(x: leftAxis, y: lineY)); path.addLine(to: CGPoint(x: size.width - rightInset, y: lineY))
                context.stroke(path, with: .color(overlayColor(overlay.kind)), style: StrokeStyle(lineWidth: 1.5, dash: [5, 3]))
                context.draw(Text(overlayTitle(overlay.kind)).font(.caption2.bold()).foregroundColor(overlayColor(overlay.kind)),
                            at: CGPoint(x: leftAxis + 30, y: max(8, lineY - 8)))
            } else {
                let matching = overlay.points.filter { visibleTimes.contains($0.timestamp) }
                for point in matching {
                    guard let index = series.timestamps.firstIndex(of: point.timestamp), range.contains(index) else { continue }
                    let pointX = x(index)
                    let stepX = plotWidth / CGFloat(max(range.count, 1))
                    path.move(to: CGPoint(x: pointX, y: y(point.value)))
                    path.addLine(to: CGPoint(x: min(pointX + stepX, size.width - rightInset), y: y(point.value)))
                }
                context.stroke(path, with: .color(overlayColor(overlay.kind)), style: StrokeStyle(lineWidth: 1.3, dash: [3, 2]))
            }
        }
        if visibleLayers.contains("iopv"), let observation = model.iopv,
           !isUnavailable(observation.quality), let value = observation.value {
            let lineY = y(value)
            var iopvPath = Path()
            iopvPath.move(to: CGPoint(x: leftAxis, y: lineY))
            iopvPath.addLine(to: CGPoint(x: size.width - rightInset, y: lineY))
            context.stroke(iopvPath, with: .color(overlayColor(.iopv)),
                           style: StrokeStyle(lineWidth: 1.3, dash: [2, 3]))
            context.draw(Text("IOPV").font(.system(size: 8, weight: .semibold))
                            .foregroundColor(overlayColor(.iopv)),
                         at: CGPoint(x: leftAxis + 24, y: max(priceTop + 7, lineY - 7)))
        }
        if let selectedIndex, range.contains(selectedIndex) {
            let cursorX = x(selectedIndex)
            var cursor = Path(); cursor.move(to: CGPoint(x: cursorX, y: priceTop)); cursor.addLine(to: CGPoint(x: cursorX, y: size.height - bottomAxis))
            context.stroke(cursor, with: .color(.secondary.opacity(0.8)), style: StrokeStyle(lineWidth: 1, dash: [3, 3]))
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
        case .brokerCost: return .gray
        case .intradayAverage: return .purple
        case .previousClose: return .gray
        case .iopv: return .cyan
        case .candidateBuy: return .green
        case .candidateSell: return .red
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
            HStack(spacing: 4) {
                Circle().fill(color).frame(width: 6, height: 6)
                Text(title).font(.caption.monospaced().weight(.medium))
                Image(systemName: active ? "eye" : "eye.slash")
                    .font(.system(size: 10, weight: .semibold))
            }
            .foregroundStyle(available ? (active ? color : Color.secondary) : Color.secondary.opacity(0.5))
            .padding(.horizontal, 10).padding(.vertical, 7)
            .frame(minHeight: 44)
            .background(active ? color.opacity(0.11) : Color.clear, in: Capsule())
            .contentShape(Capsule())
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
        let iopv = visibleLayerKeys.contains("iopv") ? model.iopv : nil
        return (try? FChartOverlayModel(chart: model.chart, priceOverlays: overlays, iopv: iopv)) ?? model
    }

    private func unavailableOverlaySummary(_ model: FChartOverlayModel) -> String {
        var unavailable: [String] = []
        if !model.priceOverlays.contains(where: { $0.kind == .intradayAverage && !isUnavailable($0.quality) }) {
            unavailable.append("均价不可用")
        }
        if !model.priceOverlays.contains(where: { $0.kind == .previousClose && !isUnavailable($0.quality) }) {
            unavailable.append("前收不可用")
        }
        if model.iopv.map({ isUnavailable($0.quality) }) != false { unavailable.append("IOPV不可用") }
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
        return try? FChartOverlayModel(chart: chart, priceOverlays: overlays,
                                       iopv: try? FIOPVObservation(securityCode: chart.securityCode,
                                                                   value: nil, observedAt: nil, fetchedAt: nil,
                                                                   source: nil,
                                                                   quality: .unavailable(reason: "没有可靠 IOPV 数据源")))
    }
}
