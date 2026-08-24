import Foundation

/// A single data point in the physical effort series.
struct EffortPoint: Codable, Sendable {
    let date: Date
    let value: Double
}

/// The last-known surface-level dashboard state, persisted so the Home cards render
/// real values immediately on a cold launch instead of zero-valued placeholders while
/// `refreshToday()` runs its HealthKit queries.
struct DashboardSnapshot: Codable, Sendable {
    let savedAt: Date
    let lastSyncedDate: Date?

    // Scores (all optional)
    let recoveryScore: RecoveryScore?
    let exertionScore: ExertionScore?
    let sleepAnalysis: SleepAnalysis?
    let stressScore: StressScore?
    let nutritionSummary: NutritionSummary?

    // Latest vitals
    let latestHeartRate: Double?
    let latestRestingHR: Double?
    let latestHRV: Double?
    let latestVO2Max: Double?
    let latestWristTempDeviation: Double?
    let latestSpO2: Double?
    let spo2Baseline: Double?
    let latestHRR: Double?
    let hrrBaseline: Double?
    let todayPhysicalEffort: Double?

    // Today's totals
    let todaySteps: Double
    let todayActiveCalories: Double
    let todayBasalCalories: Double

    // Physical effort series (converted to Codable form)
    let physicalEffortSeries: [EffortPoint]

    // Generated overview fields
    let overviewHeadline: String?
    let overviewBody: String?
    let overviewStatus: String?
    let overviewContext: String?
}

struct DashboardSnapshotStore {
    private static let key = "vector.dashboardSnapshot"

    static func save(_ snapshot: DashboardSnapshot) {
        guard let data = try? JSONEncoder().encode(snapshot) else { return }
        UserDefaults.standard.set(data, forKey: key)
    }

    static func load() -> DashboardSnapshot? {
        guard let data = UserDefaults.standard.data(forKey: key),
              let snapshot = try? JSONDecoder().decode(DashboardSnapshot.self, from: data) else {
            return nil
        }

        // Staleness guard: return nil if snapshot is more than 24 hours old
        let maxAge: TimeInterval = 86400
        guard Date().timeIntervalSince(snapshot.savedAt) < maxAge else {
            return nil
        }

        return snapshot
    }
}
