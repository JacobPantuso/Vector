import SwiftUI
import WatchKit
import Combine

struct WatchWorkoutView: View {
    @Environment(WatchConnectivityService.self) private var connectivity
    @Environment(WatchHealthStore.self) private var healthStore
    @State private var pulse = false
    @State private var selectedPage = 0
    @State private var displayRest: Int = 0
    @State private var durationTimerActive = false
    @State private var durationRemaining = 0
    @State private var showSetConfirmation = false
    private let restTicker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    var body: some View {
        NavigationStack {
            Group {
                if let workout = connectivity.activeWorkout {
                    if workout.isFinished {
                        finishedView
                    } else if workout.isResting {
                        restView(workout: workout)
                    } else {
                        activePager(workout: workout)
                    }
                }
            }
            .overlay { pausedOverlay }
            .animation(.spring(duration: 0.3), value: connectivity.activeWorkout?.status)
            .toolbar(.hidden, for: .navigationBar)
            .interactiveDismissDisabled(true)
            .sheet(isPresented: $showSetConfirmation) {
                if let w = connectivity.activeWorkout {
                    SetConfirmationView(
                        exerciseName: w.exerciseName,
                        setIndex: w.setIndex,
                        totalSets: w.totalSets,
                        weight: w.currentWeight,
                        reps: w.currentReps
                    ) { weight, reps in
                        connectivity.sendCompleteSet(weight: weight, reps: reps)
                        showSetConfirmation = false
                    }
                }
            }
            .onAppear {
                pulse = true
                displayRest = connectivity.activeWorkout?.restSecondsRemaining ?? 0
            }
            .onChange(of: connectivity.activeWorkout?.restSecondsRemaining) { _, newValue in
                displayRest = newValue ?? 0
            }
            .onChange(of: connectivity.activeWorkout?.setIndex) { _, _ in
                durationTimerActive = false
                durationRemaining = 0
            }
            .onChange(of: connectivity.activeWorkout?.exerciseIndex) { _, _ in
                durationTimerActive = false
                durationRemaining = 0
            }
            .onReceive(restTicker) { _ in
                if let w = connectivity.activeWorkout, w.isResting, !w.isPaused, displayRest > 0 {
                    displayRest -= 1
                    if displayRest == 0 {
                        // Double haptic to signal the rest period is over
                        WKInterfaceDevice.current().play(.stop)
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.2) {
                            WKInterfaceDevice.current().play(.stop)
                        }
                    }
                }
                if durationTimerActive, (connectivity.activeWorkout?.isPaused ?? false) == false, durationRemaining > 0 {
                    durationRemaining -= 1
                    if durationRemaining == 0 {
                        WKInterfaceDevice.current().play(.stop)
                    } else if durationRemaining <= 5 {
                        WKInterfaceDevice.current().play(.click)
                    }
                }
            }
        }
    }

    // MARK: - Active Pager (Swipe-up exercise list)

    private func activePager(workout: WatchWorkoutState) -> some View {
        TabView(selection: $selectedPage) {
            workoutSettingsView(workout: workout)
                .tag(-1)
            activeView(workout: workout)
                .tag(0)

            exerciseListView(workout: workout)
                .tag(1)
        }
        .tabViewStyle(.verticalPage)
    }
    
    private func workoutSettingsView(workout: WatchWorkoutState) -> some View {
        VStack(spacing: 12) {
            Text(workout.title)
                .font(.system(size: 16, weight: .bold))
                .multilineTextAlignment(.center)
                .padding(.top, 20)
            Text("\(workout.formattedElapsed)")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Button {
                WKInterfaceDevice.current().play(.click)
                connectivity.sendPause()
            } label: {
                Label(connectivity.activeWorkout?.isPaused == true ? "Resume Workout" : "Pause Workout", systemImage: connectivity.activeWorkout?.isPaused == true ? "play.fill" : "pause.fill")
                    .font(.system(size: 14, weight: .semibold))
                    .frame(maxWidth: .infinity)
            }
            .glassEffect(.regular.tint(.orange.opacity(0.7)))
            .clipShape(Capsule())
            .handGestureShortcut(.primaryAction)
			Button(role: .destructive) {
				WKInterfaceDevice.current().play(.click)
				connectivity.exitActiveWorkout()
			} label: {
				Label("End Workout", systemImage: "xmark")
					.font(.system(size: 14, weight: .semibold))
					.frame(maxWidth: .infinity)
			}
			.glassEffect(.regular.tint(.red.opacity(0.7)))
			.clipShape(Capsule())
        }
        .padding()
        .containerBackground(Color.black.opacity(0.15).gradient, for: .navigation)
    }

    // MARK: - Active View (Hero heart-rate display)

    private func activeView(workout: WatchWorkoutState) -> some View {
        VStack(alignment: .leading, spacing: 0) {
            // Compact heart-rate + set-count row (top)
            VStack(alignment: .center, spacing: 6) {
                HStack {
                    Spacer()
                    Image(systemName: "heart.fill")
                        .font(.system(size: 13))
                        .foregroundStyle(phaseColor(workout))
                        .scaleEffect(pulse ? 1.15 : 0.95)
                        .animation(.easeInOut(duration: 0.9).repeatForever(autoreverses: true), value: pulse)
                    
                    let hrValue = healthStore.heartRate > 0 ? String(Int(healthStore.heartRate)) : "--"
                    Text(hrValue)
                        .font(.system(size: 20, weight: .bold, design: .rounded))
                        .foregroundStyle(phaseColor(workout))
                    
                    Text("BPM")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(.secondary)
                    Spacer()
                }
            }
            .padding(.horizontal)
            
            Spacer()
            VStack {
                VStack(alignment: .center) {
                    Text(workout.exerciseName)
                        .font(.system(size: 22, weight: .bold))
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                        .padding(.top, 8)
                    
                    // Set progress dots
                    HStack(spacing: 5) {
                        ForEach(0..<workout.totalSets, id: \.self) { i in
                            RoundedRectangle(cornerRadius: 3)
                                .fill(i < workout.setIndex ? Color.green : (i == workout.setIndex ? Color.cyan : Color.white.opacity(0.2)))
                                .frame(width: 15,height: 5)
                        }
                    }
                    .padding(.vertical, 8)
                    
                    // At-a-glance logged weight (just above the button)
                    HStack(spacing: 4) {
                        if workout.currentWeight > 0 {
                            Image(systemName: "dumbbell.fill")
                                .font(.system(size: 10))
                                .foregroundStyle(.secondary)
                            Text(String(format: "%.0f lb", workout.currentWeight))
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                            Text("× \(workout.currentReps)")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        } else {
                            Text("Bodyweight")
                                .font(.system(size: 14, weight: .semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.bottom, 6)

                }
            // Log Set button (bottom) or Duration Timer — bound to wrist Double Tap via primaryAction
                Spacer()
                if isDurationExercise(workout) {
                    if durationTimerActive {
                        // Active timer: show countdown + checkmark
                        HStack(spacing: 12) {
                            Spacer()
                            Text(formatDuration(durationRemaining))
                                .font(.system(size: 28, weight: .bold, design: .rounded))
                                .monospacedDigit()
                                .foregroundStyle(.white)

                            Spacer()

                            Button {
                                WKInterfaceDevice.current().play(.success)
                                durationTimerActive = false
                                connectivity.sendCompleteSet()
                            } label: {
                                Image(systemName: "checkmark")
                                    .font(.system(size: 16, weight: .semibold))
                            }
                            .glassEffect(.regular.tint(.green.opacity(0.8)))
                            .clipShape(Circle())
                            .handGestureShortcut(.primaryAction)
                        }
                    } else {
                        // Not started: show Start Timer button
                        Button {
                            WKInterfaceDevice.current().play(.click)
                            if let ex = currentExercise(workout) {
                                durationRemaining = ex.durationSeconds
                                durationTimerActive = true
                                connectivity.sendStartTimer()
                            }
                        } label: {
                            Text("Start Timer")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(maxWidth: .infinity)
                        }
                        .glassEffect(.regular.tint(.blue))
                        .handGestureShortcut(.primaryAction)
                    }
                } else {
                    // Reps exercise: show Log Set button
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        showSetConfirmation = true
                    } label: {
                        Text("Log Set")
                            .font(.system(size: 16, weight: .semibold))
                            .frame(maxWidth: .infinity)
                    }
                    .glassEffect(.regular.tint(.blue))
                    .handGestureShortcut(.primaryAction)
                }

            }
            .frame(maxWidth: .infinity)
        }
        .containerRelativeFrame(.vertical, alignment: .top)
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .containerBackground(phaseColor(workout).opacity(0.15).gradient, for: .navigation)
    }

    // MARK: - Exercise List (Swipe-up page)

    private func exerciseListView(workout: WatchWorkoutState) -> some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 8) {
                Text("Exercises")
                    .font(.system(size: 14, weight: .bold))
                    .foregroundStyle(.white)
                    .padding(.bottom, 4)

                ForEach(workout.exercises.enumerated().map { $0 }, id: \.offset) { idx, exercise in
                    Button {
                        WKInterfaceDevice.current().play(.click)
                        connectivity.sendSelectExercise(idx)
                        selectedPage = 0
                    } label: {
                        HStack(spacing: 10) {
                            // Status glyph
                            ZStack {
                                Circle()
                                    .fill(
                                        exercise.completedSets >= exercise.sets
                                            ? Color.green.opacity(0.3)
                                            : (idx == workout.exerciseIndex ? Color.cyan.opacity(0.35) : Color.white.opacity(0.1))
                                    )

                                if exercise.completedSets >= exercise.sets {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 10, weight: .bold))
                                        .foregroundStyle(.green)
                                } else if idx == workout.exerciseIndex {
                                    Text("NOW")
                                        .font(.system(size: 8, weight: .semibold))
                                        .foregroundStyle(.cyan)
                                } else {
                                    Text("\(idx + 1)")
                                        .font(.system(size: 11, weight: .semibold))
                                        .foregroundStyle(.white)
                                }
                            }
                            .frame(width: 28, height: 28)

                            // Exercise info
                            VStack(alignment: .leading, spacing: 2) {
                                Text(exercise.name)
                                    .font(.system(size: 14, weight: .semibold))
                                    .foregroundStyle(.white)
                                    .lineLimit(1)
                                    .minimumScaleFactor(0.8)

                                HStack(spacing: 4) {
                                    Text("\(exercise.completedSets)/\(exercise.sets) sets")
                                        .font(.system(size: 11))
                                        .foregroundStyle(.secondary)

                                    if exercise.weight > 0 {
                                        Text(String(format: "%.0f lb", exercise.weight))
                                            .font(.system(size: 11))
                                            .foregroundStyle(.secondary)
                                    }
                                }
                            }

                            Spacer()
                        }
                        .padding(.vertical, 8)
                        .padding(.horizontal, 10)
                        .background(
                            idx == workout.exerciseIndex
                                ? Color.cyan.opacity(0.22)
                                : Color.white.opacity(0.08)
                        )
                        .cornerRadius(12)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(12)
        }
        .containerBackground(Color.black.gradient, for: .navigation)
    }

    // MARK: - Rest View

    private func restView(workout: WatchWorkoutState) -> some View {
        return VStack(alignment: .center) {
            VStack(spacing: 0) {
                Text("\(displayRest)")
                    .font(.system(size: 64, weight: .bold, design: .rounded))
                    .foregroundStyle(.blue)
                    .monospacedDigit()
                    .contentTransition(.numericText())
                    .animation(.snappy, value: displayRest)
                Text("rest")
                    .font(.system(size: 12, weight: .medium))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }
            .frame(maxWidth: .infinity)
            .padding(.top, 16)

            Spacer()

            VStack(alignment: .center) {
                HStack{
                    Text("Up Next")
                        .font(.system(size: 13))
                    Text("•")
                        .font(.system(size: 13))
                        .foregroundStyle(.tertiary)
                    Text(workout.exerciseName)
                        .font(.system(size: 13, weight: .semibold))
                }
                .minimumScaleFactor(0.8)
                .padding(.top, 6)
                // Live heart rate
                HStack(spacing: 4) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 12))
                        .foregroundStyle(.blue)
                    let hrValue = healthStore.heartRate > 0 ? String(Int(healthStore.heartRate)) : "--"
                    Text(hrValue)
                        .font(.system(size: 15, weight: .semibold))
                        .foregroundStyle(.blue)
                    Text("BPM")
                        .font(.system(size: 10, weight: .semibold))
                        .foregroundStyle(.blue)
                        .alignmentGuide(.top) { d in d[.top] }
                }
                .padding(.top, 2)

            }
            Spacer()
            HStack {
                Button {
                    WKInterfaceDevice.current().play(.click)
                    connectivity.sendPause()
                } label: {
                    Image(systemName: (connectivity.activeWorkout?.isPaused ?? false) ? "play.fill" : "pause.fill")
                }
                .glassEffect(.regular.tint(.orange.opacity(0.7)))
                .handGestureShortcut(.primaryAction)
                .clipShape(Circle())
                .padding(.top, 4)
                Spacer()
                Button {
                    WKInterfaceDevice.current().play(.click)
                    connectivity.sendSkipRest()
                } label: {
                    Image(systemName: "forward.fill")
                }
                .glassEffect(.regular.tint(.red.opacity(0.7)))
                .handGestureShortcut(.primaryAction)
                .clipShape(Circle())
                .padding(.top, 4)
            }
        }
        .containerBackground(Color.blue.opacity(0.15).gradient, for: .navigation)
    }

    // MARK: - Finished View

    private var finishedView: some View {
        VStack(spacing: 10) {
            Image(systemName: "checkmark.seal.fill")
                .font(.system(size: 40))
                .foregroundStyle(.green)
            Text("Workout")
                .font(.system(size: 14, weight: .semibold))
                .foregroundStyle(.secondary)
            Text("Complete!")
                .font(.system(size: 17, weight: .bold))
        }
        .containerBackground(Color.black.gradient, for: .navigation)
    }

    // MARK: - Helpers

    @ViewBuilder
    private var pausedOverlay: some View {
        if connectivity.activeWorkout?.isPaused == true {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 12) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 40))
                        .foregroundStyle(.orange)
                        .symbolEffect(.pulse)

                    Text("Paused")
                        .font(.system(size: 18, weight: .bold))

                    Button {
                        WKInterfaceDevice.current().play(.click)
                        connectivity.sendPause()
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(.system(size: 14, weight: .semibold))
                    }
                    .glassEffect(.regular.tint(.green.opacity(0.8)))
                    .clipShape(Capsule())
                    .handGestureShortcut(.primaryAction)
                }
            }
            .transition(.opacity)
        }
    }

    private func phaseColor(_ w: WatchWorkoutState) -> Color {
        w.isResting ? .blue : .red
    }

    private func currentExercise(_ w: WatchWorkoutState) -> WorkoutExerciseLite? {
        guard w.exerciseIndex >= 0, w.exerciseIndex < w.exercises.count else { return nil }
        return w.exercises[w.exerciseIndex]
    }

    private func isDurationExercise(_ w: WatchWorkoutState) -> Bool {
        guard let ex = currentExercise(w) else { return false }
        return ex.inputType.lowercased() == "duration"
    }

    private func formatDuration(_ seconds: Int) -> String {
        let m = seconds / 60
        let s = seconds % 60
        return String(format: "%d:%02d", m, s)
    }
}

