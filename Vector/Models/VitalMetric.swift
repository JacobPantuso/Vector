import SwiftUI

enum VitalCardSize: String, Codable, CaseIterable {
    case small, wide
}

enum VitalVisualStyle {
    case waveform, sparkline, arcGauge, sleepStages, none
}

enum VitalTone {
    case good, neutral, warn

    var color: Color {
        switch self {
        case .good:
            return .green
        case .neutral:
            return .secondary
        case .warn:
            return .orange
        }
    }
}

enum VitalMetric: String, CaseIterable, Codable, Identifiable {
    case heartRate
    case hrv
    case restingHR
    case vo2Max
    case wristTemp
    case spo2
    case respiratoryRate
    case sleep
    case activeEnergy
    case restingEnergy
    case steps
    case physicalEffort
    case hrr

    var id: String { rawValue }

    var title: String {
        switch self {
        case .heartRate:
            return "HEART RATE"
        case .hrv:
            return "HRV"
        case .restingHR:
            return "RESTING HR"
        case .vo2Max:
            return "VO2 MAX"
        case .wristTemp:
            return "TEMP. DEVIATION"
        case .spo2:
            return "BLOOD OXYGEN"
        case .respiratoryRate:
            return "RESP. RATE"
        case .sleep:
            return "SLEEP"
        case .activeEnergy:
            return "ACTIVE ENERGY"
        case .restingEnergy:
            return "RESTING ENERGY"
        case .steps:
            return "STEPS"
        case .physicalEffort:
            return "EFFORT"
        case .hrr:
            return "HR RECOVERY"
        }
    }

    var icon: String {
        switch self {
        case .heartRate:
            return "heart.fill"
        case .hrv:
            return "waveform.circle"
        case .restingHR:
            return "heart.circle"
        case .vo2Max:
            return "lungs.fill"
        case .wristTemp:
            return "thermometer"
        case .spo2:
            return "drop.fill"
        case .respiratoryRate:
            return "lungs"
        case .sleep:
            return "moon.stars.fill"
        case .activeEnergy:
            return "flame.fill"
        case .restingEnergy:
            return "bolt.circle"
        case .steps:
            return "figure.walk"
        case .physicalEffort:
            return "bolt.fill"
        case .hrr:
            return "arrow.down.heart"
        }
    }

    var tint: Color {
        switch self {
        case .heartRate:
            return .red
        case .hrv:
            return .cyan
        case .restingHR:
            return .pink
        case .vo2Max:
            return .mint
        case .wristTemp:
            return .orange
        case .spo2:
            return .teal
        case .respiratoryRate:
            return .indigo
        case .sleep:
            return .blue
        case .activeEnergy:
            return .orange
        case .restingEnergy:
            return .red
        case .steps:
            return .green
        case .physicalEffort:
            return .purple
        case .hrr:
            return .yellow
        }
    }

    var unit: String {
        switch self {
        case .heartRate:
            return "BPM"
        case .hrv:
            return "MS"
        case .restingHR:
            return "BPM"
        case .vo2Max:
            return "ML/KG"
        case .wristTemp:
            return "°C"
        case .spo2:
            return "%"
        case .respiratoryRate:
            return "BR/MIN"
        case .sleep:
            return ""
        case .activeEnergy:
            return "KCAL"
        case .restingEnergy:
            return "KCAL"
        case .steps:
            return ""
        case .physicalEffort:
            return "METS"
        case .hrr:
            return "BPM"
        }
    }

    var defaultSize: VitalCardSize {
        switch self {
        case .heartRate, .vo2Max, .wristTemp, .spo2, .respiratoryRate, .activeEnergy, .restingEnergy, .steps, .physicalEffort, .hrr:
            return .small
        case .hrv, .restingHR, .sleep:
            return .wide
        }
    }

    var defaultEnabled: Bool {
        switch self {
        case .heartRate, .hrv, .restingHR, .vo2Max, .wristTemp, .spo2, .sleep, .activeEnergy, .steps:
            return true
        case .respiratoryRate, .restingEnergy, .physicalEffort, .hrr:
            return false
        }
    }

    var visual: VitalVisualStyle {
        switch self {
        case .heartRate:
            return .waveform
        case .hrv, .restingHR, .vo2Max, .activeEnergy, .restingEnergy, .steps, .physicalEffort, .respiratoryRate, .hrr:
            return .sparkline
        case .spo2:
            return .arcGauge
        case .wristTemp:
            return .arcGauge
        case .sleep:
            return .sleepStages
        }
    }

    /// true when a higher value is the healthier direction (used to color the delta)
    var higherIsBetter: Bool {
        switch self {
        case .heartRate, .restingHR, .wristTemp, .respiratoryRate:
            return false
        case .hrv, .vo2Max, .spo2, .sleep, .activeEnergy, .restingEnergy, .steps, .physicalEffort, .hrr:
            return true
        }
    }
}

struct VitalSnapshot: Identifiable {
    let metric: VitalMetric
    var id: String { metric.rawValue }
    var value: String            // formatted, "--" when no data
    var unit: String
    var delta: String?           // e.g. "+2", "-0.4" — vs baseline, nil if unknown
    var deltaIsPositiveSignal: Bool   // whether the delta should be colored green
    var status: String?          // "Within typical range" / "Above typical" / "Below typical" / "Needs attention"
    var tone: VitalTone
    var points: [Double]         // chronological series for the visual (may be empty)
    var fraction: Double?        // 0...1 position along the arc gauge; nil when not applicable
    var gaugeValue: String?      // numeric readout drawn inside the arc gauge, e.g. "97%"
    var sleepStages: SleepStageBreakdown?
    var hasData: Bool

    /// Whether this snapshot has enough data to draw its visual. When false the
    /// card omits the visual entirely rather than reserving space for an empty
    /// chart placeholder.
    var hasVisualData: Bool {
        guard hasData else { return false }
        switch metric.visual {
        case .waveform, .sparkline:
            return points.count >= 2
        case .arcGauge:
            guard let fraction else { return false }
            return fraction.isFinite
        case .sleepStages:
            return sleepStages?.hasData == true
        case .none:
            return false
        }
    }

    init(
        metric: VitalMetric,
        value: String,
        unit: String,
        delta: String? = nil,
        deltaIsPositiveSignal: Bool = false,
        status: String? = nil,
        tone: VitalTone = .neutral,
        points: [Double] = [],
        fraction: Double? = nil,
        gaugeValue: String? = nil,
        sleepStages: SleepStageBreakdown? = nil,
        hasData: Bool = false
    ) {
        self.metric = metric
        self.value = value
        self.unit = unit
        self.delta = delta
        self.deltaIsPositiveSignal = deltaIsPositiveSignal
        self.status = status
        self.tone = tone
        self.points = points
        self.fraction = fraction
        self.gaugeValue = gaugeValue
        self.sleepStages = sleepStages
        self.hasData = hasData
    }
}

struct SleepStageBreakdown: Equatable {
    let deep: Double     // seconds
    let core: Double
    let rem: Double
    let awake: Double
    var total: Double { deep + core + rem + awake }
    var hasData: Bool { total > 0 }
}
