import FoundationModels
import Foundation

// MARK: - Advisor activity (live thought-process trail + undo log)

/// A single step in the Advisor's visible thought process — either a one-line
/// reasoning preamble or a live tool action (with a spinner until `done`).
struct AdvisorStep: Identifiable {
    enum Kind { case reasoning, tool }
    let id = UUID()
    let kind: Kind
    var text: String
    var done: Bool
}

/// A reversible change the Advisor made to app state.
struct AdvisorAction: Identifiable {
    let id = UUID()
    let summary: String
    var editTargetMealID: UUID? = nil
    let undo: @MainActor () -> Void
}

/// A workout the Advisor suggests but does NOT auto-apply. The user Adds or Dismisses it in the UI.
struct AdvisorRecommendation: Identifiable {
    let id = UUID()
    let title: String
    let focus: String
    let durationMinutes: Int
    let exerciseCount: Int
    let effort: Int
    let exerciseNames: [String]
    let add: @MainActor () -> Void
}

/// One saved workout that contains an exercise to progress, with a proposed heavier target.
struct AdvisorWorkoutMatch: Identifiable {
    let id: UUID              // the SavedWorkout's id
    let title: String
    let currentWeightKg: Double
    let newWeightKg: Double
    let apply: @MainActor () -> Void
}

/// A suggestion to bump an exercise's load across the user's existing saved workouts.
struct AdvisorExerciseUpdate: Identifiable {
    let id = UUID()
    let exerciseName: String
    let matches: [AdvisorWorkoutMatch]
}

/// MainActor-isolated singleton the tools report into while a turn runs.
/// The view observes this live; `InsightEngine` snapshots it onto the message at the end.
@MainActor
@Observable
final class AdvisorActivity {
    static let shared = AdvisorActivity()

    var steps: [AdvisorStep] = []
    var actions: [AdvisorAction] = []
    var recommendations: [AdvisorRecommendation] = []
    var exerciseUpdates: [AdvisorExerciseUpdate] = []
    /// The model's reasoning, streamed live during the current turn.
    var liveReasoning: String = ""

    func reset() {
        steps = []
        actions = []
        recommendations = []
        exerciseUpdates = []
        liveReasoning = ""
    }

    @discardableResult
    func beginStep(_ text: String) -> UUID {
        let step = AdvisorStep(kind: .tool, text: text, done: false)
        steps.append(step)
        return step.id
    }

    func finishStep(_ id: UUID, result: String) {
        guard let i = steps.firstIndex(where: { $0.id == id }) else { return }
        steps[i].text = result
        steps[i].done = true
    }

    /// Live-updates the streamed reasoning preamble (upserts a single reasoning step at the top).
    func updateReasoning(_ text: String) {
        liveReasoning = text
        if let i = steps.firstIndex(where: { $0.kind == .reasoning }) {
            steps[i].text = text
        } else {
            steps.insert(AdvisorStep(kind: .reasoning, text: text, done: true), at: 0)
        }
    }

    func addReasoning(_ text: String) {
        updateReasoning(text)
    }

    func recordAction(_ summary: String, editTargetMealID: UUID? = nil, undo: @escaping @MainActor () -> Void) {
        actions.append(AdvisorAction(summary: summary, editTargetMealID: editTargetMealID, undo: undo))
    }

    func recordRecommendation(_ recommendation: AdvisorRecommendation) {
        recommendations.append(recommendation)
    }

    func recordExerciseUpdate(_ update: AdvisorExerciseUpdate) {
        exerciseUpdates.append(update)
    }
}

// MARK: - Tools

/// Log a meal the user ate today, with macros (estimated from world knowledge if needed).
struct LogMealTool: Tool {
    typealias Output = String

    let name = "logMeal"
    let description = "Log a food or meal the user ate today along with its nutrition. Use your nutrition knowledge to estimate calories and macros when the user does not give exact numbers."

    @Generable
    struct Arguments {
        @Guide(description: "Short name of the food or meal, e.g. 'Chicken & rice bowl'")
        var name: String
        @Guide(description: "Total calories in kcal")
        var calories: Double
        @Guide(description: "Protein in grams")
        var protein: Double
        @Guide(description: "Carbohydrates in grams")
        var carbs: Double
        @Guide(description: "Fat in grams")
        var fat: Double
    }

