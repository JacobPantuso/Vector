import Foundation
import HealthKit

/// Per-workout training load computed from heart-rate data.
struct WorkoutLoad: Sendable {
    let date: Date
    let trimp: Double                 // Banister TRIMP (HR-reserve based)
    let zoneSeconds: [TimeInterval]   // 5 elements: Z1...Z5
}

/// Yesterday's total training load relative to a typical training day, used to decide whether
/// tonight's elevated resting HR / suppressed HRV is expected post-exercise physiology.
struct PriorDayStrain: Sendable {
    let trimp: Double
    let typicalTrimp: Double
    var ratio: Double { typicalTrimp > 0 ? trimp / typicalTrimp : 0 }
    /// A clearly harder-than-usual day: either a big absolute session or well above the personal norm.
    var isHard: Bool { trimp >= 250 || (trimp >= 120 && ratio >= 1.5) }
    /// One-word descriptor of yesterday's load, used in user-facing copy.
    var descriptor: String {
        if trimp >= 450 || ratio >= 2.5 { return "extreme" }
        if trimp >= 250 || ratio >= 1.5 { return "high" }
        return "elevated"
    }
}

struct TrainingLoadEngine {
    static func computeExertion(loads: [WorkoutLoad], zoneLoads: [WorkoutLoad]? = nil, fitnessTargetMultiplier: Double = 1.0, now: Date = Date()) -> ExertionScore {
        let calendar = Calendar.current
        let startOfToday = calendar.startOfDay(for: now)
        let sevenDaysAgo = calendar.date(byAdding: .day, value: -7, to: now) ?? now
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: now) ?? now

        let todayLoads = loads.filter { $0.date >= startOfToday }
        let acute = loads.filter { $0.date >= sevenDaysAgo }
        let chronic = loads.filter { $0.date >= twentyEightDaysAgo }

        let todayStrain = todayLoads.reduce(0) { $0 + $1.trimp }
        let acuteLoad = acute.reduce(0) { $0 + $1.trimp }
        let chronicTotal = chronic.reduce(0) { $0 + $1.trimp }

        // Chronic load as a weekly-equivalent EWMA of daily TRIMP (one entry per calendar day,
        // zero-filled for days with no loads). More responsive than a flat mean, robust to days
        // with no samples, and handles multiple loads per day (e.g., HR + strength top-up).
        var chronicDaily: [Double] = []
        if !chronic.isEmpty {
            // Group loads by calendar day and sum trimp per day
            let grouped = Dictionary(grouping: chronic) { calendar.startOfDay(for: $0.date) }
            // Build zero-filled series from 28 days ago through today (inclusive)
            var current = calendar.startOfDay(for: twentyEightDaysAgo)
            while current <= startOfToday {
                chronicDaily.append(grouped[current]?.reduce(0, { $0 + $1.trimp }) ?? 0)
                current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
            }
        }
        let chronicLoad = chronicDaily.isEmpty
            ? 0
            : (BaselineStatistics.ewma(chronicDaily, alpha: 2.0 / 29.0) ?? (chronicTotal / 28)) * 7

        // Personal daily target derived from chronic load, scaled by fitness level; fallback when no history.
        let dailyTarget = Self.dailyTarget(chronicLoad: chronicLoad, fitnessTargetMultiplier: fitnessTargetMultiplier)
        let score = max(0, Int((todayStrain / dailyTarget) * 100))

        // Zone splits come from actual workouts only (not all-day HR), so "time in zone" reflects training.
        let zoneSplits = aggregateZones(zoneLoads ?? acute)