// MARK: - Previews

#Preview("Active") {
    let connectivity = WatchConnectivityService()
    let healthStore = WatchHealthStore()

    let exercises = [
        WorkoutExerciseLite(
            name: "Bench Press",
            sets: 4,
            completedSets: 1,
            reps: 8,
            weight: 225,
            inputType: "reps",
            durationSeconds: 0,
            isSuperset: false
        ),
        WorkoutExerciseLite(
            name: "Plank",
            sets: 4,
            completedSets: 0,
            reps: 0,
            weight: 0,
            inputType: "Duration",
            durationSeconds: 60,
            isSuperset: false
        ),
        WorkoutExerciseLite(
            name: "Cable Fly",
            sets: 3,
            completedSets: 0,
            reps: 12,
            weight: 80,
            inputType: "reps",
            durationSeconds: 0,
            isSuperset: false
        ),
        WorkoutExerciseLite(
            name: "Tricep Pushdown",
            sets: 3,
            completedSets: 0,
            reps: 15,
            weight: 100,
            inputType: "reps",
            durationSeconds: 0,
            isSuperset: false
        )
    ]

    connectivity.activeWorkout = WatchWorkoutState(
        status: "active",
        title: "Chest & Triceps",
        exerciseName: "Plank",
        exerciseIndex: 1,
        totalExercises: 4,
        setIndex: 1,
        totalSets: 4,
        restSecondsRemaining: 0,
        elapsedSeconds: 345,
        exercises: exercises,
        currentWeight: 0,
        currentReps: 0
    )

    healthStore.heartRate = 142

    return NavigationStack {
        WatchWorkoutView()
            .environment(connectivity)
            .environment(healthStore)
    }
}