    func call(arguments args: Arguments) async throws -> String {
        let entry = FoodLogEntry(
            name: args.name,
            calories: args.calories,
            protein: args.protein,
            carbs: args.carbs,
            fat: args.fat,
            source: .manual
        )
        await MainActor.run {
            let stepID = AdvisorActivity.shared.beginStep("Logging \(args.name)…")
            FoodLogService.shared.add(entry)
            AdvisorActivity.shared.finishStep(stepID, result: "Logged \(args.name) — \(Int(args.calories)) kcal")
            AdvisorActivity.shared.recordAction("Logged \(args.name) (\(Int(args.calories)) kcal)", editTargetMealID: entry.id) {
                FoodLogService.shared.remove(entry)
            }
        }
        return ("Logged \(args.name): \(Int(args.calories)) kcal, \(Int(args.protein))g protein, \(Int(args.carbs))g carbs, \(Int(args.fat))g fat.")
    }
}

/// Remove the most recent matching meal logged today.
struct RemoveMealTool: Tool {
    let name = "removeMeal"
    let description = "Remove a meal the user logged today, matched by name."

    @Generable
    struct Arguments {
        @Guide(description: "Name (or part of the name) of the logged meal to remove")
        var name: String
    }

    func call(arguments args: Arguments) async throws -> String {
        let query = args.name.lowercased()
        let removed: FoodLogEntry? = await MainActor.run {
            let match = FoodLogService.shared.todayEntries.last { $0.name.lowercased().contains(query) }
            guard let match else { return nil }
            let stepID = AdvisorActivity.shared.beginStep("Removing \(match.name)…")
            FoodLogService.shared.remove(match)
            AdvisorActivity.shared.finishStep(stepID, result: "Removed \(match.name)")
            AdvisorActivity.shared.recordAction("Removed \(match.name)") {
                FoodLogService.shared.add(match)
            }
            return match
        }
        if let removed {
            return ("Removed \(removed.name) from today's log.")
        }
        return ("No meal matching '\(args.name)' was found in today's log.")
    }
}

/// Edit the calories/macros of a meal already logged today.
struct EditMealTool: Tool {
    let name = "editMeal"
    let description = "Edit the calories or macros of a meal the user already logged today, matched by name. Pass 0 for any value to leave it unchanged."

    @Generable
    struct Arguments {
        @Guide(description: "Name (or part of the name) of the logged meal to edit")
        var name: String
        @Guide(description: "New total calories, or 0 to leave unchanged")
        var calories: Double
        @Guide(description: "New protein grams, or 0 to leave unchanged")
        var protein: Double
        @Guide(description: "New carb grams, or 0 to leave unchanged")
        var carbs: Double
        @Guide(description: "New fat grams, or 0 to leave unchanged")
        var fat: Double
    }

    func call(arguments args: Arguments) async throws -> String {
        let result: String = await MainActor.run {
            let query = args.name.lowercased()
            guard let match = FoodLogService.shared.todayEntries.last(where: { $0.name.lowercased().contains(query) }) else {
                return "No meal matching '\(args.name)' was found in today's log."
            }
            let prior = match
            let stepID = AdvisorActivity.shared.beginStep("Editing \(match.name)…")
            var updated = match
            if args.calories > 0 { updated.calories = args.calories }
            if args.protein > 0 { updated.protein = args.protein }
            if args.carbs > 0 { updated.carbs = args.carbs }
            if args.fat > 0 { updated.fat = args.fat }
            FoodLogService.shared.update(updated)
            let label = "Updated \(updated.name) — \(Int(updated.calories)) kcal"
            AdvisorActivity.shared.finishStep(stepID, result: label)
            AdvisorActivity.shared.recordAction(label, editTargetMealID: updated.id) {
                FoodLogService.shared.update(prior)
            }
            return "Updated \(updated.name): \(Int(updated.calories)) kcal, \(Int(updated.protein))g protein, \(Int(updated.carbs))g carbs, \(Int(updated.fat))g fat."
        }
        return result
    }
}

