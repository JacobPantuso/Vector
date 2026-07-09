import Foundation

struct StressHistoryStore {
    private static let key = "vector.stressHistory"

    static func save(_ score: StressScore) {
        var history = load()
        let calendar = Calendar.current
        history.removeAll { calendar.compare($0.date, to: score.date, toGranularity: .hour) == .orderedSame }
        history.append(score)
        let cutoff = calendar.date(byAdding: .day, value: -30, to: Date()) ?? Date()
        history = history.filter { $0.date > cutoff }
        if let data = try? JSONEncoder().encode(history) {
            UserDefaults.standard.set(data, forKey: key)
        }
    }

    static func load() -> [StressScore] {
        guard let data = UserDefaults.standard.data(forKey: key),
              let history = try? JSONDecoder().decode([StressScore].self, from: data) else {
            return []
        }
        return history.sorted { $0.date < $1.date }
    }

    static func loadLast24Hours() -> [StressScore] {
        let allHistory = load()
        let calendar = Calendar.current
        let cutoff = calendar.date(byAdding: .hour, value: -24, to: Date()) ?? Date()
        return allHistory.filter { $0.date > cutoff }
    }
}