#Preview("Resting") {
    let connectivity = WatchConnectivityService()
    let healthStore = WatchHealthStore()

    connectivity.activeWorkout = WatchWorkoutState(
        status: "resting",
        title: "Chest & Triceps",
        exerciseName: "Machine Incline DB Press",
        exerciseIndex: 2,
        totalExercises: 4,
        setIndex: 2,
        totalSets: 4,
        restSecondsRemaining: 45,
        elapsedSeconds: 420,
        exercises: [],
        currentWeight: 0,
        currentReps: 0
    )

    healthStore.heartRate = 118

    return NavigationStack {
        WatchWorkoutView()
            .environment(connectivity)
            .environment(healthStore)
    }
}

#Preview("Finished") {
    let connectivity = WatchConnectivityService()
    let healthStore = WatchHealthStore()

    connectivity.activeWorkout = WatchWorkoutState(
        status: "finished",
        title: "Chest & Triceps",
        exerciseName: "Tricep Pushdown",
        exerciseIndex: 3,
        totalExercises: 4,
        setIndex: 4,
        totalSets: 4,
        restSecondsRemaining: 0,
        elapsedSeconds: 1680,
        exercises: [],
        currentWeight: 0,
        currentReps: 0
    )

    healthStore.heartRate = 95

    return NavigationStack {
        WatchWorkoutView()
            .environment(connectivity)
            .environment(healthStore)
    }
}

