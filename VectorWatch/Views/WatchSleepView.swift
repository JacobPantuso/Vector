import SwiftUI

struct WatchSleepView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let sleep = connectivityService.sleepAnalysis {
                    Text(sleep.formattedDuration)
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.blue)

                    HStack(spacing: 4) {
                        Image(systemName: "moon.stars.fill")
                            .font(.caption2)
                        Text(sleep.qualityLabel)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(sleep.qualityColor)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.tint(sleep.qualityColor.opacity(0.18)), in: .capsule)

                    VStack(spacing: 8) {
                        WatchMetricRow(
                            icon: "moon.zzz.fill",
                            label: "Deep",
                            value: String(format: "%.0f", sleep.deepDuration / 60),
                            unit: "min",
                            color: .indigo
                        )
                        WatchMetricRow(
                            icon: "eye.closed.fill",
                            label: "REM",
                            value: String(format: "%.0f", sleep.remDuration / 60),
                            unit: "min",
                            color: .blue
                        )
                    }
                } else {
                    Text("--")
                        .font(.system(size: 40, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text("No Data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .navigationTitle("Sleep")
    }
}

#Preview {
    WatchSleepView()
        .environment(WatchConnectivityService())
}
