import SwiftUI
import HealthKit

enum VitalSnapshotBuilder {
    static func snapshot(
        for metric: VitalMetric,
        service: HealthKitService,
        series: [(date: Date, value: Double)],
        paceSeries: [(date: Date, value: Double)] = []
    ) -> VitalSnapshot {
        // Sleep is handled specially since formattedDuration is a String
        if metric == .sleep {
            return snapshotForSleep(service: service, series: series)
        }

        // Wrist temperature is handled specially for deviation display
        if metric == .wristTemp {
            return snapshotForWristTemp(service: service, series: series)
        }

        if metric == .spo2 {
            return snapshotForSpO2(service: service, series: series)
        }

        let currentValue = currentValue(for: metric, from: service)
        let hasData = currentValue != nil

        // Format the current value
        let formattedValue: String
        if let value = currentValue {
            formattedValue = formatValue(value, for: metric)
        } else {
            formattedValue = "--"
        }

        // Determine if we use pace baseline for this metric
        let usePace = usesPaceBaseline(metric) && paceSeries.count >= 4

        // Compute baseline and delta
        let effectiveSeries = usePace ? paceSeries : series
        let priorValues: [Double]
        if usePace {
            let isTodayLast = effectiveSeries.last.map { Calendar.current.isDateInToday($0.date) } ?? false
            priorValues = Array((isTodayLast ? effectiveSeries.dropLast() : effectiveSeries[...]).map(\.value))
        } else {
            priorValues = Array(effectiveSeries.dropLast().map(\.value))
        }

        let baseline = BaselineStatistics.median(priorValues)
        let deltaString: String?
        let deltaIsPositive: Bool

        if let current = currentValue, let base = baseline, priorValues.count >= 3 {
            let delta = current - base
            deltaString = formatDelta(delta, for: metric)
            deltaIsPositive = (delta >= 0) == metric.higherIsBetter
        } else {
            deltaString = nil
            deltaIsPositive = false
        }

        // Compute status and tone
        let (status, tone): (String?, VitalTone)
        if usePace && priorValues.count >= 3 {
            if let current = currentValue, let base = baseline {
                let delta = current - base
                let attribution: String? = metric == .heartRate
                    ? recentWorkoutExplainingElevation(in: service.recentWorkouts).map(activityNoun(for:))
                    : nil
                (status, tone) = computePaceStatus(for: metric, delta: delta, sd: BaselineStatistics.standardDeviation(priorValues) ?? 0, workoutAttribution: attribution)
            } else {
                (status, tone) = (nil, .neutral)
            }
        } else if usePace {
            (status, tone) = (nil, .neutral)
        } else {
            (status, tone) = computeStatus(
                for: metric,
                currentValue: currentValue,
                baseline: baseline,
                priorValues: priorValues
            )
        }

        // Cap points for sparkline metrics to last 8. Heart rate keeps its full intraday
        // waveform, so it is unaffected by the pace series.
        let displayPoints: [Double]
        if metric.visual == .sparkline {
            let source = (usePace && !paceSeries.isEmpty) ? paceSeries : series
            displayPoints = Array(source.suffix(8).map(\.value))
        } else {
            displayPoints = series.map(\.value)
        }

        // Compute fraction for arc gauge
        let fraction = computeFraction(for: metric, value: currentValue)

        return VitalSnapshot(
            metric: metric,
            value: formattedValue,
            unit: metric.unit,
            delta: deltaString,
            deltaIsPositiveSignal: deltaIsPositive,
            status: status,
            tone: tone,
            points: displayPoints,
            fraction: fraction,
            hasData: hasData
        )
    }

    // MARK: - Sleep Snapshot (special case with String value)

