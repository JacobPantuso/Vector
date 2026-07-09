import SwiftUI

/// A single cross-engine relationship surfaced to the user — e.g. how sleep lifted
/// recovery, or how recovery primes (or limits) today's exertion. Pure presentation data.
struct ConnectionInsight: Identifiable {
    let id = UUID()
    let icon: String
    let text: String
    let tint: Color
    let sentiment: Sentiment

    enum Sentiment { case positive, neutral, caution }
}

/// Pure logic that links the four scoring engines. Each function returns the connections
/// most relevant to the engine currently being viewed, ordered by importance.
/// These intentionally share inputs across engines (sleep feeds recovery & stress; HRV/RHR
/// feed recovery, stress, and load) so the user sees how the scores influence each other.
enum CrossEngineInsight {

    // MARK: Recovery detail — what fed recovery, and what recovery enables.
    static func forRecovery(recovery: RecoveryScore?, sleep: SleepAnalysis?, exertion: ExertionScore?, stress: StressScore?) -> [ConnectionInsight] {
        guard let recovery, recovery.score > 0 else { return [] }
        var out: [ConnectionInsight] = []

        if let sleep, sleep.totalDuration > 0 {
            if sleep.quality >= 0.65 {
                out.append(.init(icon: "moon.stars.fill",
                    text: "Last night's \(sleep.qualityLevel.label.lowercased()) sleep (\(sleep.formattedDuration)) is directly lifting today's recovery.",
                    tint: .indigo, sentiment: .positive))
            } else {
                out.append(.init(icon: "moon.zzz.fill",
                    text: "Short or restless sleep (\(sleep.formattedDuration)) is holding recovery back — sleep is a quarter of this score.",
                    tint: .indigo, sentiment: .caution))
            }
        }

        if recovery.score >= 70 {
            out.append(.init(icon: "bolt.heart.fill",
                text: "You're well recovered — a strong position to exert yourself and push intensity today.",
                tint: .green, sentiment: .positive))
        } else if recovery.score < 45 {
            let strain = exertion?.todayStrain ?? 0
            out.append(.init(icon: "bolt.slash.fill",
                text: strain > 150
                    ? "Recovery is low and you've already logged real strain today — favor rest over more load."
                    : "Recovery is low — keep exertion light today so you don't dig a deeper hole.",
                tint: .orange, sentiment: .caution))
        }

        if let stress, stress.score > 65 {
            out.append(.init(icon: "brain.head.profile",
                text: "Elevated stress is suppressing the same HRV that drives recovery — calming your nervous system helps both scores.",
                tint: .red, sentiment: .caution))
        }
        return out
    }

    // MARK: Sleep detail — how sleep feeds recovery and lowers stress.
    static func forSleep(sleep: SleepAnalysis?, recovery: RecoveryScore?, stress: StressScore?) -> [ConnectionInsight] {
        guard let sleep, sleep.totalDuration > 0 else { return [] }
        var out: [ConnectionInsight] = []

        if let recovery, recovery.score > 0 {
            if sleep.quality >= 0.65 {
                out.append(.init(icon: "heart.fill",
                    text: "This sleep is feeding your recovery — quality rest is the biggest lever you control.",
                    tint: .green, sentiment: .positive))
            } else {
                out.append(.init(icon: "heart.slash.fill",
                    text: "Tonight's rest is dragging on your recovery. Better sleep is the fastest way to raise it.",
                    tint: .orange, sentiment: .caution))
            }
        }

        if let stress {
            if sleep.quality < 0.5 {
                out.append(.init(icon: "brain.head.profile",
                    text: "Poor sleep is a top driver of physiological stress — if you feel stressed today this is likely a big contributor.",
                    tint: .red, sentiment: .caution))
            } else if stress.score <= 40 {
                out.append(.init(icon: "checkmark.seal.fill",
                    text: "Solid sleep is helping keep your stress low — your nervous system recovered overnight.",
                    tint: .green, sentiment: .positive))
            }
        }
        return out
    }

    // MARK: Exertion detail — readiness from recovery, the recovery cost of load.
    static func forExertion(exertion: ExertionScore?, recovery: RecoveryScore?, stress: StressScore?) -> [ConnectionInsight] {
        guard let exertion else { return [] }
        var out: [ConnectionInsight] = []

        if let recovery, recovery.score > 0 {
            if recovery.score >= 70 {
                out.append(.init(icon: "bolt.heart.fill",
                    text: "Your recovery is high — you're primed to push intensity and absorb more load today.",
                    tint: .green, sentiment: .positive))
            } else if recovery.score < 45 {
                out.append(.init(icon: "bolt.slash.fill",
                    text: "Recovery is low — adding hard strain today risks digging into your reserves.",
                    tint: .orange, sentiment: .caution))
            }
        }

        if exertion.todayStrain > 150 {
            out.append(.init(icon: "moon.zzz.fill",
                text: "Today's strain will tax tonight's recovery — protect your sleep to absorb it and adapt.",
                tint: .indigo, sentiment: .neutral))
        }

        if exertion.loadStatus == .overtraining || exertion.loadStatus == .overreaching {
            out.append(.init(icon: "exclamationmark.triangle.fill",
                text: "Your acute load is outpacing your fitness base — expect higher stress and lower recovery until it settles.",
                tint: .red, sentiment: .caution))
        }
        return out
    }

    // MARK: Stress detail — shared signals with recovery, sleep's role.
    static func forStress(stress: StressScore?, recovery: RecoveryScore?, sleep: SleepAnalysis?) -> [ConnectionInsight] {
        guard let stress, stress.score > 0 else { return [] }
        var out: [ConnectionInsight] = []

        if let recovery, recovery.score > 0 {
            if stress.score > 65 {
                out.append(.init(icon: "heart.slash.fill",
                    text: "High stress and recovery share the same HRV signal — this is likely capping your recovery.",
                    tint: .orange, sentiment: .caution))
            } else if stress.score <= 40 && recovery.score >= 60 {
                out.append(.init(icon: "checkmark.seal.fill",
                    text: "Low stress and strong recovery are reinforcing each other — a green light for quality training.",
                    tint: .green, sentiment: .positive))
            }
        }

        if let sleep, sleep.totalDuration > 0, sleep.quality < 0.5 {
            out.append(.init(icon: "moon.zzz.fill",
                text: "Last night's poor sleep (\(sleep.formattedDuration)) is one of the biggest contributors to today's stress.",
                tint: .indigo, sentiment: .caution))
        }
        return out
    }
}
