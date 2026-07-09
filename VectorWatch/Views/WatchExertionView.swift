import SwiftUI

struct WatchExertionView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let exertion = connectivityService.exertionScore {
                    Text("\(exertion.score)")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(exertion.exertionLevelColor)

                    Text("total exertion score")
                        .font(.caption2)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 4) {
                        Image(systemName: "bolt.fill")
                            .font(.caption2)
                        Text(exertion.exertionLevelLabel)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(exertion.exertionLevelColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.tint(exertion.exertionLevelColor.opacity(0.18)), in: .capsule)

                    VStack(spacing: 8) {
                        WatchMetricRow(
                            icon: "chart.line.uptrend.xyaxis",
                            label: "Acute Load",
                            value: String(format: "%.0f", exertion.acuteLoad),
                            unit: "kcal",
                            color: .orange
                        )
                        WatchMetricRow(
                            icon: "calendar",
                            label: "Chronic Load",
                            value: String(format: "%.0f", exertion.chronicLoad),
                            unit: "kcal",
                            color: .yellow
                        )
                    }
                } else {
                    Text("--")
                        .font(.system(size: 48, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text("No Data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .navigationTitle("Exertion")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    WatchExertionView()
        .environment(WatchConnectivityService())
}
