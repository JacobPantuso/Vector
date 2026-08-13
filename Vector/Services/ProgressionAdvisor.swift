import SwiftUI
import Foundation

enum ProgressionInsightKind {
    case firstTime
    case readyToProgress
    case holdSteady
    case plateau
    case building
    case consolidating
    case deload
    case recoverFirst

    var symbol: String {
        switch self {
        case .firstTime: return "sparkles"
        case .readyToProgress: return "arrow.up.forward.circle.fill"
        case .holdSteady: return "target"
        case .plateau: return "exclamationmark.arrow.triangle.2.circlepath"
        case .building: return "chart.line.uptrend.xyaxis"
        case .consolidating: return "checkmark.seal"
        case .deload: return "arrow.down.right.circle"
        case .recoverFirst: return "bed.double.fill"
        }
    }

    var tint: Color {
        switch self {
        case .firstTime: return .cyan
        case .readyToProgress: return .green
        case .holdSteady: return .orange
        case .plateau: return .yellow
        case .building: return .mint
        case .consolidating: return .teal
        case .deload: return .purple
        case .recoverFirst: return .indigo
        }
    }

    var headline: String {
        switch self {
        case .firstTime: return "Set a baseline"
        case .readyToProgress: return "Ready to progress"
        case .holdSteady: return "Lock it in"
        case .plateau: return "Break the plateau"
        case .building: return "Building momentum"
        case .consolidating: return "One more clean session"
        case .deload: return "Back off to break through"
        case .recoverFirst: return "Recover first"
        }
    }
}

struct ProgressionInsight: Identifiable {
    let id = UUID()
    let kind: ProgressionInsightKind
    let detail: String
    let suggestedWeightKg: Double?
    let deltaKg: Double

    var symbol: String { kind.symbol }
    var tint: Color { kind.tint }
    var headline: String { kind.headline }
    var hasSuggestion: Bool { (suggestedWeightKg ?? 0) > 0 && deltaKg != 0 }
}

