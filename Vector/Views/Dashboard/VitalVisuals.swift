import SwiftUI

// MARK: - VitalWaveform
/// Thin continuous line chart resembling an EKG squiggle, with a final point glow.
/// Renders gracefully with 0-1 data points (draws nothing / flat placeholder).
struct VitalWaveform: View {
    let values: [Double]
    var tint: Color

    var body: some View {
        if values.isEmpty {
            EmptyVisualPlaceholder()
        } else if values.count == 1 {
            // Single point: draw a flat line with the point highlighted
            Canvas { context, size in
                let frame = CGRect(origin: .zero, size: size)
                let y = frame.midY

                // Soft gradient beneath the flat line
                var fillPath = Path()
                fillPath.move(to: CGPoint(x: frame.minX + 8, y: y))
                fillPath.addLine(to: CGPoint(x: frame.maxX - 8, y: y))
                fillPath.addLine(to: CGPoint(x: frame.maxX - 8, y: frame.maxY))
                fillPath.addLine(to: CGPoint(x: frame.minX + 8, y: frame.maxY))
                fillPath.closeSubpath()
                context.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [tint.opacity(0.28), tint.opacity(0.0)]),
                        startPoint: CGPoint(x: frame.midX, y: y),
                        endPoint: CGPoint(x: frame.midX, y: frame.maxY)
                    )
                )

                // Flat line
                var path = Path()
                path.move(to: CGPoint(x: frame.minX + 8, y: y))
                path.addLine(to: CGPoint(x: frame.maxX - 8, y: y))
                context.stroke(
                    path,
                    with: .color(tint),
                    lineWidth: 1.5
                )

                // Final point with halo
                let pointX = frame.maxX - 8
                context.fill(
                    Circle().path(in: CGRect(x: pointX - 5, y: y - 5, width: 10, height: 10)),
                    with: .color(tint.opacity(0.3))
                )
                context.fill(
                    Circle().path(in: CGRect(x: pointX - 3.5, y: y - 3.5, width: 7, height: 7)),
                    with: .color(tint)
                )
            }
        } else {
            // Multiple points: smooth interpolated line
            Canvas { context, size in
                let frame = CGRect(origin: .zero, size: size)
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 1
                let range = max(maxVal - minVal, 1)

                // Normalize values to canvas height (with padding)
                let normalized = values.map { v in
                    let normalized = (v - minVal) / range
                    let padded = 0.1 + normalized * 0.8
                    return frame.height * (1 - padded)
                }

                // Draw interpolated line using quadratic Bezier curves
                var path = Path()
                let xStep = (frame.width - 16) / CGFloat(max(values.count - 1, 1))

                path.move(to: CGPoint(x: frame.minX + 8, y: normalized[0]))

                for i in 1..<normalized.count {
                    let x1 = frame.minX + 8 + CGFloat(i - 1) * xStep
                    let y1 = normalized[i - 1]
                    let x2 = frame.minX + 8 + CGFloat(i) * xStep
                    let y2 = normalized[i]

                    let controlX = (x1 + x2) / 2
                    let controlY = (y1 + y2) / 2

                    path.addQuadCurve(to: CGPoint(x: x2, y: y2), control: CGPoint(x: controlX, y: controlY))
                }

                // Soft gradient beneath the curve
                var fillPath = path
                let lastPointX = frame.minX + 8 + CGFloat(normalized.count - 1) * xStep
                fillPath.addLine(to: CGPoint(x: lastPointX, y: frame.maxY))
                fillPath.addLine(to: CGPoint(x: frame.minX + 8, y: frame.maxY))
                fillPath.closeSubpath()
                context.fill(
                    fillPath,
                    with: .linearGradient(
                        Gradient(colors: [tint.opacity(0.30), tint.opacity(0.0)]),
                        startPoint: CGPoint(x: frame.midX, y: frame.minY),
                        endPoint: CGPoint(x: frame.midX, y: frame.maxY)
                    )
                )

                context.stroke(path, with: .color(tint), lineWidth: 1.5)

                // Final point with halo
                let lastX = frame.minX + 8 + CGFloat(normalized.count - 1) * xStep
                let lastY = normalized[normalized.count - 1]

                context.fill(
                    Circle().path(in: CGRect(x: lastX - 5, y: lastY - 5, width: 10, height: 10)),
                    with: .color(tint.opacity(0.3))
                )
                context.fill(
                    Circle().path(in: CGRect(x: lastX - 3.5, y: lastY - 3.5, width: 7, height: 7)),
                    with: .color(tint)
                )
            }
        }
    }
}

