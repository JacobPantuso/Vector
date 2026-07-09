import SwiftUI
import HealthKit

// MARK: - Unified History Item

/// A history entry that is either a synced HealthKit workout or a Vector workout
/// that was just finished and is still being written to HealthKit ("processing").
struct WorkoutHistoryItem: Identifiable {
    let id: String
    let date: Date
    let hkWorkout: HKWorkout?
    let record: WorkoutCompletionRecord?

    var isProcessing: Bool { hkWorkout == nil }

    /// Merge synced HealthKit workouts with recent local records that HealthKit
    /// has not confirmed yet (shown as "Processing").
    static func merged(workouts: [HKWorkout], store: WorkoutCompletionStore = .shared) -> [WorkoutHistoryItem] {
        var items = workouts.map { wk in
            WorkoutHistoryItem(id: wk.uuid.uuidString, date: wk.startDate, hkWorkout: wk, record: store.record(matching: wk))
        }
        for rec in store.unsyncedRecords(notMatching: workouts) {
            items.append(WorkoutHistoryItem(id: rec.id.uuidString, date: rec.date, hkWorkout: nil, record: rec))
        }
        return items.sorted { $0.date > $1.date }
    }
}

// MARK: - Stat Formatting

enum WorkoutStatFormat {
    /// Total training volume as a short string, e.g. "12.4k lbs" or "840 lbs".
    static func volume(_ value: Double) -> String {
        guard value > 0 else { return "—" }
        if value >= 1000 { return String(format: "%.1fk lbs", value / 1000) }
        return String(format: "%.0f lbs", value)
    }
}

// MARK: - Performed Exercises Section

/// Lists the exercises performed in a strength workout with per-set weight/reps.
struct PerformedExercisesSection: View {
    let exercises: [ManualExerciseEntry]

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.headline)
                .frame(maxWidth: .infinity, alignment: .leading)

            VStack(spacing: 10) {
                ForEach(exercises) { exercise in
                    PerformedExerciseRow(exercise: exercise)
                }
            }
        }
    }
}

private struct PerformedExerciseRow: View {
    let exercise: ManualExerciseEntry

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Image(systemName: exercise.displayWeight == "BW" ? "figure.strengthtraining.traditional" : "dumbbell.fill")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
                Text(exercise.displaySetsReps)
                    .font(.caption.monospacedDigit())
                    .foregroundStyle(.secondary)
            }

            if exercise.inputType == .reps {
                PerSetBreakdownView(exercise: exercise)
            }
        }
        .padding(14)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Per-Set Breakdown

/// Row-by-row per-set breakdown ("Set N — weight × reps"), shown under each exercise, one row per set. Matches the workout History detail style.
struct PerSetBreakdownView: View {
    private let sets: [SetDetail]

    init(exercise: ManualExerciseEntry) {
        self.sets = exercise.resolvedSetDetails
    }

    init(sets: [SetDetail]) {
        self.sets = sets
    }

