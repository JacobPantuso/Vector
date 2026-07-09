import Foundation

enum DisruptionSeverity: String, Codable, Sendable {
    case none, light, moderate, heavy

    var label: String {
        switch self {
        case .none: return "Restful"
        case .light: return "Slightly disrupted"
        case .moderate: return "Disrupted"
        case .heavy: return "Heavily disrupted"
        }
    }

    fileprivate var rank: Int {
        switch self {
        case .none: return 0
        case .light: return 1
        case .moderate: return 2
        case .heavy: return 3
        }
    }
}

/// A confirmable hypothesis about an unusually disrupted night (e.g. alcohol, illness, late meal),
/// derived from how last night's nocturnal markers deviate from personal baselines.
struct SleepDisruptionFlag: Codable, Sendable, Equatable {
    let severity: DisruptionSeverity
    let likelyAlcohol: Bool
    let signals: [String]

    var isFlagged: Bool { severity != .none }

    var headline: String {
        guard isFlagged else { return "No unusual disruption detected" }
        return likelyAlcohol ? "Possible alcohol or late-night disruption" : "Disrupted night detected"
    }
}

enum SleepDisruptionDetector {
    /// Dose-graded thresholds adapted from Pietilä 2018: nocturnal RHR rises ~+1.4/+4.0/+8.7 bpm and
    /// HRV falls ~−2/−5.7/−12.9 ms for light/moderate/heavy alcohol. We compare to personal baselines
    /// and surface a confirmable hypothesis, never a verdict.
    static func evaluate(
        restingHR: Double?,
        rhrBaseline: Double?,
        hrv: Double?,
        hrvBaseline: Double?,
        wristTempDeviation: Double?,
        sleepEfficiency: Double?
    ) -> SleepDisruptionFlag {
        var severities: [DisruptionSeverity] = []
        var signals: [String] = []
        var rhrElevated = false
        var hrvSuppressed = false

        if let rhr = restingHR, let base = rhrBaseline, base > 0 {
            let delta = rhr - base
            let sev: DisruptionSeverity = delta >= 8.7 ? .heavy : delta >= 4.0 ? .moderate : delta >= 1.4 ? .light : .none
            if sev != .none {
                severities.append(sev)
                rhrElevated = true
                signals.append(String(format: "Resting HR +%.0f bpm vs baseline", delta))
            }
        }
        if let hrv = hrv, let base = hrvBaseline, base > 0 {
            let delta = hrv - base    // negative = suppressed
            let sev: DisruptionSeverity = delta <= -12.9 ? .heavy : delta <= -5.7 ? .moderate : delta <= -2.0 ? .light : .none
            if sev != .none {
                severities.append(sev)
                hrvSuppressed = true
                signals.append(String(format: "HRV %.0f ms below baseline", abs(delta)))
            }
        }
        if let dev = wristTempDeviation, dev >= 0.3 {
            signals.append(String(format: "Skin temp +%.1f°C", dev))
            severities.append(.light)
        }
        if let eff = sleepEfficiency, eff < 0.80 {
            signals.append(String(format: "Sleep efficiency %.0f%%", eff * 100))
            severities.append(.light)
        }

        let severity = severities.max(by: { $0.rank < $1.rank }) ?? .none
        // The classic alcohol signature is elevated RHR *and* suppressed HRV together.
        let likelyAlcohol = rhrElevated && hrvSuppressed && severity.rank >= DisruptionSeverity.moderate.rank
        return SleepDisruptionFlag(severity: severity, likelyAlcohol: likelyAlcohol, signals: signals)
    }

    /// Sleep-amount consistency 0…1 from the coefficient of variation of recent nightly sleep
    /// durations (a lightweight stand-in for a full Sleep Regularity Index). nil if too few nights.
    static func consistency(nights: [SleepNightRecord]) -> Double? {
        let hours = nights.map { $0.asleepHours }.filter { $0 > 0 }
        guard hours.count >= 3, let mean = BaselineStatistics.mean(hours), mean > 0,
              let sd = BaselineStatistics.standardDeviation(hours) else { return nil }
        let cv = sd / mean
        return max(0, min(1, 1 - cv))
    }
}
