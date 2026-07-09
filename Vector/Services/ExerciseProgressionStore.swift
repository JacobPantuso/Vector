import Foundation
import SwiftUI

struct ExercisePerformance: Codable, Sendable {
    var weightKg: Double
    var reps: Int
    var targetReps: Int
    var date: Date
}

@Observable
final class ExerciseProgressionStore {
    static let shared = ExerciseProgressionStore()

    /// Most recent performance per exercise key (kept for quick lookups / backward compat).
    private(set) var performances: [String: ExercisePerformance] = [:]
    /// Full rolling history per exercise key, oldest first (capped at `historyCap`).
    private(set) var histories: [String: [ExercisePerformance]] = [:]

    private let historyCap = 12
    private let kvStore = NSUbiquitousKeyValueStore.default
    private let kvKey = "vector_exercise_progression"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private struct Storage: Codable {
        var performances: [String: ExercisePerformance]
        var history: [String: [ExercisePerformance]]
    }

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("vector_exercise_progression.json")
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

    static func key(for entry: ManualExerciseEntry) -> String {
        entry.libraryExerciseId ?? entry.name.lowercased()
    }

    func lastPerformance(for entry: ManualExerciseEntry) -> ExercisePerformance? {
        performances[Self.key(for: entry)]
    }

    /// Full performance history for an exercise, oldest first.
    func history(for entry: ManualExerciseEntry) -> [ExercisePerformance] {
        histories[Self.key(for: entry)] ?? []
    }

    func suggestedWeight(for entry: ManualExerciseEntry) -> Double {
        guard let last = lastPerformance(for: entry) else {
            return entry.weightKg ?? 0
        }
        if last.weightKg > 0 && last.reps >= last.targetReps {
            return last.weightKg + 5
        }
        return last.weightKg
    }

    func hasProgression(for entry: ManualExerciseEntry) -> Bool {
        guard lastPerformance(for: entry) != nil else {
            return false
        }
        return suggestedWeight(for: entry) > (entry.weightKg ?? 0)
    }

    func record(entry: ManualExerciseEntry, weightKg: Double, reps: Int, targetReps: Int? = nil) {
        let key = Self.key(for: entry)
        let perf = ExercisePerformance(
            weightKg: weightKg,
            reps: reps,
            targetReps: targetReps ?? entry.reps,
            date: Date()
        )
        performances[key] = perf
        var arr = histories[key] ?? []
        arr.append(perf)
        if arr.count > historyCap { arr.removeFirst(arr.count - historyCap) }
        histories[key] = arr
        persist()
    }

    private func decodeAny(_ data: Data) -> (perf: [String: ExercisePerformance], hist: [String: [ExercisePerformance]])? {
        if let s = try? decoder.decode(Storage.self, from: data) {
            return (s.performances, s.history)
        }
        // Legacy format: a bare [String: ExercisePerformance] dictionary.
        if let decoded = try? decoder.decode([String: ExercisePerformance].self, from: data) {
            return (decoded, decoded.mapValues { [$0] })
        }
        return nil
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL), let result = decodeAny(data) {
            performances = result.perf
            histories = result.hist
            return
        }
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let result = decodeAny(data) {
            performances = result.perf
            histories = result.hist
            persist()
        }
    }

    private func persist() {
        let storage = Storage(performances: performances, history: histories)
        guard let data = try? encoder.encode(storage) else { return }
        try? data.write(to: fileURL, options: .atomic)
        if data.count < 900_000, let jsonString = String(data: data, encoding: .utf8) {
            kvStore.set(jsonString, forKey: kvKey)
            kvStore.synchronize()
        }
    }

    @objc private func kvStoreChanged(_ notification: Notification) {
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let result = decodeAny(data) {
            performances = result.perf
            histories = result.hist
            persist()
        }
    }

#if DEBUG
    /// Seed in-memory history for SwiftUI previews. Does not persist to disk.
    /// Keys must match `key(for:)` — i.e. `libraryExerciseId` or `name.lowercased()`.
    func seedPreview(_ data: [String: [ExercisePerformance]]) {
        histories = data
        performances = data.compactMapValues { $0.last }
    }
#endif
}