// MARK: - VitalNodeSparkline
/// Dashed line connecting hollow circle nodes, with the final node solid-filled and larger.
/// Includes faint horizontal dashed guides at top and bottom.
struct VitalNodeSparkline: View {
    let values: [Double]
    var tint: Color

    var body: some View {
        if values.isEmpty {
            EmptyVisualPlaceholder()
        } else if values.count == 1 {
            // Single point: draw a centered large solid node with guides and glow
            Canvas { context, size in
                let frame = CGRect(origin: .zero, size: size)
                let centerX = frame.midX
                let centerY = frame.midY

                // Horizontal guide rules at top and bottom
                drawGuideRules(in: context, frame: frame)

                // Glow behind the node
                let glowPath = Circle().path(in: CGRect(x: centerX - 8, y: centerY - 8, width: 16, height: 16))
                context.fill(glowPath, with: .color(tint.opacity(0.25)))

                // Large solid final node
                let nodePath = Circle().path(in: CGRect(x: centerX - 5.5, y: centerY - 5.5, width: 11, height: 11))
                context.fill(nodePath, with: .color(tint))
            }
        } else {
            // Multiple points: dashed line with nodes
            Canvas { context, size in
                let frame = CGRect(origin: .zero, size: size)
                let minVal = values.min() ?? 0
                let maxVal = values.max() ?? 1
                let range = max(maxVal - minVal, 1)

                // Normalize values to canvas height (with 12% padding on each side)
                let normalized = values.map { v in
                    let normalized = (v - minVal) / range
                    let padded = 0.12 + normalized * 0.76
                    return frame.height * (1 - padded)
                }

                // Draw guide rules
                drawGuideRules(in: context, frame: frame)

                let xStep = (frame.width - 16) / CGFloat(max(values.count - 1, 1))

                // Draw dashed connecting line (manual dash segments)
                var pathPoints: [CGPoint] = []
                pathPoints.append(CGPoint(x: frame.minX + 8, y: normalized[0]))
                for i in 1..<normalized.count {
                    let x = frame.minX + 8 + CGFloat(i) * xStep
                    let y = normalized[i]
                    pathPoints.append(CGPoint(x: x, y: y))
                }

                let dashLength: CGFloat = 3
                let gapLength: CGFloat = 3

                for segmentIdx in 0..<(pathPoints.count - 1) {
                    let p1 = pathPoints[segmentIdx]
                    let p2 = pathPoints[segmentIdx + 1]
                    let dx = p2.x - p1.x
                    let dy = p2.y - p1.y
                    let distance = sqrt(dx*dx + dy*dy)
                    let angle = atan2(dy, dx)

                    var currentDist: CGFloat = 0
                    var isDash = true

                    while currentDist < distance {
                        let patternLength = isDash ? dashLength : gapLength
                        let nextDist = min(currentDist + patternLength, distance)

                        if isDash {
                            let startX = p1.x + cos(angle) * currentDist
                            let startY = p1.y + sin(angle) * currentDist
                            let endX = p1.x + cos(angle) * nextDist
                            let endY = p1.y + sin(angle) * nextDist

                            var dashSegment = Path()
                            dashSegment.move(to: CGPoint(x: startX, y: startY))
                            dashSegment.addLine(to: CGPoint(x: endX, y: endY))
                            context.stroke(dashSegment, with: .color(tint.opacity(0.6)), lineWidth: 1.5)
                        }

                        currentDist = nextDist
                        isDash.toggle()
                    }
                }

                // Draw hollow circle nodes (knocked out of dashed line)
                for i in 0..<normalized.count {
                    let x = frame.minX + 8 + CGFloat(i) * xStep
                    let y = normalized[i]

                    if i < normalized.count - 1 {
                        // Hollow node (fill with background, then stroke outline to knock out)
                        let circlePath = Circle().path(in: CGRect(x: x - 4, y: y - 4, width: 8, height: 8))
                        context.fill(circlePath, with: .color(Color(uiColor: .systemBackground)))
                        context.stroke(circlePath, with: .color(tint.opacity(0.5)), lineWidth: 1.2)
                    }
                }

                // Draw final node larger with glow and solid-filled
                let lastX = frame.minX + 8 + CGFloat(normalized.count - 1) * xStep
                let lastY = normalized[normalized.count - 1]
                let glowPath = Circle().path(in: CGRect(x: lastX - 8, y: lastY - 8, width: 16, height: 16))
                context.fill(glowPath, with: .color(tint.opacity(0.25)))
                let finalPath = Circle().path(in: CGRect(x: lastX - 5.5, y: lastY - 5.5, width: 11, height: 11))
                context.fill(finalPath, with: .color(tint))
            }
        }
    }

