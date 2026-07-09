import Foundation

final class AppModeHistoryStore {
    static let shared = AppModeHistoryStore()

    private init() {}

    func recordModeChange(to newMode: AppMode) {
        var periods = loadPeriods()

        if let lastIndex = periods.lastIndex(where: { $0.endDate == nil }) {
            periods[lastIndex].endDate = Date()
        }

        if newMode != .active {
            periods.append(AppModePeriod(mode: newMode, startDate: Date()))
        }

        savePeriods(periods)
    }

    static func periods(overlapping range: ClosedRange<Date>) -> [AppModePeriod] {
        let periods = AppModeHistoryStore.shared.loadPeriods()
        return periods.filter { period in
            let periodEnd = period.endDate ?? Date()
            let rangeStart = range.lowerBound
            let rangeEnd = range.upperBound

            return period.startDate <= rangeEnd && periodEnd >= rangeStart
        }
    }

    private func loadPeriods() -> [AppModePeriod] {
        guard let data = UserDefaults.standard.data(forKey: "vector.appModeHistory"),
              let periods = try? JSONDecoder().decode([AppModePeriod].self, from: data) else {
            return []
        }
        return periods
    }

    private func savePeriods(_ periods: [AppModePeriod]) {
        if let data = try? JSONEncoder().encode(periods) {
            UserDefaults.standard.set(data, forKey: "vector.appModeHistory")
        }
    }
}
