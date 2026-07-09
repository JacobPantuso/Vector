import SwiftUI
import Charts

struct MetricStatusCard: View {
    let title: String
    let status: String
    let statusColor: Color
    let icon: String
    let color: Color
    let series: [Double]

    private var hasSparkline: Bool { series.filter { $0 > 0 }.count >= 2 }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(status)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            if hasSparkline {
                Spacer(minLength: 8)
                MetricMiniSparkline(values: series, color: color)
                    .padding(.bottom, 14)
                    .padding(.horizontal, 2)
            }
        }
        .frame(maxWidth: .infinity, minHeight: hasSparkline ? 132 : nil, alignment: .topLeading)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .clipShape(.rect(cornerRadius: 20))
    }
}

struct MetricMiniSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        let maxV = values.max() ?? 0
        let minV = values.min() ?? 0
        let span = max(maxV - minV, 1)
        return Chart(Array(values.enumerated()), id: \.offset) { idx, v in
            AreaMark(x: .value("i", idx), y: .value("v", v))
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("i", idx), y: .value("v", v))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: (minV - span * 0.18)...(maxV + span * 0.1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.frame(maxWidth: .infinity).padding(0)
        }
        .frame(height: 40)
    }
}

#Preview("Sparkline states") {
    ScrollView {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            Button {} label: {
                MetricStatusCard(title: "Empty", status: "93%", statusColor: .green, icon: "bed.double.fill", color: .purple, series: [])
            }
            .buttonStyle(.plain)

            Button {} label: {
                MetricStatusCard(title: "Full Series", status: "14.0 br/min", statusColor: .green, icon: "lungs.fill", color: .cyan, series: [12, 14, 13, 15, 14, 13, 14])
            }
            .buttonStyle(.plain)

            Button {} label: {
                MetricStatusCard(title: "One Point", status: "-0.1°C", statusColor: .green, icon: "thermometer.medium", color: .orange, series: [36.5])
            }
            .buttonStyle(.plain)

            Button {} label: {
                MetricStatusCard(title: "Empty 2", status: "11:05 PM", statusColor: .indigo, icon: "clock.fill", color: .indigo, series: [])
            }
            .buttonStyle(.plain)
        }
        .padding(16)
    }
}
