#if DEBUG
import Foundation
import SwiftUI

// MARK: - Mock model data for SwiftUI previews

extension RecoveryScore {
    /// Realistic "excellent recovery" sample for previews.
    static var mock: RecoveryScore {
        RecoveryScore(
            score: 78,
            hrvValue: 68,
            restingHeartRate: 52,
            sleepQuality: 0.82,
            hrvBaseline: 62,
            rhrBaseline: 54,
            respiratoryRate: 14.2,
            respiratoryBaseline: 14.5,
            wristTempDeviation: -0.1,
            spo2: 97,
            spo2Baseline: 96.5,
            hrr: 28,
            hrrBaseline: 25
        )
    }
}

extension ExertionScore {
    /// Realistic "moderate exertion, optimal load" sample for previews.
    static var mock: ExertionScore {
        ExertionScore(
            score: 52,
            acuteLoad: 420,
            chronicLoad: 380,
            todayStrain: 180,
            zoneSplits: [
                ZoneTime(zone: 1, duration: 600,  percentage: 0.18),
                ZoneTime(zone: 2, duration: 900,  percentage: 0.27),
                ZoneTime(zone: 3, duration: 1200, percentage: 0.36),
                ZoneTime(zone: 4, duration: 480,  percentage: 0.15),
                ZoneTime(zone: 5, duration: 120,  percentage: 0.04)
            ]
        )
    }
}

extension SleepAnalysis {
    /// Realistic "good 7.5h night" sample for previews.
    static var mock: SleepAnalysis {
        let wake = Calendar.current.date(bySettingHour: 7, minute: 5, second: 0, of: Date()) ?? Date()
        let bed = wake.addingTimeInterval(-28800)
        return SleepAnalysis(
            totalDuration: 28800,   // 8h in bed
            remDuration: 5400,      // 1.5h
            deepDuration: 3960,     // 1.1h
            coreDuration: 17640,    // 4.9h
            awakeDuration: 1800,    // 0.5h
            bedtime: bed,
            wakeTime: wake,
            respiratoryRate: 14.0,
            respiratoryBaseline: 14.5,
            wristTempDeviation: -0.05,
            wristTempBaseline: 33.2,
            wristTempOvernight: 33.15
        )
    }
}

extension StressScore {
    /// Realistic "low stress" sample for previews.
    static var mock: StressScore {
        StressScore(
            score: 32,
            hrvValue: 68,
            restingHeartRate: 52,
            hrvBaseline: 62,
            rhrBaseline: 54,
            sleepQuality: 0.82,
            respiratoryRate: 14.2,
            respiratoryBaseline: 14.5,
            wristTempDeviation: -0.05,
            circadianPhase: .midday,
            hoursSinceWake: 5.0,
            recentHR: 68,
            hrElevationPercent: 12
        )
    }
}

extension NutritionSummary {
    /// Realistic "calorie deficit" sample for previews.
    static var mock: NutritionSummary {
        NutritionSummary(
            caloriesConsumed: 1850,
            caloriesBurned: 2400,
            protein: 140,
            carbs: 180,
            fat: 60
        )
    }
}

extension HealthKitService {
    /// Populates this service with realistic mock data. Used by previews and by
    /// the DEBUG simulator boot path so the Dashboard renders with data.
    func applyMockData() {
        isAuthorized = true
        recoveryScore = .mock
        exertionScore = .mock
        sleepAnalysis = .mock
        stressScore = .mock
        nutritionSummary = .mock
        latestHeartRate = 64
        latestRestingHR = 52
        latestHRV = 68
        todaySteps = 8200
        todayActiveCalories = 540
        todayBasalCalories = 1680
        latestWristTempDeviation = -0.05
        todayPhysicalEffort = 4.2
        let today = Date()
        let calendar = Calendar.current
        physicalEffortSeries = (0..<21).map { daysAgo in
            let date = calendar.date(byAdding: .day, value: -daysAgo, to: today) ?? today
            let effort = 3.0 + Double.random(in: 0..<3)
            return (date: date, value: effort)
        }.reversed()
        latestHRR = 28
        hrrBaseline = 25
        lastSyncedDate = Date()
        generatedOverview = GeneratedOverview(
            reasoningSteps: "Recovery is strong and load is in the optimal band, so the athlete has room to build today.",
            headline: "Primed to Build",
            body: "Your recovery is excellent and last night's sleep was restful. With a balanced training load, today is a green light to add intensity.",
            status: "Build"
        )
    }

    /// A fully populated service for SwiftUI previews.
    static var preview: HealthKitService {
        let service = HealthKitService()
        service.applyMockData()
        return service
    }
}
#endif
