import SwiftUI

struct WorkoutDetailView: View {
    let workout: SavedWorkout
    let onStartWorkout: (ActiveWorkoutSession) -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    headerCard
                    exercisesSection
                    startButton
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle(workout.title)
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Done") { dismiss() }
                        .buttonStyle(.plain)
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button(role: .destructive) { showingDeleteConfirm = true } label: {
                        Image(systemName: "trash")
                            .foregroundStyle(.red.opacity(0.8))
                    }
                    .buttonStyle(.plain)
                }
            }
            .confirmationDialog("Delete Workout?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    WorkoutStorageService.shared.delete(workout)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
        }
    }

    private var headerCard: some View {
        GlassCard(tint: workout.source == .ai ? .purple.opacity(0.18) : .orange.opacity(0.18), cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Label(workout.source.rawValue, systemImage: workout.source == .ai ? "sparkles" : "list.bullet.clipboard.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 10)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(workout.source == .ai ? .purple.opacity(0.3) : .orange.opacity(0.3)), in: .capsule)
                    Spacer()
                    Text(workout.createdAt, style: .date)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(workout.focus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                HStack(spacing: 24) {
                    metaStat(label: "Duration", value: "\(workout.durationMinutes)m", icon: "clock")
                    metaStat(label: "Exercises", value: "\(workout.exercises.count)", icon: "dumbbell")
                    metaStat(label: "Effort", value: "\(workout.effort)/10", icon: "flame")
                }
            }
        }
    }

    private func metaStat(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.headline.monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
    }

    private var exercisesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exercises")
                .font(.title3.bold())

            ForEach(Array(workout.exercises.enumerated()), id: \.element.id) { idx, exercise in
                exerciseRow(exercise, index: idx)
            }
        }
    }

    private func exerciseRow(_ exercise: ManualExerciseEntry, index: Int) -> some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 36, height: 36)
                Text("\(index + 1)")
                    .font(.caption2.bold())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                HStack(spacing: 8) {
                    Text(exercise.displaySetsReps)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if exercise.weightKg ?? 0 > 0 {
                        Text("·")
                            .foregroundStyle(.tertiary)
                        Text(exercise.displayWeight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text("Rest \(exercise.restSeconds)s")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }
            Spacer()
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }

    private var startButton: some View {
        Button {
            let session = ActiveWorkoutSession(workout: workout)
            dismiss()
            onStartWorkout(session)
        } label: {
            Label("Start Workout", systemImage: "play.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
    }
}
