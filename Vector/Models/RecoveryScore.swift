import Foundation
import SwiftUI

enum RecoveryLevel: Sendable, Equatable {
    case poor, good, excellent, superior

    var color: Color {
        switch self {
        case .poor:
            return .red
        case .good:
            return .yellow
        case .excellent:
            return .green
        case .superior:
            return .mint
        }
    }

    var label: String {
        switch self {
        case .poor:
            return "Poor"
        case .good:
            return "Good"
        case .excellent:
            return "Excellent"
        case .superior:
            return "Superior"
        }
    }

    var systemImage: String {
        switch self {
        case .poor:
            return "battery.25"
        case .good:
            return "battery.50"
        case .excellent:
            return "battery.100"
        case .superior:
            return "battery.100.bolt"
        }
    }
}

struct RecoveryScore: Identifiable, Codable, Sendable, Equatable {
    let id: UUID
    let score: Int
    let hrvValue: Double
    let restingHeartRate: Double
    let sleepQuality: Double
    let date: Date
    let hrvBaseline: Double
    let rhrBaseline: Double
    let respiratoryRate: Double?
    let respiratoryBaseline: Double?
    let wristTempDeviation: Double?  // °C deviation from baseline (Apple wrist temp is already baseline-relative); nil if unavailable
    let spo2: Double?                // overnight average blood oxygen %, nil if unavailable
    let spo2Baseline: Double?        // 14-day baseline %, nil if unavailable
    let hrr: Double?                 // most recent 1-min heart-rate recovery (bpm drop), nil if unavailable
    let hrrBaseline: Double?         // baseline HRR for comparison, nil if unavailable
    var confidence: Double? = nil

    var level: RecoveryLevel {
        if score <= 49 {
            return .poor
        } else if score <= 69 {
            return .good
        } else if score <= 84 {
            return .excellent
        } else {
            return .superior
        }
    }

    var hrvDeviation: Double {
        guard hrvBaseline != 0 else { return 0 }
        return ((hrvValue - hrvBaseline) / hrvBaseline) * 100
    }

    var rhrDeviation: Double {
        guard rhrBaseline != 0 else { return 0 }
        return ((restingHeartRate - rhrBaseline) / rhrBaseline) * 100
    }

    var respiratoryDeviation: Double? {
        guard let rr = respiratoryRate, let baseline = respiratoryBaseline, baseline != 0 else { return nil }
        return ((rr - baseline) / baseline) * 100
    }

    var spo2Deviation: Double? {
        guard let s = spo2, let b = spo2Baseline, b != 0 else { return nil }
        return ((s - b) / b) * 100
    }

    init(id: UUID = UUID(), score: Int, hrvValue: Double, restingHeartRate: Double, sleepQuality: Double, date: Date = Date(), hrvBaseline: Double, rhrBaseline: Double, respiratoryRate: Double? = nil, respiratoryBaseline: Double? = nil, wristTempDeviation: Double? = nil, spo2: Double? = nil, spo2Baseline: Double? = nil, hrr: Double? = nil, hrrBaseline: Double? = nil) {
        self.id = id
        self.score = score
        self.hrvValue = hrvValue
        self.restingHeartRate = restingHeartRate
        self.sleepQuality = sleepQuality
        self.date = date
        self.hrvBaseline = hrvBaseline
        self.rhrBaseline = rhrBaseline
        self.respiratoryRate = respiratoryRate
        self.respiratoryBaseline = respiratoryBaseline
        self.wristTempDeviation = wristTempDeviation
        self.spo2 = spo2
        self.spo2Baseline = spo2Baseline
        self.hrr = hrr
        self.hrrBaseline = hrrBaseline
    }
}
