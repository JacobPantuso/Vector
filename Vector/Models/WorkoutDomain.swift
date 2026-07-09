import Foundation
import FoundationModels

enum MuscleGroup: String, CaseIterable, Codable, Sendable {
    case chest = "Chest"
    case back = "Back"
    case shoulders = "Shoulders"
    case arms = "Arms"
    case legs = "Legs"
    case glutes = "Glutes"
    case core = "Core"
    case cardio = "Cardio"
}

@Generable
struct WorkoutWarmupStep: Codable, Sendable {
    @Guide(description: "Warm-up step title")
    var title: String

    @Guide(description: "Warm-up duration in minutes")
    var durationMinutes: Int

    @Guide(description: "What the user should focus on during the warm-up")
    var cue: String
}

@Generable
struct WorkoutExerciseStep: Codable, Sendable {
    @Guide(description: "Exercise name")
    var name: String

    @Guide(description: "Primary muscle groups targeted")
    var muscleGroups: [String]

    @Guide(description: "Number of working sets")
    var sets: Int

    @Guide(description: "Number of reps per set")
    var reps: Int

    @Guide(description: "Weight target as a short string such as 185 lb or bodyweight")
    var weight: String

    @Guide(description: "Rest between sets in seconds")
    var restSeconds: Int

    @Guide(description: "Technique cue for the exercise")
    var cue: String
}

@Generable
struct WorkoutCooldownStep: Codable, Sendable {
    @Guide(description: "Cooldown step title")
    var title: String

    @Guide(description: "Cooldown duration in minutes")
    var durationMinutes: Int

    @Guide(description: "Cooldown cue")
    var cue: String
}

@Generable
struct WorkoutPlan: Codable, Sendable {
    @Guide(description: "Workout title")
    var title: String

    @Guide(description: "One-line summary of the workout focus")
    var focus: String

    @Guide(description: "Estimated duration in minutes")
    var durationMinutes: Int

    @Guide(description: "Overall effort from 1 to 10")
    var effort: Int

    @Guide(description: "Warm-up sequence")
    var warmups: [WorkoutWarmupStep]

    @Guide(description: "Main workout exercises")
    var exercises: [WorkoutExerciseStep]

    @Guide(description: "Cooldown sequence")
    var cooldowns: [WorkoutCooldownStep]

    @Guide(description: "Whether this plan is ready to use today")
    var isTodayReady: Bool
}

struct WorkoutSessionState: Codable, Sendable {
    var plan: WorkoutPlan
    var startedAt: Date
    var currentExerciseIndex: Int
    var currentSetIndex: Int
    var remainingRestSeconds: Int

    var currentExercise: WorkoutExerciseStep? {
        guard plan.exercises.indices.contains(currentExerciseIndex) else { return nil }
        return plan.exercises[currentExerciseIndex]
    }

    var progressText: String {
        guard let currentExercise else { return "Ready to start" }
        return "\(currentExercise.name) • set \(currentSetIndex + 1)"
    }
}

// MARK: - Exercise Library (decoded from workouts.json)

struct LibraryExercise: Codable, Identifiable, Sendable {
    let id: String
    let name: String
    let aliases: [String]
    let equipment: String
    let targetMuscleGroup: String
    let movementPattern: String
    let primaryMuscle: String
    let secondaryMuscles: [String]
    let mechanics: String
    let force: String
    let difficulty: String
    let steps: [String]

    enum CodingKeys: String, CodingKey {
        case id, name, aliases, equipment
        case targetMuscleGroup = "target_muscle_group"
        case movementPattern = "movement_pattern"
        case primaryMuscle = "primary_muscle"
        case secondaryMuscles = "secondary_muscles"
        case mechanics, force, difficulty, steps
    }
}

extension LibraryExercise {
    /// Granular muscle category for the Train "Muscle Focus" breakdown.
    /// Maps the fine-grained `primaryMuscle` into one of seven display groups.
    /// Order matters: deltoid/shoulder checks run before the "lat" check so
    /// "Lateral Deltoids" is not mis-routed to Back.
    var muscleCategory: String {
        let m = primaryMuscle.lowercased()
        if m.contains("bicep") || m.contains("tricep") || m.contains("forearm") || m.contains("brachio") {
            return "Arms"
        }
        if m.contains("delt") || m.contains("shoulder") {
            return "Shoulders"
        }
        if m.contains("chest") || m.contains("pec") {
            return "Chest"
        }
        if m.contains("lat") || m.contains("trap") || m.contains("rhomboid") || m.contains("back") {
            return "Back"
        }
        if m.contains("glute") || m.contains("hip") {
            return "Hips & Glutes"
        }
        if m.contains("quad") || m.contains("hamstring") || m.contains("calf") || m.contains("calves") || m.contains("adductor") || m.contains("abductor") || m.contains("leg") {
            return "Legs"
        }
        if m.contains("oblique") || m.contains("core") || m.contains("ab") {
            return "Core"
        }
        // Fall back to the coarse target group (e.g. Cardio, Full Body).
        return targetMuscleGroup
    }
}

