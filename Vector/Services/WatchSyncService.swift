import Foundation
import WatchConnectivity

struct WorkoutExerciseLite: Codable, Sendable {
    var name: String
    var sets: Int
    var completedSets: Int
    var reps: Int
    var weight: Double
    var inputType: String
    var durationSeconds: Int
    var isSuperset: Bool
}

struct WorkoutSyncState: Codable, Sendable {
    var status: String
    var title: String
    var exerciseName: String
    var exerciseIndex: Int
    var totalExercises: Int
    var setIndex: Int
    var totalSets: Int
    var restSecondsRemaining: Int
    var elapsedSeconds: Int
    var exercises: [WorkoutExerciseLite]
    var currentWeight: Double
    var currentReps: Int
    var isPaused: Bool = false
}

@Observable
final class WatchSyncService: NSObject, WCSessionDelegate {
    static let shared = WatchSyncService()

    private var lastContextSignature: String?

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    var isPaired: Bool { WCSession.default.isPaired }
    var isWatchAppInstalled: Bool { WCSession.default.isWatchAppInstalled }
    var isReachable: Bool { WCSession.default.isReachable }
    var liveWatchHeartRate: Double = 0
    var watchReachable: Bool = false
    var watchName: String?
    /// Whether the iPhone currently has a live workout in progress. Set by ActiveWorkoutView.
    var hasActiveWorkout: Bool = false

    func syncScores(recovery: RecoveryScore?, exertion: ExertionScore?, sleep: SleepAnalysis?, stress: StressScore?) {
        guard WCSession.default.activationState == .activated else { return }

        var payload: [String: Any] = [:]

        if let r = recovery,
           let data = try? JSONEncoder().encode(r),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["recovery"] = dict
        }

        if let e = exertion,
           let data = try? JSONEncoder().encode(e),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["exertion"] = dict
        }

        if let s = sleep,
           let data = try? JSONEncoder().encode(s),
           var dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            // Inject the phone's computed score so the watch displays the same number
            // rather than recomputing it from a formula that can drift.
            dict["qualityScore"] = Int((s.quality * 100).rounded())
            payload["sleep"] = dict
        }

        if let st = stress,
           let data = try? JSONEncoder().encode(st),
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["stress"] = dict
        }

        guard !payload.isEmpty else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(payload)
        }
    }

    func sendWorkoutUpdate(_ state: WorkoutSyncState) {
        guard WCSession.default.activationState == .activated else { return }
        guard let data = try? JSONEncoder().encode(state),
              let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] else { return }
        let payload: [String: Any] = ["workout": dict]

        // Live, low-latency path when the watch is reachable.
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        // Refresh the background application context only when a meaningful field
        // changes, so a relaunched/returning watch app gets current state without
        // per-second context churn.
        let signature = "\(state.status)|\(state.exerciseIndex)|\(state.setIndex)|\(state.isPaused)|\(state.restSecondsRemaining > 0)"
        if signature != lastContextSignature {
            lastContextSignature = signature
            try? WCSession.default.updateApplicationContext(payload)
        }
    }

    func sendWorkoutEnded() {
        guard WCSession.default.activationState == .activated else { return }
        let payload: [String: Any] = ["workout": ["status": "ended"]]
        // Live, low-latency path when reachable.
        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        }
        // Always refresh the background application context to "ended" and reset the
        // signature. Previously this only updated the context on the unreachable path
        // and never touched lastContextSignature, so a following workout whose first
        // state matched a leftover signature would SKIP its context update — leaving the
        // background context stuck at "ended" while a live workout ran. A relaunched/
        // returning watch then read that stale "ended" context and killed its live
        // session, creating a phantom ~1-minute Apple Health workout.
        lastContextSignature = "ended"
        try? WCSession.default.updateApplicationContext(payload)
    }

	/// Like `sendWorkoutEnded`, but tells the watch the workout was DISCARDED, so it
	/// calls `discardWorkout()` and never saves a phantom HKWorkout. Used whenever the
	/// phone ends a workout without authoring one (discard, or an orphaned watch session).
	func sendWorkoutDiscarded() {
		guard WCSession.default.activationState == .activated else { return }
		let payload: [String: Any] = ["workout": ["status": "discarded"]]
		if WCSession.default.isReachable {
			WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
		}
		lastContextSignature = "discarded"
		try? WCSession.default.updateApplicationContext(payload)
	}

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
        DispatchQueue.main.async { self.watchReachable = session.isReachable }
    }
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }
    func sessionReachabilityDidChange(_ session: WCSession) {
        DispatchQueue.main.async { self.watchReachable = session.isReachable }
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any], replyHandler: @escaping ([String: Any]) -> Void) {
        // The watch sends its "request:update" via the reply-handler API; WatchConnectivity
        // requires this variant to exist or it drops the message entirely. Route it through
        // the existing handler and acknowledge with an empty reply.
        self.session(session, didReceiveMessage: message)
        replyHandler([:])
    }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        DispatchQueue.main.async {
            if message["request"] as? String == "update" {
                NotificationCenter.default.post(name: .watchRequestedSync, object: nil)
                // Be authoritative about workout state: if no workout is live on the
                // iPhone, tell the watch to clear any stale persisted workout.
                if !self.hasActiveWorkout {
                    // No live phone workout, so any watch session is orphaned: discard it
                    // rather than end it, so watchOS doesn't finalize a phantom workout.
                    self.sendWorkoutDiscarded()
                }
            }
            if let command = message["command"] as? String {
                switch command {
                case "completeSet":
                    var info: [String: Any] = [:]
                    if let weight = message["weight"] as? Double { info["weight"] = weight }
                    if let reps = message["reps"] as? Int { info["reps"] = reps }
                    NotificationCenter.default.post(name: .watchCommandCompleteSet, object: nil, userInfo: info.isEmpty ? nil : info)
                case "skipRest":
                    NotificationCenter.default.post(name: .watchCommandSkipRest, object: nil)
                case "pause":
                    NotificationCenter.default.post(name: .watchCommandPause, object: nil)
                case "endWorkout":
                    NotificationCenter.default.post(name: .watchCommandEndWorkout, object: nil)
                case "selectExercise":
                    let index = message["exerciseIndex"] as? Int ?? 0
                    NotificationCenter.default.post(name: .watchCommandSelectExercise, object: nil, userInfo: ["index": index])
                case "startTimer":
                    NotificationCenter.default.post(name: .watchCommandStartTimer, object: nil)
                default:
                    break
                }
            }
            if let bpm = message["heartRate"] as? Double {
                self.liveWatchHeartRate = bpm
            }
        }
    }

    func session(_ session: WCSession, didReceiveUserInfo userInfo: [String: Any]) {
        DispatchQueue.main.async {
            if let bpm = userInfo["heartRate"] as? Double {
                self.liveWatchHeartRate = bpm
            }
            if let name = userInfo["deviceName"] as? String {
                self.watchName = name
            }
        }
    }
}

extension Notification.Name {
    static let watchRequestedSync = Notification.Name("com.vector.watchRequestedSync")
    static let watchCommandCompleteSet = Notification.Name("com.vector.watchCommandCompleteSet")
    static let watchCommandSkipRest = Notification.Name("com.vector.watchCommandSkipRest")
    static let watchCommandPause = Notification.Name("com.vector.watchCommandPause")
    static let watchCommandEndWorkout = Notification.Name("com.vector.watchCommandEndWorkout")
    static let watchCommandSelectExercise = Notification.Name("com.vector.watchCommandSelectExercise")
    static let watchCommandStartTimer = Notification.Name("com.vector.watchCommandStartTimer")
}
