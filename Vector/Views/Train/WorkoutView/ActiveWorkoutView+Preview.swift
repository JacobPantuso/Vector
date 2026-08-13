import SwiftUI

// MARK: - Preview

#Preview("Active Workout") {
    // Mock workout with a standard exercise, a reps exercise, and a 2-exercise superset.
    let bench = ManualExerciseEntry(
        name: "Barbell Bench Press",
        sets: 4, reps: 8, durationSeconds: 0,
        inputType: .reps, weightKg: 135, restSeconds: 90, notes: ""
    )
    let plank = ManualExerciseEntry(
        name: "Plank",
        sets: 3, reps: 0, durationSeconds: 45,
        inputType: .duration, weightKg: nil, restSeconds: 60, notes: ""
    )
    let supersetID = UUID()
    let curl = ManualExerciseEntry(
        supersetID: supersetID,
        name: "Dumbbell Curl",
        sets: 3, reps: 12, durationSeconds: 0,
        inputType: .reps, weightKg: 30, restSeconds: 75, notes: ""
    )
    let pushdown = ManualExerciseEntry(
        supersetID: supersetID,
        name: "Tricep Pushdown",
        sets: 3, reps: 12, durationSeconds: 0,
        inputType: .reps, weightKg: 50, restSeconds: 75, notes: ""
    )
    let pec = ManualExerciseEntry(
        name: "Pec Deck Fly",
        sets: 3, reps: 12, durationSeconds: 0,
        inputType: .reps, weightKg: 40, restSeconds: 60, notes: ""
    )

    let shoulder = ManualExerciseEntry(
        name: "Shoulder Press",
        sets: 3, reps: 10, durationSeconds: 0,
        inputType: .reps, weightKg: 60, restSeconds: 90, notes: ""
    )

    let workout = SavedWorkout(
        title: "Upper Body Strength",
        focus: "Chest & Arms",
        source: .manual,
        aiPlan: nil,
        exercises: [curl, pushdown, bench, plank, pec, shoulder],
        durationMinutes: 45,
        effort: 7
    )

#if DEBUG
    ExerciseProgressionStore.shared.seedPreview([
        "barbell bench press": [
            ExercisePerformance(weightKg: 125, reps: 8, targetReps: 8, date: Date().addingTimeInterval(-86400 * 14)),
            ExercisePerformance(weightKg: 130, reps: 8, targetReps: 8, date: Date().addingTimeInterval(-86400 * 7)),
            ExercisePerformance(weightKg: 135, reps: 8, targetReps: 8, date: Date().addingTimeInterval(-86400 * 2))
        ],
        "dumbbell curl": [
            ExercisePerformance(weightKg: 30, reps: 10, targetReps: 12, date: Date().addingTimeInterval(-86400 * 3))
        ],
        "tricep pushdown": [
            ExercisePerformance(weightKg: 50, reps: 12, targetReps: 12, date: Date().addingTimeInterval(-86400 * 9)),
            ExercisePerformance(weightKg: 50, reps: 12, targetReps: 12, date: Date().addingTimeInterval(-86400 * 5)),
            ExercisePerformance(weightKg: 50, reps: 12, targetReps: 12, date: Date().addingTimeInterval(-86400 * 2))
        ]
    ])
#endif

    let session = ActiveWorkoutSession(workout: workout)

    let watchSync = WatchSyncService()
    watchSync.liveWatchHeartRate = 128

    return Color.black.opacity(0.001)
        .ignoresSafeArea()
        .vectorSheet(isPresented: .constant(true)) {
            ActiveWorkoutView(session: session, onFinish: {})
                .environment(HealthKitService())
                .environment(watchSync)
        }
}

