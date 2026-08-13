import SwiftUI

/// Review sheet for pending progressive-overload changes on a workout template.
/// Lets the user pick which weight changes to apply before committing.
struct ProgressionReviewSheet: View {
    let changes: [ProgressionChange]
    /// Advisor headline per exercise ID (e.g. "Ready to progress"), optional.
    var headlines: [UUID: String] = [:]
    let onConfirm: ([ProgressionChange]) -> Void

    @State private var selectedIDs: Set<UUID>

    init(changes: [ProgressionChange], headlines: [UUID: String] = [:], onConfirm: @escaping ([ProgressionChange]) -> Void) {
        self.changes = changes
        self.headlines = headlines
        self.onConfirm = onConfirm
        // All selected by default.
        self._selectedIDs = State(initialValue: Set(changes.map(\.id)))
    }

    private var selectedChanges: [ProgressionChange] {
        changes.filter { selectedIDs.contains($0.id) }
    }

    private var confirmLabel: String {
        let count = selectedIDs.count
        return count == 1 ? "Apply 1 change" : "Apply \(count) changes"
    }

    var body: some View {
        VStack(spacing: 0) {
            // Header
            VStack(alignment: .leading, spacing: 4) {
                Text("Review Progression")
                    .font(.title3.bold())
                Text("Select the increases you want to apply.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 12)

            ScrollView {
                VStack(spacing: 10) {
                    ForEach(changes) { change in
                        row(for: change)
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 4)
                .padding(.bottom, 12)
            }
            .safeAreaInset(edge: .bottom) {
                // Confirm — anchored to the bottom; content scrolls beneath it.
                Button {
                    onConfirm(selectedChanges)
                } label: {
                    Text(confirmLabel)
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 6)
                }
                .buttonStyle(.glassProminent)
                .tint(
                    LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                )
                .shadow(color: .purple.opacity(0.25), radius: 8, y: 2)
                .disabled(selectedIDs.isEmpty)
                .padding(.horizontal, 20)
                .padding(.top, 8)
                .padding(.bottom, 10)
            }
        }
    }

    private func row(for change: ProgressionChange) -> some View {
        let isSelected = selectedIDs.contains(change.id)
        let delta = change.deltaKg
        let deltaColor: Color = delta >= 0 ? .green : .purple

        return Button {
            withAnimation(.spring(duration: 0.25)) {
                if isSelected {
                    selectedIDs.remove(change.id)
                } else {
                    selectedIDs.insert(change.id)
                }
            }
        } label: {
            HStack(spacing: 12) {
                VStack(alignment: .leading, spacing: 4) {
                    Text(change.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)

                    HStack(spacing: 8) {
                        Text("\(fmt(change.oldWeightKg)) lb → \(fmt(change.newWeightKg)) lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)

                        Text(delta >= 0 ? "+\(fmt(delta)) lb" : "−\(fmt(abs(delta))) lb")
                            .font(.caption2.weight(.bold))
                            .padding(.horizontal, 7)
                            .padding(.vertical, 2)
                            .background(deltaColor.opacity(0.15))
                            .foregroundStyle(deltaColor)
                            .clipShape(Capsule())
                    }

                    if let headline = headlines[change.id] {
                        Label(headline, systemImage: "sparkles")
                            .font(.caption2.weight(.medium))
                            .foregroundStyle(
                                LinearGradient(colors: [.indigo, .purple], startPoint: .leading, endPoint: .trailing)
                            )
                    }
                }

                Spacer(minLength: 0)

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .font(.title3)
                    .foregroundStyle(isSelected ? AnyShapeStyle(Color.purple) : AnyShapeStyle(Color.secondary))
                    .contentTransition(.symbolEffect(.replace))
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .background(Color(.secondarySystemGroupedBackground), in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(isSelected ? Color.purple.opacity(0.35) : Color.clear, lineWidth: 1)
            }
        }
        .buttonStyle(.plain)
    }

    private func fmt(_ v: Double) -> String {
        v.rounded() == v ? String(format: "%.0f", v) : String(format: "%.1f", v)
    }
}

#if DEBUG
#Preview("Progression Review") {
    let a = UUID(); let b = UUID(); let c = UUID()
    return Color.black.vectorSheet(isPresented: .constant(true), style: .half) {
        ProgressionReviewSheet(
            changes: [
                ProgressionChange(id: a, name: "Barbell Back Squat", oldWeightKg: 185, newWeightKg: 195),
                ProgressionChange(id: b, name: "Bench Press", oldWeightKg: 135, newWeightKg: 140),
                ProgressionChange(id: c, name: "Romanian Deadlift", oldWeightKg: 150, newWeightKg: 135)
            ],
            headlines: [a: "Ready to progress", b: "Break the plateau", c: "Back off to break through"]
        ) { _ in }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
    }
    .preferredColorScheme(.dark)
}
#endif
