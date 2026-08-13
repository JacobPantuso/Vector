import SwiftUI

struct InlineSetEditor: View {
    @Binding var entry: ManualExerciseEntry

    private let restPresets = [0, 30, 45, 60, 75, 90, 120, 150, 180]

    var body: some View {
        if isDurationOnly {
            timedBlockEditor
        } else {
            regularEditor
        }
    }

    /// Warm-ups, cool-downs, and custom timed blocks are measured purely by duration —
    /// no reps/sets and no Reps/Duration picker. Everything else gets the full editor.
    private var isDurationOnly: Bool {
        entry.resolvedRole == .warmup
            || entry.resolvedRole == .cooldown
            || (entry.libraryExerciseId == nil && entry.inputType == .duration)
    }

    private var timedBlockEditor: some View {
        VStack(spacing: 20) {
            HStack(spacing: 28) {
                Button {
                    entry.durationSeconds = max(15, entry.durationSeconds - 15)
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(entry.durationSeconds <= 15 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
                }
                .buttonStyle(.plain)
                .disabled(entry.durationSeconds <= 15)

                Text(entry.durationSeconds.durationLabel)
                    .font(.system(size: 46, weight: .bold, design: .rounded))
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .frame(minWidth: 130)
                    .animation(.snappy, value: entry.durationSeconds)

                Button {
                    entry.durationSeconds = min(1800, entry.durationSeconds + 15)
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.system(size: 32))
                        .foregroundStyle(entry.durationSeconds >= 1800 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
                }
                .buttonStyle(.plain)
                .disabled(entry.durationSeconds >= 1800)
            }

            HStack(spacing: 8) {
                ForEach([60, 180, 300, 600], id: \.self) { secs in
                    let selected = entry.durationSeconds == secs
                    Button {
                        entry.durationSeconds = secs
                    } label: {
                        Text(secs.durationLabel)
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 8)
                            .foregroundStyle(selected ? .white : .primary)
                            .glassEffect(.regular.tint(selected ? .orange.opacity(0.7) : .white.opacity(0.06)), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 22)
    }

    private var regularEditor: some View {
        VStack(spacing: 0) {
            // Input type picker
            Picker("Type", selection: $entry.inputType) {
                ForEach(ExerciseInputType.allCases, id: \.self) { type in
                    Text(type.rawValue).tag(type)
                }
            }
            .pickerStyle(.segmented)
            .padding(.horizontal, 14)
            .padding(.top, 12)
            .padding(.bottom, 14)

            Divider()

            // Reps mode: table with header + per-set rows
            if entry.inputType == .reps {
                repsTable
            } else {
                // Duration mode: single row
                durationRow
            }

            Divider()

            // Notes field
            VStack(alignment: .leading, spacing: 8) {
                Label("Notes", systemImage: "text.bubble")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                TextField("Optional cue…", text: $entry.notes, axis: .vertical)
                    .font(.caption)
                    .lineLimit(2...3)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
        }
    }

    // MARK: - Reps Mode Table

    private var repsTable: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Header
            HStack(spacing: 8) {
                Text("SET")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                Text("WEIGHT")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                Text("REPS")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)

                Text("REST")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            // Per-set rows
            ForEach(0..<entry.sets, id: \.self) { i in
                SwipeToDelete(onDelete: {
                    var updated = entry
                    var details = updated.setDetails ?? updated.resolvedSetDetails
                    guard entry.sets > 1, details.indices.contains(i) else { return }
                    details.remove(at: i)
                    updated.sets = max(1, updated.sets - 1)
                    updated.setDetails = details.isEmpty ? nil : details
                    entry = updated
                }) {
                    setRow(i)
                }

                if i < entry.sets - 1 {
                    Divider()
                }
            }

            Divider()

            // Add Set button
            HStack(spacing: 12) {
                Button {
                    let pad = entry.resolvedSetDetails.last ?? SetDetail(weightKg: entry.weightKg, reps: entry.reps)
                    var updated = entry
                    updated.sets += 1
                    if updated.setDetails == nil { updated.setDetails = updated.resolvedSetDetails }
                    updated.setDetails?.append(pad)
                    entry = updated
                } label: {
                    Label("Add Set", systemImage: "plus.circle.fill")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.cyan)
                }
                .buttonStyle(.plain)

                Spacer()
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    private func setRow(_ i: Int) -> some View {
        let binding = setBinding(i)
        let currentDetail = binding.wrappedValue
        let currentRest = currentDetail.restSeconds ?? entry.restSeconds

        return HStack(spacing: 8) {
            // Set index
            Text("\(i + 1)")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity)

            // Weight field
            HStack(spacing: 4) {
                TextField("BW", value: binding.weightKg, format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.center)
                    .font(.caption.monospacedDigit())
                    .frame(width: 40)
                Text("lb")
                    .font(.caption2)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 5)
            .background(Color.white.opacity(0.06))
            .cornerRadius(8)
            .frame(maxWidth: .infinity)

            // Reps field
            TextField("\(entry.reps)", value: binding.reps, format: .number)
                .keyboardType(.numberPad)
                .multilineTextAlignment(.center)
                .font(.caption.weight(.semibold).monospacedDigit())
                .frame(maxWidth: .infinity)

            // Rest Menu
            Menu {
                ForEach(restPresets, id: \.self) { seconds in
                    Button(action: {
                        var detail = binding.wrappedValue
                        detail.restSeconds = seconds
                        binding.wrappedValue = detail
                    }) {
                        HStack {
                            Text(restLabel(seconds))
                            if currentRest == seconds {
                                Image(systemName: "checkmark")
                            }
                        }
                    }
                }
            } label: {
                HStack(spacing: 4) {
                    Image(systemName: "timer")
                        .font(.caption2)
                    Text(restLabel(currentRest))
                        .font(.caption2.weight(.semibold))
                }
                .foregroundStyle(.orange)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(Color.orange.opacity(0.15))
                .cornerRadius(8)
                .frame(maxWidth: .infinity)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
    }

    // MARK: - Duration Mode

    private var durationRow: some View {
        VStack(spacing: 0) {
            HStack(spacing: 12) {
                Label("Duration", systemImage: "hourglass.tophalf.fill")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                HStack(spacing: 16) {
                    Button {
                        if entry.durationSeconds - 5 >= 5 { entry.durationSeconds -= 5 }
                    } label: {
                        Image(systemName: "minus.circle.fill")
                            .font(.caption)
                            .foregroundStyle(entry.durationSeconds <= 5 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.durationSeconds <= 5)

                    Text(entry.durationSeconds.durationLabel)
                        .font(.caption.weight(.semibold).monospacedDigit())
                        .frame(minWidth: 48)
                        .multilineTextAlignment(.center)

                    Button {
                        if entry.durationSeconds + 5 <= 600 { entry.durationSeconds += 5 }
                    } label: {
                        Image(systemName: "plus.circle.fill")
                            .font(.caption)
                            .foregroundStyle(entry.durationSeconds >= 600 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
                    }
                    .buttonStyle(.plain)
                    .disabled(entry.durationSeconds >= 600)
                }
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            Divider()

            HStack(spacing: 12) {
                Label("Rest Between Sets", systemImage: "timer")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                Spacer()

                Menu {
                    ForEach(restPresets, id: \.self) { seconds in
                        Button(action: { entry.restSeconds = seconds }) {
                            HStack {
                                Text(restLabel(seconds))
                                if entry.restSeconds == seconds {
                                    Image(systemName: "checkmark")
                                }
                            }
                        }
                    }
                } label: {
                    HStack(spacing: 4) {
                        Image(systemName: "timer")
                            .font(.caption2)
                        Text(restLabel(entry.restSeconds))
                            .font(.caption2.weight(.semibold))
                    }
                    .foregroundStyle(.orange)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.orange.opacity(0.15))
                    .cornerRadius(8)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)
        }
    }

    // MARK: - Helpers

    private func setBinding(_ i: Int) -> Binding<SetDetail> {
        Binding(
            get: {
                if let details = entry.setDetails, details.indices.contains(i) { return details[i] }
                return SetDetail(weightKg: entry.weightKg, reps: entry.reps, restSeconds: nil)
            },
            set: { newValue in
                var details = entry.setDetails ?? entry.resolvedSetDetails
                // pad/trim to `sets` so the index is always valid
                while details.count < entry.sets {
                    details.append(details.last ?? SetDetail(weightKg: entry.weightKg, reps: entry.reps))
                }
                if details.count > entry.sets { details = Array(details.prefix(entry.sets)) }
                guard details.indices.contains(i) else { return }
                details[i] = newValue
                var updated = entry
                updated.setDetails = details
                updated.weightKg = details.compactMap(\.weightKg).filter { $0 > 0 }.max() ?? updated.weightKg
                entry = updated
            }
        )
    }

    private func restLabel(_ seconds: Int) -> String {
        if seconds == 0 { return "None" }
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
}

#if DEBUG
#Preview("Reps Mode") {
    @Previewable @State var entry = ManualExerciseEntry(
        name: "Barbell Bench Press",
        sets: 4,
        reps: 8,
        durationSeconds: 0,
        inputType: .reps,
        weightKg: 135,
        restSeconds: 90,
        notes: "Full range of motion"
    )

    VStack {
        InlineSetEditor(entry: $entry)
            .glassEffect(in: .rect(cornerRadius: 20))
        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}

#Preview("Duration Mode") {
    @Previewable @State var entry = ManualExerciseEntry(
        name: "Plank",
        sets: 3,
        reps: 0,
        durationSeconds: 45,
        inputType: .duration,
        weightKg: nil,
        restSeconds: 60,
        notes: "Keep core tight"
    )

    VStack {
        InlineSetEditor(entry: $entry)
            .glassEffect(in: .rect(cornerRadius: 20))
        Spacer()
    }
    .padding()
    .preferredColorScheme(.dark)
}
#endif
