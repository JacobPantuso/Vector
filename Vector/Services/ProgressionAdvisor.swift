import SwiftUI

enum ProgressionInsightKind {
    case firstTime
    case readyToProgress
    case holdSteady
    case plateau
    case building

    var symbol: String {
        switch self {
        case .firstTime: return "sparkles"
        case .readyToProgress: return "arrow.up.forward.circle.fill"
        case .holdSteady: return "target"
        case .plateau: return "exclamationmark.arrow.triangle.2.circlepath"
        case .building: return "chart.line.uptrend.xyaxis"
        }
    }

    var tint: Color {
        switch self {
        case .firstTime: return .cyan
        case .readyToProgress: return .green
        case .holdSteady: return .orange
        case .plateau: return .yellow
        case .building: return .mint
        }
    }

    var headline: String {
        switch self {
        case .firstTime: return "Set a baseline"
        case .readyToProgress: return "Ready to progress"
        case .holdSteady: return "Lock it in"
        case .plateau: return "Break the plateau"
        case .building: return "Building momentum"
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
    static func insight(for entry: ManualExerciseEntry, store: ExerciseProgressionStore = .shared) -> ProgressionInsight? {
        // Only meaningful for weighted, reps-based exercises.
        guard entry.inputType == .reps else { return nil }

        let hist = store.history(for: entry)
        guard let last = hist.last else {
            return ProgressionInsight(
                kind: .firstTime,
                detail: "First time logging this lift — finish your sets and we'll start tracking your progressive overload.",
                suggestedWeightKg: nil,
                deltaKg: 0
            )
        }

        let wStr = fmt(last.weightKg)

        // Hit (or beat) the target last time.
        if last.weightKg > 0 && last.reps >= last.targetReps {
            let suggested = last.weightKg + 5
            let recent = hist.suffix(3)
            let stalled = recent.count >= 3 && recent.allSatisfy { abs($0.weightKg - last.weightKg) < 0.1 }
            if stalled {
                return ProgressionInsight(
                    kind: .plateau,
                    detail: "3 sessions parked at \(wStr) lb. You've earned it — push to \(fmt(suggested)) lb today.",
                    suggestedWeightKg: suggested,
                    deltaKg: 5
                )
            }
            return ProgressionInsight(
                kind: .readyToProgress,
                detail: "Last time you hit \(last.reps)×\(wStr) lb and cleared your target. Try \(fmt(suggested)) lb today.",
                suggestedWeightKg: suggested,
                deltaKg: 5
            )
        }

        // Weighted but missed the target rep count.
        if last.weightKg > 0 {
            return ProgressionInsight(
                kind: .holdSteady,
                detail: "Last time \(last.reps)/\(last.targetReps) reps @ \(wStr) lb. Stay at \(wStr) lb and own all \(last.targetReps) reps before adding load.",
                suggestedWeightKg: last.weightKg,
                deltaKg: 0
            )
        }

        // Bodyweight / unloaded movement — progress via reps.
        return ProgressionInsight(
            kind: .building,
            detail: "You logged \(last.reps) reps last time. Add 1–2 reps per set to keep progressing.",
            suggestedWeightKg: nil,
            deltaKg: 0
        )
    }

    private static func fmt(_ kg: Double) -> String {
        kg.rounded() == kg ? String(format: "%.0f", kg) : String(format: "%.1f", kg)
    }
}
