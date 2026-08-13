import SwiftUI

struct WorkoutPhaseView: View {
    let role: ExerciseRole
    @Bindable var session: ActiveWorkoutSession
    let onFinish: () -> Void

    var phaseTitle: String {
        role == .warmup ? "Warm-Up" : "Cool-Down"
    }

    var phaseGuidance: String {
        role == .warmup ? "Move through these to raise your heart rate." : "Ease down and stretch out."
    }

    var phaseTint: Color {
        role == .warmup ? .orange : .blue
    }

    var phaseButtonLabel: String {
        role == .warmup ? "Start Workout" : "Finish"
    }

    var phaseSkipLabel: String {
        role == .warmup ? "Skip Warmup" : "Skip Cooldown"
    }

    var body: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            LinearGradient(
                colors: [
                    phaseTint.opacity(0.12),
                    phaseTint.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 40)

                VStack(spacing: 32) {
                    Text(phaseTitle)
                        .font(.system(size: 36, weight: .bold))
                        .foregroundStyle(.primary)
                    Spacer()
                    phaseTimer

                    exercisesList
                    Spacer()
                }
                .padding(.horizontal, 20)

            }
        }
        .safeAreaInset(edge: .bottom) {
            actionBar
                .padding(.bottom, 25)
        }
    }

    var actionBar: some View {
        Button {
            onFinish()
        } label: {
            Text(phaseSkipLabel)
                .font(.headline)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
                .frame(maxWidth: .infinity)
                .padding(.vertical, 14)
        }
        .buttonStyle(.glassProminent)
        .padding(.horizontal, 30)
        .tint(phaseTint)
    }

    var phaseTimer: some View {
        let totalSeconds = session.phaseTotalSeconds
        let progress = totalSeconds > 0 ? Double(totalSeconds - session.phaseSecondsRemaining) / Double(totalSeconds) : 0

        return MetricRing(
            progress: progress,
            lineWidth: 12,
            gradient: LinearGradient(colors: [phaseTint, phaseTint.opacity(0.6)], startPoint: .topLeading, endPoint: .bottomTrailing),
            size: 180
        ) {
            VStack(spacing: 8) {
                Text(timeFormatted(session.phaseSecondsRemaining))
                    .font(.system(size: 44, weight: .bold, design: .default).monospacedDigit())
                    .foregroundStyle(phaseTint)

                Text("Remaining")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
        }
    }

    var exercisesList: some View {
        let exercises = session.phaseExercises(for: role)
        let durationsSum = exercises.reduce(0) { $0 + $1.durationSeconds }
        let elapsed = session.phaseTotalSeconds - session.phaseSecondsRemaining

        // Mark each exercise done once the countdown has passed its cumulative window.
        var cumulative = 0
        let items: [(exercise: ManualExerciseEntry, isDone: Bool)] = exercises.map { ex in
            cumulative += ex.durationSeconds
            let done = durationsSum > 0 && elapsed >= cumulative
            return (ex, done)
        }

        return ScrollView {
            VStack(spacing: 8) {
                ForEach(items, id: \.exercise.id) { item in
                    let tint = item.isDone ? Color.green : phaseTint
                    GlassCard(tint: tint.opacity(0.2)) {
                        HStack(spacing: 12) {
                            if item.isDone {
                                Image(systemName: "checkmark.circle.fill")
                                    .font(.subheadline)
                                    .foregroundStyle(.green)
                            }

                            Text(item.exercise.name)
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)

                            Spacer()

                            VStack(alignment: .trailing, spacing: 4) {
                                if item.exercise.inputType == .duration {
                                    Text(timeFormatted(item.exercise.durationSeconds))
                                        .font(.caption.weight(.semibold).monospacedDigit())
                                        .foregroundStyle(tint)
                                }
                            }
                        }
                    }
                    .animation(.spring(duration: 0.3), value: item.isDone)
                }
            }
            .padding(.vertical, 4)
        }
        .scrollIndicators(.hidden)
    }

    func timeFormatted(_ seconds: Int) -> String {
        let mins = seconds / 60
        let secs = seconds % 60
        return String(format: "%d:%02d", mins, secs)
    }
}

#Preview {
    // Warm-up exercises MUST be tagged `.warmup` so `phaseExercises(for:)` returns them
    // (otherwise it falls back to library exercises and the ring total won't match the cards).
    let workout = SavedWorkout(
        title: "Warm-Up Preview",
        focus: "Full Body",
        source: .manual,
        exercises: [
            ManualExerciseEntry(role: .warmup, name: "Arm Circles", sets: 1, reps: 0, durationSeconds: 45, inputType: .duration, restSeconds: 0, notes: ""),
            ManualExerciseEntry(role: .warmup, name: "Leg Swings", sets: 1, reps: 0, durationSeconds: 60, inputType: .duration, restSeconds: 0, notes: ""),
            ManualExerciseEntry(role: .warmup, name: "Bodyweight Squats", sets: 1, reps: 0, durationSeconds: 45, inputType: .duration, restSeconds: 0, notes: "")
        ],
        durationMinutes: 5,
        effort: 3
    )
    let session = ActiveWorkoutSession(workout: workout)
    session.phase = .warmup
    // Derive the total exactly like the live app does: the sum of the phase exercises' durations.
    let total = session.phaseDurationSeconds(for: .warmup, fallbackMinutes: 5) // 45 + 60 + 45 = 150
    session.phaseTotalSeconds = total
    session.phaseSecondsRemaining = total - 60 // 60s elapsed → first card (0:45) is green, ring ~40% filled

    return WorkoutPhaseView(role: .warmup, session: session) {}
}
