import Foundation

struct StressEngine {

    static func computeScore(
        hrvSeries: [(date: Date, value: Double)],
        restingHRSeries: [(date: Date, value: Double)],
        respiratorySeries: [(date: Date, value: Double)] = [],
        sleepQuality: Double = 0.5,
        sleepWakeTime: Date? = nil,
        wristTempDeviation: Double? = nil,
        daytimeHRSamples: [(date: Date, value: Double)] = [],
        workoutIntervals: [DateInterval] = [],
        restingHR: Double? = nil,
        now: Date = Date()
    ) -> StressScore {

        let calendar = Calendar.current

        // Extract today's entries and compute prior-day baselines
        let todayHRV = hrvSeries.last(where: { calendar.isDate($0.date, inSameDayAs: now) })?.value
        let todayRHR = restingHRSeries.last(where: { calendar.isDate($0.date, inSameDayAs: now) })?.value
        let todayRR = respiratorySeries.last(where: { calendar.isDate($0.date, inSameDayAs: now) })?.value

        let priorHRVs = hrvSeries.filter { !calendar.isDate($0.date, inSameDayAs: now) }.map(\.value)
        let priorRHRs = restingHRSeries.filter { !calendar.isDate($0.date, inSameDayAs: now) }.map(\.value)
        let priorRRs = respiratorySeries.filter { !calendar.isDate($0.date, inSameDayAs: now) }.map(\.value)

        let hrvBaselineValue = BaselineStatistics.mean(priorHRVs) ?? (todayHRV ?? 45.0)
        let rhrBaselineValue = BaselineStatistics.mean(priorRHRs) ?? (todayRHR ?? 65.0)
        let rrBaselineValue = priorRRs.count >= 2 ? BaselineStatistics.mean(priorRRs) : nil

        // --- HRV component (weight 0.30): lower HRV vs baseline = more stress ---
        var hrvComponent: Double? = nil
        if let today = todayHRV {
            if let z = BaselineStatistics.logZScore(current: today, history: priorHRVs) {
                hrvComponent = (50 - z * 15).clamped(to: 0...100)
            }
        }

        // --- RHR component (weight 0.15): higher RHR vs baseline = more stress ---
        var rhrComponent: Double? = nil
        if let today = todayRHR {
            if let z = BaselineStatistics.logZScore(current: today, history: priorRHRs) {
                rhrComponent = (50 + z * 15).clamped(to: 0...100)
            }
        }

        // --- Daytime HR elevation (weight 0.25): recent intraday signal ---
        var daytimeHRComponent: Double? = nil
        var recentHRMedian: Double? = nil
        var hrElevationPercent: Double? = nil

        if let baseRHR = restingHR, baseRHR > 0 {
            let threeHoursAgo = now.addingTimeInterval(-3 * 3600)
            var recentSamples = daytimeHRSamples.filter { $0.date >= threeHoursAgo && $0.date <= now }

            // Exclude samples within workouts + 30min EPOC window
            let epocWindow: TimeInterval = 1800
            recentSamples = recentSamples.filter { sample in
                !workoutIntervals.contains { interval in
                    let epocEnd = interval.end.addingTimeInterval(epocWindow)
                    return sample.date >= interval.start && sample.date <= epocEnd
                }
            }

            if recentSamples.count >= 12 {
                if let median = BaselineStatistics.median(recentSamples.map(\.value)) {
                    recentHRMedian = median
                    let elevation = (median - baseRHR) / baseRHR
                    hrElevationPercent = elevation * 100

                    var componentValue = (50 + (elevation - 0.15) * 175).clamped(to: 0...100)

                    // CAR softening: applied here within the component
                    if let hrs = sleepWakeTime.map({ now.timeIntervalSince($0) / 3600 }), hrs < 1.5 {
                        componentValue += -8.0 * (1.0 - hrs / 1.5)
                        componentValue = componentValue.clamped(to: 0...100)
                    }

                    daytimeHRComponent = componentValue
                }
            }
        }

        // --- Sleep component (weight 0.15): recentered ---
        let sleepComponent = ((0.65 - sleepQuality) * 100 + 50).clamped(to: 0...100)

        // --- Respiratory rate component (weight 0.10) ---
        var rrComponent: Double? = nil
        if let today = todayRR, let baseline = rrBaselineValue {
            let deviation = (today - baseline) / baseline
            rrComponent = (50 + deviation * 100).clamped(to: 0...100)
        }

        // --- Wrist temperature component (weight 0.05) ---
        let tempComponent: Double? = wristTempDeviation.map { dev in
            let tolerance = 0.15
            let signed = dev >= 0 ? max(0, dev - tolerance) : min(0, dev + tolerance)
            return (50 + signed * 60).clamped(to: 0...100)
        }

        // --- Weighted final score, re-normalized over present signals ---
        var parts: [(value: Double, weight: Double)] = []

        if let hrv = hrvComponent {
            parts.append((hrv, 0.30))
        }
        if let rhr = rhrComponent {
            parts.append((rhr, 0.15))
        }
        if let daytimeHR = daytimeHRComponent {
            parts.append((daytimeHR, 0.25))
        }
        parts.append((sleepComponent, 0.15))
        if let rr = rrComponent {
            parts.append((rr, 0.10))
        }
        if let temp = tempComponent {
            parts.append((temp, 0.05))
        }

        let totalWeight = parts.reduce(0) { $0 + $1.weight }
        let weighted = parts.reduce(0) { $0 + $1.value * $1.weight }
        let weightedScore = totalWeight > 0 ? weighted / totalWeight : 50

        let finalScore = Int(weightedScore.clamped(to: 0...100))

        // --- Circadian phase ---
        let (phase, hoursSinceWake) = circadianPhase(wakeTime: sleepWakeTime, now: now)

        return StressScore(
            score: finalScore,
            hrvValue: todayHRV ?? (hrvSeries.last?.value ?? 0),
            restingHeartRate: todayRHR ?? (restingHRSeries.last?.value ?? 0),
            date: now,
            hrvBaseline: hrvBaselineValue,
            rhrBaseline: rhrBaselineValue,
            sleepQuality: sleepQuality,
            respiratoryRate: todayRR,
            respiratoryBaseline: rrBaselineValue,
            wristTempDeviation: wristTempDeviation,
            circadianPhase: phase,
            hoursSinceWake: hoursSinceWake,
            recentHR: recentHRMedian,
            hrElevationPercent: hrElevationPercent
        )
    }

    private static func circadianPhase(wakeTime: Date?, now: Date) -> (CircadianPhase, Double?) {
        let hour = Calendar.current.component(.hour, from: now)
        var hoursSinceWake: Double? = nil

        if let wake = wakeTime {
            hoursSinceWake = now.timeIntervalSince(wake) / 3600
        }

        // If we know wake time, use it for early morning detection
        if let hrs = hoursSinceWake {
            if hrs < 1.0 { return (.earlyMorning, hrs) }
            if hrs < 3.0 { return (.morning, hrs) }
        }

        switch hour {
        case 5..<9:   return (.morning, hoursSinceWake)
        case 9..<13:  return (.midday, hoursSinceWake)
        case 13..<17: return (.afternoon, hoursSinceWake)
        case 17..<21: return (.evening, hoursSinceWake)
        default:      return (.night, hoursSinceWake)
        }
    }
}
