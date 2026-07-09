import SwiftUI

struct MetricRow: View {
    let label: String
    let value: String
    let unit: String
    let delta: Double?
    let icon: String

    init(label: String, value: String, unit: String, delta: Double? = nil, icon: String) {
        self.label = label
        self.value = value
        self.unit = unit
        self.delta = delta
        self.icon = icon
    }

    var body: some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.system(size: 16, weight: .semibold))
                .foregroundStyle(.cyan)
                .frame(width: 32)

            VStack(alignment: .leading, spacing: 4) {
                Text(label)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                Text(unit)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(value)
                    .font(.headline)
                    .monospacedDigit()

                if let delta {
                    HStack(spacing: 4) {
                        Image(systemName: delta >= 0 ? "arrow.up.right" : "arrow.down.right")
                            .font(.caption2)
                        Text(String(format: "%.0f", abs(delta)))
                            .font(.caption2)
                            .monospacedDigit()
                    }
                    .foregroundStyle(delta >= 0 ? .green : .red)
                }
            }
        }
    }
}

#Preview {
    MetricRow(label: "Heart Rate", value: "72", unit: "bpm", delta: 5, icon: "heart.fill")
        .padding()
}