// MARK: - Manual Workout Building

enum ExerciseInputType: String, CaseIterable, Codable, Sendable {
    case reps = "Reps"
    case duration = "Duration"
}

/// Per-set weight and rep target. Used when an exercise varies load/reps across sets.
struct SetDetail: Codable, Sendable, Hashable {
    var weightKg: Double?
    var reps: Int
}

struct ManualExerciseEntry: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var supersetID: UUID? = nil
    var libraryExerciseId: String?
    var name: String
    var sets: Int
    var reps: Int
    var durationSeconds: Int
    var inputType: ExerciseInputType
    var weightKg: Double?
    var restSeconds: Int
    var notes: String
    /// Optional per-set overrides. When non-nil, each entry corresponds to one set.
    var setDetails: [SetDetail]? = nil

    /// Per-set targets resolved to always have length == `sets`.
    /// Uses `setDetails` when present; otherwise repeats the uniform `weightKg`/`reps`.
    var resolvedSetDetails: [SetDetail] {
        if let details = setDetails, !details.isEmpty {
            if details.count == sets { return details }
            if details.count > sets { return Array(details.prefix(sets)) }
            let pad = details.last ?? SetDetail(weightKg: weightKg, reps: reps)
            return details + Array(repeating: pad, count: sets - details.count)
        }
        return Array(repeating: SetDetail(weightKg: weightKg, reps: reps), count: max(sets, 0))
    }

    /// True when the sets differ in weight or reps.
    var hasPerSetVariation: Bool {
        guard let details = setDetails, details.count > 1 else { return false }
        let weights = Set(details.map { $0.weightKg ?? -1 })
        let repsSet = Set(details.map { $0.reps })
        return weights.count > 1 || repsSet.count > 1
    }

    /// Heaviest working-set weight — the representative load for progression.
    var topSetWeightKg: Double? {
        let weights = resolvedSetDetails.compactMap { $0.weightKg }.filter { $0 > 0 }
        return weights.max() ?? weightKg
    }

    /// Total reps × weight summed across all sets (reps exercises only).
    var totalVolumeKg: Double {
        guard inputType == .reps else { return 0 }
        return resolvedSetDetails.reduce(0) { $0 + Double($1.reps) * ($1.weightKg ?? 0) }
    }

    var displaySetsReps: String {
        if inputType == .duration {
            let mins = durationSeconds / 60
            let secs = durationSeconds % 60
            let timeStr = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
            return "\(sets)x \(timeStr)"
        }
        if hasPerSetVariation {
            let repsValues = resolvedSetDetails.map { $0.reps }
            let avgReps = repsValues.isEmpty ? reps : Int((Double(repsValues.reduce(0, +)) / Double(repsValues.count)).rounded())
            return "\(sets)x\(avgReps)"
        }
        return "\(sets)x\(reps)"
    }

    var displayWeight: String {
        if hasPerSetVariation {
            // Average only the weighted sets; bodyweight (BW) sets are ignored.
            let weights = resolvedSetDetails.compactMap { $0.weightKg }.filter { $0 > 0 }
            if weights.isEmpty { return "BW" }
            let avg = weights.reduce(0, +) / Double(weights.count)
            return String(format: "%.0f lbs", avg)
        }
        if let kg = weightKg, kg > 0 {
            return String(format: "%.1f lbs", kg)
        }
        return "BW"
    }
}

// MARK: - Saved Workout

enum WorkoutSource: String, CaseIterable, Codable, Sendable {
    case ai = "AI Generated"
    case manual = "Manual"
}

struct SavedWorkout: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var title: String
    var focus: String
    var createdAt: Date = Date()
    var source: WorkoutSource
    var aiPlan: WorkoutPlan?
    var exercises: [ManualExerciseEntry]
    var durationMinutes: Int
    var effort: Int

    var exerciseCount: Int { exercises.count }

    var muscleGroupSummary: String {
        exercises.prefix(3).map(\.name).joined(separator: ", ")
    }
}

// MARK: - Superset Grouping

/// A run of one or more consecutive exercises. A group with more than one entry,
/// all sharing the same non-nil supersetID, is a superset performed back-to-back.
struct ExerciseGroup: Identifiable, Sendable {
    let id: UUID
    var entries: [ManualExerciseEntry]
    var isSuperset: Bool { entries.count > 1 }
}

extension Array where Element == ManualExerciseEntry {
    /// Groups consecutive entries that share the same non-nil supersetID into supersets.
    /// Entries with a nil supersetID each become their own single-entry group.
    func groupedBySuperset() -> [ExerciseGroup] {
        var groups: [ExerciseGroup] = []
        for entry in self {
            if let sid = entry.supersetID,
               let lastIdx = groups.indices.last,
               groups[lastIdx].entries.last?.supersetID == sid {
                groups[lastIdx].entries.append(entry)
            } else {
                groups.append(ExerciseGroup(id: entry.supersetID ?? entry.id, entries: [entry]))
            }
        }
        return groups
    }
}