    private static func snapshotForSleep(
        service: HealthKitService,
        series: [(date: Date, value: Double)]
    ) -> VitalSnapshot {
        guard let analysis = service.sleepAnalysis else {
            return VitalSnapshot(metric: .sleep, value: "--", unit: "", hasData: false)
        }

        let targetHours = max(analysis.sleepTargetHours, 1)
        let shortfall = (targetHours * 3600) - analysis.asleepDuration
        let targetText = targetHours == targetHours.rounded()
            ? String(format: "%.0fh", targetHours)
            : String(format: "%.1fh", targetHours)

        let status: String
        let tone: VitalTone
        if shortfall <= 5 * 60 {
            status = "Met your \(targetText) goal"
            tone = .good
        } else {
            status = "\(formatShortDuration(shortfall)) below your \(targetText) goal"
            tone = shortfall <= 45 * 60 ? .neutral : .warn
        }

        return VitalSnapshot(
            metric: .sleep,
            value: analysis.formattedDuration,
            unit: "asleep",
            delta: nil,
            deltaIsPositiveSignal: false,
            status: status,
            tone: tone,
            points: series.map(\.value),
            fraction: nil,
            sleepStages: SleepStageBreakdown(
                deep: analysis.deepDuration,
                core: analysis.coreDuration,
                rem: analysis.remDuration,
                awake: analysis.awakeDuration
            ),
            hasData: true
        )
    }

    /// "1h 6m" / "42m" — used for the sleep shortfall line.
    private static func formatShortDuration(_ seconds: Double) -> String {
        let total = Int(max(0, seconds).rounded())
        let h = total / 3600
        let m = (total % 3600) / 60
        if h > 0 {
            return m > 0 ? "\(h)h \(m)m" : "\(h)h"
        }
        return "\(m)m"
    }

    // MARK: - Wrist Temperature Snapshot (special deviation case)

    private static func snapshotForWristTemp(
        service: HealthKitService,
        series: [(date: Date, value: Double)]
    ) -> VitalSnapshot {
        guard let dev = service.latestWristTempDeviation else {
            return VitalSnapshot(metric: .wristTemp, value: "--", unit: "", hasData: false)
        }

        let word: String
        let tone: VitalTone
        switch dev {
        case ..<(-0.7):      word = "Low";      tone = .warn
        case ..<(-0.3):      word = "Below";    tone = .neutral
        case ..<0.3:         word = "Normal";   tone = .good
        case ..<0.7:         word = "Elevated"; tone = .neutral
        default:             word = "High";     tone = .warn
        }

        let detail: String
        if abs(dev) < 0.05 {
            detail = "At your baseline"
        } else {
            detail = dev > 0 ? "Above your baseline" : "Below your baseline"
        }

        return VitalSnapshot(
            metric: .wristTemp,
            value: word,
            unit: "",
            delta: nil,
            deltaIsPositiveSignal: false,
            status: detail,
            tone: tone,
            points: series.map(\.value),
            fraction: max(0, min(1, (dev + 1.0) / 2.0)),
            gaugeValue: abs(dev) < 0.05 ? "0.0°" : String(format: "%+.1f°", dev),
            hasData: true
        )
    }

    // MARK: - Blood Oxygen Snapshot (word hero, reading shown in the gauge)

    private static func snapshotForSpO2(
        service: HealthKitService,
        series: [(date: Date, value: Double)]
    ) -> VitalSnapshot {
        guard let value = service.latestSpO2 else {
            return VitalSnapshot(metric: .spo2, value: "--", unit: "", hasData: false)
        }

        let word: String
        let tone: VitalTone
        switch value {
        case ..<90:  word = "Very low"; tone = .warn
        case ..<95:  word = "Low";      tone = .neutral
        default:     word = "Normal";   tone = .good
        }

        // Baseline-relative status when there is enough history; otherwise fall back
        // to the clinical range, which needs no history to be true.
        let priorValues = Array(series.dropLast().map(\.value))
        let baseline = BaselineStatistics.median(priorValues)
        let status: String
        if let base = baseline, priorValues.count >= 3 {
            let delta = value - base
            let sd = BaselineStatistics.standardDeviation(priorValues) ?? 1.0
            if abs(delta) <= sd {
                status = "Within your typical range"
            } else {
                status = delta > 0 ? "Above your typical range" : "Below your typical range"
            }
        } else {
            status = value >= 95 ? "In the healthy range" : "Below the healthy range"
        }

        return VitalSnapshot(
            metric: .spo2,
            value: word,
            unit: "",
            delta: nil,
            deltaIsPositiveSignal: false,
            status: status,
            tone: tone,
            points: series.map(\.value),
            fraction: max(0, min(1, (value - 90) / 10)),
            gaugeValue: String(format: "%.0f%%", value),
            hasData: true
        )
    }