    private func drawGuideRules(in context: GraphicsContext, frame: CGRect) {
        var topRule = Path()
        topRule.move(to: CGPoint(x: frame.minX + 8, y: frame.minY + 8))
        topRule.addLine(to: CGPoint(x: frame.maxX - 8, y: frame.minY + 8))
        context.stroke(topRule, with: .color(.secondary.opacity(0.15)), lineWidth: 1)

        var bottomRule = Path()
        bottomRule.move(to: CGPoint(x: frame.minX + 8, y: frame.maxY - 8))
        bottomRule.addLine(to: CGPoint(x: frame.maxX - 8, y: frame.maxY - 8))
        context.stroke(bottomRule, with: .color(.secondary.opacity(0.15)), lineWidth: 1)
    }
}



// MARK: - VitalArcGauge
/// A 180° dome gauge that scales to whatever space it is given: grey track, an optional
/// highlighted band, an optional tick at the apex, and a marker at `fraction`.
/// Wider than it is tall, so it fills a card's horizontal space instead of floating in it.
struct VitalArcGauge: View {
    let fraction: Double            // 0...1 along the arc, left end to right end
    var tint: Color
    var lowLabel: String
    var highLabel: String
    var bandStart: Double? = nil    // optional highlighted range, same 0...1 scale
    var bandEnd: Double? = nil
    var showsMidTick: Bool = false  // tick at the apex (a baseline)
    var valueLabel: String? = nil   // numeric readout drawn inside the dome

    private let startAngle: Double = 180
    private let sweep: Double = 180

    private func angle(for f: Double) -> Double {
        startAngle + max(0, min(1, f)) * sweep
    }

    var body: some View {
        if fraction.isNaN || fraction.isInfinite {
            EmptyVisualPlaceholder()
        } else {
            GeometryReader { geo in
                let w = geo.size.width
                let h = geo.size.height
                let labelRow: CGFloat = 14
                let usableH = max(h - labelRow, 26)
                let lw = max(8, min(12, usableH * 0.18))
                // Keep the apex clear of the Canvas edge — at zero margin the outer
                // stroke lands on y = 0 and gets clipped.
                let topMargin: CGFloat = 10
                let r = max(min(usableH - lw - topMargin, (w - lw) / 2 - 8), 14)
                // Anchor the dome to the bottom: when width caps the radius, the slack
                // goes above the arc rather than leaving a gap beneath the labels.
                let contentH = r + lw + labelRow
                let topInset = max(0, h - contentH)
                let center = CGPoint(x: w / 2, y: topInset + r + lw / 2)
                let clamped = max(0, min(1, fraction))
                let labelY = center.y + lw / 2 + 8

                ZStack(alignment: .topLeading) {
                    Canvas { context, _ in
                        // Track
                        var track = Path()
                        track.addArc(
                            center: center,
                            radius: r,
                            startAngle: .degrees(startAngle),
                            endAngle: .degrees(startAngle + sweep),
                            clockwise: false
                        )
                        context.stroke(
                            track,
                            with: .color(.primary.opacity(0.12)),
                            style: StrokeStyle(lineWidth: lw, lineCap: .round)
                        )

                        // Highlighted band
                        if let bandStart, let bandEnd, bandEnd > bandStart {
                            var band = Path()
                            band.addArc(
                                center: center,
                                radius: r,
                                startAngle: .degrees(angle(for: bandStart)),
                                endAngle: .degrees(angle(for: bandEnd)),
                                clockwise: false
                            )
                            context.stroke(
                                band,
                                with: .color(tint.opacity(0.35)),
                                style: StrokeStyle(lineWidth: lw, lineCap: .round)
                            )
                        }

                        // Apex tick
                        if showsMidTick {
                            let a = Angle(degrees: angle(for: 0.5)).radians
                            var tick = Path()
                            tick.move(to: CGPoint(
                                x: center.x + (r - lw / 2 - 2) * cos(a),
                                y: center.y + (r - lw / 2 - 2) * sin(a)
                            ))
                            tick.addLine(to: CGPoint(
                                x: center.x + (r + lw / 2 + 2) * cos(a),
                                y: center.y + (r + lw / 2 + 2) * sin(a)
                            ))
                            context.stroke(tick, with: .color(.primary.opacity(0.35)), lineWidth: 1.5)
                        }

                        // Marker
                        let ma = Angle(degrees: angle(for: clamped)).radians
                        let mx = center.x + r * cos(ma)
                        let my = center.y + r * sin(ma)
                        let mr = lw / 2 + 2
                        let dot = Circle().path(in: CGRect(x: mx - mr, y: my - mr, width: mr * 2, height: mr * 2))
                        context.fill(dot, with: .color(.white))
                        context.stroke(dot, with: .color(tint), lineWidth: 2.5)
                    }
                    .frame(width: w, height: h)

                    Text(lowLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                        .position(x: center.x - (r - 2), y: labelY)

                    Text(highLabel)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.tertiary)
                        .fixedSize()
                        .position(x: center.x + (r - 2), y: labelY)

                    if let valueLabel {
                        Text(valueLabel)
                            .font(.system(size: max(19, min(28, r * 0.52)), weight: .bold, design: .rounded))
                            .monospacedDigit()
                            .foregroundStyle(.primary)
                            .fixedSize()
                            .position(x: center.x, y: center.y - r * 0.30)
                    }
                }
            }
        }
    }
}