/// Generate a structured workout and present it to the user as a recommendation card they can Add or Dismiss.
struct GenerateWorkoutTool: Tool {
    let name = "generateWorkout"
    let description = "Build a BRAND-NEW workout from scratch, shown as an Add/Dismiss card (NOT saved automatically). Use this ONLY when the user wants a new workout. If the user wants to progress, add weight to, or break a plateau on a specific exercise they ALREADY train, do NOT use this — use updateExerciseLoad instead."

    let profile: UserProfile
    let recovery: RecoveryScore?
    let exertion: ExertionScore?

    @Generable
    struct Arguments {
        @Guide(description: "What the workout should focus on, e.g. 'push day', 'full-body conditioning', 'legs and core'")
        var focus: String
        @Guide(description: "Target duration in minutes, e.g. 45")
        var durationMinutes: Int
    }

    func call(arguments args: Arguments) async throws -> String {
        let stepID = await MainActor.run {
            AdvisorActivity.shared.beginStep("Preparing workout…")
        }
        let prompt = "\(args.focus), about \(args.durationMinutes) minutes"
        let plan = await WorkoutPlanningEngine.generatePlan(
            from: prompt,
            profile: profile,
            recoveryScore: recovery,
            exertionScore: exertion
        )
        let entries: [ManualExerciseEntry] = plan.exercises.map { step in
            ManualExerciseEntry(
                libraryExerciseId: nil,
                name: step.name,
                sets: step.sets,
                reps: step.reps,
                durationSeconds: 0,
                inputType: .reps,
                weightKg: nil,
                restSeconds: step.restSeconds,
                notes: step.cue
            )
        }
        let saved = SavedWorkout(
            title: plan.title,
            focus: "Generated Workout",
            source: .ai,
            aiPlan: plan,
            exercises: entries,
            durationMinutes: plan.durationMinutes,
            effort: plan.effort
        )
        await MainActor.run {
            AdvisorActivity.shared.finishStep(stepID, result: "Strength workout")
            AdvisorActivity.shared.recordRecommendation(
                AdvisorRecommendation(
                    title: plan.title,
                    focus: plan.focus,
                    durationMinutes: plan.durationMinutes,
                    exerciseCount: plan.exercises.count,
                    effort: plan.effort,
                    exerciseNames: entries.map { $0.name },
                    add: { WorkoutStorageService.shared.save(saved) }
                )
            )
        }
        return "Prepared a recommended workout '\(plan.title)' (\(plan.exercises.count) exercises, ~\(plan.durationMinutes) min). A card is shown below this message for the user to Add or Dismiss — it has NOT been saved. In your reply, briefly explain HOW this workout addresses the user's question. If you reference it, call it 'the card below' (never 'in your app' or 'in the app'). Do not claim it was saved or added."
    }
}

/// Adjust the auto-logged breakfast schedule (enable/disable, time, optionally add one item).
struct SetBreakfastTool: Tool {
    let name = "setBreakfastSchedule"
    let description = "Configure the user's auto-logged breakfast: enable or disable it, set the time, and optionally add one breakfast item."

    @Generable
    struct Arguments {
        @Guide(description: "Whether auto-breakfast logging should be enabled")
        var enabled: Bool
        @Guide(description: "Hour of day (0-23) to auto-log breakfast")
        var hour: Int
        @Guide(description: "Minute (0-59) to auto-log breakfast")
        var minute: Int
        @Guide(description: "Optional name of a breakfast item to add; empty string to add nothing")
        var addItemName: String
        @Guide(description: "Calories for the added item, 0 if none")
        var addItemCalories: Double
        @Guide(description: "Protein grams for the added item, 0 if none")
        var addItemProtein: Double
        @Guide(description: "Carb grams for the added item, 0 if none")
        var addItemCarbs: Double
        @Guide(description: "Fat grams for the added item, 0 if none")
        var addItemFat: Double
    }