    // MARK: - Helper Functions

    private static func currentValue(for metric: VitalMetric, from service: HealthKitService) -> Double? {
        switch metric {
        case .heartRate:
            return service.latestHeartRate
        case .hrv:
            return service.latestHRV
        case .restingHR:
            return service.latestRestingHR
        case .vo2Max:
            return service.latestVO2Max
        case .wristTemp:
            return service.latestWristTempDeviation
        case .spo2:
            return service.latestSpO2
        case .respiratoryRate:
            return service.sleepAnalysis?.respiratoryRate
        case .sleep:
            return nil  // Sleep handled separately
        case .activeEnergy:
            return service.todayActiveCalories
        case .restingEnergy:
            return service.todayBasalCalories
        case .steps:
            return service.todaySteps
        case .physicalEffort:
            return service.todayPhysicalEffort
        case .hrr:
            return service.latestHRR
        }
    }

    private static func formatValue(_ value: Double, for metric: VitalMetric) -> String {
        switch metric {
        case .heartRate, .restingHR, .steps, .activeEnergy, .restingEnergy, .spo2, .hrr:
            return String(Int(value))
        case .hrv:
            return String(Int(value))
        case .vo2Max:
            return String(format: "%.1f", value)
        case .wristTemp:
            return String(format: "%+.1f", value)
        case .respiratoryRate:
            return String(format: "%.1f", value)
        case .physicalEffort:
            return String(format: "%.1f", value)
        case .sleep:
            return "--"  // Never called; sleep handled in snapshotForSleep
        }
    }

    private static func formatDelta(_ delta: Double, for metric: VitalMetric) -> String {
        let sign = delta >= 0 ? "+" : ""
        switch metric {
        case .heartRate, .restingHR, .steps, .activeEnergy, .restingEnergy, .spo2, .hrv, .hrr:
            return sign + String(Int(delta))
        case .vo2Max:
            return sign + String(format: "%.1f", delta)
        case .wristTemp:
            return String(format: "%+.1f", delta)
        case .respiratoryRate:
            return sign + String(format: "%.1f", delta)
        case .physicalEffort:
            return sign + String(format: "%.1f", delta)
        case .sleep:
            return ""
        }
    }

    private static func computeStatus(
        for metric: VitalMetric,
        currentValue: Double?,
        baseline: Double?,
        priorValues: [Double]
    ) -> (String?, VitalTone) {
        guard let current = currentValue, let base = baseline, priorValues.count >= 3 else {
            return (nil, .neutral)
        }

        // Special handling for vo2Max: no baseline status when there are <3 points
        if metric == .vo2Max, priorValues.count < 3 {
            return (nil, .neutral)
        }

        let delta = current - base
        let sd = BaselineStatistics.standardDeviation(priorValues) ?? 1.0

        if abs(delta) <= sd {
            return ("Within typical range", .good)
        }

        let isHealthyDirection = (delta > 0) == metric.higherIsBetter

        if abs(delta) <= 2 * sd {
            let status = delta > 0 ? "Above typical" : "Below typical"
            return (status, .neutral)
        } else {
            // Beyond 2 SD — check if unhealthy
            if isHealthyDirection {
                return ("Above typical", .neutral)
            } else {
                return ("Needs attention", .warn)
            }
        }
    }

    private static func computeFraction(for metric: VitalMetric, value: Double?) -> Double? {
        guard let value else { return nil }

        switch metric {
        case .spo2:
            // Normalize 90...100 into 0...1
            return max(0, min(1, (value - 90) / 10))

        case .wristTemp:
            // Normalize −1.0...+1.0 into 0...1
            return max(0, min(1, (value + 1.0) / 2.0))

        default:
            return nil
        }
    }

