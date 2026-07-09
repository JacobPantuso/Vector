import Foundation
import SwiftUI
import HealthKit

struct WorkoutCompletionRecord: Codable, Identifiable, Sendable {
    var id: UUID = UUID()
    let templateID: UUID
    let date: Date
    let totalVolume: Double
    let durationMinutes: Int
    var muscleVolumes: [String: Double]? = nil
    var title: String? = nil
    var performedExercises: [ManualExerciseEntry]? = nil
    /// Whether this workout expected to sync to HealthKit (i.e. a watch was available).
    /// nil = legacy record, treat as true. false = recorded without a watch; never shown as "Processing".
    var expectsHealthSync: Bool? = nil
    /// Whether this workout has been written to HealthKit. Prevents the backfill from
    /// re-creating a workout the user deleted, or re-pushing iCloud-restored records.
    var syncedToHealth: Bool? = nil
}

@Observable
final class WorkoutCompletionStore {
    static let shared = WorkoutCompletionStore()

    private(set) var records: [WorkoutCompletionRecord] = []

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let kvKey = "vector_workout_completions"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("vector_workout_completions.json")
    }

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
        migrateLegacyMuscleGroupsIfNeeded()
        consolidateDuplicateRecordsIfNeeded()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        kvStore.synchronize()
    }

    @discardableResult
    func record(templateID: UUID, totalVolume: Double, durationMinutes: Int, muscleVolumes: [String: Double]? = nil, title: String? = nil, performedExercises: [ManualExerciseEntry]? = nil, expectsHealthSync: Bool = true, date: Date = Date()) -> UUID {
        // Dedup on insert: a finish can fire from multiple onChange paths. Drop any record
        // for the same template logged within the last 10 minutes before adding the new one.
        records.removeAll { $0.templateID == templateID && abs($0.date.timeIntervalSince(date)) < 600 }
        let entry = WorkoutCompletionRecord(
            templateID: templateID,
            date: date,
            totalVolume: totalVolume,
            durationMinutes: durationMinutes,
            muscleVolumes: muscleVolumes,
            title: title,
            performedExercises: performedExercises,
            expectsHealthSync: expectsHealthSync
        )
        records.append(entry)
        persist()
        return entry.id
    }

    /// Marks a record as written to HealthKit so the backfill never re-pushes it.
    func markSynced(_ id: UUID) {
        guard let idx = records.firstIndex(where: { $0.id == id }) else { return }
        guard records[idx].syncedToHealth != true else { return }
        records[idx].syncedToHealth = true
        persist()
    }

    /// Attach (or replace) user-entered exercises onto an existing HealthKit workout.
    /// Creates a record matched to that workout WITHOUT writing to HealthKit and WITHOUT
    /// appearing as a standalone history item (expectsHealthSync=false). Keyed by workout.uuid.
    func annotate(workout: HKWorkout, exercises: [ManualExerciseEntry]) {
        // Compute volume and muscleVolumes from reps exercises (mirror ActiveWorkoutView.recordCompletion pattern)
        let library = ExerciseLibrary.shared
        var volume = 0.0
        var muscleVolumes: [String: Double] = [:]

        for exercise in exercises where exercise.inputType == .reps {
            let resolved = exercise.resolvedSetDetails
            var exVolume = 0.0
            for detail in resolved {
                exVolume += Double(detail.reps) * (detail.weightKg ?? 0)
            }
            volume += exVolume
            guard exVolume > 0 else { continue }
            if let lib = library.exercises.first(where: { $0.name.lowercased() == exercise.name.lowercased() }) {
                muscleVolumes[lib.muscleCategory, default: 0] += exVolume
            }
        }

        // Remove any existing record keyed to this workout (templateID == workout.uuid)
        records.removeAll { $0.templateID == workout.uuid }

        // Append new record
        let record = WorkoutCompletionRecord(
            templateID: workout.uuid,
            date: workout.endDate,
            totalVolume: volume,
            durationMinutes: Int(workout.duration / 60),
            muscleVolumes: muscleVolumes,
            title: workout.metadata?["VectorWorkoutTitle"] as? String,
            performedExercises: exercises,
            expectsHealthSync: false,
            syncedToHealth: true
        )
        records.append(record)
        persist()

        // Record progression for each reps exercise: use the top set (heaviest weight) as the representative load
        for ex in exercises where ex.inputType == .reps {
            let resolved = ex.resolvedSetDetails
            guard !resolved.isEmpty else { continue }
            let weights = resolved.compactMap { $0.weightKg }.filter { $0 > 0 }
            guard let topWeight = weights.max() else { continue }
            let topSetIndex = resolved.firstIndex { $0.weightKg == topWeight } ?? 0
            let topReps = resolved[topSetIndex].reps
            let targetReps = resolved[topSetIndex].reps
            ExerciseProgressionStore.shared.record(entry: ex, weightKg: topWeight, reps: topReps, targetReps: targetReps)
        }
    }

    /// Completions for a given template, oldest first.
    func completions(for templateID: UUID) -> [WorkoutCompletionRecord] {
        records.filter { $0.templateID == templateID }.sorted { $0.date < $1.date }
    }

    /// The local completion record that corresponds to a saved HealthKit workout, if any.
    /// Matches on the Vector title stored in HKWorkout metadata and a close timestamp.
    func record(matching workout: HKWorkout) -> WorkoutCompletionRecord? {
        let hkTitle = workout.metadata?["VectorWorkoutTitle"] as? String
        return records
            .filter { record in
                // Title must match when both are present.
                if let t = record.title, let h = hkTitle, t != h { return false }
                // Record timestamp (taken at finish) should be within a few minutes of the workout end.
                return abs(record.date.timeIntervalSince(workout.endDate)) < 300
            }
            .max { $0.date < $1.date }
    }

    /// Recent local records that have NOT yet been confirmed by a matching HealthKit workout.
    /// Used to show a "Processing" placeholder in history right after finishing.
    func unsyncedRecords(notMatching workouts: [HKWorkout], within seconds: TimeInterval = 900) -> [WorkoutCompletionRecord] {
        let now = Date()
        return records.filter { record in
            guard record.expectsHealthSync ?? true else { return false }
            guard now.timeIntervalSince(record.date) < seconds else { return false }
            let hkTitle: (HKWorkout) -> String? = { $0.metadata?["VectorWorkoutTitle"] as? String }
            let matched = workouts.contains { wk in
                if let t = record.title, let h = hkTitle(wk), t != h { return false }
                return abs(record.date.timeIntervalSince(wk.endDate)) < 300
            }
            return !matched
        }
        .sorted { $0.date > $1.date }
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let decoded = try? decoder.decode([WorkoutCompletionRecord].self, from: data) {
            records = decoded
            return
        }
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let decoded = try? decoder.decode([WorkoutCompletionRecord].self, from: data) {
            records = decoded
            persist()
        }
    }

    private func persist() {
        guard let data = try? encoder.encode(records) else { return }
        try? data.write(to: fileURL, options: .atomic)
        if data.count < 900_000, let jsonString = String(data: data, encoding: .utf8) {
            kvStore.set(jsonString, forKey: kvKey)
            kvStore.synchronize()
        }
    }

    /// One-time cleanup: removes the legacy coarse muscle groups ("Upper Body",
    /// "Lower Body", "Full Body") captured by older builds, so the Train "Muscle
    /// Focus" chart only shows the new granular groups. Workouts logged after this
    /// build repopulate granular data; old records simply drop their coarse buckets.
    private func migrateLegacyMuscleGroupsIfNeeded() {
        let flagKey = "vector_migrated_muscle_groups_v1"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        let legacyKeys: Set<String> = ["Upper Body", "Lower Body", "Full Body"]
        var changed = false
        for i in records.indices {
            guard var volumes = records[i].muscleVolumes else { continue }
            let before = volumes.count
            for key in legacyKeys { volumes.removeValue(forKey: key) }
            if volumes.count != before {
                records[i].muscleVolumes = volumes
                changed = true
            }
        }
        if changed { persist() }
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    /// One-time cleanup of historical duplicate completion records produced by the
    /// pre-fix recording bug (one session logged multiple times). Groups records by
    /// title within a 15-minute window and keeps the richest (most exercises, then
    /// highest volume), dropping the rest.
    private func consolidateDuplicateRecordsIfNeeded() {
        let flagKey = "vector_dedupe_records_v1"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        var kept: [WorkoutCompletionRecord] = []
        let sorted = records.sorted { $0.date < $1.date }
        for record in sorted {
            if let idx = kept.firstIndex(where: { existing in
                (existing.title ?? "") == (record.title ?? "") &&
                abs(existing.date.timeIntervalSince(record.date)) < 900
            }) {
                // Duplicate cluster — keep whichever is richer.
                let existing = kept[idx]
                let existingScore = (existing.performedExercises?.count ?? 0, existing.totalVolume)
                let candidateScore = (record.performedExercises?.count ?? 0, record.totalVolume)
                if candidateScore > existingScore { kept[idx] = record }
            } else {
                kept.append(record)
            }
        }
        if kept.count != records.count {
            records = kept
            persist()
            print("[WorkoutCompletionStore] consolidated duplicate records → \(kept.count) remain")
        }
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    @objc private func kvStoreChanged(_ notification: Notification) {
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let decoded = try? decoder.decode([WorkoutCompletionRecord].self, from: data) {
            records = decoded
            persist()
        }
    }

#if DEBUG
    /// Seed in-memory completion records for SwiftUI previews. Does not persist to disk.
    func seedPreview(_ records: [WorkoutCompletionRecord]) {
        self.records = records
    }
#endif
}