// MARK: - VitalSleepBars
/// Vertical column chart of the four sleep stages, scaled against the longest stage.
/// Used on the wide sleep card, where there is room for a real chart.
struct VitalSleepBars: View {
    let stages: SleepStageBreakdown

    private struct Stage: Identifiable {
        let name: String
        let seconds: Double
        let color: Color
        var id: String { name }
    }

    private var items: [Stage] {
        [
            Stage(name: "Deep", seconds: stages.deep, color: Color(red: 0.6, green: 0.4, blue: 1)),
            Stage(name: "Core", seconds: stages.core, color: Color(red: 0.2, green: 0.6, blue: 1)),
            Stage(name: "REM", seconds: stages.rem, color: .cyan),
            Stage(name: "Awake", seconds: stages.awake, color: Color.red.opacity(0.7))
        ]
    }

    private func formatStageDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var body: some View {
        if stages.hasData {
            GeometryReader { geo in
                let peak = max(items.map(\.seconds).max() ?? 1, 1)
                let barSpace = max(geo.size.height - 34, 14)

                HStack(alignment: .bottom, spacing: 8) {
                    ForEach(items) { item in
                        VStack(spacing: 3) {
                            Text(formatStageDuration(item.seconds))
                                .font(.system(size: 11, weight: .semibold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.primary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)

                            RoundedRectangle(cornerRadius: 4)
                                .fill(item.color)
                                .frame(height: max(barSpace * (item.seconds / peak), 3))

                            Text(item.name)
                                .font(.system(size: 10, weight: .medium))
                                .foregroundStyle(.secondary)
                                .lineLimit(1)
                                .minimumScaleFactor(0.7)
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
                .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .bottom)
            }
        } else {
            EmptyVisualPlaceholder()
        }
    }
}

// MARK: - VitalSleepStages
/// Sleep stage segmented bar with a 2×2 duration legend.
struct VitalSleepStages: View {
    let stages: SleepStageBreakdown

    private func formatStageDuration(_ seconds: Double) -> String {
        guard seconds > 0 else { return "—" }
        let hours = Int(seconds / 3600)
        let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
        if hours > 0 {
            return "\(hours)h\(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    @ViewBuilder
    private func legendCell(color: Color, name: String, duration: Double) -> some View {
        VStack(alignment: .leading, spacing: 1) {
            HStack(spacing: 4) {
                RoundedRectangle(cornerRadius: 2)
                    .fill(color)
                    .frame(width: 6, height: 6)
                Text(name)
                    .font(.system(size: 10, weight: .medium))
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            Text(formatStageDuration(duration))
                .font(.system(size: 13, weight: .semibold, design: .rounded))
                .monospacedDigit()
                .foregroundStyle(.primary)
                .lineLimit(1)
                .minimumScaleFactor(0.8)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    var body: some View {
        if stages.hasData {
            VStack(alignment: .leading, spacing: 8) {
                // Stage bar
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        if stages.deep > 0 {
                            Capsule()
                                .fill(Color(red: 0.6, green: 0.4, blue: 1))
                                .frame(maxWidth: geo.size.width * (stages.deep / stages.total))
                        }
                        if stages.core > 0 {
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.6, blue: 1))
                                .frame(maxWidth: geo.size.width * (stages.core / stages.total))
                        }
                        if stages.rem > 0 {
                            Capsule()
                                .fill(.cyan)
                                .frame(maxWidth: geo.size.width * (stages.rem / stages.total))
                        }
                        if stages.awake > 0 {
                            Capsule()
                                .fill(Color.red.opacity(0.7))
                                .frame(maxWidth: geo.size.width * (stages.awake / stages.total))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: 10)

                // Legend — two lines per entry so narrow cards never truncate
                HStack(spacing: 8) {
                    legendCell(color: Color(red: 0.6, green: 0.4, blue: 1), name: "Deep", duration: stages.deep)
                    legendCell(color: Color(red: 0.2, green: 0.6, blue: 1), name: "Core", duration: stages.core)
                }
                HStack(spacing: 8) {
                    legendCell(color: .cyan, name: "REM", duration: stages.rem)
                    legendCell(color: Color.red.opacity(0.7), name: "Awake", duration: stages.awake)
                }
            }
        } else {
            EmptyVisualPlaceholder()
        }
    }
}

// MARK: - Helpers
private struct EmptyVisualPlaceholder: View {
    var body: some View {
        VStack {
            Spacer()
            Image(systemName: "chart.line.uptrend.xyaxis")
                .font(.caption)
                .foregroundStyle(.tertiary)
            Text("No data yet")
                .font(.caption2)
                .foregroundStyle(.tertiary)
            Spacer()
        }
    }
}

// MARK: - Previews
#Preview("VitalWaveform") {
    VStack(spacing: 16) {
        Text("Multiple points").font(.caption).foregroundStyle(.secondary)
        VitalWaveform(values: [65, 72, 68, 75, 70, 73, 71], tint: .red)
            .frame(height: 54)

        Text("Single point").font(.caption).foregroundStyle(.secondary)
        VitalWaveform(values: [72], tint: .red)
            .frame(height: 54)

        Text("Empty").font(.caption).foregroundStyle(.secondary)
        VitalWaveform(values: [], tint: .red)
            .frame(height: 54)
    }
    .padding(16)
}

#Preview("VitalNodeSparkline") {
    VStack(spacing: 16) {
        Text("Multiple points").font(.caption).foregroundStyle(.secondary)
        VitalNodeSparkline(values: [42, 48, 44, 52, 50, 46, 49], tint: .cyan)
            .frame(height: 54)

        Text("Single point").font(.caption).foregroundStyle(.secondary)
        VitalNodeSparkline(values: [48], tint: .cyan)
            .frame(height: 54)

        Text("Empty").font(.caption).foregroundStyle(.secondary)
        VitalNodeSparkline(values: [], tint: .cyan)
            .frame(height: 54)
    }
    .padding(16)
}

#Preview("VitalArcGauge") {
    HStack(spacing: 24) {
        VitalArcGauge(fraction: 0.7, tint: .teal, lowLabel: "90%", highLabel: "100%", bandStart: 0.5, bandEnd: 1.0, valueLabel: "97%")
            .frame(width: 180, height: 78)
        VitalArcGauge(fraction: 0.4, tint: .orange, lowLabel: "−1.0°", highLabel: "+1.0°", showsMidTick: true, valueLabel: "+0.2°")
            .frame(width: 180, height: 78)
    }
    .padding(16)
}

#Preview("VitalSleepBars") {
    VitalSleepBars(stages: SleepStageBreakdown(deep: 4200, core: 15360, rem: 5640, awake: 840))
        .frame(width: 190, height: 110)
        .padding(16)
}

#Preview("VitalSleepStages") {
    VStack(spacing: 16) {
        Text("With data").font(.caption).foregroundStyle(.secondary)
        VitalSleepStages(stages: SleepStageBreakdown(deep: 5400, core: 14400, rem: 7200, awake: 3600))
            .frame(height: 78)

        Text("Empty").font(.caption).foregroundStyle(.secondary)
        VitalSleepStages(stages: SleepStageBreakdown(deep: 0, core: 0, rem: 0, awake: 0))
            .frame(height: 54)
    }
    .padding(16)
}
