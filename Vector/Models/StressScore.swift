import Foundation
import SwiftUI

enum StressLevel: Sendable, Equatable {
    case low, moderate, high

    var label: String {
        switch self {
        case .low: return "Low"
        case .moderate: return "Moderate"
        case .high: return "High"
        }
    }

    var color: Color {
        switch self {
        case .low: return .indigo
        case .moderate: return .indigo
        case .high: return .red
        }
    }

    var systemImage: String {
        switch self {
        case .low: return "brain.head.profile"
        case .moderate: return "waveform.path.ecg"
        case .high: return "exclamationmark.heart.fill"
        }
    }
}

enum CircadianPhase: String, Sendable, Codable, Equatable {
    case earlyMorning = "Early Morning"
    case morning = "Morning"
    case midday = "Midday"
    case afternoon = "Afternoon"
    case evening = "Evening"
    case night = "Night"

    var note: String {
        switch self {
        case .earlyMorning:
            return "Cortisol naturally peaks 30–60 min after waking, so some elevation is normal."
        case .morning:
            return "Your nervous system is warming up. Overnight metrics are most reliable now."
        case .midday:
            return "Most representative window for stress assessment."
        case .afternoon:
            return "Afternoon readings reflect accumulated daily load."
        case .evening:
            return "Pre-sleep metrics can show daily stress residue."
        case .night:
            return "Overnight HRV is your most accurate stress signal."
        }
    }

    var icon: String {
        switch self {
        case .earlyMorning: return "sunrise.fill"
        case .morning: return "sun.and.horizon.fill"
        case .midday: return "sun.max.fill"
        case .afternoon: return "cloud.sun.fill"
        case .evening: return "sunset.fill"
        case .night: return "moon.stars.fill"
        }
    }
}

struct StressFactor: Sendable, Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let value: String
    let contribution: Double  // 0–1, how much it pushed score up
    let isElevating: Bool     // true = contributing to stress
    let weight: Double        // percentage weight in final score
    let explanation: String
    let actionItem: String
}