/// Rule-based progressive-overload analyzer. Deterministic, no network/LLM.
enum ProgressionAdvisor {
    static func insight(for entry: ManualExerciseEntry, store: ExerciseProgressionStore = .shared, recoveryScore: Int? = nil, prefs: EquipmentPreferences = EquipmentPreferencesStore.shared.preferences) -> ProgressionInsight? {
        // Only meaningful for weighted, reps-based exercises.
        guard entry.inputType == .reps else { return nil }

        let hist = store.history(for: entry)

        // No history: first time
        guard let last = hist.last else {
            return ProgressionInsight(
                kind: .firstTime,
                detail: "First time logging this lift — finish your sets and we'll start tracking your progressive overload.",
                suggestedWeightKg: nil,
                deltaKg: 0
            )
        }

        // Resolve the exercise's EquipmentKind
        let library = ExerciseLibrary.shared
        let exercise: LibraryExercise?

        if let libId = entry.libraryExerciseId {
            exercise = library.exercises.first { $0.id == libId }
        } else {
            exercise = library.allExercises.first { $0.name.lowercased() == entry.name.lowercased() }
        }

        let kind = exercise.map { EquipmentKind.classify(equipment: $0.equipment, name: $0.name) }
            ?? EquipmentKind.classify(equipment: "", name: entry.name)
        let step = prefs.increment(for: kind)

        let wStr = fmt(last.weightKg)

        // For equipment types that don't support load progression (.band, .bodyweight),
        // progress via reps/band-tension only
        if !kind.supportsLoadProgression {
            let detail: String
            if kind == .band {
                detail = "You logged \(last.reps) reps last time. Add reps or move up a band to keep progressing."
            } else {
                detail = "You logged \(last.reps) reps last time. Add 1–2 reps per set to keep progressing."
            }
            return ProgressionInsight(
                kind: .building,
                detail: detail,
                suggestedWeightKg: nil,
                deltaKg: 0
            )
        }

        // Bodyweight (weight <= 0): progress via reps only
        if last.weightKg <= 0 {
            return ProgressionInsight(
                kind: .building,
                detail: "You logged \(last.reps) reps last time. Add 1–2 reps per set to keep progressing.",
                suggestedWeightKg: nil,
                deltaKg: 0
            )
        }

        // Layoff: more than 21 days since last session
        let daysSinceLast = Calendar.current.dateComponents([.day], from: last.date, to: Date()).day ?? 0
        if daysSinceLast > 21 {
            let suggested = snapDown(last.weightKg * 0.9, to: step)
            let ensured = max(step, suggested)
            let delta = ensured - last.weightKg
            return ProgressionInsight(
                kind: .holdSteady,
                detail: "It's been \(daysSinceLast) days since you last did this lift. Ease back in around \(fmt(ensured)) lb and rebuild from there.",
                suggestedWeightKg: ensured,
                deltaKg: delta
            )
        }

        // Plateau/deload: last 3+ sessions at same weight, none hit all targets, reps haven't improved
        let sameWeightStreak = hist.suffix(3).filter { abs($0.weightKg - last.weightKg) < 0.1 }
        if sameWeightStreak.count >= 3 && !sameWeightStreak.contains(where: { $0.hitAllTargets }) {
            let firstReps = sameWeightStreak.first?.reps ?? 0
            let lastReps = sameWeightStreak.last?.reps ?? 0
            let repsHaveNotImproved = lastReps <= firstReps
            if repsHaveNotImproved {
                let suggested = snapDown(last.weightKg * 0.9, to: step)
                let ensured = max(step, suggested)
                // Make sure we deload by at least one step
                var deload = ensured
                if deload >= last.weightKg {
                    deload = max(step, last.weightKg - step)
                }
                let delta = deload - last.weightKg
                return ProgressionInsight(
                    kind: .deload,
                    detail: "You've been stuck at \(wStr) lb for a few sessions. Try a ~10% deload to \(fmt(deload)) lb for 1–2 sessions, or focus on slower tempo to reset.",
                    suggestedWeightKg: deload,
                    deltaKg: delta
                )
            }
        }

        // Check if hit all targets this session
        let hitAllTargets = last.hitAllTargets

        // Missed targets but close: within 1-2 reps
        if !hitAllTargets && last.weightKg > 0 {
            if let sets = last.sets, !sets.isEmpty {
                let missedSets = sets.filter { $0.weightKg > 0 && $0.reps < $0.targetReps }
                let allClose = missedSets.allSatisfy { $0.targetReps - $0.reps <= 2 }
                if allClose && !missedSets.isEmpty {
                    return ProgressionInsight(
                        kind: .building,
                        detail: "Close — you're 1–2 reps shy on \(missedSets.count) set(s) at \(wStr) lb. Add a rep per set before adding load.",
                        suggestedWeightKg: last.weightKg,
                        deltaKg: 0
                    )
                }
            } else {
                // Legacy: just top set
                if last.targetReps - last.reps <= 2 {
                    return ProgressionInsight(
                        kind: .building,
                        detail: "Close — you're \(last.targetReps - last.reps) rep(s) shy at \(wStr) lb. Add a rep before adding load.",
                        suggestedWeightKg: last.weightKg,
                        deltaKg: 0
                    )
                }
            }

            // Not close; just hold steady
            if let sets = last.sets, !sets.isEmpty {
                let shortCount = sets.filter { $0.weightKg > 0 && $0.reps < $0.targetReps }.count
                return ProgressionInsight(
                    kind: .holdSteady,
                    detail: "\(shortCount) of \(sets.count) sets short at \(wStr) lb. Own all target reps before adding load.",
                    suggestedWeightKg: last.weightKg,
                    deltaKg: 0
                )
            }
            return ProgressionInsight(
                kind: .holdSteady,
                detail: "Last time \(last.reps)/\(last.targetReps) reps @ \(wStr) lb. Stay at \(wStr) lb and own all \(last.targetReps) reps before adding load.",
                suggestedWeightKg: last.weightKg,
                deltaKg: 0
            )
        }

        // Hit all targets: consistency and recovery gates
        if hitAllTargets {
            // Count trailing consecutive sessions at same weight where hitAllTargets is true
            var consecutiveStreak = 1
            for i in (0..<hist.count - 1).reversed() {
                let curr = hist[i]
                let next = hist[i + 1]
                if abs(curr.weightKg - next.weightKg) < 0.1 && curr.hitAllTargets {
                    consecutiveStreak += 1
                } else {
                    break
                }
            }

            // Compute suggested weight using increment rule
            let suggested = computeNextWeight(for: entry, currentWeight: last.weightKg, store: store, step: step, kind: kind)
            let delta = suggested - last.weightKg

            // Recovery gate: only apply when progression is earned
            if let recovery = recoveryScore, recovery < 40 {
                return ProgressionInsight(
                    kind: .recoverFirst,
                    detail: "You've earned a load increase, but recovery is low today (\(recovery)). Repeat \(wStr) lb and bump the weight when you're fresher.",
                    suggestedWeightKg: last.weightKg,
                    deltaKg: 0
                )
            }

            // Consolidating: first clean session at this weight
            if consecutiveStreak == 1 {
                return ProgressionInsight(
                    kind: .consolidating,
                    detail: "Clean session at \(wStr) lb. Repeat it once more and you've earned the bump to \(fmt(suggested)) lb.",
                    suggestedWeightKg: last.weightKg,
                    deltaKg: 0
                )
            }

            // Plateau: 4+ sessions at same weight (all successful)
            let sameWeightCount = hist.suffix(4).filter { abs($0.weightKg - last.weightKg) < 0.1 }.count
            if consecutiveStreak >= 4 || sameWeightCount >= 4 {
                return ProgressionInsight(
                    kind: .plateau,
                    detail: "\(sameWeightCount) sessions parked at \(wStr) lb — you've more than earned \(fmt(suggested)) lb. That's \(stepPhrase(delta: delta, step: step, kind: kind)).",
                    suggestedWeightKg: suggested,
                    deltaKg: delta
                )
            }

            // Ready to progress: 2+ consecutive sessions
            if consecutiveStreak >= 2 {
                return ProgressionInsight(
                    kind: .readyToProgress,
                    detail: "Last time you hit \(last.reps)×\(wStr) lb and cleared your target. Try \(fmt(suggested)) lb today — \(stepPhrase(delta: delta, step: step, kind: kind)).",
                    suggestedWeightKg: suggested,
                    deltaKg: delta
                )
            }
        }

        // Fallback (should not reach here in normal flow)
        return ProgressionInsight(
            kind: .holdSteady,
            detail: "Stay at \(wStr) lb and focus on hitting all target reps.",
            suggestedWeightKg: last.weightKg,
            deltaKg: 0
        )
    }

