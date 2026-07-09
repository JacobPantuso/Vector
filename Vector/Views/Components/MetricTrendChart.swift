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

    private var yDomain: ClosedRange<Double> {
        let values = points.map(\.value) + (baseline.map { [$0] } ?? [])
        guard let lo = values.min(), let hi = values.max() else { return 0...100 }
        let pad = Swift.max((hi - lo) * 0.15, 4)
        return Swift.max(0, lo - pad)...(hi + pad)
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
                            Text(valueFormat(v))
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
        }
    }
}