    func call(arguments args: Arguments) async throws -> String {
        let summary: String = await MainActor.run {
            let prior = FoodLogService.shared.breakfastSchedule
            let stepID = AdvisorActivity.shared.beginStep("Updating breakfast schedule…")
            var schedule = prior
            schedule.isEnabled = args.enabled
            schedule.scheduledHour = min(23, max(0, args.hour))
            schedule.scheduledMinute = min(59, max(0, args.minute))
            if !args.addItemName.trimmingCharacters(in: .whitespaces).isEmpty {
                schedule.items.append(BreakfastSchedule.ScheduledItem(
                    name: args.addItemName,
                    calories: args.addItemCalories,
                    protein: args.addItemProtein,
                    carbs: args.addItemCarbs,
                    fat: args.addItemFat
                ))
            }
            FoodLogService.shared.breakfastSchedule = schedule
            FoodLogService.shared.saveSchedule()
            let label = "Breakfast schedule \(args.enabled ? "on" : "off") at \(String(format: "%02d:%02d", schedule.scheduledHour, schedule.scheduledMinute))"
            AdvisorActivity.shared.finishStep(stepID, result: label)
            AdvisorActivity.shared.recordAction(label) {
                FoodLogService.shared.breakfastSchedule = prior
                FoodLogService.shared.saveSchedule()
            }
            return label
        }
        return (summary + ".")
    }
}

/// Set the user's daily nutrition targets (stored as overrides read by the Nutrition tab).
struct SetNutritionTargetTool: Tool {
    let name = "setNutritionTarget"
    let description = "Set the user's daily nutrition targets (calories and macros). Pass 0 for any value that should stay unchanged."

    @Generable
    struct Arguments {
        @Guide(description: "New daily calorie target in kcal, or 0 to leave unchanged")
        var calories: Double
        @Guide(description: "New daily protein target in grams, or 0 to leave unchanged")
        var protein: Double
        @Guide(description: "New daily carbohydrate target in grams, or 0 to leave unchanged")
        var carbs: Double
        @Guide(description: "New daily fat target in grams, or 0 to leave unchanged")
        var fat: Double
    }

    func call(arguments args: Arguments) async throws -> String {
        let summary: String = await MainActor.run {
            let defaults = UserDefaults.standard
            let priorCalories = defaults.double(forKey: "nutritionTargetCalories")
            let priorProtein = defaults.double(forKey: "nutritionTargetProtein")
            let priorCarbs = defaults.double(forKey: "nutritionTargetCarbs")
            let priorFat = defaults.double(forKey: "nutritionTargetFat")
            let stepID = AdvisorActivity.shared.beginStep("Updating nutrition targets…")
            var parts: [String] = []
            if args.calories > 0 {
                defaults.set(args.calories, forKey: "nutritionTargetCalories")
                parts.append("\(Int(args.calories)) kcal")
            }
            if args.protein > 0 {
                defaults.set(args.protein, forKey: "nutritionTargetProtein")
                parts.append("\(Int(args.protein))g protein")
            }
            if args.carbs > 0 {
                defaults.set(args.carbs, forKey: "nutritionTargetCarbs")
                parts.append("\(Int(args.carbs))g carbs")
            }
            if args.fat > 0 {
                defaults.set(args.fat, forKey: "nutritionTargetFat")
                parts.append("\(Int(args.fat))g fat")
            }
            let label = parts.isEmpty ? "No targets changed" : "Target set: " + parts.joined(separator: ", ")
            AdvisorActivity.shared.finishStep(stepID, result: label)
            AdvisorActivity.shared.recordAction(label) {
                defaults.set(priorCalories, forKey: "nutritionTargetCalories")
                defaults.set(priorProtein, forKey: "nutritionTargetProtein")
                defaults.set(priorCarbs, forKey: "nutritionTargetCarbs")
                defaults.set(priorFat, forKey: "nutritionTargetFat")
            }
            return label
        }
        return (summary + ".")
    }
}

/// Set the user's nightly sleep target in hours.
struct SetSleepTargetTool: Tool {
    let name = "setSleepTarget"
    let description = "Set the user's nightly sleep target in hours."

    @Generable
    struct Arguments {
        @Guide(description: "Target nightly sleep in hours, e.g. 8")
        var hours: Double
    }

