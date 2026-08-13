import Foundation

/// Builds the comprehensive context string the Vector Advisor sees each turn —
/// readiness, nutrition, training, progression, and profile.
enum AdvisorContext {
    /// Returns a SHORT authoritative block of only today's headline numbers that is
    /// prepended to every prompt so the model never references stale data.
    @MainActor
    static func currentReadings(_ health: HealthKitService) -> String {
        let now = Date()
        let timeStr = now.formatted(date: .omitted, time: .shortened)
        var lines: [String] = []

        // Recovery score + HRV + RHR
        if let r = health.recoveryScore {
            lines.append("Recovery: \(r.score)/100 (\(r.level.label)) — HRV \(String(format: "%.0f", r.hrvValue))ms, RHR \(String(format: "%.0f", r.restingHeartRate))bpm")
        }

        // Training load status + today strain
        if let e = health.exertionScore {
            lines.append("Exertion: \(e.score)/100 (\(e.loadStatus.label)) — today's raw strain \(String(format: "%.0f", e.todayStrain))")
        }

        // Sleep duration + quality
        if let s = health.sleepAnalysis {
            lines.append("Sleep: \(s.formattedDuration), \(s.qualityLevel.label)")
        }

        // Stress score
        if let st = health.stressScore {
            lines.append("Stress: \(st.score)/100 (\(st.level.label))")
        }

        // Active calories + steps when > 0
        if health.todayActiveCalories > 0 {
            lines.append("Active calories: \(String(format: "%.0f", health.todayActiveCalories)) kcal")
        }
        if health.todaySteps > 0 {
            lines.append("Steps: \(String(format: "%.0f", health.todaySteps))")
        }

        lines.append("(Scores are 0-100 and are what the user sees in the app. Each score has a qualitative label (Excellent, Low, etc.) and a 0-100 value. Default to the label: say \"your recovery is excellent,\" not \"you're at 74 recovery.\" Give the numeric score only when the user explicitly asks for the number; when you do, use the 0-100 score, never raw strain, and these are not percentages (no % sign). Raw strain, calories, and steps are supporting figures.)")

        let lineStr = lines.joined(separator: "\n")
        return "[Current readings as of \(timeStr) — these supersede any numbers earlier in this conversation]\n\(lineStr)"
    }

    @MainActor
    static func snapshot(_ health: HealthKitService) -> String {
        var lines: [String] = []

        // Recovery score + HRV + RHR
        if let r = health.recoveryScore {
            let line = "Recovery: \(r.score)/100 (\(r.level.label)) — HRV \(String(format: "%.0f", r.hrvValue))ms, RHR \(String(format: "%.0f", r.restingHeartRate))bpm"
            lines.append(line)
        }

        // Training load status + today strain
        if let e = health.exertionScore {
            lines.append("Exertion score: \(e.score)/100 — load \(e.loadStatus.label), today's raw strain \(String(format: "%.0f", e.todayStrain))")
        }

        // Sleep duration + quality
        if let s = health.sleepAnalysis {
            lines.append("Sleep: \(s.formattedDuration), \(s.qualityLevel.label) quality")
        }

        // Stress score
        if let st = health.stressScore {
            lines.append("Stress: \(st.score)/100 (\(st.level.label))")
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
            lines.append("Exertion score: \(e.score)/100 — load \(e.loadStatus.label), today's raw strain \(String(format: "%.0f", e.todayStrain)), 7-day load \(String(format: "%.0f", e.acuteLoad))")
        }
        if let s = health.sleepAnalysis {
            lines.append("Sleep: \(s.formattedDuration), \(s.qualityLevel.label) quality (\(String(format: "%.0f", s.efficiency * 100))% efficiency)")
            if let need = s.sleepNeed { lines.append("Sleep need: \(String(format: "%.1f", need / 3600))h, debt \(String(format: "%.1f", (s.sleepDebt ?? 0) / 3600))h") }
            if let flag = s.disruption, flag.isFlagged { lines.append("Sleep disruption: \(flag.headline) [\(flag.signals.joined(separator: "; "))]") }
        }
        if let st = health.stressScore {
            lines.append("Stress: \(st.score)/100 (\(st.level.label))")
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
        let defaults = UserDefaults.standard
        if FeatureFlags.nutritionEnabled {
            let food = FoodLogService.shared
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
        }

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
                if let insight = ProgressionAdvisor.insight(for: ex, recoveryScore: health.recoveryScore?.score),
                   insight.kind == .readyToProgress || insight.kind == .plateau {
                    highlights.append("\(ex.name): \(insight.headline)")
                }
            }
        }
        if !highlights.isEmpty {
            lines.append("Progression: " + Array(Set(highlights)).prefix(6).joined(separator: ", "))
        }

        // MARK: Body patterns
        let checkIns = BodyCheckInStore.shared
        var bodyPatternLines: [String] = []

        if let summary = checkIns.patternSummary {
            bodyPatternLines.append(summary)
            // The three most recent answers, so the model can reference a specific
            // window rather than only the aggregate.
            for entry in checkIns.checkIns.prefix(3) {
                var line = "\(entry.startDate.formatted(date: .abbreviated, time: .omitted)): felt \(entry.feeling.label.lowercased())"
                if !entry.contexts.isEmpty {
                    line += " — attributed to \(entry.contexts.map(\.label).joined(separator: ", ").lowercased())"
                }
                if let note = entry.note, !note.isEmpty {
                    line += " (\"\(note)\")"
                }
                bodyPatternLines.append(line)
            }
        }

        if let current = BodySignalMonitor.shared.episodes.first,
           Calendar.current.dateComponents([.day], from: current.endDate, to: Date()).day ?? 99 <= 2 {
            bodyPatternLines.append("Right now several signals are off baseline (\(current.dateRangeLabel), \(current.severity.label)): \(current.signalSummaries.joined(separator: "; ")). The user has not said how they feel about this yet.")
        }

        if !bodyPatternLines.isEmpty {
            lines.append("\n--- What the user has told us about their body ---")
            lines.append(contentsOf: bodyPatternLines)
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
