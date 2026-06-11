import Foundation
import SwiftUI

@Observable
final class WorkoutStorageService {
    static let shared = WorkoutStorageService()

    private(set) var savedWorkouts: [SavedWorkout] = []

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let kvKey = "vector_saved_workouts"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("vector_workouts.json")
    }

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        kvStore.synchronize()
    }

    func save(_ workout: SavedWorkout) {
        if let idx = savedWorkouts.firstIndex(where: { $0.id == workout.id }) {
            savedWorkouts[idx] = workout
        } else {
            savedWorkouts.insert(workout, at: 0)
        }
        persist()
    }

    func delete(_ workout: SavedWorkout) {
        savedWorkouts.removeAll { $0.id == workout.id }
        persist()
    }

    func delete(at offsets: IndexSet) {
        savedWorkouts.remove(atOffsets: offsets)
        persist()
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let workouts = try? decoder.decode([SavedWorkout].self, from: data) {
            savedWorkouts = workouts
            return
        }
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let workouts = try? decoder.decode([SavedWorkout].self, from: data) {
            savedWorkouts = workouts
            persist()
        }
    }

    private func persist() {
        guard let data = try? encoder.encode(savedWorkouts) else { return }
        try? data.write(to: fileURL, options: .atomic)
        if data.count < 900_000, let jsonString = String(data: data, encoding: .utf8) {
            kvStore.set(jsonString, forKey: kvKey)
            kvStore.synchronize()
        }
    }

    @objc private func kvStoreChanged(_ notification: Notification) {
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let workouts = try? decoder.decode([SavedWorkout].self, from: data) {
            savedWorkouts = workouts
            persist()
        }
    }
}
