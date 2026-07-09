import Foundation

/// Builds the comprehensive context string the Vector Advisor sees each turn —
/// readiness, nutrition, training, progression, and profile.
enum AdvisorContext {
    @MainActor
    static func snapshot(_ health: HealthKitService) -> String {
        var lines: [String] = []

        // Recovery score + HRV + RHR
        if let r = health.recoveryScore {
            var line = "Recovery: \(r.score)/100 (\(r.level.label)) — HRV \(String(format: "%.0f", r.hrvValue))ms, RHR \(String(format: "%.0f", r.restingHeartRate))bpm"
            lines.append(line)
        }

        // Training load status + today strain
        if let e = health.exertionScore {
            lines.append("Training load: \(e.loadStatus.label) — today strain \(String(format: "%.0f", e.todayStrain))")
        }

        // Sleep duration + quality
        if let s = health.sleepAnalysis {
            lines.append("Sleep: \(s.formattedDuration), \(s.qualityLevel.label) quality")
        }

        // Stress score
        if let st = health.stressScore {
            lines.append("Stress: \(st.score)/100")
        }

        // Active calories + steps
        if health.todayActiveCalories > 0 { lines.append("Active calories: \(String(format: "%.0f", health.todayActiveCalories)) kcal") }
        if health.todaySteps > 0 { lines.append("Steps: \(String(format: "%.0f", health.todaySteps))") }

        // Goal + training days + sleep target
        let defaults = UserDefaults.standard
        let goal = FitnessGoal(rawValue: defaults.string(forKey: UserProfileStorage.goal) ?? "") ?? UserProfile.defaultGoal
        let days = defaults.object(forKey: UserProfileStorage.trainingDays) as? Int ?? UserProfile.defaultTrainingDays
        let sleepTarget = defaults.object(forKey: UserProfileStorage.sleepTargetHours) as? Double ?? UserProfile.defaultSleepTargetHours
        lines.append("Goal: \(goal.rawValue) · Training days/wk: \(days) · Sleep target: \(String(format: "%.1f", sleepTarget))h")

        if AppModeStore.shared.currentMode != .active {
            lines.append("User status: \(AppModeStore.shared.currentMode.displayName) — prioritize rest/recovery advice and avoid pushing exertion targets.")
        }

        return lines.joined(separator: "\n")
    }

