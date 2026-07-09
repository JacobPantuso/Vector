import Foundation

/// A named, scheduled meal that can be auto-logged (e.g. Breakfast, Lunch, Pre-workout).
struct MealSchedule: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var isEnabled: Bool
    var scheduledHour: Int
    var scheduledMinute: Int
    var items: [BreakfastSchedule.ScheduledItem]

    init(id: UUID = UUID(), name: String, isEnabled: Bool = true, scheduledHour: Int = 8, scheduledMinute: Int = 0, items: [BreakfastSchedule.ScheduledItem] = []) {
        self.id = id
        self.name = name
        self.isEnabled = isEnabled
        self.scheduledHour = scheduledHour
        self.scheduledMinute = scheduledMinute
        self.items = items
    }

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }
    var timeLabel: String { String(format: "%02d:%02d", scheduledHour, scheduledMinute) }
}
