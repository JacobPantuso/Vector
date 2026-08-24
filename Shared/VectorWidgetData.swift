import Foundation
#if canImport(WidgetKit)
import WidgetKit
#endif

enum VectorMetricKind: String, Codable, CaseIterable, Sendable, Hashable {
    case recovery, exertion, sleep, stress
}

struct VectorWidgetSnapshot: Codable, Equatable, Sendable {
    var updated: Date
    var recovery: Int?
    var exertion: Int?
    var exertionTargetLow: Int?
    var exertionTargetHigh: Int?
    var sleep: Int?                    // sleep quality 0...100
    var sleepAsleepSeconds: Double?
    var stress: Int?
    var hrv: Double?
    var restingHR: Double?
    var steps: Int?
    var recoveryHistory: [Int]         // oldest -> newest, up to 7 entries, may be empty
    var name: String?
    var sleepDeepSeconds: Double?
    var sleepRemSeconds: Double?
    var sleepCoreSeconds: Double?
    var sleepAwakeSeconds: Double?

    init(updated: Date = .now, recovery: Int? = nil, exertion: Int? = nil, exertionTargetLow: Int? = nil, exertionTargetHigh: Int? = nil, sleep: Int? = nil, sleepAsleepSeconds: Double? = nil, stress: Int? = nil, hrv: Double? = nil, restingHR: Double? = nil, steps: Int? = nil, recoveryHistory: [Int] = [], name: String? = nil, sleepDeepSeconds: Double? = nil, sleepRemSeconds: Double? = nil, sleepCoreSeconds: Double? = nil, sleepAwakeSeconds: Double? = nil) {
        self.updated = updated
        self.recovery = recovery
        self.exertion = exertion
        self.exertionTargetLow = exertionTargetLow
        self.exertionTargetHigh = exertionTargetHigh
        self.sleep = sleep
        self.sleepAsleepSeconds = sleepAsleepSeconds
        self.stress = stress
        self.hrv = hrv
        self.restingHR = restingHR
        self.steps = steps
        self.recoveryHistory = recoveryHistory
        self.name = name
        self.sleepDeepSeconds = sleepDeepSeconds
        self.sleepRemSeconds = sleepRemSeconds
        self.sleepCoreSeconds = sleepCoreSeconds
        self.sleepAwakeSeconds = sleepAwakeSeconds
    }

    func value(for kind: VectorMetricKind) -> Int? {
        switch kind {
        case .recovery:
            return recovery
        case .exertion:
            return exertion
        case .sleep:
            return sleep
        case .stress:
            return stress
        }
    }

    var isEmpty: Bool {
        recovery == nil && exertion == nil && sleep == nil && stress == nil
    }

    static let placeholder: VectorWidgetSnapshot = .init(
        updated: .now,
        recovery: 78,
        exertion: 62,
        exertionTargetLow: 55,
        exertionTargetHigh: 75,
        sleep: 84,
        sleepAsleepSeconds: 26400,  // 7h20m
        stress: 31,
        hrv: 68,
        restingHR: 54,
        steps: 8420,
        recoveryHistory: [64, 71, 69, 80, 75, 72, 78],
        name: nil,
        sleepDeepSeconds: 4320,   // 1h12m
        sleepRemSeconds: 6000,    // 1h40m
        sleepCoreSeconds: 16080,  // 4h28m
        sleepAwakeSeconds: 900    // 15m
    )
}

enum VectorWidgetStore {
    static let appGroupID = "group.com.jacobpantuso.Vector"
    static let snapshotKey = "vector.widget.snapshot"

    static func save(_ snapshot: VectorWidgetSnapshot) {
        guard let defaults = UserDefaults(suiteName: appGroupID) else { return }
        if let data = try? JSONEncoder().encode(snapshot) {
            defaults.set(data, forKey: snapshotKey)
            #if canImport(WidgetKit)
            WidgetCenter.shared.reloadAllTimelines()
            #endif
        }
    }

    static func load() -> VectorWidgetSnapshot? {
        guard let defaults = UserDefaults(suiteName: appGroupID),
              let data = defaults.data(forKey: snapshotKey) else {
            return nil
        }
        return try? JSONDecoder().decode(VectorWidgetSnapshot.self, from: data)
    }

    /// Sample data for the widget gallery, with the real user's first name mixed in
    /// so the greeting never shows a stranger's name.
    static func previewSnapshot() -> VectorWidgetSnapshot {
        var snapshot = VectorWidgetSnapshot.placeholder
        snapshot.name = load()?.name
        return snapshot
    }
}