    func call(arguments args: Arguments) async throws -> String {
        let summary: String = await MainActor.run {
            let defaults = UserDefaults.standard
            let prior = defaults.object(forKey: UserProfileStorage.sleepTargetHours) as? Double ?? UserProfile.defaultSleepTargetHours
            let stepID = AdvisorActivity.shared.beginStep("Updating sleep target…")
            let clamped = min(14, max(4, args.hours))
            defaults.set(clamped, forKey: UserProfileStorage.sleepTargetHours)
            let label = "Sleep target set to \(String(format: "%.1f", clamped))h"
            AdvisorActivity.shared.finishStep(stepID, result: label)
            AdvisorActivity.shared.recordAction(label) {
                defaults.set(prior, forKey: UserProfileStorage.sleepTargetHours)
            }
            return label
        }
        return (summary + ".")
    }
}

/// Read-only: the user's saved workout templates and recent completed workouts.
struct GetWorkoutHistoryTool: Tool {
    let name = "getWorkoutHistory"
    let description = "Get the user's saved workout templates and recent completed workouts with training volume."

    @Generable
    struct Arguments {
        @Guide(description: "How many recent completed workouts to return, e.g. 5")
        var maxResults: Int
    }

    func call(arguments args: Arguments) async throws -> String {
        await MainActor.run {
            let templates = WorkoutStorageService.shared.savedWorkouts
            let limit = max(1, min(10, args.maxResults))
            let recent = WorkoutCompletionStore.shared.records.sorted { $0.date > $1.date }.prefix(limit)
            var lines: [String] = []
            lines.append("Saved templates (\(templates.count)): " + (templates.isEmpty ? "none" : templates.prefix(8).map(\.title).joined(separator: ", ")))
            if recent.isEmpty {
                lines.append("No completed workouts recorded yet.")
            } else {
                lines.append("Recent completions:")
                for r in recent {
                    let title = templates.first { $0.id == r.templateID }?.title ?? "Workout"
                    lines.append("• \(title) — \(Int(r.totalVolume)) lb volume, \(r.durationMinutes)m on \(r.date.formatted(date: .abbreviated, time: .omitted))")
                }
            }
            return lines.joined(separator: "\n")
        }
    }
}

/// Read-only: recent performance and progressive-overload recommendation for one exercise.
struct GetProgressionTool: Tool {
    let name = "getExerciseProgression"
    let description = "Look up the user's recent performance and progressive-overload recommendation for a specific exercise by name."
    let recoveryScore: Int?

    @Generable
    struct Arguments {
        @Guide(description: "Exercise name, e.g. 'Barbell Bench Press'")
        var exerciseName: String
    }

    func call(arguments args: Arguments) async throws -> String {
        await MainActor.run {
            let entry = ManualExerciseEntry(
                libraryExerciseId: nil,
                name: args.exerciseName,
                sets: 3,
                reps: 8,
                durationSeconds: 0,
                inputType: .reps,
                weightKg: nil,
                restSeconds: 60,
                notes: ""
            )
            var parts: [String] = []
            if let last = ExerciseProgressionStore.shared.lastPerformance(for: entry) {
                parts.append("Last: \(last.reps)×\(Int(last.weightKg)) lb on \(last.date.formatted(date: .abbreviated, time: .omitted))")
            } else {
                parts.append("No logged history yet.")
            }
            if let insight = ProgressionAdvisor.insight(for: entry, recoveryScore: recoveryScore) {
                parts.append("Coach: \(insight.headline) — \(insight.detail)")
            }
            return "\(args.exerciseName): " + parts.joined(separator: " ")
        }
    }
}

/// Find the user's saved workouts containing an exercise and propose bumping its load to the next progressive-overload step.
struct UpdateExerciseLoadTool: Tool {
    let name = "updateExerciseLoad"
    let description = "For an exercise the user is plateaued on or wants to push heavier, find their saved workouts that already contain it and propose increasing its weight to the next progressive-overload step. PREFER THIS over generateWorkout when the exercise already appears in one of the user's saved workouts. If none are found, it returns a note telling you to call generateWorkout instead."
    let recoveryScore: Int?

