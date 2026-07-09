import Foundation

@Observable
final class ExerciseLibrary {
    static let shared = ExerciseLibrary()

    private(set) var exercises: [LibraryExercise] = []

    var allExercises: [LibraryExercise] {
        exercises + CustomExerciseStore.shared.customExercises
    }

    var allEquipmentTypes: [String] {
        Array(Set(allExercises.map(\.equipment))).sorted()
    }

    var allMuscleGroups: [String] {
        Array(Set(allExercises.map(\.targetMuscleGroup))).sorted()
    }

    init() {
        loadExercises()
    }

    func search(_ query: String) -> [LibraryExercise] {
        guard !query.isEmpty else { return allExercises }
        let q = query.lowercased()
        return allExercises.filter {
            $0.name.lowercased().contains(q) ||
            $0.primaryMuscle.lowercased().contains(q) ||
            $0.equipment.lowercased().contains(q) ||
            $0.aliases.contains(where: { $0.lowercased().contains(q) })
        }
    }

    func filtered(equipment: String?, muscleGroup: String?) -> [LibraryExercise] {
        allExercises.filter { ex in
            (equipment == nil || ex.equipment == equipment) &&
            (muscleGroup == nil || ex.targetMuscleGroup == muscleGroup)
        }
    }

    func searchAndFilter(query: String, equipment: String?, muscleGroup: String?) -> [LibraryExercise] {
        var result = allExercises
        if !query.isEmpty {
            let q = query.lowercased()
            result = result.filter {
                $0.name.lowercased().contains(q) ||
                $0.primaryMuscle.lowercased().contains(q) ||
                $0.aliases.contains(where: { $0.lowercased().contains(q) })
            }
        }
        if let equipment { result = result.filter { $0.equipment == equipment } }
        if let muscleGroup { result = result.filter { $0.targetMuscleGroup == muscleGroup } }
        return result
    }

    private func loadExercises() {
        guard let url = Bundle.main.url(forResource: "workouts", withExtension: "json"),
              let data = try? Data(contentsOf: url) else { return }
        struct Root: Decodable { let exercises: [LibraryExercise] }
        if let root = try? JSONDecoder().decode(Root.self, from: data) {
            exercises = root.exercises
        }
    }
}

extension LibraryExercise {
    var isCustom: Bool { id.hasPrefix("custom_") }
}
