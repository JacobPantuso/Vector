import SwiftUI

struct WatchMetricRow: View {
    let icon: String
    let label: String
    let value: String
    let unit: String
    let color: Color

    var body: some View {
        HStack(spacing: 8) {
            Image(systemName: icon)
                .font(.system(size: 12, weight: .semibold))
                .foregroundStyle(color)
                .frame(width: 16)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.secondary)

                HStack(spacing: 2) {
                    Text(value)
                        .font(.system(size: 14, weight: .bold, design: .rounded))
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(10)
        .glassEffect(.regular.tint(color.opacity(0.08)), in: .rect(cornerRadius: 12))
    }
}

#Preview {
    VStack {
        WatchMetricRow(icon: "heart.fill", label: "HRV", value: "65", unit: "ms", color: .green)
        WatchMetricRow(icon: "waveform.path.ecg", label: "Resting HR", value: "58", unit: "bpm", color: .pink)
    }
    .padding()
}
