import SwiftUI
import Combine

extension ActiveWorkoutView {

    func liveActivityState() -> WorkoutActivityAttributes.ContentState {
        WorkoutActivityAttributes.ContentState(
            exerciseName: session.currentExercise?.name ?? "",
            exerciseIndex: session.currentExerciseIndex,
            totalExercises: session.workout.exercises.count,
            setIndex: session.currentSetIndex,
            totalSets: session.isInSuperset ? session.currentGroupRounds : session.totalSets,
            isResting: session.isResting,
            restSecondsRemaining: session.restSecondsRemaining,
            restEndDate: (session.isResting && session.restSecondsRemaining > 0)
                ? Date().addingTimeInterval(TimeInterval(session.restSecondsRemaining))
                : nil,
            heartRate: Int(watchSync.liveWatchHeartRate),
            weight: session.currentLoggedWeight,
            reps: session.currentLoggedReps,
            elapsedSeconds: elapsedSeconds,
            startDate: Date().addingTimeInterval(-Double(elapsedSeconds)),
            isPaused: isPaused
        )
    }

    // MARK: - Timer

    func runTimer() async {
        elapsedSeconds = Int(Date().timeIntervalSince(session.startedAt))
        var lastRestState = session.isResting
        var lastPausedState = isPaused
        for await _ in Timer.publish(every: 1, on: .main, in: .common).autoconnect().values {
            if session.isFinished && session.phase == .main { break }
            if session.isResting != lastRestState || isPaused != lastPausedState {
                lastRestState = session.isResting
                lastPausedState = isPaused
                WorkoutLiveActivityController.shared.update(liveActivityState())
            }
            if isPaused { continue }
            elapsedSeconds += 1
            if session.isResting && session.restSecondsRemaining > 0 {
                session.restSecondsRemaining -= 1
                if session.restSecondsRemaining == 0 {
                    withAnimation(.spring(duration: 0.3)) { session.isResting = false }
                }
            }
            if session.isExerciseTimerRunning {
                session.exerciseSecondsRemaining -= 1
            }
            if session.isPhaseTimerRunning && session.phaseSecondsRemaining > 0 {
                session.phaseSecondsRemaining -= 1
                if session.phaseSecondsRemaining == 0 {
                    session.isPhaseTimerRunning = false
                    withAnimation(.spring(duration: 0.3)) {
                        if session.phase == .warmup {
                            endWarmupPhase()
                        } else if session.phase == .cooldown {
                            endCooldownPhase()
                        }
                    }
                }
            }
            if elapsedSeconds % 5 == 0 { syncToWatch() }
        }
    }

    var elapsedFormatted: String {
        let m = elapsedSeconds / 60
        let s = elapsedSeconds % 60
        return String(format: "%d:%02d", m, s)
    }

    // MARK: - Actions

    func startExerciseTimer() {
        guard let ex = session.currentExercise, ex.inputType == .duration else { return }
        session.exerciseSecondsRemaining = ex.durationSeconds
        session.isExerciseTimerRunning = true
    }

    func completeSet() {
        guard let exercise = session.currentExercise else { return }

        // Stop any running duration countdown
        session.isExerciseTimerRunning = false
        session.exerciseSecondsRemaining = 0

        // Capture the set index being completed
        let finishedID = exercise.id
        let finishedSetIndex = session.currentSetIndex

        // Insert into completedSetIndices FIRST (before computing advancement)
        session.completedSetIndices[finishedID, default: []].insert(finishedSetIndex)

        if exercise.supersetID != nil {
            // Superset flow
            let endIdx = session.currentGroupEndIndex
            let startIdx = session.currentGroupStartIndex
            let isLastInGroup = session.currentExerciseIndex >= endIdx
            let isLastRound = session.currentSetIndex >= session.currentGroupRounds - 1

            withAnimation(.spring(duration: 0.3)) {
                if !isLastInGroup {
                    // Next exercise in the superset, same round, no rest
                    session.currentExerciseIndex += 1
                    session.isResting = false
                    session.restSecondsRemaining = 0
                } else if !isLastRound {
                    // Finished a round; rest, then back to the start of the group for next round
                    session.currentExerciseIndex = startIdx
                    session.currentSetIndex += 1
                    let rest = exercise.rest(forSet: finishedSetIndex)
                    session.restSecondsRemaining = rest
                    session.isResting = rest > 0
                } else {
                    // Group complete; check if any exercise in the group is still incomplete
                    let groupExercises = Array(session.workout.exercises[startIdx...endIdx])
                    let anyIncomplete = groupExercises.contains { !session.isExerciseComplete($0) }

                    if anyIncomplete {
                        // Some sets in the group are still pending; find next incomplete
                        session.advanceToNextIncomplete(preferring: startIdx)
                    } else {
                        // Group fully complete; advance past it
                        session.advanceToNextIncomplete(preferring: endIdx + 1)
                    }
                }
            }
        } else {
            // Standard (non-superset) flow
            withAnimation(.spring(duration: 0.3)) {
                // Check if current exercise still has incomplete sets
                let incompleteCount = exercise.sets - session.completedCount(for: exercise)

                if incompleteCount > 0 {
                    // Exercise still has incomplete sets; stay on it and move to next incomplete set
                    let completed = session.completedSetIndices[exercise.id] ?? []
                    var lowestIncomplete = exercise.sets - 1
                    for i in 0..<exercise.sets {
                        if !completed.contains(i) {
                            lowestIncomplete = i
                            break
                        }
                    }
                    session.currentSetIndex = lowestIncomplete
                    let rest = exercise.rest(forSet: finishedSetIndex)
                    session.restSecondsRemaining = rest
                    session.isResting = rest > 0
                } else {
                    // Exercise complete; advance to next incomplete exercise
                    session.advanceToNextIncomplete(preferring: session.currentExerciseIndex + 1)
                }
            }
        }
    }

