import Foundation
import SwiftUI

enum SleepQuality: Sendable, Equatable {
    case poor, fair, good, excellent

    var color: Color {
        switch self {
        case .poor:
            return .red
        case .fair:
            return .blue
        case .good:
            return .blue
        case .excellent:
            return .blue
        }
    }

    var label: String {
        switch self {
        case .poor:
            return "Poor"
        case .fair:
            return "Fair"
        case .good:
            return "Good"
        case .excellent:
            return "Excellent"
        }
    }
}

struct SleepSegment: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let stage: Int   // 0=Awake, 1=REM, 2=Core, 3=Deep
    let start: Date
    let end: Date

    init(id: UUID = UUID(), stage: Int, start: Date, end: Date) {
        self.id = id
        self.stage = stage
        self.start = start
        self.end = end
    }
}

struct SleepAnalysis: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let totalDuration: TimeInterval
    let remDuration: TimeInterval
    let deepDuration: TimeInterval
    let coreDuration: TimeInterval
    let awakeDuration: TimeInterval
    let date: Date
    let bedtime: Date
    let wakeTime: Date
    var segments: [SleepSegment] = []
    var respiratoryRate: Double? = nil
    var respiratoryBaseline: Double? = nil
    var wristTempDeviation: Double? = nil   // °C overnight deviation from baseline; nil if unavailable
    var wristTempBaseline: Double? = nil    // °C personal overnight baseline (rolling mean); nil if unavailable
    var wristTempOvernight: Double? = nil   // °C most-recent overnight absolute reading; nil if unavailable
    var confidence: Double? = nil
    var sleepTargetHours: Double = 8
    var sleepNeed: TimeInterval? = nil
    var sleepDebt: TimeInterval? = nil
    var disruption: SleepDisruptionFlag? = nil
    var consistency: Double? = nil

    /// Time actually asleep (deep + core + REM), excluding time awake in bed.
    /// `totalDuration` remains time-in-bed (includes awake) for efficiency and the stage breakdown.
    var asleepDuration: TimeInterval { deepDuration + coreDuration + remDuration }

    var quality: Double {
        guard asleepDuration > 0 else { return 0 }
        let durationTarget = min(asleepDuration / (max(sleepTargetHours, 1) * 3600), 1)
        // Raw efficiency almost never leaves 0.6–1.0, so remap that band to 0–1 —
        // otherwise even two hours awake barely moves the score.
        let efficiencyScore = max(0, min(1, (efficiency - 0.60) / 0.35))
        let stageBalance = min((remDuration + deepDuration) / asleepDuration, 1)
        // Continuity: explicit penalty for time awake in bed. 20 minutes of grace
        // (normal wake-ups), then it decays linearly — 2h awake drives it to 0.
        let awakeMinutes = awakeDuration / 60
        let continuity = max(0, min(1, 1 - max(0, awakeMinutes - 20) / 100))

        // Core sleep architecture, always available.
        let architecture = (durationTarget * 0.35) + (efficiencyScore * 0.20) + (stageBalance * 0.15) + (continuity * 0.30)

        // Optional overnight physiological signals (respiratory rate, wrist temperature)
        // nudge the score toward how restful/recovered the night actually was.
        var refinements: [Double] = []
        if let stability = respiratoryStability { refinements.append(stability) }
        if let tempStability = temperatureStability { refinements.append(tempStability) }
        guard !refinements.isEmpty else { return architecture }
        let refinementAvg = refinements.reduce(0, +) / Double(refinements.count)
        return architecture * 0.80 + refinementAvg * 0.20
    }

    /// 0...1 — 1 means overnight respiratory rate is at or below baseline; drops as it rises above baseline.
    var respiratoryStability: Double? {
        guard let rr = respiratoryRate, let baseline = respiratoryBaseline, baseline > 0, rr > 0 else { return nil }
        let deviation = (rr - baseline) / baseline
        // Only penalize elevation above baseline; a 25% rise drives the component to 0.
        let stability = 1 - max(0, deviation) * 4
        return max(0, min(1, stability))
    }

    /// 0...1 — 1 means overnight wrist temperature is at baseline; drops as it deviates in either direction.
    var temperatureStability: Double? {
        guard let dev = wristTempDeviation else { return nil }
        // Ignore sub-noise wobble (~±0.15°C); a 0.5°C deviation beyond that drives the component to 0.
        let excess = max(0, abs(dev) - 0.15)
        let stability = 1 - excess / 0.5
        return max(0, min(1, stability))
    }

    var efficiency: Double {
        guard totalDuration > 0 else { return 0 }
        return (totalDuration - awakeDuration) / totalDuration
    }

    var formattedDuration: String {
        let hours = Int(asleepDuration) / 3600
        let minutes = (Int(asleepDuration) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    var qualityLevel: SleepQuality {
        if quality < 0.45 {
            return .poor
        } else if quality < 0.65 {
            return .fair
        } else if quality < 0.82 {
            return .good
        } else {
            return .excellent
        }
    }

    init(id: UUID = UUID(), totalDuration: TimeInterval, remDuration: TimeInterval, deepDuration: TimeInterval, coreDuration: TimeInterval, awakeDuration: TimeInterval, date: Date = Date(), bedtime: Date? = nil, wakeTime: Date? = nil, sleepTargetHours: Double = 8, segments: [SleepSegment] = [], respiratoryRate: Double? = nil, respiratoryBaseline: Double? = nil, wristTempDeviation: Double? = nil, wristTempBaseline: Double? = nil, wristTempOvernight: Double? = nil) {
        self.id = id
        self.totalDuration = totalDuration
        self.remDuration = remDuration
        self.deepDuration = deepDuration
        self.coreDuration = coreDuration
        self.awakeDuration = awakeDuration
        self.date = date
        self.bedtime = bedtime ?? date.addingTimeInterval(-totalDuration)
        self.wakeTime = wakeTime ?? date
        self.sleepTargetHours = sleepTargetHours
        self.segments = segments
        self.respiratoryRate = respiratoryRate
        self.respiratoryBaseline = respiratoryBaseline
        self.wristTempDeviation = wristTempDeviation
        self.wristTempBaseline = wristTempBaseline
        self.wristTempOvernight = wristTempOvernight
    }
}
