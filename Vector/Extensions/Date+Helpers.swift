import Foundation

extension Date {
    var startOfDay: Date {
        Calendar.current.startOfDay(for: self)
    }

    func daysAgo(_ days: Int) -> Date {
        Calendar.current.date(byAdding: .day, value: -days, to: self) ?? self
    }

    func formatted(as style: String) -> String {
        let formatter = DateFormatter()
        formatter.locale = Locale.current

        switch style.lowercased() {
        case "short":
            formatter.dateStyle = .short
            formatter.timeStyle = .none
        case "long":
            formatter.dateStyle = .long
            formatter.timeStyle = .none
        case "time":
            formatter.dateStyle = .none
            formatter.timeStyle = .short
        case "datetime":
            formatter.dateStyle = .short
            formatter.timeStyle = .short
        case "iso8601":
            return ISO8601DateFormatter().string(from: self)
        default:
            formatter.dateStyle = .medium
            formatter.timeStyle = .none
        }

        return formatter.string(from: self)
    }

    var isToday: Bool {
        Calendar.current.isDateInToday(self)
    }

    func daysBetween(_ date: Date) -> Int {
        let calendar = Calendar.current
        let components = calendar.dateComponents([.day], from: self.startOfDay, to: date.startOfDay)
        return components.day ?? 0
    }
}