        var result = ExertionScore(
            score: score,
            acuteLoad: acuteLoad,
            chronicLoad: chronicLoad,
            todayStrain: todayStrain,
            date: now,
            zoneSplits: zoneSplits
        )
        result.fitnessTargetMultiplier = fitnessTargetMultiplier
        return result
    }

    /// Personal daily strain target derived from chronic load, scaled by fitness level.
    static func dailyTarget(chronicLoad: Double, fitnessTargetMultiplier: Double = 1.0) -> Double {
        let baseTarget = chronicLoad > 0 ? max(30, (chronicLoad / 7) * 1.5) : 80
        return baseTarget * max(0.5, fitnessTargetMultiplier)
    }

    /// Total TRIMP accumulated on the calendar day before `now`, plus the median of non-zero daily
    /// totals over the prior 28 days as the personal "typical day" reference.
    static func priorDayStrain(loads: [WorkoutLoad], now: Date = Date(), calendar: Calendar = .current) -> PriorDayStrain? {
        guard !loads.isEmpty else { return nil }
        let startOfToday = calendar.startOfDay(for: now)
        let yesterday = calendar.date(byAdding: .day, value: -1, to: startOfToday) ?? startOfToday
        let twentyEightDaysAgo = calendar.date(byAdding: .day, value: -28, to: now) ?? now

        // Group all loads by calendar day and sum trimp per day
        let allGrouped = Dictionary(grouping: loads) { calendar.startOfDay(for: $0.date) }
        let yesterdayTrimp = allGrouped[yesterday]?.reduce(0) { $0 + $1.trimp } ?? 0

        // Build 28-day daily totals (inclusive of yesterday) and compute median of non-zero days
        var dailyTotals: [Double] = []
        var current = calendar.startOfDay(for: twentyEightDaysAgo)
        while current <= yesterday {
            if let total = allGrouped[current] {
                let daySum = total.reduce(0) { $0 + $1.trimp }
                if daySum > 0 {
                    dailyTotals.append(daySum)
                }
            }
            current = calendar.date(byAdding: .day, value: 1, to: current) ?? current
        }

        let typicalTrimp = dailyTotals.isEmpty ? 0 : (BaselineStatistics.median(dailyTotals) ?? 0)
        return PriorDayStrain(trimp: yesterdayTrimp, typicalTrimp: typicalTrimp)
    }

    private static func aggregateZones(_ loads: [WorkoutLoad]) -> [ZoneTime] {
        var totals = [TimeInterval](repeating: 0, count: 5)
        for load in loads {
            for i in 0..<min(5, load.zoneSeconds.count) {
                totals[i] += load.zoneSeconds[i]
            }
        }
        let grand = totals.reduce(0, +)
        return (0..<5).map { i in
            ZoneTime(
                zone: i + 1,
                duration: totals[i],
                percentage: grand > 0 ? totals[i] / grand : 0
            )
        }
    }

    /// Banister TRIMP + HR-reserve zone split for a single workout.
    static func workoutLoad(
        date: Date,
        hrSamples: [(date: Date, value: Double)],
        restingHR: Double,
        maxHR: Double,
        fallbackEnergyKcal: Double,
        fallbackDuration: TimeInterval,
        isFemale: Bool = false
    ) -> WorkoutLoad {
        guard maxHR > restingHR, hrSamples.count > 1 else {
            // No usable HR — modest energy-based estimate so the session isn't zero.
            let estTrimp = min(150, fallbackEnergyKcal * 0.12)
            var zones = [TimeInterval](repeating: 0, count: 5)
            zones[1] = fallbackDuration   // park in Z2 as a neutral guess
            return WorkoutLoad(date: date, trimp: estTrimp, zoneSeconds: zones)
        }

        return integrate(date: date, hrSamples: hrSamples, restingHR: restingHR, maxHR: maxHR, isFemale: isFemale)
    }

    /// Banister TRIMP integration over arbitrary HR sample window.
    private static func integrate(
        date: Date,
        hrSamples: [(date: Date, value: Double)],
        restingHR: Double,
        maxHR: Double,
        isFemale: Bool = false
    ) -> WorkoutLoad {
        let sorted = hrSamples.sorted { $0.date < $1.date }
        var trimp = 0.0
        var zones = [TimeInterval](repeating: 0, count: 5)

        for i in 0..<(sorted.count - 1) {
            let dt = min(sorted[i + 1].date.timeIntervalSince(sorted[i].date), 120) // cap gaps at 2 min
            guard dt > 0 else { continue }
            let hr = sorted[i].value
            let hrr = ((hr - restingHR) / (maxHR - restingHR)).clamped(to: 0...1)
            let factor = isFemale ? 0.86 * exp(1.67 * hrr) : 0.64 * exp(1.92 * hrr)   // Banister TRIMP (sex-specific)
            trimp += (dt / 60.0) * hrr * factor
            zones[zoneIndex(hrr)] += dt
        }

        return WorkoutLoad(date: date, trimp: trimp, zoneSeconds: zones)
    }

    /// All-day strain grouped into one load per calendar day, from continuous HR.
    static func dailyLoads(
        hrSamples: [(date: Date, value: Double)],
        restingHR: Double,
        maxHR: Double,
        isFemale: Bool = false,
        calendar: Calendar = .current
    ) -> [WorkoutLoad] {
        guard maxHR > restingHR, !hrSamples.isEmpty else { return [] }
        let grouped = Dictionary(grouping: hrSamples) { calendar.startOfDay(for: $0.date) }
        return grouped.map { (day, samples) in
            integrate(date: day, hrSamples: samples, restingHR: restingHR, maxHR: maxHR, isFemale: isFemale)
        }
    }

    private static func zoneIndex(_ hrr: Double) -> Int {
        switch hrr {
        case ..<0.6: return 0   // Z1
        case ..<0.7: return 1   // Z2
        case ..<0.8: return 2   // Z3
        case ..<0.9: return 3   // Z4
        default:     return 4   // Z5
        }
    }

    /// Tanaka age-predicted maximum heart rate.
    static func estimatedMaxHR(age: Int) -> Double {
        208 - 0.7 * Double(age)
    }
}
