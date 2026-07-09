import Foundation

/// Persists nightly overnight RMSSD (beat-to-beat HRV, ms) so Recovery can compare tonight's
/// value against a personal baseline in the same units. One record per calendar day; 30-day
/// retention. Mirrors SleepDebtStore.
struct HRVNightRecord: Codable, Sendable {
    let date: Date
    let rmssd: Double
}

enum HRVHistoryStore {
    private static let key = "hrvRMSSDNightHistory"
    private static let retentionDays = 30

    static func record(date: Date, rmssd: Double) {
        guard rmssd > 0 else { return }
        let cal = Calendar.current
        let day = cal.startOfDay(for: date)
        var records = all().filter { cal.startOfDay(for: $0.date) != day }
        records.append(HRVNightRecord(date: day, rmssd: rmssd))
        let cutoff = cal.date(byAdding: .day, value: -retentionDays, to: Date()) ?? Date()
        records = records.filter { $0.date >= cutoff }.sorted { $0.date < $1.date }
        if let data = try? JSONEncoder().encode(records) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func all() -> [HRVNightRecord] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let records = try? JSONDecoder().decode([HRVNightRecord].self, from: data) else { return [] }
        return records.sorted { $0.date < $1.date }
    }

    /// Stored RMSSD values within the last `days`, chronological (oldest first, newest last).
    static func recentValues(days: Int) -> [Double] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return all().filter { $0.date >= cutoff }.map(\.rmssd)
    }
}