#Preview("Exercise List") {
    let connectivity = WatchConnectivityService()
    let healthStore = WatchHealthStore()

    let exercises = [
        WorkoutExerciseLite(
            name: "Bench Press",
            sets: 4,
            completedSets: 1,
            reps: 8,
            weight: 225,
            inputType: "reps",
            durationSeconds: 0,
            isSuperset: false
        ),
        WorkoutExerciseLite(
            name: "Incline DB Press",
            sets: 4,
            completedSets: 0,
            reps: 10,
            weight: 90,
            inputType: "reps",
            durationSeconds: 0,
            isSuperset: false
        ),
        WorkoutExerciseLite(
            name: "Cable Fly",
            sets: 3,
            completedSets: 0,
            reps: 12,
            weight: 80,
            inputType: "reps",
            durationSeconds: 0,
            isSuperset: false
        ),
        WorkoutExerciseLite(
            name: "Tricep Pushdown",
            sets: 3,
            completedSets: 0,
            reps: 15,
            weight: 100,
            inputType: "reps",
            durationSeconds: 0,
            isSuperset: false
        )
    ]

    connectivity.activeWorkout = WatchWorkoutState(
        status: "active",
        title: "Chest & Triceps",
        exerciseName: "Incline DB Press",
        exerciseIndex: 1,
        totalExercises: 4,
        setIndex: 1,
        totalSets: 4,
        restSecondsRemaining: 0,
        elapsedSeconds: 345,
        exercises: exercises,
        currentWeight: 135,
        currentReps: 8
    )

    healthStore.heartRate = 142

    return NavigationStack {
        WatchWorkoutView()
            .environment(connectivity)
            .environment(healthStore)
    }
}