    var body: some View {
        VStack(spacing: 4) {
            ForEach(Array(sets.enumerated()), id: \.offset) { index, set in
                HStack {
                    Text("Set \(index + 1)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Spacer()
                    Text(Self.setLabel(set))
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    static func setLabel(_ set: SetDetail) -> String {
        if let w = set.weightKg, w > 0 {
            return String(format: "%.0f lbs × %d", w, set.reps)
        }
        return "BW × \(set.reps)"
    }
}

// MARK: - Processing Workout Detail

/// Lightweight detail shown for a just-finished workout that HealthKit has not
/// confirmed yet. Shows the logged exercises and a syncing note.
struct ProcessingWorkoutDetailView: View {
    let record: WorkoutCompletionRecord
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell.fill")
                        .font(.system(size: 44))
                        .foregroundStyle(.red)
                    Text(record.title ?? "Workout")
                        .font(.system(size: 26, weight: .bold, design: .rounded))
                    Text(record.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
                .padding(.top, 12)

                HStack(spacing: 10) {
                    ProgressView()
                        .controlSize(.small)
                    Text("Syncing with Apple Health…")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
                .padding(14)
                .glassEffect(.regular.tint(.orange.opacity(0.12)), in: .rect(cornerRadius: 16))

                HStack(spacing: 12) {
                    miniStat(label: "Duration", value: "\(record.durationMinutes) min", icon: "clock.fill", color: .cyan)
                    miniStat(label: "Volume", value: WorkoutStatFormat.volume(record.totalVolume), icon: "scalemass.fill", color: .indigo)
                }

                if let exercises = record.performedExercises, !exercises.isEmpty {
                    PerformedExercisesSection(exercises: exercises)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 20)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button { dismiss() } label: {
                    Image(systemName: "multiply").font(.body.weight(.medium)).padding(8)
                }
            }
        }
    }

    @ViewBuilder
    private func miniStat(label: String, value: String, icon: String, color: Color) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon).font(.caption).foregroundStyle(color.opacity(0.8))
            Text(value).font(.system(size: 20, weight: .bold, design: .rounded)).monospacedDigit()
            Text(label).font(.caption).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Strength Exercise Editor Sheet

struct StrengthExerciseEditorView: View {
    let workout: HKWorkout
    let initial: [ManualExerciseEntry]
    let onSave: ([ManualExerciseEntry]) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var exercises: [ManualExerciseEntry]
    @State private var showingExercisePicker = false
    @State private var showingTemplatePicker = false
    @State private var editingExercise: ManualExerciseEntry?

    init(workout: HKWorkout, initial: [ManualExerciseEntry], onSave: @escaping ([ManualExerciseEntry]) -> Void) {
        self.workout = workout
        self.initial = initial
        self.onSave = onSave
        _exercises = State(initialValue: initial)
    }

    var body: some View {
        NavigationStack {
            Group {
                if exercises.isEmpty {
                    emptyState
                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                        .padding(.horizontal, 20)
                } else {
                    ScrollView {
                        VStack(spacing: 14) {
                            ForEach(Array(exercises.enumerated()), id: \.element.id) { index, exercise in
                                exerciseCard(index: index, exercise: exercise)
                            }
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 8)
                        .padding(.bottom, 24)
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle("Edit Exercises")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        onSave(exercises)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
            }
            .safeAreaInset(edge: .bottom) {
                HStack(spacing: 12) {
                    Button {
                        showingExercisePicker = true
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glassProminent)

                    Button {
                        showingTemplatePicker = true
                    } label: {
                        Label("Template", systemImage: "square.stack.3d.up")
                            .font(.subheadline.weight(.semibold))
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                    }
                    .buttonStyle(.glass)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
            .sheet(isPresented: $showingExercisePicker) {
                ExercisePickerView { new in
                    exercises.append(contentsOf: new)
                }
            }
            .sheet(isPresented: $showingTemplatePicker) {
                TemplatePickerView { templateExercises in
                    exercises.append(contentsOf: templateExercises)
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
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "dumbbell")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No exercises")
                .font(.subheadline.weight(.semibold))
            Text("Add exercises or select a template below.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    @ViewBuilder
    private func exerciseCard(index: Int, exercise: ManualExerciseEntry) -> some View {
        Button {
            editingExercise = exercise
        } label: {
            HStack(alignment: .top, spacing: 12) {
                ZStack {
                    Circle()
                        .fill(.ultraThinMaterial)
                        .frame(width: 32, height: 32)
                    Text("\(index + 1)")
                        .font(.caption.bold())
                        .foregroundStyle(.secondary)
                }

                VStack(alignment: .leading, spacing: 6) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .multilineTextAlignment(.leading)

                    Text(exercise.displaySetsReps)
                        .font(.caption.monospacedDigit())
                        .foregroundStyle(.secondary)

                    if exercise.inputType == .reps {
                        PerSetBreakdownView(exercise: exercise)
                            .padding(.top, 2)
                    }
                }

                Spacer(minLength: 4)

                Menu {
                    Button {
                        editingExercise = exercise
                    } label: {
                        Label("Edit", systemImage: "slider.horizontal.3")
                    }
                    Divider()
                    Button(role: .destructive) {
                        exercises.removeAll { $0.id == exercise.id }
                    } label: {
                        Label("Remove", systemImage: "trash")
                    }
                } label: {
                    Image(systemName: "ellipsis.circle")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(14)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Template Picker Sheet

struct TemplatePickerView: View {
    let onSelect: ([ManualExerciseEntry]) -> Void
    @Environment(\.dismiss) private var dismiss

    var savedWorkouts: [SavedWorkout] {
        WorkoutStorageService.shared.savedWorkouts
    }

    var body: some View {
        NavigationStack {
            if savedWorkouts.isEmpty {
                ContentUnavailableView(
                    label: {
                        Label("No Saved Workouts", systemImage: "square.stack.3d.up")
                    },
                    description: {
                        Text("Create and save a workout template to load it here.")
                    }
                )
                .navigationTitle("Load Template")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                }
            } else {
                List {
                    ForEach(savedWorkouts) { workout in
                        Button(action: {
                            selectTemplate(workout)
                        }) {
                            workoutRow(workout)
                        }
                    }
                }
                .listStyle(.plain)
                .navigationTitle("Load Template")
                .navigationBarTitleDisplayMode(.inline)
                .toolbar {
                    ToolbarItem(placement: .topBarLeading) {
                        Button("Cancel") { dismiss() }
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func workoutRow(_ workout: SavedWorkout) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                Text(workout.title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Spacer()
            }

            HStack(spacing: 12) {
                Text("\(workout.focus) · \(workout.exerciseCount) exercises")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if !workout.muscleGroupSummary.isEmpty {
                Text(workout.muscleGroupSummary)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
        }
        .padding(.vertical, 8)
    }

    private func selectTemplate(_ workout: SavedWorkout) {
        let remappedExercises = remapExerciseIDs(workout.exercises)
        onSelect(remappedExercises)
        dismiss()
    }

    /// Remap exercise and superset IDs to avoid collisions with existing entries.
    /// Each old supersetID maps to a new UUID, keeping grouped supersets together.
    private func remapExerciseIDs(_ templateExercises: [ManualExerciseEntry]) -> [ManualExerciseEntry] {
        var supersetIDMap: [UUID: UUID] = [:]
        var remappedExercises: [ManualExerciseEntry] = []

        for exercise in templateExercises {
            var newExercise = exercise
            newExercise.id = UUID()

            if let oldSupersetID = exercise.supersetID {
                if supersetIDMap[oldSupersetID] == nil {
                    supersetIDMap[oldSupersetID] = UUID()
                }
                newExercise.supersetID = supersetIDMap[oldSupersetID]
            }

            remappedExercises.append(newExercise)
        }

        return remappedExercises
    }
}