struct StressScore: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let score: Int
    let hrvValue: Double
    let restingHeartRate: Double
    let date: Date
    let hrvBaseline: Double
    let rhrBaseline: Double
    // Baseline fields
    let sleepQuality: Double         // 0–1
    let respiratoryRate: Double?     // breaths/min, nil if unavailable
    let respiratoryBaseline: Double? // 14-day baseline
    let wristTempDeviation: Double?  // °C overnight deviation from baseline; nil if unavailable
    let circadianPhase: CircadianPhase
    let hoursSinceWake: Double?      // nil if sleep data unavailable
    // New daytime HR fields
    let recentHR: Double?            // median HR from last 3h, nil if unavailable
    let hrElevationPercent: Double?  // elevation % (median - resting) / resting, nil if unavailable
    var confidence: Double? = nil

    var level: StressLevel {
        if score <= 40 { return .low }
        else if score <= 65 { return .moderate }
        else { return .high }
    }

    var hrvDeviation: Double {
        guard hrvBaseline != 0 else { return 0 }
        return ((hrvValue - hrvBaseline) / hrvBaseline) * 100
    }

    var rhrDeviation: Double {
        guard rhrBaseline != 0 else { return 0 }
        return ((restingHeartRate - rhrBaseline) / rhrBaseline) * 100
    }

    var circadianAdjustmentApplied: Int {
        guard recentHR != nil, let hrs = hoursSinceWake, hrs < 1.5 else { return 0 }
        return Int(-8.0 * (1.0 - hrs / 1.5))
    }

    var factors: [StressFactor] {
        var result: [StressFactor] = []

        // HRV factor (weight 0.30)
        let hrvStress = hrvBaseline > 0
            ? ((hrvBaseline - hrvValue) / hrvBaseline).clamped(to: 0...1)
            : 0.5
        let hrvIsElevating = hrvDeviation < -5
        result.append(StressFactor(
            name: "Heart Rate Variability",
            icon: "waveform.path.ecg",
            value: hrvValue > 0 ? String(format: "%.0f ms", hrvValue) : "No data",
            contribution: hrvStress,
            isElevating: hrvIsElevating,
            weight: 0.30,
            explanation: hrvBaseline > 0
                ? "Your HRV is \(abs(Int(hrvDeviation)))% \(hrvDeviation >= 0 ? "above" : "below") your 14-day baseline of \(Int(hrvBaseline)) ms."
                : "No HRV baseline yet. Wear your watch overnight for accurate readings.",
            actionItem: hrvIsElevating
                ? "Try 10–15 min of slow breathing or meditation today. The Heart & Stroke Foundation recommends daily breathing practice to lower physiological stress."
                : "HRV is healthy. Maintain your sleep consistency and keep your recovery routine."
        ))

        // RHR factor (weight 0.15)
        let rhrStress = rhrBaseline > 0
            ? ((restingHeartRate - rhrBaseline) / rhrBaseline).clamped(to: 0...1)
            : 0.5
        let rhrIsElevating = rhrDeviation > 5
        result.append(StressFactor(
            name: "Resting Heart Rate",
            icon: "heart.fill",
            value: restingHeartRate > 0 ? String(format: "%.0f bpm", restingHeartRate) : "No data",
            contribution: rhrStress,
            isElevating: rhrIsElevating,
            weight: 0.15,
            explanation: rhrBaseline > 0
                ? "Your RHR is \(abs(Int(rhrDeviation)))% \(rhrDeviation >= 0 ? "above" : "below") your 14-day average of \(Int(rhrBaseline)) bpm."
                : "No RHR baseline yet. Wear your watch overnight for accurate readings.",
            actionItem: rhrIsElevating
                ? "Elevated RHR signals under-recovery. Hydrate well, limit caffeine and sugar, and target 7–9 hours of sleep tonight."
                : "Resting HR is within your normal range, which is a sign of good cardiovascular recovery."
        ))

        // Daytime Heart Rate factor (weight 0.25) — new, shown only when available
        if let hr = recentHR, let elevPct = hrElevationPercent {
            let hrIsElevating = elevPct > 20
            let contribution = max(0, (elevPct / 100 - 0.15) / 0.35).clamped(to: 0...1)
            result.append(StressFactor(
                name: "Daytime Heart Rate",
                icon: "heart.circle.fill",
                value: String(format: "%.0f bpm avg", hr),
                contribution: contribution,
                isElevating: hrIsElevating,
                weight: 0.25,
                explanation: String(format: "Your recent heart rate (last ~3 hours) averaged %.0f bpm, which is %.0f%% above your resting rate. A modest elevation is normal when awake and active; sustained high readings can signal accumulated stress.", hr, elevPct),
                actionItem: hrIsElevating
                    ? "An elevated daytime heart rate suggests accumulated stress. Try a 5–10 minute calming break, a short walk, or gentle stretching to help your nervous system downshift."
                    : "Your daytime heart rate is well-controlled, showing good cardiovascular regulation during daily activities."
            ))
        }

        // Sleep factor (weight 0.15)
        let sleepIsElevating = sleepQuality < 0.5
        result.append(StressFactor(
            name: "Sleep Quality",
            icon: "moon.zzz.fill",
            value: sleepQuality > 0 ? "\(Int(sleepQuality * 100))%" : "No data",
            contribution: max(0, sleepQuality < 0.65 ? (0.65 - sleepQuality) : 0).clamped(to: 0...1),
            isElevating: sleepIsElevating,
            weight: 0.15,
            explanation: sleepQuality > 0
                ? "Last night's sleep was \(sleepQualityLabel). Poor sleep is a top driver of physiological stress."
                : "No sleep data available. Apple Watch must be worn during sleep.",
            actionItem: sleepIsElevating
                ? "Poor sleep is a primary stress driver. If you can't fall asleep, get up and do a calming activity rather than watching the clock, then try again (Heart & Stroke Foundation)."
                : "Good sleep is your strongest lever against stress. Keep your sleep schedule consistent."
        ))

        // Respiratory rate factor (weight 0.10) — if available
        if let rr = respiratoryRate {
            let rrBaseline = respiratoryBaseline ?? 15.0
            let rrStress = max(0, (rr - rrBaseline) / rrBaseline).clamped(to: 0...1)
            let rrIsElevating = rr > rrBaseline + 1.5
            result.append(StressFactor(
                name: "Respiratory Rate",
                icon: "lungs.fill",
                value: String(format: "%.1f br/min", rr),
                contribution: rrStress,
                isElevating: rrIsElevating,
                weight: 0.10,
                explanation: "Resting at \(String(format: "%.1f", rr)) breaths/min vs your baseline of \(String(format: "%.1f", rrBaseline)).",
                actionItem: rrIsElevating
                    ? "Elevated breathing rate signals tension. Try 3–5 min of deep breathing: inhale slowly through your nose, expanding your abdomen first, then exhale fully."
                    : "Respiratory rate is normal, which suggests your nervous system is at ease."
            ))
        }

        // Wrist temperature factor (weight 0.05) — if available
        if let dev = wristTempDeviation {
            let tempIsElevating = dev > 0.3
            let tempStress = max(0, dev / 1.0).clamped(to: 0...1)
            result.append(StressFactor(
                name: "Wrist Temperature",
                icon: "thermometer.medium",
                value: String(format: "%+.1f°C", dev),
                contribution: tempStress,
                isElevating: tempIsElevating,
                weight: 0.05,
                explanation: String(format: "Overnight wrist temperature was %+.1f°C vs your baseline. Elevated temperature can signal strain, illness, or poor recovery.", dev),
                actionItem: tempIsElevating
                    ? "An elevated overnight temperature often precedes illness or follows hard training. Prioritize hydration, rest, and lighter activity until it normalizes."
                    : "Your overnight temperature is stable, a sign your body is well-regulated and recovering normally."
            ))
        }

        return result
    }

    private var sleepQualityLabel: String {
        switch sleepQuality {
        case 0.8...: return "excellent"
        case 0.65...: return "good"
        case 0.5...: return "fair"
        default: return "poor"
        }
    }

    init(
        id: UUID = UUID(),
        score: Int,
        hrvValue: Double,
        restingHeartRate: Double,
        date: Date = Date(),
        hrvBaseline: Double,
        rhrBaseline: Double,
        sleepQuality: Double = 0.5,
        respiratoryRate: Double? = nil,
        respiratoryBaseline: Double? = nil,
        wristTempDeviation: Double? = nil,
        circadianPhase: CircadianPhase = .midday,
        hoursSinceWake: Double? = nil,
        recentHR: Double? = nil,
        hrElevationPercent: Double? = nil
    ) {
        self.id = id
        self.score = score
        self.hrvValue = hrvValue
        self.restingHeartRate = restingHeartRate
        self.date = date
        self.hrvBaseline = hrvBaseline
        self.rhrBaseline = rhrBaseline
        self.sleepQuality = sleepQuality
        self.respiratoryRate = respiratoryRate
        self.respiratoryBaseline = respiratoryBaseline
        self.wristTempDeviation = wristTempDeviation
        self.circadianPhase = circadianPhase
        self.hoursSinceWake = hoursSinceWake
        self.recentHR = recentHR
        self.hrElevationPercent = hrElevationPercent
    }
}

extension Comparable {
    func clamped(to range: ClosedRange<Self>) -> Self {
        return min(max(self, range.lowerBound), range.upperBound)
    }
}
