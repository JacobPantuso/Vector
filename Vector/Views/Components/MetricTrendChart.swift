import SwiftUI
import Charts

struct MetricTrendPoint: Identifiable {
    let id = UUID()
    let date: Date
    let value: Double
}

/// A real-data line+area trend chart with an optional baseline rule. Shows a friendly
/// empty state when there isn't enough history yet (never fabricates data).
struct MetricTrendChart: View {
    let points: [MetricTrendPoint]
    var baseline: Double? = nil
    var tint: Color = .indigo
    var valueFormat: (Double) -> String = { String(Int($0)) }
    var modeAnnotations: [AppModePeriod] = []
    /// Hard clamp for the Y domain — e.g. `0...100` for percentages so padding
    /// can't produce an impossible ">100%" tick.
    var domainLimit: ClosedRange<Double>? = nil
    /// Unit suffix shown in the scrub callout ("ms", "bpm", "%").
    var unit: String = ""
    /// Set false for decorative/at-a-glance charts that shouldn't capture drags.
    var isInteractive: Bool = true

    @State private var selectedDate: Date?

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value) + (baseline.map { [$0] } ?? [])
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        let span = hi - lo
        // Pad relative to the data's own scale, not a fixed number of units: a
        // ±0.3 °C deviation series and a 12,000 lb volume series both need room.
        let magnitude = Swift.max(abs(lo), abs(hi))
        let pad = Swift.max(span * 0.15, magnitude * 0.002, 0.05)
        // Only floor at zero when the metric itself is non-negative — deviation
        // series legitimately go below zero.
        var lower = lo - pad
        if lo >= 0 { lower = Swift.max(0, lower) }
        var upper = hi + pad
        if let limit = domainLimit {
            lower = Swift.max(limit.lowerBound, lower)
            upper = Swift.min(limit.upperBound, upper)
        }
        guard upper > lower else { return lower...(lower + 1) }
        return lower...upper
    }

    /// Axis labels sized to the visible span rather than the raw magnitude — a
    /// narrow domain formatted through an integer formatter renders every tick
    /// with the same text.
    private func axisLabel(_ v: Double) -> String {
        let span = yDomain.upperBound - yDomain.lowerBound
        let formatted = valueFormat(v)
        // If the caller's format collapses the span into one label, add precision.
        if span < 3, formatted == valueFormat(v + span / 4) {
            return String(format: span < 0.5 ? "%.2f" : "%.1f", v)
        }
        return formatted
    }

    private var selectedPoint: MetricTrendPoint? {
        guard let selectedDate else { return nil }
        let startOfDay = Calendar.current.startOfDay(for: selectedDate)
        return points.min { a, b in
            abs(a.date.timeIntervalSince(startOfDay)) < abs(b.date.timeIntervalSince(startOfDay))
        }
    }

    private var strideDays: Int {
        Swift.max(1, points.count / 5)
    }

    var body: some View {
        if points.count < 2 {
            VStack(spacing: 6) {
                Image(systemName: "chart.line.uptrend.xyaxis")
                    .font(.title3)
                    .foregroundStyle(.tertiary)
                Text("Not enough history yet")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text("Keep wearing your watch — your trend builds over the next few days.")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
            }
            .frame(maxWidth: .infinity, minHeight: 120)
        } else {
            Chart {
                ForEach(modeAnnotations) { period in
                    RectangleMark(
                        xStart: .value("start", period.startDate),
                        xEnd: .value("end", period.endDate ?? Date())
                    )
                    .foregroundStyle(period.mode.color.opacity(0.12))
                    .annotation(position: .top, alignment: .center) {
                        Image(systemName: period.mode.icon)
                            .font(.caption2)
                            .foregroundStyle(period.mode.color)
                    }
                }

                ForEach(points) { point in
                    LineMark(
                        x: .value("Day", point.date, unit: .day),
                        y: .value("Value", point.value)
                    )
                    .foregroundStyle(tint.gradient)
                    .interpolationMethod(.catmullRom)

                    AreaMark(
                        x: .value("Day", point.date, unit: .day),
                        yStart: .value("Min", yDomain.lowerBound),
                        yEnd: .value("Value", point.value)
                    )
                    .foregroundStyle(tint.opacity(0.1).gradient)
                    .interpolationMethod(.catmullRom)
                }

                if let baseline {
                    RuleMark(y: .value("Baseline", baseline))
                        .foregroundStyle(Color.secondary.opacity(0.4))
                        .lineStyle(StrokeStyle(dash: [4, 4]))
                        .annotation(position: .trailing, alignment: .center) {
                            Text("avg")
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                }

                if let selectedPoint {
                    RuleMark(x: .value("Day", selectedPoint.date, unit: .day))
                        .foregroundStyle(Color.secondary.opacity(0.35))
                        .lineStyle(StrokeStyle(lineWidth: 1))
                        .annotation(position: .top, spacing: 4, overflowResolution: .init(x: .fit(to: .chart), y: .fit(to: .chart))) {
                            VStack(alignment: .leading, spacing: 1) {
                                Text("\(valueFormat(selectedPoint.value))\(unit.isEmpty ? "" : " " + unit)")
                                    .font(.caption.weight(.semibold))
                                    .monospacedDigit()
                                Text(selectedPoint.date.formatted(.dateTime.weekday(.abbreviated).month(.abbreviated).day()))
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            }
                            .padding(.horizontal, 8)
                            .padding(.vertical, 5)
                            // Liquid Glass has no surface to sample inside a chart's
                            // annotation layer and falls back to an opaque slab, so the
                            // scrub callout uses a plain material instead.
                            .background(.regularMaterial, in: .rect(cornerRadius: 8))
                            .overlay {
                                RoundedRectangle(cornerRadius: 8)
                                    .strokeBorder(Color.primary.opacity(0.08), lineWidth: 0.5)
                            }
                            .shadow(color: .black.opacity(0.12), radius: 4, y: 2)
                        }

                    // White/background ring behind the point
                    PointMark(x: .value("Day", selectedPoint.date, unit: .day), y: .value("Value", selectedPoint.value))
                        .foregroundStyle(Color(.systemBackground))
                        .symbolSize(110)

                    // Colored point in front
                    PointMark(x: .value("Day", selectedPoint.date, unit: .day), y: .value("Value", selectedPoint.value))
                        .foregroundStyle(tint)
                        .symbolSize(60)
                }
            }
            .chartYScale(domain: yDomain)
            .chartXAxis {
                AxisMarks(values: .stride(by: .day, count: strideDays)) { value in
                    AxisValueLabel {
                        if let date = value.as(Date.self) {
                            Text(date.formatted(.dateTime.weekday(.abbreviated)))
                                .font(.system(size: 9))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartYAxis {
                AxisMarks(position: .leading, values: .automatic(desiredCount: 3)) { value in
                    AxisValueLabel {
                        if let v = value.as(Double.self) {
                            Text(axisLabel(v))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .chartXSelection(value: isInteractive ? $selectedDate : .constant(nil))
            .sensoryFeedback(.selection, trigger: selectedPoint?.id)
        }
    }
}
