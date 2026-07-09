import SwiftUI

struct WatchRecoveryView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                if let recovery = connectivityService.recoveryScore {
                    Text("\(recovery.score)")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(recovery.level.color)

                    HStack(spacing: 4) {
                        Image(systemName: recovery.level.systemImage)
                            .font(.caption2)
                        Text(recovery.level.label)
                            .font(.caption.weight(.semibold))
                    }
                    .foregroundStyle(recovery.level.color)
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .glassEffect(.regular.tint(recovery.level.color.opacity(0.18)), in: .capsule)

                    VStack(spacing: 8) {
                        WatchMetricRow(
                            icon: "waveform.path.ecg",
                            label: "HRV",
                            value: String(format: "%.0f", recovery.hrvValue),
                            unit: "ms",
                            color: .green
                        )
                        WatchMetricRow(
                            icon: "heart.fill",
                            label: "Resting HR",
                            value: String(format: "%.0f", recovery.restingHeartRate),
                            unit: "bpm",
                            color: .pink
                        )
                    }
                } else {
                    Text("--")
                        .font(.system(size: 52, weight: .bold, design: .rounded))
                        .foregroundStyle(.tertiary)
                    Text("No Data")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(10)
        }
        .navigationTitle("Recovery")
        .navigationBarTitleDisplayMode(.inline)
    }
}

#Preview {
    WatchRecoveryView()
        .environment(WatchConnectivityService())
}
