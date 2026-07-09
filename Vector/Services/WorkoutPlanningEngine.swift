import Foundation
import FoundationModels

struct WorkoutPlanningEngine {
    static func generatePlan(
        from prompt: String,
        profile: UserProfile,
        recoveryScore: RecoveryScore?,
        exertionScore: ExertionScore?
    ) async -> WorkoutPlan {
        let recovered = recoveryScore?.score ?? 0
        let loadStatus = exertionScore?.loadStatus.label ?? "unknown"
        let instructions = """
        You are Vector's workout planner.
        Generate a safe, realistic strength or conditioning workout as structured data.
        Match the user's goal, age range, training frequency, recovery, and current load.
        Include warm-ups, working sets, rest periods, cooldowns, and exact weights where possible.
        Keep the workout under 75 minutes.
        Keep the workout title under 40 characters. Use short, descriptive names like "Push Day" or "Upper Body Strength".
        """

        let request = """
        User goal: \(profile.goal.rawValue)
        Age range: \(profile.ageRange.rawValue)
        Training days/week: \(profile.trainingDaysPerWeek)
        Sleep target: \(profile.sleepTargetHours) hours
        Recovery score: \(recovered)
        Load status: \(loadStatus)
        Workout request: \(prompt)
        """

        if SystemLanguageModel.default.availability == .available {
            let session = LanguageModelSession(
                model: SystemLanguageModel.default,
                instructions: instructions
            )
            if let plan = try? await session.respond(to: request, generating: WorkoutPlan.self) {
                return plan.content
            }
        }

        return fallbackPlan(for: prompt, profile: profile, recoveryScore: recovered)
    }

    static func planJSON(_ plan: WorkoutPlan) -> String {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        guard let data = try? encoder.encode(plan), let json = String(data: data, encoding: .utf8) else {
            return "{}"
        }
        return json
    }

    private static func fallbackPlan(for prompt: String, profile: UserProfile, recoveryScore: Int) -> WorkoutPlan {
        let isRecoveryFocused = recoveryScore < 45
        let title = String((prompt.isEmpty ? "Daily Session" : prompt.capitalized).prefix(40))
        let focus = isRecoveryFocused ? "Movement quality and easy volume" : "Progressive overload and clean sets"
        let effort = isRecoveryFocused ? 5 : 7

        return WorkoutPlan(
            title: title,
            focus: focus,
            durationMinutes: isRecoveryFocused ? 35 : 55,
            effort: effort,
            warmups: [
                WorkoutWarmupStep(title: "Raise temperature", durationMinutes: 5, cue: "Walk, bike, or row to get moving."),
                WorkoutWarmupStep(title: "Ramp the first lift", durationMinutes: 6, cue: "Use 2-3 gradual build-up sets.")
            ],
            exercises: [
                WorkoutExerciseStep(name: "Primary lift", muscleGroups: [profile.goal == .muscleGain ? "Chest" : "Legs"], sets: 4, reps: isRecoveryFocused ? 6 : 8, weight: "Moderate", restSeconds: 120, cue: "Keep the first rep smooth."),
                WorkoutExerciseStep(name: "Accessory pair", muscleGroups: ["Core", "Back"], sets: 3, reps: 10, weight: "Bodyweight", restSeconds: 75, cue: "Move clean and controlled.")
            ],
            cooldowns: [
                WorkoutCooldownStep(title: "Breathe down", durationMinutes: 3, cue: "Use nasal breathing to bring the heart rate down."),
                WorkoutCooldownStep(title: "Reset", durationMinutes: 4, cue: "Finish with mobility for the worked muscles.")
            ],
            isTodayReady: true
        )
    }
}