    @Generable
    struct Arguments {
        @Guide(description: "Exercise name to progress, e.g. 'Dumbbell Curl'")
        var exerciseName: String
    }

    func call(arguments args: Arguments) async throws -> String {
        await MainActor.run {
            let checkStep = AdvisorActivity.shared.beginStep("Reading your workout data…")
            let name = args.exerciseName.trimmingCharacters(in: .whitespaces).lowercased()
            let templates = WorkoutStorageService.shared.savedWorkouts
            let prefs = EquipmentPreferencesStore.shared.preferences
            var matches: [AdvisorWorkoutMatch] = []

            for template in templates {
                guard let entry = template.exercises.first(where: { $0.name.lowercased() == name }) else { continue }
                let current = entry.weightKg ?? 0
                guard current > 0 else { continue }

                let insight = ProgressionAdvisor.insight(for: entry, recoveryScore: recoveryScore)
                let libExercise = ExerciseLibrary.shared.allExercises.first { $0.name.lowercased() == entry.name.lowercased() }
                let equipKind = libExercise.map { EquipmentKind.classify(equipment: $0.equipment, name: $0.name) }
                    ?? EquipmentKind.classify(equipment: "", name: entry.name)
                let step = prefs.increment(for: equipKind)

                var newWeight = insight?.suggestedWeightKg ?? (current + step)
                if newWeight <= current { newWeight = current + step }

                let workoutID = template.id
                let exName = entry.name
                let target = newWeight
                matches.append(
                    AdvisorWorkoutMatch(
                        id: workoutID,
                        title: template.title,
                        currentWeightKg: current,
                        newWeightKg: newWeight,
                        apply: {
                            guard var wo = WorkoutStorageService.shared.savedWorkouts.first(where: { $0.id == workoutID }) else { return }
                            for i in wo.exercises.indices where wo.exercises[i].name.lowercased() == exName.lowercased() {
                                wo.exercises[i].weightKg = target
                                wo.exercises[i].setDetails = nil
                            }
                            WorkoutStorageService.shared.save(wo)
                        }
                    )
                )
            }

            if matches.isEmpty {
                AdvisorActivity.shared.finishStep(checkStep, result: "No saved workouts found")
                return "The user has no saved workout containing '\(args.exerciseName)'. Call generateWorkout to build a new, heavier-focused workout instead."
            }

            AdvisorActivity.shared.finishStep(checkStep, result: "Found \(matches.count) workout\(matches.count == 1 ? "" : "s")")

            let analyzeStep = AdvisorActivity.shared.beginStep("Analyzing progression data…")
            AdvisorActivity.shared.finishStep(analyzeStep, result: "Progression analyzed")

            AdvisorActivity.shared.recordExerciseUpdate(
                AdvisorExerciseUpdate(exerciseName: args.exerciseName, matches: matches)
            )
            let list = matches.map { $0.title }.joined(separator: ", ")
            return "Found \(matches.count) of the user's EXISTING workout(s) that include '\(args.exerciseName)': \(list). A card below this message lets them pick which of these workouts to bump to the next progressive-overload weight. In your reply: (1) briefly explain that progressive overload — small weight increases — is what breaks the plateau, and (2) say you found their existing workouts and can bump the weight in the card below. Do NOT describe or offer a brand-new routine, and do NOT call generateWorkout. Refer to it as 'the card below' or 'your workouts below' (never 'in your app'). Do not claim you changed anything — the user chooses on the card."
        }
    }
}

/// Update the user's fitness profile: biological sex, fitness level, and primary activity.
struct SetFitnessProfileTool: Tool {
    let name = "setFitnessProfile"
    let description = "Update the user's fitness profile: biological sex (male/female/unspecified), fitness level (sedentary/recreational/trained/athlete), and/or primary activity (strength/endurance/mixed). Use when the user describes their training background or asks to change it. Leave a field blank to keep it unchanged."

    @Generable
    struct Arguments {
        @Guide(description: "Biological sex: male, female, or unspecified. Empty to leave unchanged.")
        var biologicalSex: String
        @Guide(description: "Fitness level: sedentary, recreational, trained, or athlete. Empty to leave unchanged.")
        var fitnessLevel: String
        @Guide(description: "Primary activity: strength, endurance, or mixed. Empty to leave unchanged.")
        var primaryActivity: String
    }

