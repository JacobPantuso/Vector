import SwiftUI
import Combine

struct ActiveWorkoutSession: Identifiable, Sendable {
    let id = UUID()
    let workout: SavedWorkout
    var currentExerciseIndex: Int = 0
    var currentSetIndex: Int = 0
    var restSecondsRemaining: Int = 0
    var isResting: Bool = false
    var startedAt: Date = Date()

    var currentExercise: ManualExerciseEntry? {
        guard workout.exercises.indices.contains(currentExerciseIndex) else { return nil }
        return workout.exercises[currentExerciseIndex]
    }

    var totalSets: Int { currentExercise?.sets ?? 0 }
    var isFinished: Bool { currentExerciseIndex >= workout.exercises.count }

    var nextExercise: ManualExerciseEntry? {
        let next = currentExerciseIndex + 1
        guard workout.exercises.indices.contains(next) else { return nil }
        return workout.exercises[next]
    }
}

struct ActiveWorkoutView: View {
    @State private var session: ActiveWorkoutSession
    let onFinish: () -> Void

    @State private var elapsedSeconds: Int = 0
    @State private var showingFinishConfirm = false

    init(session: ActiveWorkoutSession, onFinish: @escaping () -> Void) {
        _session = State(initialValue: session)
        self.onFinish = onFinish
    }

