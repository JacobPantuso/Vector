import SwiftUI

struct VitalsCustomizeSheet: View {
    @Environment(\.dismiss) private var dismiss
    let store: VitalsLayoutStore

    // MARK: - Display Name Mapping
    private let displayNames: [VitalMetric: String] = [
        .heartRate: "Heart Rate",
        .hrv: "HRV",
        .restingHR: "Resting HR",
        .vo2Max: "VO₂ Max",
        .wristTemp: "Wrist Temperature",
        .spo2: "Blood Oxygen",
        .respiratoryRate: "Respiratory Rate",
        .sleep: "Sleep",
        .activeEnergy: "Active Energy",
        .restingEnergy: "Resting Energy",
        .steps: "Steps",
        .physicalEffort: "Physical Effort",
        .hrr: "Heart Rate Recovery"
    ]

    private func displayName(for metric: VitalMetric) -> String {
        displayNames[metric] ?? metric.title
    }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Text("Drag to reorder. Toggle which vitals appear on your Home screen.")
                        .font(.callout)
                        .foregroundStyle(.secondary)
                }

                Section {
                    ForEach(store.order, id: \.self) { metric in
                        VitalCustomizeRow(
                            metric: metric,
                            displayName: displayName(for: metric),
                            isEnabled: store.enabled.contains(metric),
                            size: store.sizes[metric] ?? .small,
                            onToggle: { store.toggle(metric) },
                            onSizeChange: { store.setSize($0, for: metric) }
                        )
                    }
                    .onMove { store.move(fromOffsets: $0, toOffset: $1) }
                }

                Section {
                    Button(role: .destructive) {
                        store.resetToDefaults()
                    } label: {
                        Text("Reset to Defaults")
                    }
                }
            }
            .environment(\.editMode, .constant(.active))
            .navigationTitle("Customize Vitals")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}

// MARK: - VitalCustomizeRow
private struct VitalCustomizeRow: View {
    let metric: VitalMetric
    let displayName: String
    let isEnabled: Bool
    let size: VitalCardSize
    let onToggle: () -> Void
    let onSizeChange: (VitalCardSize) -> Void

    var body: some View {
        HStack(spacing: 12) {
            // Icon swatch
            Image(systemName: metric.icon)
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(isEnabled ? metric.tint : metric.tint.opacity(0.5))
                .frame(width: 28, height: 28)
                .background(
                    RoundedRectangle(cornerRadius: 6)
                        .fill(metric.tint.opacity(isEnabled ? 0.15 : 0.08))
                )

            // Title
            VStack(alignment: .leading, spacing: 0) {
                Text(displayName)
                    .font(.body)
                    .foregroundStyle(isEnabled ? .primary : .secondary)
            }

            Spacer()

            // Size control capsule (if enabled)
            if isEnabled {
                Menu {
                    Picker("Size", selection: .init(
                        get: { size },
                        set: { onSizeChange($0) }
                    )) {
                        ForEach(VitalCardSize.allCases, id: \.self) { s in
                            Text(s.rawValue.capitalized).tag(s)
                        }
                    }
                } label: {
                    Text(size.rawValue.capitalized)
                        .font(.caption2)
                        .fontWeight(.semibold)
                        .foregroundStyle(.secondary)
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .background(Color(.quaternarySystemFill))
                        .clipShape(Capsule())
                }
                .contextMenu {
                    Picker("Card Size", selection: .init(
                        get: { size },
                        set: { onSizeChange($0) }
                    )) {
                        ForEach(VitalCardSize.allCases, id: \.self) { s in
                            Text(s.rawValue.capitalized).tag(s)
                        }
                    }
                }
            } else {
                Text(size.rawValue.capitalized)
                    .font(.caption2)
                    .fontWeight(.semibold)
                    .foregroundStyle(.tertiary)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color(.quaternarySystemFill))
                    .clipShape(Capsule())
            }

            // Toggle
            Toggle("", isOn: .init(
                get: { isEnabled },
                set: { _ in onToggle() }
            ))
            .labelsHidden()
            .tint(metric.tint)
        }
    }
}

#Preview {
    VitalsCustomizeSheet(store: VitalsLayoutStore.shared)
}