// MARK: - SetConfirmationView

struct SetConfirmationView: View {
	let exerciseName: String
	let setIndex: Int
	let totalSets: Int
	@State var weight: Double
	@State var reps: Int
	var onContinue: (Double, Int) -> Void

	var body: some View {
		ScrollView {
			VStack(alignment: .center, spacing: 10) {

					Text("Confirmation")
						.font(.system(size: 13, weight: .semibold))
						.foregroundStyle(.secondary)

				// Exercise name
				Text(exerciseName)
					.font(.system(size: 16, weight: .bold))
					.lineLimit(2)
					.minimumScaleFactor(0.8)

				// Weight stepper
				HStack(spacing: 0) {
					Button {
						WKInterfaceDevice.current().play(.click)
						weight = max(0, weight - 5)
					} label: {
						Image(systemName: "minus")
							.font(.system(size: 16, weight: .semibold))
							.foregroundStyle(.blue)
					}
					.buttonStyle(.plain)

					Spacer()

					VStack(spacing: 0) {
						Text(String(format: "%.0f", weight))
							.font(.system(size: 22, weight: .bold, design: .rounded))
						Text("lb")
							.font(.system(size: 10))
							.foregroundStyle(.secondary)
					}

					Spacer()

					Button {
						WKInterfaceDevice.current().play(.click)
						weight += 5
					} label: {
						Image(systemName: "plus")
							.font(.system(size: 16, weight: .semibold))
							.foregroundStyle(.blue)
					}
					.buttonStyle(.plain)
				}
				.padding(.vertical, 8)
				.padding(.horizontal, 12)
				.background(Color.white.opacity(0.08))
				.cornerRadius(12)

				// Reps stepper
				HStack(spacing: 0) {
					Button {
						WKInterfaceDevice.current().play(.click)
						reps = max(0, reps - 1)
					} label: {
						Image(systemName: "minus")
							.font(.system(size: 16, weight: .semibold))
							.foregroundStyle(.blue)
					}
					.buttonStyle(.plain)

					Spacer()

					VStack(spacing: 0) {
						Text("\(reps)")
							.font(.system(size: 22, weight: .bold, design: .rounded))
						Text("reps")
							.font(.system(size: 10))
							.foregroundStyle(.secondary)
					}

					Spacer()

					Button {
						WKInterfaceDevice.current().play(.click)
						reps += 1
					} label: {
						Image(systemName: "plus")
							.font(.system(size: 16, weight: .semibold))
							.foregroundStyle(.blue)
					}
					.buttonStyle(.plain)
				}
				.padding(.vertical, 8)
				.padding(.horizontal, 12)
				.background(Color.white.opacity(0.08))
				.cornerRadius(12)

				// Continue button
				Button {
					WKInterfaceDevice.current().play(.success)
					onContinue(weight, reps)
				} label: {
					Text("Continue")
						.font(.system(size: 15, weight: .semibold))
						.frame(maxWidth: .infinity)
				}
				.buttonStyle(.borderedProminent)
				.tint(.blue)
				.padding(.top, 4)
			}
			.padding(.horizontal, 4)
		}
		.containerBackground(Color.blue.opacity(0.15).gradient, for: .navigation)
	}
}

