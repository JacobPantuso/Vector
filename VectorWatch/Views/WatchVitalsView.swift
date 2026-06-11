import SwiftUI

struct WatchVitalsView: View {
    @Environment(WatchHealthStore.self) private var healthStore

    var body: some View {
        ScrollView {
            VStack(spacing: 8) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
                    VitalTile(
                        icon: "heart.fill",
                        label: "Heart Rate",
                        value: healthStore.heartRate > 0 ? String(format: "%.0f", healthStore.heartRate) : "--",
                        unit: "bpm",
                        color: .red
                    )
                    VitalTile(
                        icon: "waveform.path.ecg",
                        label: "HRV",
                        value: healthStore.hrv > 0 ? String(format: "%.0f", healthStore.hrv) : "--",
                        unit: "ms",
                        color: .cyan
                    )
                    VitalTile(
                        icon: "moon.fill",
                        label: "Sleep",
                        value: healthStore.sleepHours > 0 ? String(format: "%.1f", healthStore.sleepHours) : "--",
                        unit: "hrs",
                        color: .indigo
                    )
                    VitalTile(
                        icon: "figure.run",
                        label: "Recovery",
                        value: healthStore.recoveryScore > 0 ? "\(healthStore.recoveryScore)" : "--",
                        unit: "score",
                        color: .green
                    )
                }
            }
            .padding(8)
        }
        .navigationTitle("Vitals")
        .task {
            await healthStore.fetchAll()
        }
    }
}

private struct VitalTile: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(color)

            Text(value)
                .font(.system(size: 15, weight: .bold, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.8)

            Text(unit)
                .font(.system(size: 9, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(color.opacity(0.12)), in: .rect(cornerRadius: 12))
    }
}

#Preview {
    WatchVitalsView()
        .environment(WatchHealthStore())
}