    func skipRest() {
        withAnimation(.spring(duration: 0.2)) {
            session.restSecondsRemaining = 0
            session.isResting = false
        }
        WorkoutLiveActivityController.shared.update(liveActivityState())
    }

    func handleCompletionTrigger() {
        guard session.isFinished || session.allMainExercisesComplete else { return }
        guard session.phase == .main else { return }
        if cooldownMinutes > 0 && !session.hasRunCooldown {
            session.hasRunCooldown = true
            session.phase = .cooldown
            let total = session.phaseDurationSeconds(for: .cooldown, fallbackMinutes: cooldownMinutes)
            session.phaseTotalSeconds = total
            session.phaseSecondsRemaining = total
            session.isPhaseTimerRunning = true
            syncToWatch()
            return
        }
        handleWorkoutFinished()
    }

    func finishWorkout() {
        session.isPhaseTimerRunning = false
        session.phase = .main
        session.hasRunCooldown = true
        handleWorkoutFinished()
        commitEffortScore()
        onFinish()
    }

    func endWarmupPhase() {
        session.markRoleComplete(.warmup)
        session.isPhaseTimerRunning = false
        session.phase = .main
        session.advanceToNextIncomplete(preferring: 0)
    }

    func endCooldownPhase() {
        session.markRoleComplete(.cooldown)
        session.isPhaseTimerRunning = false
        session.phase = .main
        session.currentExerciseIndex = session.workout.exercises.count
        handleWorkoutFinished()
    }

    func handleWorkoutFinished() {
        WorkoutLiveActivityController.shared.end()
        WatchSyncService.shared.sendWorkoutEnded()
        recordCompletion()
        saveToHealth()
        recordProgression()
    }

    func recordCompletion() {
        guard !session.hasRecordedCompletion else { return }
        guard !devModeEnabled else { return }
        session.hasRecordedCompletion = true
        // Use the user's actually-logged weights/reps; fall back to the template when nothing was logged.
        let library = ExerciseLibrary.shared
        var volume = 0.0
        var muscleVolumes: [String: Double] = [:]
        for exercise in session.workout.exercises where exercise.inputType == .reps {
            let weights = session.loggedSetWeights[exercise.id] ?? exercise.resolvedSetDetails.map { $0.weightKg ?? 0 }
            let reps = session.loggedSetReps[exercise.id] ?? exercise.resolvedSetDetails.map { $0.reps }
            var exVolume = 0.0
            for i in 0..<min(weights.count, reps.count) {
                exVolume += Double(reps[i]) * weights[i]
            }
            volume += exVolume
            guard exVolume > 0 else { continue }
            if let lib = library.exercises.first(where: { $0.name.lowercased() == exercise.name.lowercased() }) {
                muscleVolumes[lib.muscleCategory, default: 0] += exVolume
            }
        }
        let minutes = max(1, Int(Date().timeIntervalSince(session.startedAt) / 60))
        session.lastCompletionRecordID = WorkoutCompletionStore.shared.record(
            templateID: session.workout.id,
            totalVolume: volume,
            durationMinutes: minutes,
            muscleVolumes: muscleVolumes,
            title: session.workout.title,
            performedExercises: loggedExercises(),
            expectsHealthSync: watchSync.isWatchAppInstalled
        )
        // Seed the perceived effort from a heuristic
        let minutesDouble = Double(minutes)
        session.perceivedEffort = min(10, max(1, (minutesDouble / 12) + (volume / 2500) + 1)).rounded()
    }

    func recordProgression() {
        guard !session.hasRecordedProgression else { return }
        guard !devModeEnabled else { return }
        session.hasRecordedProgression = true
        for ex in session.workout.exercises {
            let resolved = ex.resolvedSetDetails
            let weights = session.loggedSetWeights[ex.id] ?? resolved.map { $0.weightKg ?? 0 }
            let repsArr = session.loggedSetReps[ex.id] ?? resolved.map { $0.reps }
            // Record the heaviest working set as the representative performance.
            let topIdx = weights.indices.max(by: { weights[$0] < weights[$1] }) ?? 0
            let topWeight = weights.indices.contains(topIdx) ? weights[topIdx] : (ex.weightKg ?? 0)
            let topReps = repsArr.indices.contains(topIdx) ? repsArr[topIdx] : ex.reps
            let targetReps = resolved.indices.contains(topIdx) ? resolved[topIdx].reps : ex.reps

            // Build per-set detail from logged weights/reps
            let setCount = min(weights.count, repsArr.count, resolved.count)
            var sets: [SetPerformance]? = nil
            if setCount > 0 {
                sets = (0..<setCount).map { idx in
                    SetPerformance(
                        weightKg: weights[idx],
                        reps: repsArr[idx],
                        targetReps: resolved[idx].reps
                    )
                }
            }

            ExerciseProgressionStore.shared.record(entry: ex, weightKg: topWeight, reps: topReps, targetReps: targetReps, sets: sets)
        }
    }