// MARK: - DurationSetView

struct DurationSetView: View {
	let exerciseName: String
	let setIndex: Int
	let totalSets: Int
	let totalSeconds: Int
	var onComplete: () -> Void

	@State private var remaining: Int
	@State private var isRunning: Bool = true
	private let ticker = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

	init(exerciseName: String, setIndex: Int, totalSets: Int, totalSeconds: Int, onComplete: @escaping () -> Void) {
		self.exerciseName = exerciseName
		self.setIndex = setIndex
		self.totalSets = totalSets
		self.totalSeconds = totalSeconds
		self.onComplete = onComplete
		_remaining = State(initialValue: totalSeconds)
	}

	var progressFraction: Double {
		totalSeconds > 0 ? Double(remaining) / Double(totalSeconds) : 0
	}

	var body: some View {
		VStack(spacing: 8) {
			Text("Set \(setIndex + 1)/\(totalSets)")
				.font(.system(size: 12, weight: .semibold))
				.foregroundStyle(.cyan)
				.frame(maxWidth: .infinity, alignment: .leading)

			// Countdown ring
			ZStack {
				Circle()
					.fill(.cyan.opacity(0.1))

				Circle()
					.stroke(.cyan.opacity(0.25), lineWidth: 6)

				Circle()
					.trim(from: 0, to: progressFraction)
					.stroke(.cyan, style: StrokeStyle(lineWidth: 6, lineCap: .round))
					.rotationEffect(.degrees(-90))
					.animation(.linear(duration: 1), value: remaining)

				VStack(spacing: 2) {
					Text("\(remaining)")
						.font(.system(size: 30, weight: .bold, design: .rounded))
						.foregroundStyle(.cyan)
					Text("sec")
						.font(.system(size: 11, weight: .medium))
						.foregroundStyle(.secondary)
				}
			}
			.frame(width: 110, height: 110)

			// Exercise name
			Text(exerciseName)
				.font(.system(size: 14, weight: .semibold))
				.lineLimit(1)
				.minimumScaleFactor(0.8)

			// Button controls
			HStack(spacing: 12) {
				Button {
					WKInterfaceDevice.current().play(.click)
					isRunning.toggle()
				} label: {
					Image(systemName: isRunning ? "pause.fill" : "play.fill")
				}
				.glassEffect(.regular.tint(.cyan.opacity(0.7)))
				.clipShape(Circle())

				Spacer()

				Button {
					WKInterfaceDevice.current().play(.success)
					onComplete()
				} label: {
					Image(systemName: "checkmark")
				}
				.glassEffect(.regular.tint(.green.opacity(0.8)))
				.clipShape(Circle())
			}
		}
		.containerBackground(Color.cyan.opacity(0.12).gradient, for: .navigation)
		.onReceive(ticker) { _ in
			if isRunning && remaining > 0 {
				remaining -= 1
				if remaining == 0 {
					WKInterfaceDevice.current().play(.success)
					onComplete()
					isRunning = false
				}
			}
		}
	}
}

#Preview("Set Confirmation") {
	NavigationStack {
		SetConfirmationView(
			exerciseName: "Incline DB Press",
			setIndex: 1,
			totalSets: 4,
			weight: 135,
			reps: 8,
			onContinue: { _, _ in }
		)
	}
}

#Preview("Duration Set") {
	NavigationStack {
		DurationSetView(
			exerciseName: "Plank",
			setIndex: 1,
			totalSets: 3,
			totalSeconds: 60,
			onComplete: {}
		)
	}
}
