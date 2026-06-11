import SwiftUI

struct ManualWorkoutBuilder: View {
    let onSave: (SavedWorkout) -> Void

    @State private var title = ""
    @State private var focus = ""
    @State private var effort: Double = 6
    @State private var exercises: [ManualExerciseEntry] = []
    @State private var showingPicker = false
    @State private var editingExercise: ManualExerciseEntry?

    private var estimatedDuration: Int {
        let total = exercises.reduce(0) { acc, ex in
            let setTime = ex.inputType == .duration ? ex.durationSeconds : ex.reps * 3
            let restTime = ex.restSeconds * max(ex.sets - 1, 0)
            return acc + (setTime * ex.sets) + restTime
        }
        return total / 60 + 5
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                metadataSection
                exerciseListSection
                if !exercises.isEmpty {
                    statsRow
                }
                if !title.isEmpty && !exercises.isEmpty {
                    saveButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { selected in
                exercises.append(selected)
                showingPicker = false
            }
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEntryEditor(entry: exercise) { updated in
                if let idx = exercises.firstIndex(where: { $0.id == updated.id }) {
                    exercises[idx] = updated
                }
                editingExercise = nil
            }
        }
    }

    // MARK: - Metadata
    private var metadataSection: some View {
        GlassCard(cornerRadius: 20) {
            VStack(spacing: 14) {
                TextField("Workout Title", text: $title)
                    .font(.title3.bold())

                Divider()

                TextField("Focus or goal (optional)", text: $focus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Label("Effort", systemImage: "flame")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(effort))/10")
                        .font(.subheadline.monospacedDigit())
                }

                Slider(value: $effort, in: 1...10, step: 1)
                    .tint(.orange)
            }
        }
    }

    // MARK: - Exercise List
    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercises")
                    .font(.title3.bold())
                Spacer()
                Button {
                    showingPicker = true
                } label: {
                    Label("Add", systemImage: "plus.circle.fill")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.plain)
                .foregroundStyle(.cyan)
            }

            if exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No exercises yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button { showingPicker = true } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassEffect(in: .rect(cornerRadius: 20))
            } else {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, exercise in
                    exerciseRow(exercise, index: idx)
                }
            }
        }
    }

    private func exerciseRow(_ exercise: ManualExerciseEntry, index: Int) -> some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 6) {
                    Text(exercise.displaySetsReps)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if exercise.weightKg ?? 0 > 0 {
                        Text("·").foregroundStyle(.tertiary)
                        Text(exercise.displayWeight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            Spacer()

            Button { editingExercise = exercise } label: {
                Image(systemName: "pencil.circle")
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)

            Button {
                withAnimation(.spring(duration: 0.3)) {
                    exercises.removeAll { $0.id == exercise.id }
                }
            } label: {
                Image(systemName: "xmark.circle.fill")
                    .foregroundStyle(.red.opacity(0.7))
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "Exercises", value: "\(exercises.count)", icon: "dumbbell")
            Divider().frame(height: 40)
            statCell(label: "Est. Time", value: "\(estimatedDuration)m", icon: "clock")
            Divider().frame(height: 40)
            statCell(label: "Effort", value: "\(Int(effort))/10", icon: "flame")
        }
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 18))
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            let workout = SavedWorkout(
                title: title,
                focus: focus.isEmpty ? "Custom workout" : focus,
                source: .manual,
                aiPlan: nil,
                exercises: exercises,
                durationMinutes: estimatedDuration,
                effort: Int(effort)
            )
            onSave(workout)
        } label: {
            Label("Save Workout", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
    }
}

// MARK: - Exercise Entry Editor
struct ExerciseEntryEditor: View {
    @State var entry: ManualExerciseEntry
    let onDone: (ManualExerciseEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            Form {
                Section("Sets & Reps") {
                    Picker("Type", selection: $entry.inputType) {
                        ForEach(ExerciseInputType.allCases, id: \.self) { type in
                            Text(type.rawValue).tag(type)
                        }
                    }
                    .pickerStyle(.segmented)

                    Stepper("Sets: \(entry.sets)", value: $entry.sets, in: 1...20)

                    if entry.inputType == .reps {
                        Stepper("Reps: \(entry.reps)", value: $entry.reps, in: 1...100)
                    } else {
                        Stepper("Duration: \(entry.durationSeconds)s", value: $entry.durationSeconds, in: 5...600, step: 5)
                    }
                }

                Section("Weight") {
                    HStack {
                        Text("Weight (kg)")
                        Spacer()
                        TextField("0", value: $entry.weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                    }
                }

                Section("Rest") {
                    Stepper("Rest: \(entry.restSeconds)s", value: $entry.restSeconds, in: 0...300, step: 15)
                }

                Section("Notes") {
                    TextField("Optional cue or note", text: $entry.notes)
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
}
