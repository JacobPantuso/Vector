import Foundation

/// Persists nightly "asleep" durations so the engine can derive a personalized sleep need
/// and a decaying sleep-debt figure. One record per calendar day; 30-day retention.
struct SleepNightRecord: Codable, Sendable {
    let date: Date
    let asleepHours: Double
}

enum SleepDebtStore {
    private static let key = "sleepNightHistory"
    private static let retentionDays = 30

    static func record(date: Date, asleepHours: Double) {
        guard asleepHours > 0 else { return }
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        var records = all().filter { cal.startOfDay(for: $0.date) != day }
        records.append(SleepNightRecord(date: day, asleepHours: asleepHours))
        let cutoff = cal.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        records = records.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func all() -> [SleepNightRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([SleepNightRecord].self, from: data) else { return [] }
        return records.sorted { $0.date < $1.date }
    }

    static func recentNights(days: Int) -> [SleepNightRecord] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return all().filter { $0.date >= cutoff }
    }
}
