import Foundation
import SwiftUI

@Observable
final class CustomExerciseStore {
    static let shared = CustomExerciseStore()

    private(set) var customExercises: [LibraryExercise] = []

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let kvKey = "vector_custom_exercises"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("vector_custom_exercises.json")
    }

    init() {
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        kvStore.synchronize()
    }

    func add(_ exercise: LibraryExercise) {
        customExercises.insert(exercise, at: 0)
        persist()
    }

    func delete(_ exercise: LibraryExercise) {
        customExercises.removeAll { $0.id == exercise.id }
        persist()
    }

    static func makeExercise(
        name: String,
        equipment: String,
        targetMuscleGroup: String,
        primaryMuscle: String
    ) -> LibraryExercise {
        LibraryExercise(
            id: "custom_" + UUID().uuidString,
            name: name,
            aliases: [],
            equipment: equipment,
            targetMuscleGroup: targetMuscleGroup,
            movementPattern: "Custom",
            primaryMuscle: primaryMuscle,
            secondaryMuscles: [],
            mechanics: "Compound",
            force: "Push",
            difficulty: "Beginner",
            steps: []
        )
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let exercises = try? decoder.decode([LibraryExercise].self, from: data) {
            customExercises = exercises
            return
        }
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let exercises = try? decoder.decode([LibraryExercise].self, from: data) {
            customExercises = exercises
            persist()
        }
    }

    private func persist() {
        guard let data = try? encoder.encode(customExercises) else { return }
        try? data.write(to: fileURL, options: .atomic)
        if data.count < 900_000, let jsonString = String(data: data, encoding: .utf8) {
            kvStore.set(jsonString, forKey: kvKey)
            kvStore.synchronize()
        }
    }

    @objc private func kvStoreChanged(_ notification: Notification) {
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let exercises = try? decoder.decode([LibraryExercise].self, from: data) {
            customExercises = exercises
            persist()
        }
    }
}