    func commitEffortScore() {
        guard !session.hasWrittenEffort else { return }
        session.hasWrittenEffort = true
        let session = self.session
        let service = healthService
        Task {
            // The Health save is async; wait briefly for it to land before relating the effort.
            for _ in 0..<20 {
                if session.savedHealthWorkout != nil { break }
                try? await Task.sleep(for: .milliseconds(500))
            }
            guard let workout = session.savedHealthWorkout else { return }
            // Capture effort at write time so user adjustments are included
            let effort = session.perceivedEffort
            await service.writeEffortScore(effort, for: workout)
        }
    }

    /// The session's exercises with the user's actually-logged weights/reps applied.
    /// Only reps exercises are adjusted; duration exercises are left untouched.
    func loggedExercises() -> [ManualExerciseEntry] {
        session.workout.exercises.map { ex in
            guard ex.inputType == .reps else { return ex }
            var updated = ex
            let weights = session.loggedSetWeights[ex.id] ?? ex.resolvedSetDetails.map { $0.weightKg ?? 0 }
            let repsArr = session.loggedSetReps[ex.id] ?? ex.resolvedSetDetails.map { $0.reps }
            let count = min(weights.count, repsArr.count)
            guard count > 0 else { return updated }
            let varied = Set(weights.prefix(count)).count > 1 || Set(repsArr.prefix(count)).count > 1
            if varied {
                updated.setDetails = (0..<count).map { SetDetail(weightKg: weights[$0], reps: repsArr[$0]) }
                updated.weightKg = weights.prefix(count).max()
                updated.reps = repsArr.prefix(count).max() ?? ex.reps
            } else {
                updated.setDetails = nil
                updated.weightKg = weights.first ?? ex.weightKg
                updated.reps = repsArr.first ?? ex.reps
            }
            return updated
        }
    }

    func saveToHealth() {
        guard !session.hasSavedToHealth else { return }
        guard !devModeEnabled else { return }
        guard watchSync.isWatchAppInstalled else { return }
        session.hasSavedToHealth = true
        let recordID = session.lastCompletionRecordID
        if let recordID { healthService.beginPendingSave(recordID) }
        Task {
            let workout = await healthService.saveStrengthWorkout(
                title: session.workout.title,
                startDate: session.startedAt,
                endDate: Date(),
                exercises: loggedExercises()
            )
            // Mark the local record as synced so the hourly backfill never re-saves a duplicate.
            if let workout, let recordID {
                WorkoutCompletionStore.shared.markSynced(recordID)
                session.savedHealthWorkout = workout
            }
            if let recordID { healthService.endPendingSave(recordID) }
        }
    }

    func updateTemplate() {
        guard !session.hasUpdatedTemplate else { return }
        guard !devModeEnabled else { return }
        session.hasUpdatedTemplate = true
        var updated = session.workout
        updated.exercises = loggedExercises()
        WorkoutStorageService.shared.save(updated)
    }

    func syncToWatch() {
        guard !session.isFinished || session.phase != .main else { return }

        let exercises = session.workout.exercises.map { ex in
            WorkoutExerciseLite(
                name: ex.name,
                sets: ex.sets,
                completedSets: session.completedSetIndices[ex.id]?.count ?? 0,
                reps: session.loggedSetReps[ex.id]?.first ?? ex.reps,
                weight: session.loggedSetWeights[ex.id]?.max() ?? (ex.weightKg ?? 0),
                inputType: ex.inputType.rawValue,
                durationSeconds: ex.durationSeconds,
                isSuperset: ex.supersetID != nil
            )
        }

        let state = WorkoutSyncState(
            status: session.isResting ? "resting" : "active",
            title: session.workout.title,
            exerciseName: session.currentExercise?.name ?? "",
            exerciseIndex: session.currentExerciseIndex,
            totalExercises: session.workout.exercises.count,
            setIndex: session.currentSetIndex,
            totalSets: session.totalSets,
            restSecondsRemaining: session.restSecondsRemaining,
            elapsedSeconds: elapsedSeconds,
            exercises: exercises,
            currentWeight: session.currentLoggedWeight,
            currentReps: session.currentLoggedReps,
            isPaused: isPaused,
            phase: session.phase == .warmup ? "warmup" : (session.phase == .cooldown ? "cooldown" : "main"),
            phaseSecondsRemaining: session.phaseSecondsRemaining
        )
        WatchSyncService.shared.sendWorkoutUpdate(state)
        WorkoutLiveActivityController.shared.update(liveActivityState())
    }
}
