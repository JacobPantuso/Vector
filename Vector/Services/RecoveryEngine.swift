import Foundation
import HealthKit

struct RecoveryEngine {
    static func computeScore(
        hrvValues: [Double],
        restingHRValues: [Double],
        sleepQuality: Double,
        respiratoryValues: [Double] = [],
        wristTempDeviation: Double? = nil,
        spo2: Double? = nil,
        spo2Baseline: Double? = nil,
        hrr: Double? = nil,
        hrrBaseline: Double? = nil
    ) -> RecoveryScore {
        let hrvBaseline: Double = {
            guard !hrvValues.isEmpty else { return 0 }
            let history = hrvValues.count > 1 ? Array(hrvValues.dropLast()) : hrvValues
            return history.reduce(0, +) / Double(history.count)
        }()
        let rhrBaseline: Double = {
            guard !restingHRValues.isEmpty else { return 0 }
            let history = restingHRValues.count > 1 ? Array(restingHRValues.dropLast()) : restingHRValues
            return BaselineStatistics.median(BaselineStatistics.rejectOutliers(history)) ?? (history.reduce(0, +) / Double(history.count))
        }()

        let currentHRV = hrvValues.last ?? 0
        let currentRHR = restingHRValues.last ?? 0

        // Respiratory rate: need >2 readings for a meaningful baseline
        let rrBaseline: Double? = respiratoryValues.count > 2
            ? Array(respiratoryValues.dropLast()).reduce(0, +) / Double(respiratoryValues.count - 1)
            : nil
        let currentRR = respiratoryValues.last

        let hrvComponent: Double = {
            if let z = BaselineStatistics.logZScore(current: currentHRV, history: Array(hrvValues.dropLast())) {
                return max(0, min(100, 50 + 25 * z))
            }
            return calculateHRVComponent(current: currentHRV, baseline: hrvBaseline)
        }()
        let rhrComponent = calculateRHRComponent(current: currentRHR, baseline: rhrBaseline)
        let sleepComponent = sleepQuality * 100

        // Build the set of present (component, weight) pairs, then take a weighted average
        // re-normalized over only the signals we actually have. This keeps the score on a
        // consistent 0–100 scale whether or not RR / wrist temp / SpO2 are available.
        var parts: [(value: Double, weight: Double)] = [
            (hrvComponent, 0.30),
            (rhrComponent, 0.20),
            (sleepComponent, 0.25),
        ]

        if let rr = currentRR, let baseline = rrBaseline {
            // Elevated respiratory rate vs baseline signals strain/illness → lower recovery
            parts.append((calculateRRComponent(current: rr, baseline: baseline), 0.10))
        }
        if let dev = wristTempDeviation {
            parts.append((calculateTempComponent(deviation: dev), 0.10))
        }
        if let ox = spo2 {
            parts.append((calculateSpO2Component(current: ox, baseline: spo2Baseline), 0.05))
        }
        if let h = hrr {
            parts.append((calculateHRRComponent(current: h, baseline: hrrBaseline), 0.05))
        }

        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        let weighted = parts.reduce(0) { $0 + $1.value * $1.weight }
        let finalScore = totalWeight > 0 ? Int(weighted / totalWeight) : 50
        let clampedScore = max(0, min(100, finalScore))

        return RecoveryScore(
            score: clampedScore,
            hrvValue: currentHRV,
            restingHeartRate: currentRHR,
            sleepQuality: sleepQuality,
            date: Date(),
            hrvBaseline: hrvBaseline,
            rhrBaseline: rhrBaseline,
            respiratoryRate: currentRR,
            respiratoryBaseline: rrBaseline,
            wristTempDeviation: wristTempDeviation,
            spo2: spo2,
            spo2Baseline: spo2Baseline,
            hrr: hrr,
            hrrBaseline: hrrBaseline
        )
    }

    /// Wrist-temp deviation from baseline (°C). 0 → ideal (100); penalized in both directions,
    /// steeper for elevation (fever/illness/strain). A small tolerance absorbs the natural
    /// night-to-night wobble (~±0.15°C from bedding, room temp, alcohol) so only clinically
    /// meaningful deviations move the score: a ~1.25°C elevation drives the component to 0.
    private static func calculateTempComponent(deviation: Double) -> Double {
        let tolerance = 0.15
        let excess = max(0, abs(deviation) - tolerance)
        let penaltyPerDegree = deviation >= 0 ? 80.0 : 60.0  // elevation hurts recovery more
        let component = 100 - excess * penaltyPerDegree
        return max(0, min(100, component))
    }

    /// Blood oxygen (%). At/above baseline (or ~97% absolute) → ~100; each point of deficit
    /// is penalized, with a steeper drop once readings fall below the healthy ~95% floor.
    private static func calculateSpO2Component(current: Double, baseline: Double?) -> Double {
        guard current > 0 else { return 50 }
        let reference = (baseline ?? 97).clamped(to: 95...100)
        let deficit = max(0, reference - current)
        var component = 100 - deficit * 20      // 5% below reference → 0
        if current < 95 { component -= (95 - current) * 15 }  // extra penalty below clinical floor
        return max(0, min(100, component))
    }

    /// Higher heart-rate recovery = better autonomic fitness. Compare to personal baseline
    /// when available; otherwise map absolute HRR (≥40 bpm excellent, ≤15 poor).
    private static func calculateHRRComponent(current: Double, baseline: Double?) -> Double {
        if let baseline, baseline > 0 {
            let deviation = (current - baseline) / baseline   // ±20% ≈ full swing
            return (0.6 + deviation * 1.25).clamped(to: 0...1) * 100
        }
        return (((current - 15) / 25).clamped(to: 0...1)) * 100
    }

    private static func calculateHRVComponent(current: Double, baseline: Double) -> Double {
        guard baseline != 0 else { return 50 }
        let component = 50 + (current - baseline) / baseline * 100
        return max(0, min(100, component))
    }

    private static func calculateRHRComponent(current: Double, baseline: Double) -> Double {
        guard baseline != 0 else { return 50 }
        let component = 50 - (current - baseline) / baseline * 100
        return max(0, min(100, component))
    }

    private static func calculateRRComponent(current: Double, baseline: Double) -> Double {
        guard baseline != 0, current != 0 else { return 50 }
        // Respiratory rate deviations are small in absolute terms; amplify.
        // Elevated RR (positive deviation) lowers recovery.
        let component = 50 - (current - baseline) / baseline * 150
        return max(0, min(100, component))
    }
}
