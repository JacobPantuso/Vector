import AppIntents

struct SleepEntity: AppEntity {
    static var defaultQuery = SleepEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Sleep Session"

    var id: String
    var totalHours: Double
    var quality: String

    var displayRepresentation: DisplayRepresentation {
        DisplayRepresentation(
            title: "Sleep: \(String(format: "%.1f", totalHours))h",
            subtitle: "\(quality) quality",
            image: .init(systemName: "moon.fill")
        )
    }
}

struct SleepEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [SleepEntity] {
        []
    }
}
