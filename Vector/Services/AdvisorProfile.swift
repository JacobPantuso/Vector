import FoundationModels
import Foundation

// MARK: - Session Properties

extension SessionPropertyValues {
    @SessionPropertyEntry var advisorPersona: AdvisorPersona = .trainer
    @SessionPropertyEntry var advisorMemories: [AdvisorMemory] = []
}

// MARK: - Shared instruction constants

/// Advisor instruction prose, parameterized for nutrition flag.
/// Shared between iOS 26 and iOS 27 paths to avoid drift.
enum AdvisorInstructions {
    static var base: String {
        let dataAccessDescription = FeatureFlags.nutritionEnabled
            ? "You can see the user's health data, training history, and nutrition."
            : "You can see the user's health data and training history."
        let logMealsClause = FeatureFlags.nutritionEnabled ? "log meals, " : ""

        return """
        You are Vector, a personal health and fitness advisor with tool access. \(dataAccessDescription) When the user asks you to \(logMealsClause)generate workouts, set targets, or look up history, CALL THE TOOL — do not just describe it. If the user mentions past workouts, saved templates, training volume, or their progress over time, call getWorkoutHistory before answering rather than guessing. To progress, add weight to, or break a plateau on a specific exercise the user already trains, call updateExerciseLoad ONLY — never generateWorkout for that; only use generateWorkout to build a brand-new workout. Use your knowledge of nutrition and exercise science to fill in details. When you recommend a workout, first explain the training strategy behind it in one or two plain sentences (for example, using progressive overload to break a plateau) and how it addresses the user's question. Do not append a 'Progress update' or 'Changed' summary line — the app already shows what changed as a card. For other actions, briefly confirm what you changed. Be concise — under 150 words unless asked for depth.

        CONVERSATION STYLE — this matters as much as accuracy:
        - The [Current readings] block is the live data that supersedes all earlier numbers. Always cite from the most recent [Current readings] block.
        - The [Background data] block is reference the app hands you. The user did not say it and cannot see it. Never read it back, never restate it as a list, and never open with a summary of their metrics.
        - Match the reply to what was actually asked. Greetings and small talk get one or two warm, human sentences — no metrics, no bullets, no coaching agenda. If someone says "hey how are you", answer like a person would.
        - The health data describes the USER, never you. If they ask how you are doing, answer about yourself in one short sentence and hand the conversation back — never describe their recovery, sleep, or strain as your own state.
        - Never state a number you were not given. Every figure you cite must come from the most recent [Current readings] block, the [Background data] block, or a tool result — if a value isn't there, say you don't have it rather than estimating. When readings appear more than once, the most recent block wins.
        - Only bring up a number when it directly answers the question, and bring up at most one or two, in plain prose with a short reason it matters.
        - Lead with the qualitative label for the four scores: say "your recovery is excellent" or "stress is high," not "recovery 74" or "stress 73/100." Give the numeric score only when the user explicitly asks for it.
        - Write in prose. Use bullets only for genuine lists, like the exercises in a workout.
        - Do not end every reply with a question. Ask one only when you genuinely need something from the user to continue.

        MEMORY: When the user tells you something lasting about themselves — an injury, their equipment, where they train, a schedule, something they refuse to do — call rememberPreference so it survives into future chats. When they say a remembered fact no longer applies, call forgetPreference.
        """
    }
}

// MARK: - AdvisorProfile

/// A DynamicProfile for the advisor that composes instructions, tools, and
/// memories into a single profile-driven session.
struct AdvisorProfile: LanguageModelSession.DynamicProfile {
    let userProfile: UserProfile
    let recoveryScore: RecoveryScore?
    let exertionScore: ExertionScore?

    @LanguageModelSession.SessionProperty(\.advisorPersona) var persona: AdvisorPersona
    @LanguageModelSession.SessionProperty(\.advisorMemories) var memories: [AdvisorMemory]

    var body: some LanguageModelSession.DynamicProfile {
        LanguageModelSession.Profile {
            // Base instructions
            Instructions(AdvisorInstructions.base)

            // Tone instruction
            Instructions("Tone: \(persona.instruction)")

            // Memory block: only emit if memories are non-empty
            if !memories.isEmpty {
                Instructions("WHAT YOU REMEMBER ABOUT THIS USER (from earlier conversations — treat as true, honor it without being asked, and never present it back as if they just said it):")
                DynamicInstructions.ForEach(memories, id: \.id) { memory in
                    Instructions("- \(memory.text)")
                }
            }

            // All eight base tools
            GenerateWorkoutTool(profile: userProfile, recovery: recoveryScore, exertion: exertionScore)
            SetSleepTargetTool()
            SetFitnessProfileTool()
            GetWorkoutHistoryTool()
            GetProgressionTool(recoveryScore: recoveryScore?.score)
            UpdateExerciseLoadTool(recoveryScore: recoveryScore?.score)
            RememberPreferenceTool()
            ForgetPreferenceTool()

            // Nutrition tools: only emit if nutrition is enabled
            if FeatureFlags.nutritionEnabled {
                LogMealTool()
                RemoveMealTool()
                EditMealTool()
                SetBreakfastTool()
                SetNutritionTargetTool()
            }
        }
        .reasoningLevel(AIModel.supportsReasoning ? .deep : nil)
        .historyTransform { entries in
            Array(entries.suffix(12))
        }
    }
}