    func call(arguments args: Arguments) async throws -> String {
        var changes: [String] = []
        await MainActor.run {
            let stepID = AdvisorActivity.shared.beginStep("Updating fitness profile…")
            if let sex = BiologicalSex.allCases.first(where: { $0.rawValue.lowercased() == args.biologicalSex.lowercased() }) {
                UserDefaults.standard.set(sex.rawValue, forKey: UserProfileStorage.biologicalSex)
                changes.append("sex \(sex.rawValue)")
            }
            if let level = FitnessLevel.allCases.first(where: { $0.rawValue.lowercased() == args.fitnessLevel.lowercased() }) {
                UserDefaults.standard.set(level.rawValue, forKey: UserProfileStorage.fitnessLevel)
                changes.append("level \(level.rawValue)")
            }
            if let activity = PrimaryActivity.allCases.first(where: { $0.rawValue.lowercased() == args.primaryActivity.lowercased() }) {
                UserDefaults.standard.set(activity.rawValue, forKey: UserProfileStorage.primaryActivity)
                changes.append("activity \(activity.rawValue)")
            }
            AdvisorActivity.shared.finishStep(stepID, result: changes.isEmpty ? "No changes" : "Updated " + changes.joined(separator: ", "))
        }
        return changes.isEmpty
            ? "No recognizable fitness-profile values were provided."
            : "Updated fitness profile: " + changes.joined(separator: ", ") + "."
    }
}

/// Save a durable fact about the user (an injury, equipment constraint, schedule, or preference)
/// so it is remembered in future conversations.
struct RememberPreferenceTool: Tool {
    typealias Output = String

    let name = "rememberPreference"
    let description = "Save a durable fact about the user so it is remembered in future conversations — an injury or limitation, available equipment, gym or home training, schedule constraints, exercises they like or refuse, dietary preferences, or a coaching style they asked for. Call this whenever the user states a lasting preference or constraint about themselves, even if they did not explicitly ask you to remember it. Do not use it for one-off questions or for numbers the app already tracks."

    @Generable
    struct Arguments {
        @Guide(description: "The fact to remember, written as a short third-person statement about the user, e.g. 'Trains at home with dumbbells only' or 'Recovering from a left shoulder impingement'")
        var fact: String
    }

    func call(arguments args: Arguments) async throws -> String {
        let result: String = await MainActor.run {
            let stepID = AdvisorActivity.shared.beginStep("Remembering that…")
            let changed = AdvisorMemoryStore.shared.remember(args.fact)
            if changed {
                AdvisorActivity.shared.finishStep(stepID, result: "Remembered: \(args.fact)")
                AdvisorActivity.shared.recordAction("Remembered: \(args.fact)") {
                    AdvisorMemoryStore.shared.forget(matching: args.fact)
                }
                return "Saved to memory: \(args.fact)"
            } else {
                AdvisorActivity.shared.finishStep(stepID, result: "Already known")
                return "Already remembered."
            }
        }
        return result
    }
}

/// Remove something previously saved about the user when it is no longer true or user asks to forget it.
struct ForgetPreferenceTool: Tool {
    typealias Output = String

    let name = "forgetPreference"
    let description = "Remove something previously saved about the user. Call this when the user says a saved fact is no longer true or asks you to forget it."

    @Generable
    struct Arguments {
        @Guide(description: "Words identifying the memory to remove, e.g. 'shoulder injury'")
        var about: String
    }

    func call(arguments args: Arguments) async throws -> String {
        let result: String = await MainActor.run {
            let stepID = AdvisorActivity.shared.beginStep("Updating what I remember…")
            if let removed = AdvisorMemoryStore.shared.forget(matching: args.about) {
                AdvisorActivity.shared.finishStep(stepID, result: "Removed: \(removed)")
                return "Forgot: \(removed)"
            } else {
                AdvisorActivity.shared.finishStep(stepID, result: "Nothing found")
                return "Nothing matching that is saved."
            }
        }
        return result
    }
}
