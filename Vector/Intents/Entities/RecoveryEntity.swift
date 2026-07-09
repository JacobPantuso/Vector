import AppIntents

struct RecoveryEntity: AppEntity {
    static var defaultQuery = RecoveryEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Recovery Score"

    var id: String
    var score: Int
    var level: String
    var hrvValue: Double
    var restingHeartRate: Double

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Recovery: \(score)%",
            subtitle: "\(level) — HRV \(String(format: "%.0f", hrvValue))ms",
            image: .init(systemName: score > 66 ? "battery.100" : score > 33 ? "battery.50" : "battery.25")
        )
    }
}

struct RecoveryEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [RecoveryEntity] {
        []
    }

    func suggestedEntities() async throws -> [RecoveryEntity] {
        [RecoveryEntity(id: "today", score: 78, level: "High", hrvValue: 45, restingHeartRate: 58)]
    }
}