    @MainActor
    static func build(_ health: HealthKitService) -> String {
        var lines: [String] = []

        // MARK: Readiness
        if let r = health.recoveryScore {
            var recoveryLine = "Recovery: \(r.score)/100 (\(r.level.label)) — HRV \(String(format: "%.0f", r.hrvValue))ms, RHR \(String(format: "%.0f", r.restingHeartRate))bpm"
            if let t = r.wristTempDeviation { recoveryLine += String(format: ", wrist temp %+.1f°C", t) }
            if let ox = r.spo2 { recoveryLine += String(format: ", SpO2 %.0f%%", ox) }
            if let c = r.confidence { recoveryLine += " (confidence \(Int(c * 100))%)" }
            lines.append(recoveryLine)
        }
        if let e = health.exertionScore {
            lines.append("Training load: \(e.loadStatus.label) — today strain \(String(format: "%.0f", e.todayStrain)), 7-day load \(String(format: "%.0f", e.acuteLoad))")
        }
        if let s = health.sleepAnalysis {
            lines.append("Sleep: \(s.formattedDuration), \(s.qualityLevel.label) quality (\(String(format: "%.0f", s.efficiency * 100))% efficiency)")
            if let need = s.sleepNeed { lines.append("Sleep need: \(String(format: "%.1f", need / 3600))h, debt \(String(format: "%.1f", (s.sleepDebt ?? 0) / 3600))h") }
            if let flag = s.disruption, flag.isFlagged { lines.append("Sleep disruption: \(flag.headline) [\(flag.signals.joined(separator: "; "))]") }
        }
        if let st = health.stressScore {
            lines.append("Stress: \(st.score)/100")
        }
        // HRV/RHR are reported on the Recovery line above (canonical source) to avoid the
        // app showing two different HRV numbers; only surface them standalone if no recovery score.
        if health.recoveryScore == nil {
            if let hrv = health.latestHRV { lines.append("Latest HRV: \(String(format: "%.0f", hrv))ms") }
            if let rhr = health.latestRestingHR { lines.append("Resting HR: \(String(format: "%.0f", rhr))bpm") }
        }
        if health.todayActiveCalories > 0 { lines.append("Active calories today: \(String(format: "%.0f", health.todayActiveCalories)) kcal") }
        if health.todaySteps > 0 { lines.append("Steps today: \(String(format: "%.0f", health.todaySteps))") }

        // MARK: Nutrition
        let food = FoodLogService.shared
        let defaults = UserDefaults.standard
        let calTarget = defaults.double(forKey: "nutritionTargetCalories")
        let proTarget = defaults.double(forKey: "nutritionTargetProtein")
        let carbTarget = defaults.double(forKey: "nutritionTargetCarbs")
        let fatTarget = defaults.double(forKey: "nutritionTargetFat")
        lines.append("\n--- Nutrition today ---")
        lines.append("Calories: \(Int(food.todayCalories))\(calTarget > 0 ? " / \(Int(calTarget)) target" : "")")
        lines.append("Protein: \(Int(food.todayProtein))g\(proTarget > 0 ? " / \(Int(proTarget))g" : "") · Carbs: \(Int(food.todayCarbs))g\(carbTarget > 0 ? " / \(Int(carbTarget))g" : "") · Fat: \(Int(food.todayFat))g\(fatTarget > 0 ? " / \(Int(fatTarget))g" : "")")
        if food.todayEntries.isEmpty {
            lines.append("No meals logged yet today.")
        } else {
            lines.append("Logged: " + food.todayEntries.map { "\($0.name) (\(Int($0.calories)) kcal)" }.joined(separator: ", "))
        }
        let bf = food.breakfastSchedule
        lines.append("Auto-breakfast: \(bf.isEnabled ? "on at \(String(format: "%02d:%02d", bf.scheduledHour, bf.scheduledMinute))" : "off")")

        // MARK: Training
        let templates = WorkoutStorageService.shared.savedWorkouts
        lines.append("\n--- Training ---")
        lines.append("Saved workouts (\(templates.count)): " + (templates.isEmpty ? "none" : templates.prefix(6).map(\.title).joined(separator: ", ")))
        let recent = WorkoutCompletionStore.shared.records.sorted { $0.date > $1.date }.prefix(3)
        for r in recent {
            let title = templates.first { $0.id == r.templateID }?.title ?? "Workout"
            lines.append("Completed \(title): \(Int(r.totalVolume)) lb on \(r.date.formatted(date: .abbreviated, time: .omitted))")
        }
        var highlights: [String] = []
        for t in templates {
            for ex in t.exercises {
                if let insight = ProgressionAdvisor.insight(for: ex),
                   insight.kind == .readyToProgress || insight.kind == .plateau {
                    highlights.append("\(ex.name): \(insight.headline)")
                }
            }
        }
        if !highlights.isEmpty {
            lines.append("Progression: " + Array(Set(highlights)).prefix(6).joined(separator: ", "))
        }

        // MARK: Profile
        let goal = FitnessGoal(rawValue: defaults.string(forKey: UserProfileStorage.goal) ?? "") ?? UserProfile.defaultGoal
        let days = defaults.object(forKey: UserProfileStorage.trainingDays) as? Int ?? UserProfile.defaultTrainingDays
        let sleepTarget = defaults.object(forKey: UserProfileStorage.sleepTargetHours) as? Double ?? UserProfile.defaultSleepTargetHours
        lines.append("\n--- Profile ---")
        lines.append("Goal: \(goal.rawValue) · Training days/wk: \(days) · Sleep target: \(String(format: "%.1f", sleepTarget))h")

        if AppModeStore.shared.currentMode != .active {
            lines.append("User status: \(AppModeStore.shared.currentMode.displayName) — prioritize rest/recovery advice and avoid pushing exertion targets.")
        }

        return lines.joined(separator: "\n")
    }
}