    /// Metrics whose raw value is not comparable across the day — either they accumulate from
    /// midnight (steps, energy) or they swing with activity (heart rate). These are judged
    /// against a time-of-day-matched baseline instead of prior days' full-day figures.
    private static func usesPaceBaseline(_ metric: VitalMetric) -> Bool {
        switch metric {
        case .steps, .activeEnergy, .restingEnergy, .physicalEffort, .heartRate:
            return true
        default:
            return false
        }
    }

    /// The most recently ended workout whose recovery window still covers now, if any.
    /// An elevated heart rate shortly after training is expected, not a warning sign.
    private static func recentWorkoutExplainingElevation(
        in workouts: [HKWorkout],
        now: Date = Date()
    ) -> HKWorkout? {
        workouts
            .filter { $0.endDate <= now && now.timeIntervalSince($0.endDate) <= recoveryWindow(for: $0) }
            .max(by: { $0.endDate < $1.endDate })
    }

    /// How long after a workout an elevated heart rate is still attributable to it.
    /// Longer and harder sessions keep the heart rate up for longer.
    private static func recoveryWindow(for workout: HKWorkout) -> TimeInterval {
        let minutes = workout.duration / 60
        var window = 45 + minutes * 1.5

        // Intensity proxy: active calories burned per minute.
        if minutes >= 5,
           let kcal = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?
               .sumQuantity()?
               .doubleValue(for: .kilocalorie()) {
            let rate = kcal / minutes
            if rate >= 10 {
                window *= 1.25
            } else if rate < 4 {
                window *= 0.75
            }
        }

        return min(max(window, 30), 180) * 60
    }

    /// Lowercase noun that reads naturally after "your" — "Recovering from your walk".
    private static func activityNoun(for workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .running: return "run"
        case .walking: return "walk"
        case .cycling: return "ride"
        case .hiking: return "hike"
        case .swimming: return "swim"
        case .yoga: return "yoga session"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "strength session"
        case .highIntensityIntervalTraining: return "HIIT session"
        case .dance: return "dance session"
        case .cooldown: return "cooldown"
        case .elliptical: return "elliptical session"
        case .rowing: return "row"
        case .stairClimbing: return "stair climb"
        default: return "workout"
        }
    }

    /// Wording for a time-of-day comparison. Being behind on a running total early in the day is
    /// normal, not a problem, so these never escalate to `.warn` on the cumulative metrics — only
    /// an instantaneous reading (heart rate) that is genuinely off for this hour does.
    private static func computePaceStatus(
        for metric: VitalMetric,
        delta: Double,
        sd: Double,
        workoutAttribution: String? = nil
    ) -> (String?, VitalTone) {
        let threshold = max(sd, paceFloor(for: metric))

        if abs(delta) <= threshold {
            return ("Within your typical range", .good)
        }

        if delta > 0 {
            if metric == .heartRate {
                if let workoutAttribution {
                    return ("Recovering from your \(workoutAttribution)", .neutral)
                }
                return abs(delta) > 2 * threshold
                    ? ("Elevated for this time of day", .warn)
                    : ("Above your usual for this time", .neutral)
            } else {
                return ("Ahead of your usual pace", .good)
            }
        }

        if metric == .heartRate {
            // Phrased as a range, not a shortfall. The pace metrics below read as
            // "behind" because they are running totals with somewhere to get to;
            // a heart rate has no target, and a low reading has many benign
            // explanations, so it gets the complement of "Within your typical
            // range" rather than the vocabulary of falling short.
            return ("Below your typical range", .neutral)
        } else {
            return abs(delta) > 2 * threshold
                ? ("Well behind your usual pace", .neutral)
                : ("Behind your usual pace", .neutral)
        }
    }

    /// Floor value for pace baseline comparison — prevents near-zero SD from making every tiny
    /// difference "ahead"/"behind".
    private static func paceFloor(for metric: VitalMetric) -> Double {
        switch metric {
        case .steps:
            return 400
        case .activeEnergy, .restingEnergy:
            return 40
        case .physicalEffort:
            return 0.3
        case .heartRate:
            return 4
        default:
            return 0
        }
    }
}