    var body: some View {
        ZStack {
            LinearGradient(
                colors: [Color.black, Color(.systemBackground).opacity(0.7)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                topBar
                    .padding(.horizontal, 20)
                    .padding(.top, 8)

                if session.isFinished {
                    completionView
                } else {
                    ScrollView {
                        VStack(spacing: 20) {
                            currentExerciseCard
                            if session.isResting {
                                restTimerCard
                            }
                            setProgressRow
                            if let next = session.nextExercise {
                                nextExercisePreview(next)
                            }
                            exerciseQueueList
                        }
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                        .padding(.bottom, 30)
                    }
                }
            }
        }
        .task { await runTimer() }
        .confirmationDialog("End Workout?", isPresented: $showingFinishConfirm) {
            Button("End Workout", role: .destructive) { onFinish() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Top Bar
    private var topBar: some View {
        HStack {
            VStack(alignment: .leading, spacing: 2) {
                Text("Elapsed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(elapsedFormatted)
                    .font(.title3.bold().monospacedDigit())
            }
            Spacer()
            Text(session.workout.title)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .lineLimit(1)
            Spacer()
            Button {
                showingFinishConfirm = true
            } label: {
                Text("Finish")
                    .font(.subheadline.weight(.semibold))
                    .padding(.horizontal, 14)
                    .padding(.vertical, 6)
                    .glassEffect(.regular.tint(.red.opacity(0.25)), in: .capsule)
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Current Exercise Card
    private var currentExerciseCard: some View {
        GlassCard(tint: .cyan.opacity(0.15), cornerRadius: 28) {
            VStack(alignment: .leading, spacing: 16) {
                Text("Exercise \(session.currentExerciseIndex + 1) of \(session.workout.exercises.count)")
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if let exercise = session.currentExercise {
                    Text(exercise.name)
                        .font(.title.bold())

                    HStack(spacing: 12) {
                        statPill(label: exercise.displaySetsReps, icon: "arrow.2.squarepath")
                        statPill(label: exercise.displayWeight, icon: "scalemass")
                        statPill(label: "\(exercise.restSeconds)s rest", icon: "timer")
                    }

                    Button {
                        completeSet()
                    } label: {
                        Label("Complete Set \(session.currentSetIndex + 1)", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 4)
                }
            }
        }
    }

    // MARK: - Rest Timer Card
    private var restTimerCard: some View {
        GlassCard(tint: .orange.opacity(0.2), cornerRadius: 24) {
            HStack(spacing: 20) {
                ZStack {
                    Circle()
                        .stroke(.orange.opacity(0.25), lineWidth: 4)
                    Circle()
                        .trim(from: 0, to: restProgress)
                        .stroke(.orange, style: StrokeStyle(lineWidth: 4, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: restProgress)
                }
                .frame(width: 60, height: 60)
                .overlay {
                    Text("\(session.restSecondsRemaining)")
                        .font(.title3.bold().monospacedDigit())
                        .foregroundStyle(.orange)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Rest Time")
                        .font(.headline)
                    Text("Next set in \(session.restSecondsRemaining)s")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Button { skipRest() } label: {
                    Text("Skip")
                        .font(.subheadline.weight(.semibold))
                }
                .buttonStyle(.glass)
            }
        }
    }

    private var restProgress: Double {
        guard let exercise = session.currentExercise, exercise.restSeconds > 0 else { return 0 }
        return Double(exercise.restSeconds - session.restSecondsRemaining) / Double(exercise.restSeconds)
    }

    // MARK: - Set Progress
    private var setProgressRow: some View {
        HStack(spacing: 8) {
            ForEach(0..<(session.currentExercise?.sets ?? 0), id: \.self) { setIdx in
                RoundedRectangle(cornerRadius: 4)
                    .fill(setIdx < session.currentSetIndex
                          ? Color.green
                          : (setIdx == session.currentSetIndex ? Color.cyan : Color.white.opacity(0.2)))
                    .frame(height: 6)
                    .animation(.spring(duration: 0.3), value: session.currentSetIndex)
            }
        }
        .padding(.horizontal, 4)
    }

    // MARK: - Next Exercise Preview
    private func nextExercisePreview(_ exercise: ManualExerciseEntry) -> some View {
        HStack(spacing: 12) {
            Image(systemName: "arrow.right.circle")
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 2) {
                Text("Up Next")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            Spacer()
            Text(exercise.displaySetsReps)
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    // MARK: - Exercise Queue
    private var exerciseQueueList: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Workout Plan")
                .font(.subheadline.bold())
            ForEach(Array(session.workout.exercises.enumerated()), id: \.element.id) { idx, exercise in
                HStack(spacing: 12) {
                    ZStack {
                        Circle()
                            .fill(idx < session.currentExerciseIndex
                                  ? Color.green.opacity(0.4)
                                  : (idx == session.currentExerciseIndex ? Color.cyan.opacity(0.4) : Color.white.opacity(0.1)))
                            .frame(width: 28, height: 28)
                        if idx < session.currentExerciseIndex {
                            Image(systemName: "checkmark")
                                .font(.caption.bold())
                                .foregroundStyle(.green)
                        } else {
                            Text("\(idx + 1)")
                                .font(.caption.bold())
                                .foregroundStyle(idx == session.currentExerciseIndex ? .cyan : .secondary)
                        }
                    }
                    Text(exercise.name)
                        .font(.subheadline)
                        .foregroundStyle(idx == session.currentExerciseIndex ? .primary : .secondary)
                    Spacer()
                    Text(exercise.displaySetsReps)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                .opacity(idx < session.currentExerciseIndex ? 0.5 : 1)
            }
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: - Completion View
    private var completionView: some View {
        VStack(spacing: 28) {
            Spacer()

            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 80))
                .foregroundStyle(.green.gradient)

            VStack(spacing: 8) {
                Text("Workout Complete!")
                    .font(.largeTitle.bold())
                Text(session.workout.title)
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }

            HStack(spacing: 30) {
                completionStat(label: "Time", value: elapsedFormatted, icon: "clock")
                completionStat(label: "Exercises", value: "\(session.workout.exercises.count)", icon: "dumbbell")
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 20))

            Button { onFinish() } label: {
                Label("Done", systemImage: "checkmark")
                    .frame(maxWidth: .infinity)
            }
            .buttonStyle(.glassProminent)
            .padding(.horizontal, 40)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    private func completionStat(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 6) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.title2.bold().monospacedDigit())
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }

    private func statPill(label: String, icon: String) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption2)
            Text(label)
                .font(.caption.weight(.medium))
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(.white.opacity(0.08)), in: .capsule)
    }

    // MARK: - Timer
    private func runTimer() async {
        for await _ in Timer.publish(every: 1, on: .main, in: .common).autoconnect().values {
            elapsedSeconds += 1
            if session.isResting && session.restSecondsRemaining > 0 {
                session.restSecondsRemaining -= 1
                if session.restSecondsRemaining == 0 {
                    withAnimation(.spring(duration: 0.3)) { session.isResting = false }
                }
            }
        }
    }

    private var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Actions
    private func completeSet() {
        guard let exercise = session.currentExercise else { return }
        let isLastSet = session.currentSetIndex >= exercise.sets - 1

        withAnimation(.spring(duration: 0.3)) {
            if isLastSet {
                session.currentExerciseIndex += 1
                session.currentSetIndex = 0
                session.isResting = false
                session.restSecondsRemaining = 0
            } else {
                session.currentSetIndex += 1
                session.restSecondsRemaining = exercise.restSeconds
                session.isResting = exercise.restSeconds > 0
            }
        }
    }

    private func skipRest() {
        withAnimation(.spring(duration: 0.2)) {
            session.restSecondsRemaining = 0
            session.isResting = false
        }
    }
}