#Preview("Warm-Up Phase") {
    // Mock workout with warmup mobility exercises followed by main strength exercises.
    let jumpingJacks = ManualExerciseEntry(
        role: .warmup,
        name: "Jumping Jacks",
        sets: 1, reps: 0, durationSeconds: 45,
        inputType: .duration, weightKg: nil, restSeconds: 0, notes: ""
    )
    let armCircles = ManualExerciseEntry(
        role: .warmup,
        name: "Arm Circles",
        sets: 1, reps: 0, durationSeconds: 60,
        inputType: .duration, weightKg: nil, restSeconds: 0, notes: ""
    )
    let bodyweightSquats = ManualExerciseEntry(
        role: .warmup,
        name: "Bodyweight Squats",
        sets: 1, reps: 0, durationSeconds: 45,
        inputType: .duration, weightKg: nil, restSeconds: 0, notes: ""
    )
    let benchPress = ManualExerciseEntry(
        role: .main,
        name: "Barbell Bench Press",
        sets: 4, reps: 8, durationSeconds: 0,
        inputType: .reps, weightKg: 135, restSeconds: 90, notes: ""
    )
    let shoulderPress = ManualExerciseEntry(
        role: .main,
        name: "Shoulder Press",
        sets: 3, reps: 10, durationSeconds: 0,
        inputType: .reps, weightKg: 60, restSeconds: 90, notes: ""
    )

    let workout = SavedWorkout(
        title: "Warmup Strength Session",
        focus: "Upper Body",
        source: .manual,
        aiPlan: nil,
        exercises: [jumpingJacks, armCircles, bodyweightSquats, benchPress, shoulderPress],
        durationMinutes: 50,
        effort: 6
    )

    let session = ActiveWorkoutSession(workout: workout)
    session.hasInitializedPhase = true
    session.phase = .warmup
    // Total = sum of the warm-up exercises' durations (45 + 60 + 45 = 150), same as the live app.
    let total = session.phaseDurationSeconds(for: .warmup, fallbackMinutes: 5)
    session.phaseTotalSeconds = total
    session.phaseSecondsRemaining = total
    session.isPhaseTimerRunning = true

    let watchSync = WatchSyncService()
    watchSync.liveWatchHeartRate = 95

    return Color.black.opacity(0.001)
        .ignoresSafeArea()
        .vectorSheet(isPresented: .constant(true)) {
            ActiveWorkoutView(session: session, onFinish: {})
                .environment(HealthKitService())
                .environment(watchSync)
        }
}

#Preview("Cool-Down Phase") {
    // Mock workout with main strength exercises followed by cooldown stretches.
    let benchPress = ManualExerciseEntry(
        role: .main,
        name: "Barbell Bench Press",
        sets: 4, reps: 8, durationSeconds: 0,
        inputType: .reps, weightKg: 135, restSeconds: 90, notes: ""
    )
    let shoulderPress = ManualExerciseEntry(
        role: .main,
        name: "Shoulder Press",
        sets: 3, reps: 10, durationSeconds: 0,
        inputType: .reps, weightKg: 60, restSeconds: 90, notes: ""
    )
    let hamstringStretch = ManualExerciseEntry(
        role: .cooldown,
        name: "Hamstring Stretch",
        sets: 1, reps: 0, durationSeconds: 60,
        inputType: .duration, weightKg: nil, restSeconds: 0, notes: ""
    )
    let childsPose = ManualExerciseEntry(
        role: .cooldown,
        name: "Child's Pose",
        sets: 1, reps: 0, durationSeconds: 45,
        inputType: .duration, weightKg: nil, restSeconds: 0, notes: ""
    )
    let chestStretch = ManualExerciseEntry(
        role: .cooldown,
        name: "Chest Stretch",
        sets: 1, reps: 0, durationSeconds: 45,
        inputType: .duration, weightKg: nil, restSeconds: 0, notes: ""
    )

    let workout = SavedWorkout(
        title: "Cooldown Strength Session",
        focus: "Upper Body",
        source: .manual,
        aiPlan: nil,
        exercises: [benchPress, shoulderPress, hamstringStretch, childsPose, chestStretch],
        durationMinutes: 50,
        effort: 6
    )

    let session = ActiveWorkoutSession(workout: workout)
    session.hasInitializedPhase = true
    session.hasRunCooldown = true
    session.phase = .cooldown
    // Total = sum of the cool-down exercises' durations (60 + 45 + 45 = 150), same as the live app.
    let total = session.phaseDurationSeconds(for: .cooldown, fallbackMinutes: 5)
    session.phaseTotalSeconds = total
    session.phaseSecondsRemaining = total
    session.isPhaseTimerRunning = true
    session.currentExerciseIndex = workout.exercises.count

    let watchSync = WatchSyncService()
    watchSync.liveWatchHeartRate = 75

    return Color.black.opacity(0.001)
        .ignoresSafeArea()
        .vectorSheet(isPresented: .constant(true)) {
            ActiveWorkoutView(session: session, onFinish: {})
                .environment(HealthKitService())
                .environment(watchSync)
        }
}
