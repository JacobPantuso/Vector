import SwiftUI
import HealthKit

@Observable final class ActiveWorkoutSession: Identifiable {
    let id = UUID()
    var workout: SavedWorkout
    var currentExerciseIndex: Int = 0
    var currentSetIndex: Int = 0
    var restSecondsRemaining: Int = 0
    var isResting: Bool = false
    var exerciseSecondsRemaining: Int = 0
    var isExerciseTimerRunning: Bool = false
    let startedAt: Date = Date()

    // PART A: Progression tracking (per-set)
    var completedSetIndices: [UUID: Set<Int>] = [:]
    var loggedSetWeights: [UUID: [Double]] = [:]
    var loggedSetReps: [UUID: [Int]] = [:]
    /// Exercises whose progressive-overload suggestion has been applied or dismissed this session.
    var appliedOverloadIDs: Set<UUID> = []

    // Completion idempotency guards — live on the session (which survives sheet re-presentation),
    // NOT on view @State, so finishing can never double-record/double-save.
    var hasRecordedCompletion = false
    var hasSavedToHealth = false
    var hasRecordedProgression = false
    var hasUpdatedTemplate = false
    /// id of the completion record created at finish, so the HealthKit save can mark it synced.
    var lastCompletionRecordID: UUID? = nil
    /// The HKWorkout saved at finish, once the async Health save lands. Used to attach the user's effort rating.
    var savedHealthWorkout: HKWorkout? = nil
    /// User-adjustable perceived effort (1–10) shown on the completion screen; seeded from a heuristic.
    var perceivedEffort: Double = 5
    var hasWrittenEffort = false

    init(workout: SavedWorkout) {
        self.workout = workout

        // Seed per-set weights/reps straight from the template. Progressive overload is
        // applied opt-in by the user via WorkoutAdvisorCallout, never automatically.
        for ex in workout.exercises {
            let resolved = ex.resolvedSetDetails
            loggedSetWeights[ex.id] = resolved.map { max(0, $0.weightKg ?? 0) }
            loggedSetReps[ex.id] = resolved.map { $0.reps }
        }
    }

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

    /// The exercise that becomes active after completing the current set, accounting for
    /// superset round-looping. Mirrors the advancement logic in `completeSet`.
    var upNextExercise: ManualExerciseEntry? {
        guard isInSuperset else { return nextExercise }
        let isLastInGroup = currentExerciseIndex >= currentGroupEndIndex
        let isLastRound = currentSetIndex >= currentGroupRounds - 1
        if !isLastInGroup {
            return workout.exercises[safe: currentExerciseIndex + 1]
        } else if !isLastRound {
            return workout.exercises[safe: currentGroupStartIndex]
        } else {
            return workout.exercises[safe: currentGroupEndIndex + 1]
        }
    }

    /// Index in `workout.exercises` of the first exercise sharing the current exercise's superset run.
    var currentGroupStartIndex: Int {
        guard let sid = currentExercise?.supersetID else { return currentExerciseIndex }
        var i = currentExerciseIndex
        while i > 0, workout.exercises[i - 1].supersetID == sid { i -= 1 }
        return i
    }

    /// Index of the last exercise in the current superset run.
    var currentGroupEndIndex: Int {
        guard let sid = currentExercise?.supersetID else { return currentExerciseIndex }
        var i = currentExerciseIndex
        while i + 1 < workout.exercises.count, workout.exercises[i + 1].supersetID == sid { i += 1 }
        return i
    }

    var isInSuperset: Bool { currentExercise?.supersetID != nil }

    /// Exercises composing the current superset run (or just the current exercise).
    var currentGroupExercises: [ManualExerciseEntry] {
        guard isInSuperset else { return currentExercise.map { [$0] } ?? [] }
        return Array(workout.exercises[currentGroupStartIndex...currentGroupEndIndex])
    }

    /// Rounds (sets) for the current group — uses the first exercise's set count.
    var currentGroupRounds: Int { workout.exercises[safe: currentGroupStartIndex]?.sets ?? totalSets }

    // PART A: Computed properties for the current set's logged values
    var currentLoggedWeight: Double {
        guard let ex = currentExercise, let arr = loggedSetWeights[ex.id], arr.indices.contains(currentSetIndex) else { return 0 }
        return arr[currentSetIndex]
    }
    var currentLoggedReps: Int {
        guard let ex = currentExercise, let arr = loggedSetReps[ex.id], arr.indices.contains(currentSetIndex) else { return currentExercise?.reps ?? 0 }
        return arr[currentSetIndex]
    }

    // PART A: Helper functions
    func completedCount(for ex: ManualExerciseEntry) -> Int { completedSetIndices[ex.id]?.count ?? 0 }
    func isExerciseComplete(_ ex: ManualExerciseEntry) -> Bool { completedCount(for: ex) >= ex.sets }
    var allExercisesComplete: Bool { workout.exercises.allSatisfy { isExerciseComplete($0) } }

