import SwiftUI

struct WatchVitalsView: View {
    @Environment(WatchHealthStore.self) private var healthStore
    @Environment(WatchConnectivityService.self) private var connectivityService

	var body: some View {
		let recovery = connectivityService.recoveryScore
		let hr = recovery?.restingHeartRate ?? healthStore.heartRate
		let hrv = recovery?.hrvValue ?? healthStore.hrv
		let sleepHrs: Double = {
			if let asleep = connectivityService.sleepAnalysis?.asleepDuration, asleep > 0 { return asleep / 3600 }
			return healthStore.sleepHours
		}()
		ScrollView {
			VStack(spacing: 8) {
				LazyVGrid(columns: [GridItem(.flexible(), spacing: 8), GridItem(.flexible(), spacing: 8)], spacing: 8) {
					VitalTile(
						icon: "heart.fill",
						label: "Resting HR",
						value: hr > 0 ? String(format: "%.0f", hr) : "--",
						unit: "bpm",
						color: .red
					)
					VitalTile(
						icon: "waveform.path.ecg",
						label: "HRV",
						value: hrv > 0 ? String(format: "%.0f", hrv) : "--",
						unit: "ms",
						color: .cyan
					)
					VitalTile(
						icon: "moon.fill",
						label: "Sleep",
						value: sleepHrs > 0 ? String(format: "%.1f", sleepHrs) : "--",
						unit: "hrs",
						color: .indigo
					)
					VitalTile(
						icon: "figure.run",
						label: "Recovery",
						value: (recovery?.score ?? 0) > 0 ? "\(recovery!.score)" : "--",
						unit: "score",
						color: .green
					)
				}
			}
			.padding(8)
		}
		.navigationTitle("Vitals")
		.navigationBarTitleDisplayMode(.inline)
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
        .environment(WatchConnectivityService())
}