    private static func computeNextWeight(for entry: ManualExerciseEntry, currentWeight: Double, store: ExerciseProgressionStore, step: Double, kind: EquipmentKind) -> Double {
        // Look up the exercise in the library to determine muscle category
        let library = ExerciseLibrary.shared
        let exercise: LibraryExercise?

        if let libId = entry.libraryExerciseId {
            exercise = library.exercises.first { $0.id == libId }
        } else {
            exercise = library.allExercises.first { $0.name.lowercased() == entry.name.lowercased() }
        }

        // Determine percentage based on muscle category
        let percentage: Double
        if let ex = exercise {
            let category = ex.muscleCategory.lowercased()
            // Lower-body and large compounds: 5%
            if category.contains("leg") || category.contains("glute") || category.contains("hip") || category.contains("back") {
                percentage = 0.05
            } else {
                // Everything else: 2.5%
                percentage = 0.025
            }
        } else {
            // Default to 2.5% if exercise not found
            percentage = 0.025
        }

        // Compute raw increment from percentage
        let raw = currentWeight * percentage
        // Target is current + max(step, raw), but capped at 3 steps
        let target = currentWeight + max(step, min(raw, 3 * step))
        var next = snap(target, to: step)

        // Ensure result > current weight and is at least one step above it
        if next <= currentWeight {
            next = currentWeight + step
        }

        return next
    }

    /// Describes an increase in terms of how many equipment steps it actually is.
    /// e.g. "one 5 lb step up on the barbell" / "3 × 5 lb steps up on the barbell".
    private static func stepPhrase(delta: Double, step: Double, kind: EquipmentKind) -> String {
        guard step > 0 else { return "a \(fmt(delta)) lb jump on the \(kind.rawValue.lowercased())" }
        let steps = max(1, Int((delta / step).rounded()))
        let stepStr = fmt(step)
        let noun = steps == 1 ? "one \(stepStr) lb step" : "\(steps) × \(stepStr) lb steps"
        return "\(noun) up on the \(kind.rawValue.lowercased())"
    }

    private static func snap(_ value: Double, to step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded() * step
    }

    private static func snapDown(_ value: Double, to step: Double) -> Double {
        guard step > 0 else { return value }
        return (value / step).rounded(.down) * step
    }

    private static func fmt(_ kg: Double) -> String {
        kg.rounded() == kg ? String(format: "%.0f", kg) : String(format: "%.1f", kg)
    }
}