    // PART B: Exercise mutation helpers
    private func updateExercise(_ id: UUID, _ mutate: (inout ManualExerciseEntry) -> Void) {
        guard let idx = workout.exercises.firstIndex(where: { $0.id == id }) else { return }
        mutate(&workout.exercises[idx])
    }

    func addExercises(_ entries: [ManualExerciseEntry]) {
        for entry in entries {
            workout.exercises.append(entry)
            let resolved = entry.resolvedSetDetails
            loggedSetWeights[entry.id] = resolved.map { max(0, $0.weightKg ?? 0) }
            loggedSetReps[entry.id] = resolved.map { $0.reps }
        }
    }

    func deleteExercise(id: UUID) {
        guard workout.exercises.count > 1 else { return }
        guard let idx = workout.exercises.firstIndex(where: { $0.id == id }) else { return }
        workout.exercises.remove(at: idx)
        loggedSetWeights.removeValue(forKey: id)
        loggedSetReps.removeValue(forKey: id)
        completedSetIndices.removeValue(forKey: id)
        appliedOverloadIDs.remove(id)

        // Clamp currentExerciseIndex
        if currentExerciseIndex >= workout.exercises.count {
            currentExerciseIndex = max(0, workout.exercises.count - 1)
        }

        // Reset set index and clear resting state
        if let ex = currentExercise {
            currentSetIndex = min(completedCount(for: ex), max(0, ex.sets - 1))
        }
        isResting = false
        restSecondsRemaining = 0
    }

    func setWeight(for id: UUID, setIndex: Int, to value: Double) {
        var arr = loggedSetWeights[id] ?? []
        while arr.count <= setIndex { arr.append(0) }
        arr[setIndex] = max(0, value)
        loggedSetWeights[id] = arr
    }

    func setReps(for id: UUID, setIndex: Int, to value: Int) {
        var arr = loggedSetReps[id] ?? []
        while arr.count <= setIndex { arr.append(0) }
        arr[setIndex] = max(0, value)
        loggedSetReps[id] = arr
    }

    func toggleSetDone(for id: UUID, setIndex: Int) {
        var indices = completedSetIndices[id] ?? []
        if indices.contains(setIndex) {
            indices.remove(setIndex)
        } else {
            indices.insert(setIndex)
        }
        completedSetIndices[id] = indices

        // If toggled exercise is current, re-point currentSetIndex to lowest incomplete set
        if id == currentExercise?.id, let ex = currentExercise {
            let completed = completedSetIndices[id] ?? []
            var lowestIncomplete: Int? = nil
            for i in 0..<ex.sets {
                if !completed.contains(i) {
                    lowestIncomplete = i
                    break
                }
            }
            if let lowestIncomplete = lowestIncomplete {
                currentSetIndex = lowestIncomplete
            }
        }
    }

    func isSetDone(_ id: UUID, _ setIndex: Int) -> Bool {
        completedSetIndices[id]?.contains(setIndex) ?? false
    }

    func addSet(to id: UUID) {
        updateExercise(id) { ex in
            let last = ex.resolvedSetDetails.last ?? SetDetail(weightKg: ex.weightKg, reps: ex.reps)
            if ex.setDetails == nil {
                ex.setDetails = []
            }
            ex.setDetails?.append(last)
            ex.sets += 1
        }

        if let resolved = currentExercise?.resolvedSetDetails {
            let last = resolved.last ?? SetDetail(weightKg: currentExercise?.weightKg, reps: currentExercise?.reps ?? 0)
            if var weights = loggedSetWeights[id] {
                weights.append(max(0, last.weightKg ?? 0))
                loggedSetWeights[id] = weights
            }
            if var reps = loggedSetReps[id] {
                reps.append(last.reps)
                loggedSetReps[id] = reps
            }
        }
    }

    func removeSet(from id: UUID, setIndex: Int) {
        updateExercise(id) { ex in
            guard ex.sets > 1 else { return }
            ex.sets -= 1
            if var details = ex.setDetails {
                if details.indices.contains(setIndex) {
                    details.remove(at: setIndex)
                    ex.setDetails = details.isEmpty ? nil : details
                }
            }
        }

        if var weights = loggedSetWeights[id] {
            if weights.indices.contains(setIndex) {
                weights.remove(at: setIndex)
                loggedSetWeights[id] = weights
            }
        }
        if var reps = loggedSetReps[id] {
            if reps.indices.contains(setIndex) {
                reps.remove(at: setIndex)
                loggedSetReps[id] = reps
            }
        }

        var indices = completedSetIndices[id] ?? []
        indices.remove(setIndex)
        for idx in (setIndex + 1)..<Int.max {
            if indices.contains(idx) {
                indices.remove(idx)
                indices.insert(idx - 1)
            } else {
                break
            }
        }
        completedSetIndices[id] = indices.isEmpty ? nil : indices
    }

