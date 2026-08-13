import SwiftUI

struct ExerciseEntryEditor: View {
    @State var entry: ManualExerciseEntry
    let onDone: (ManualExerciseEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    private let restPresets = [0, 30, 45, 60, 75, 90, 120, 150, 180]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 14) {
                    // Input type picker
                    GlassCard(cornerRadius: 20) {
                        Picker("Type", selection: $entry.inputType) {
                            ForEach(ExerciseInputType.allCases, id: \.self) { type in
                                Text(type.rawValue).tag(type)
                            }
                        }
                        .pickerStyle(.segmented)
                    }

                    // Sets counter
                    GlassCard(cornerRadius: 20) {
                        counterRow(
                            label: "Sets",
                            value: $entry.sets,
                            range: 1...20,
                            step: 1,
                            color: .cyan
                        )
                    }

                    // Rest time
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Rest Between Sets", systemImage: "timer")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                                ForEach(restPresets, id: \.self) { seconds in
                                    let isSelected = entry.restSeconds == seconds
                                    Button {
                                        entry.restSeconds = seconds
                                    } label: {
                                        Text(restLabel(seconds))
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .glassEffect(.regular.tint(isSelected ? .orange.opacity(0.35) : .white.opacity(0.06)), in: .rect(cornerRadius: 12))
                                            .foregroundStyle(isSelected ? .orange : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Per-set editing or duration
                    if entry.inputType == .reps {
                        GlassCard(cornerRadius: 20) {
                            VStack(alignment: .leading, spacing: 14) {
                                Label("Set Targets", systemImage: "slider.horizontal.3")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)

                                ForEach(0..<entry.sets, id: \.self) { i in
                                    HStack(spacing: 12) {
                                        Text("Set \(i + 1)")
                                            .font(.subheadline.weight(.semibold))
                                            .foregroundStyle(.secondary)
                                            .frame(width: 52, alignment: .leading)
                                        Spacer()
                                        HStack(spacing: 4) {
                                            TextField("0", value: setBinding(i).weightKg, format: .number)
                                                .keyboardType(.decimalPad)
                                                .multilineTextAlignment(.trailing)
                                                .font(.subheadline.bold().monospacedDigit())
                                                .frame(width: 35)
                                            Text("lb")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                        }
                                        .padding(.horizontal, 10)
                                        .padding(.vertical, 6)
                                        .overlay {
                                            RoundedRectangle(cornerRadius: 8)
                                                .strokeBorder(Color.black.opacity(0.5), lineWidth: 1)
                                        }
                                        Spacer()

                                        HStack(spacing: 16) {
                                            Button { adjustSetReps(i, -1) } label: {
                                                Image(systemName: "minus.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(setReps(i) <= 1 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.gray))
                                            }
                                            .buttonStyle(.plain)
                                            .disabled(setReps(i) <= 1)

                                            Text("\(setReps(i)) reps")
                                                .font(.subheadline.bold().monospacedDigit())
                                                .frame(minWidth: 54)
                                                .multilineTextAlignment(.center)

                                            Button { adjustSetReps(i, 1) } label: {
                                                Image(systemName: "plus.circle.fill")
                                                    .font(.title3)
                                                    .foregroundStyle(Color.gray)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                }
                            }
                        }
                    } else {
                        GlassCard(cornerRadius: 20) {
                            HStack {
                                Text("Duration")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 72, alignment: .leading)

                                Spacer()

                                HStack(spacing: 24) {
                                    Button {
                                        if entry.durationSeconds - 5 >= 5 { entry.durationSeconds -= 5 }
                                    } label: {
                                        Image(systemName: "minus.circle.fill")
                                            .font(.title)
                                            .foregroundStyle(entry.durationSeconds <= 5 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(entry.durationSeconds <= 5)

                                    Text(entry.durationSeconds.durationLabel)
                                        .font(.title2.bold().monospacedDigit())
                                        .frame(minWidth: 56)
                                        .multilineTextAlignment(.center)

                                    Button {
                                        if entry.durationSeconds + 5 <= 600 { entry.durationSeconds += 5 }
                                    } label: {
                                        Image(systemName: "plus.circle.fill")
                                            .font(.title)
                                            .foregroundStyle(entry.durationSeconds >= 600 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.orange))
                                    }
                                    .buttonStyle(.plain)
                                    .disabled(entry.durationSeconds >= 600)
                                }
                            }
                        }
                    }

                    // Weight (for duration mode)
                    if entry.inputType == .duration {
                        GlassCard(cornerRadius: 20) {
                            HStack {
                                Label("Weight", systemImage: "scalemass")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("0", value: $entry.weightKg, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.title3.bold().monospacedDigit())
                                    .frame(width: 72)
                                Text("lbs")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Notes
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "text.bubble")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Optional cue or note…", text: $entry.notes, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(2...4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .onAppear {
                if entry.inputType == .reps, entry.setDetails == nil {
                    entry.setDetails = entry.resolvedSetDetails
                }
            }
            .onChange(of: entry.sets) { resizeSetDetails() }
            .onChange(of: entry.inputType) { _, type in
                if type == .reps {
                    if entry.setDetails == nil { entry.setDetails = entry.resolvedSetDetails }
                } else {
                    entry.setDetails = nil
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone(entry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func counterRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            Spacer()

            HStack(spacing: 24) {
                Button {
                    if value.wrappedValue - step >= range.lowerBound {
                        value.wrappedValue -= step
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(value.wrappedValue <= range.lowerBound ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)")
                    .font(.title2.bold().monospacedDigit())
                    .frame(minWidth: 44)
                    .multilineTextAlignment(.center)

                Button {
                    if value.wrappedValue + step <= range.upperBound {
                        value.wrappedValue += step
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(value.wrappedValue >= range.upperBound ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    private func setReps(_ i: Int) -> Int {
        if let details = entry.setDetails, details.indices.contains(i) { return details[i].reps }
        return entry.reps
    }

    private func setBinding(_ i: Int) -> Binding<SetDetail> {
        Binding(
            get: {
                if let details = entry.setDetails, details.indices.contains(i) { return details[i] }
                return SetDetail(weightKg: entry.weightKg, reps: entry.reps)
            },
            set: { newValue in
                var details = normalizedSetDetails()
                guard details.indices.contains(i) else { return }
                details[i] = newValue
                var updated = entry
                updated.setDetails = details
                entry = updated
            }
        )
    }

    private func adjustSetReps(_ i: Int, _ delta: Int) {
        var details = normalizedSetDetails()
        guard details.indices.contains(i) else { return }
        details[i].reps = max(1, details[i].reps + delta)
        var updated = entry
        updated.setDetails = details
        entry = updated
    }

    /// Set details padded/trimmed to `entry.sets` so any set index is valid.
    private func normalizedSetDetails() -> [SetDetail] {
        var details = entry.setDetails ?? entry.resolvedSetDetails
        while details.count < entry.sets {
            details.append(details.last ?? SetDetail(weightKg: entry.weightKg, reps: entry.reps))
        }
        if details.count > entry.sets { details = Array(details.prefix(entry.sets)) }
        return details
    }

    private func resizeSetDetails() {
        guard entry.inputType == .reps else { return }
        var details = entry.setDetails ?? entry.resolvedSetDetails
        if details.count < entry.sets {
            let pad = details.last ?? SetDetail(weightKg: entry.weightKg, reps: entry.reps)
            details.append(contentsOf: Array(repeating: pad, count: entry.sets - details.count))
        } else if details.count > entry.sets {
            details = Array(details.prefix(entry.sets))
        }
        entry.setDetails = details
    }

    private func restLabel(_ seconds: Int) -> String {
        if seconds == 0 { return "None" }
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }
}
