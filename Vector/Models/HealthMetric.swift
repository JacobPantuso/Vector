import Foundation

enum MetricCategory: String, Codable, Sendable, CaseIterable {
    case recovery, exertion, sleep, vitals, nutrition, activity
}

struct HealthMetric: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let value: Double
    let unit: String
    let category: MetricCategory
    let date: Date
    var previousValue: Double?

    var delta: Double? {
        guard let prev = previousValue else { return nil }
        return value - prev
    }

    var deltaPercentage: Double? {
        guard let prev = previousValue, prev != 0 else { return nil }
        return ((value - prev) / prev) * 100
    }

    init(id: UUID = UUID(), name: String, value: Double, unit: String, category: MetricCategory, date: Date = Date(), previousValue: Double? = nil) {
        self.id = id
        self.name = name
        self.value = value
        self.unit = unit
        self.category = category
        self.date = date
        self.previousValue = previousValue
    }
}