    func adjustWeight(_ delta: Double) {
        guard let ex = currentExercise else { return }
        var arr = loggedSetWeights[ex.id] ?? ex.resolvedSetDetails.map { $0.weightKg ?? 0 }
        guard arr.indices.contains(currentSetIndex) else { return }
        arr[currentSetIndex] = max(0, arr[currentSetIndex] + delta)
        loggedSetWeights[ex.id] = arr
    }

    func adjustReps(_ delta: Int) {
        guard let ex = currentExercise else { return }
        var arr = loggedSetReps[ex.id] ?? ex.resolvedSetDetails.map { $0.reps }
        guard arr.indices.contains(currentSetIndex) else { return }
        arr[currentSetIndex] = max(0, arr[currentSetIndex] + delta)
        loggedSetReps[ex.id] = arr
    }

    func logCurrentSet(weight: Double?, reps: Int?) {
        guard let ex = currentExercise else { return }
        if let weight {
            var arr = loggedSetWeights[ex.id] ?? ex.resolvedSetDetails.map { $0.weightKg ?? 0 }
            if arr.indices.contains(currentSetIndex) {
                arr[currentSetIndex] = max(0, weight)
                loggedSetWeights[ex.id] = arr
            }
        }
        if let reps {
            var arr = loggedSetReps[ex.id] ?? ex.resolvedSetDetails.map { $0.reps }
            if arr.indices.contains(currentSetIndex) {
                arr[currentSetIndex] = max(0, reps)
                loggedSetReps[ex.id] = arr
            }
        }
    }

    /// Apply a suggested top-set weight, shifting every set by the same delta to preserve the spread.
    func applySuggestedTopWeight(_ weight: Double, for ex: ManualExerciseEntry) {
        let base = ex.topSetWeightKg ?? (ex.weightKg ?? 0)
        let delta = weight - base
        let arr = loggedSetWeights[ex.id] ?? ex.resolvedSetDetails.map { $0.weightKg ?? 0 }
        loggedSetWeights[ex.id] = arr.map { max(0, $0 + delta) }
    }

    func select(index: Int) {
        guard workout.exercises.indices.contains(index) else { return }
        isResting = false
        restSecondsRemaining = 0
        isExerciseTimerRunning = false
        exerciseSecondsRemaining = 0
        let ex = workout.exercises[index]
        if ex.supersetID != nil {
            var i = index
            while i > 0, workout.exercises[i-1].supersetID == ex.supersetID { i -= 1 }
            currentExerciseIndex = i
        } else {
            currentExerciseIndex = index
        }
        currentSetIndex = min(completedCount(for: workout.exercises[currentExerciseIndex]), max(0, workout.exercises[currentExerciseIndex].sets - 1))
    }

    /// Moves the session to the next incomplete set, searching the current exercise first,
    /// then subsequent exercises, then wrapping to earlier ones. Marks the session finished
    /// (index past the end) only when every set of every exercise is complete.
    func advanceToNextIncomplete(preferring startExercise: Int) {
        var searchOrder: [Int] = []
        let count = workout.exercises.count
        if count == 0 { return }

        let clamped = min(max(0, startExercise), count - 1)

        // Build search order: startExercise, then indices after it to the end, then 0..<startExercise
        searchOrder.append(clamped)
        for i in (clamped + 1)..<count {
            searchOrder.append(i)
        }
        for i in 0..<clamped {
            searchOrder.append(i)
        }

        // Find first incomplete exercise
        for idx in searchOrder {
            let ex = workout.exercises[idx]
            if !isExerciseComplete(ex) {
                // Handle superset: rewind to start of run like select() does
                var finalIndex = idx
                if ex.supersetID != nil {
                    var i = idx
                    while i > 0, workout.exercises[i - 1].supersetID == ex.supersetID { i -= 1 }
                    finalIndex = i
                }

                let wasDifferentExercise = currentExerciseIndex != finalIndex
                currentExerciseIndex = finalIndex

                // Set currentSetIndex to lowest incomplete set for the exercise at finalIndex
                let exAtFinal = workout.exercises[finalIndex]
                let completed = completedSetIndices[exAtFinal.id] ?? []
                var lowestIncomplete = exAtFinal.sets - 1
                for i in 0..<exAtFinal.sets {
                    if !completed.contains(i) {
                        lowestIncomplete = i
                        break
                    }
                }
                currentSetIndex = lowestIncomplete

                // Clear rest/timer only when the exercise changed
                if wasDifferentExercise {
                    isResting = false
                    restSecondsRemaining = 0
                    isExerciseTimerRunning = false
                    exerciseSecondsRemaining = 0
                }

                return
            }
        }

        // No incomplete exercise found — mark as finished
        currentExerciseIndex = workout.exercises.count
    }
}

extension Array {
    subscript(safe index: Int) -> Element? { indices.contains(index) ? self[index] : nil }
}
