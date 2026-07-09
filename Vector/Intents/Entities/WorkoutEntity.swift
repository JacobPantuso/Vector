import AppIntents
import Foundation

private let workoutLibrary: [WorkoutEntity] = [
    WorkoutEntity(id: "push-power", name: "Push Power", duration: 45 * 60, calories: 420),
    WorkoutEntity(id: "pull-volume", name: "Pull Volume", duration: 50 * 60, calories: 390),
    WorkoutEntity(id: "leg-builder", name: "Leg Builder", duration: 55 * 60, calories: 510),
    WorkoutEntity(id: "full-body", name: "Full Body Momentum", duration: 35 * 60, calories: 310)
]

struct WorkoutEntity: AppEntity {
    static var defaultQuery = WorkoutEntityQuery()
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Workout"

    var id: String
    var name: String
    var duration: TimeInterval
    var calories: Double

    var displayRepresentation: DisplayRepresentation {
        let mins = Int(duration / 60)
        return DisplayRepresentation(
            title: "\(name)",
            subtitle: "\(mins) min · \(String(format: "%.0f", calories)) kcal",
            image: .init(systemName: "figure.run")
        )
    }
}

struct WorkoutEntityQuery: EntityQuery {
    func entities(for identifiers: [String]) async throws -> [WorkoutEntity] {
        if identifiers.isEmpty {
            return workoutLibrary
        }

        return workoutLibrary.filter { identifiers.contains($0.id) }
    }
}
