import Foundation
import SwiftUI

enum LoadStatus: Sendable, Equatable {
    case detraining, optimal, overreaching, overtraining

    var color: Color {
        switch self {
        case .detraining:
            return .blue
        case .optimal:
            return .green
        case .overreaching:
            return .orange
        case .overtraining:
            return .red
        }
    }

    var label: String {
        switch self {
        case .detraining:
            return "Detraining"
        case .optimal:
            return "Optimal"
        case .overreaching:
            return "Overreaching"
        case .overtraining:
            return "Overtraining"
        }
    }
}

enum ExertionLevel: Sendable, Equatable {
    case noStrain, low, moderate, high, extreme

    var label: String {
        switch self {
        case .noStrain: return "No strain"
        case .low:      return "Low"
        case .moderate: return "Moderate"
        case .high:     return "High"
        case .extreme:  return "Extreme"
        }
    }

    var color: Color {
        switch self {
        case .noStrain: return .secondary
        case .low:      return Color(hue: 0.12, saturation: 0.85, brightness: 0.95)  // warm amber
        case .moderate: return Color(hue: 0.08, saturation: 0.90, brightness: 0.97)  // orange
        case .high:     return Color(hue: 0.04, saturation: 0.92, brightness: 0.95)  // deep orange
        case .extreme:  return Color(hue: 0.0,  saturation: 0.85, brightness: 0.90)  // red
        }
    }
}

struct ZoneTime: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let zone: Int
    let duration: TimeInterval
    let percentage: Double

    init(id: UUID = UUID(), zone: Int, duration: TimeInterval, percentage: Double) {
        self.id = id
        self.zone = zone
        self.duration = duration
        self.percentage = percentage
    }
}

struct ExertionScore: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let score: Int
    let acuteLoad: Double
    let chronicLoad: Double
    let todayStrain: Double
    let date: Date
    let zoneSplits: [ZoneTime]
    var confidence: Double? = nil

    var loadRatio: Double {
        guard chronicLoad != 0 else { return 0 }
        return acuteLoad / chronicLoad
    }

    var todayStrainLevel: String {
        switch todayStrain {
        case 0:
            return "Fresh"
        case ..<200:
            return "Light"
        case ..<500:
            return "Moderate"
        default:
            return "Heavy"
        }
    }

    var loadStatus: LoadStatus {
        let ratio = loadRatio
        if ratio < 0.8 {
            return .detraining
        } else if ratio <= 1.3 {
            return .optimal
        } else if ratio <= 1.5 {
            return .overreaching
        } else {
            return .overtraining
        }
    }

    var exertionLevel: ExertionLevel {
        switch score {
        case ..<1:   return .noStrain
        case ..<30:  return .low
        case ..<60:  return .moderate
        case ..<85:  return .high
        default:     return .extreme
        }
    }

    /// The exertion-score band (same 0–100+ scale as `score`) that today's strain should
    /// land in to keep the weekly acute:chronic ratio inside the healthy part of the
    /// optimal 0.8–1.3 band. Returns nil when there's no chronic history to anchor a target.
    ///
    /// Rather than trying to close the entire weekly acute:chronic gap in a single day
    /// (which produced wildly high targets when the ratio was even slightly low — e.g. a
    /// 0.88 ratio asking for a 140+ day), this anchors on the daily load that *maintains*
    /// the ratio and reports the band that nudges the weekly ratio toward ~0.95–1.15.
    var optimalTargetRange: ClosedRange<Double>? {
        guard chronicLoad > 0 else { return nil }
        let lower = targetScore(forRatio: 0.95)
        let upper = targetScore(forRatio: 1.15)
        return min(lower, upper)...max(lower, upper)
    }

    /// Exertion score that today should reach for the weekly acute:chronic ratio to settle
    /// at `targetRatio`, anchored on the steady-state daily load and nudged gently by the
    /// current weekly ratio.
    private func targetScore(forRatio targetRatio: Double) -> Double {
        // Daily load that, sustained, holds the weekly acute:chronic ratio at ~1.0.
        let maintenanceLoad = chronicLoad / 7
        guard maintenanceLoad > 0 else { return 0 }
        // Score scale: 100 == a hard day of 1.5x the average daily load.
        let dailyTarget = max(30, maintenanceLoad * 1.5)
        // Steady-state daily load that holds the weekly ratio at `targetRatio`.
        let steadyLoad = maintenanceLoad * targetRatio
        // Small, damped nudge for the current weekly deficit/surplus (excluding today, for
        // intraday stability). Spreading only a fraction of the weekly gap over the day keeps
        // a lumpy or light week from demanding an all-out ~100 day.
        let priorAcute = max(0, acuteLoad - todayStrain)
        let priorRatio = priorAcute / chronicLoad
        let nudge = ((targetRatio - priorRatio) * 0.25).clamped(to: -0.15...0.15)
        let adjustedLoad = steadyLoad + maintenanceLoad * nudge
        return min(max((adjustedLoad / dailyTarget) * 100, 0), 100)
    }

    init(id: UUID = UUID(), score: Int, acuteLoad: Double, chronicLoad: Double, todayStrain: Double, date: Date = Date(), zoneSplits: [ZoneTime]) {
        self.id = id
        self.score = score
        self.acuteLoad = acuteLoad
        self.chronicLoad = chronicLoad
        self.todayStrain = todayStrain
        self.date = date
        self.zoneSplits = zoneSplits
    }
}
