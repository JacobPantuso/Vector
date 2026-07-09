import Foundation

struct ScoreHistoryStore {
    enum Metric: String {
        case stress, recovery, exertion, sleep, sleepEfficiency, bedtime
    }

    private struct Entry: Codable {
        let score: Int
        let date: Date
    }

    private static func key(for metric: Metric) -> String {
        "vector.scoreHistory.\(metric.rawValue)"
    }

    static func save(metric: Metric, score: Int) {
        var history = loadEntries(metric: metric)
        let calendar = Calendar.current
        history.removeAll { calendar.compare($0.date, to: Date(), toGranularity: .hour) == .orderedSame }
        history.append(Entry(score: score, date: Date()))
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        history = history.filter { $0.date > cutoff }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key(for: metric))
        }
    }

    static func saveHistorical(metric: Metric, score: Int, date: Date) {
        var history = loadEntries(metric: metric)
        let calendar = Calendar.current
        history.removeAll { calendar.isDate($0.date, inSameDayAs: date) }
        history.append(Entry(score: score, date: date))
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        history = history.filter { $0.date > cutoff }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key(for: metric))
        }
    }

    static func average(for metric: Metric) -> Int? {
        let entries = loadEntries(metric: metric)
        guard !entries.isEmpty else { return nil }
        let sum = entries.reduce(0) { $0 + $1.score }
        return sum / entries.count
    }

    /// Real accumulated daily score history for charting, oldest first.
    static func series(for metric: Metric) -> [(date: Date, score: Int)] {
        loadEntries(metric: metric)
            .sorted { $0.date < $1.date }
            .map { (date: $0.date, score: $0.score) }
    }

    /// The score recorded on the same calendar day as `date`, if any.
    static func score(for metric: Metric, on date: Date) -> Int? {
        let cal = Calendar.current
        return loadEntries(metric: metric).first { cal.isDate($0.date, inSameDayAs: date) }?.score
    }

    private static func loadEntries(metric: Metric) -> [Entry] {
        guard let data = UserDefaults.standard.data(forKey: key(for: metric)),
              let entries = try? JSONDecoder().decode([Entry].self, from: data) else {
            return []
        }
        return entries
    }
}
