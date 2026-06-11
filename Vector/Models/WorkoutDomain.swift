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

// MARK: - Manual Workout Building

enum ExerciseInputType: String, CaseIterable, Codable, Sendable {
    case reps = "Reps"
    case duration = "Duration"
}

struct ManualExerciseEntry: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    var libraryExerciseId: String?
    var name: String
    var sets: Int
    var reps: Int
    var durationSeconds: Int
    var inputType: ExerciseInputType
    var weightKg: Double?
    var restSeconds: Int
    var notes: String

    var displaySetsReps: String {
        if inputType == .duration {
            let mins = durationSeconds / 60
            let secs = durationSeconds % 60
            let timeStr = mins > 0 ? "\(mins)m \(secs)s" : "\(secs)s"
            return "\(sets)x \(timeStr)"
        } else {
            return "\(sets)x\(reps)"
        }
    }

    var displayWeight: String {
        if let kg = weightKg, kg > 0 {
            return String(format: "%.1f kg", kg)
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
