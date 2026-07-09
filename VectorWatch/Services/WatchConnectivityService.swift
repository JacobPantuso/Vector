import Foundation
import WatchConnectivity
import Observation
import WatchKit

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
	var recoveryScore: WatchRecoveryScore?
	var exertionScore: WatchExertionScore?
	var sleepAnalysis: WatchSleepAnalysis?
	var stressScore: WatchStressScore?
	var activeWorkout: WatchWorkoutState?

	private var healthStore: WatchHealthStore?

	func configure(healthStore: WatchHealthStore) {
		self.healthStore = healthStore
		healthStore.onHeartRateUpdate = { [weak self] bpm in
			self?.sendHeartRate(bpm)
		}
	}

	func sendDeviceInfo() {
		guard WCSession.default.activationState == .activated else { return }
		WCSession.default.transferUserInfo(["deviceName": WKInterfaceDevice.current().name])
	}

	override init() {
		super.init()
		restoreActiveWorkout()
		let isPreview = ProcessInfo.processInfo.environment["XCODE_RUNNING_FOR_PREVIEWS"] == "1"
		if !isPreview, WCSession.isSupported() {
			WCSession.default.delegate = self
			WCSession.default.activate()
		}
	}

	// MARK: - Commands to iPhone

	func sendCompleteSet(weight: Double? = nil, reps: Int? = nil) {
		var message: [String: Any] = ["command": "completeSet"]
		if let weight { message["weight"] = weight }
		if let reps { message["reps"] = reps }
		send(message)
	}

	func sendStartTimer() {
		send(["command": "startTimer"])
	}

	func sendSkipRest() {
		send(["command": "skipRest"])
	}

	func sendPause() {
		send(["command": "pause"])
	}

	func sendEndWorkout() {
		send(["command": "endWorkout"])
	}

	/// Exit the active workout from the watch itself. Tells the phone (best-effort)
	/// and clears local state regardless, so the watch can never be trapped on a
	/// stale workout screen when the phone is unreachable.
	func exitActiveWorkout() {
		sendEndWorkout()
		activeWorkout = nil
		persistActiveWorkout()
		healthStore?.discardWorkoutSession()
	}

	func sendSelectExercise(_ index: Int) {
		send(["command": "selectExercise", "exerciseIndex": index])
	}

	private func sendHeartRate(_ bpm: Double) {
		guard WCSession.default.activationState == .activated else { return }
		let message = ["heartRate": bpm]
		if WCSession.default.isReachable {
			WCSession.default.sendMessage(message, replyHandler: nil) { error in
				print("[WatchConnectivity] heartRate sendMessage failed: \(error.localizedDescription)")
			}
		} else {
			// Phone unreachable (locked/pocket): queue for guaranteed background delivery.
			WCSession.default.transferUserInfo(message)
		}
	}

	private func send(_ message: [String: Any]) {
		guard WCSession.default.activationState == .activated,
			  WCSession.default.isReachable else { return }
		WCSession.default.sendMessage(message, replyHandler: nil, errorHandler: nil)
	}

	// MARK: - WCSessionDelegate

	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {
		if activationState == .activated {
			requestUpdate()
			sendDeviceInfo()
		}
	}

	func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
		DispatchQueue.main.async {
			self.parseMessage(message)
		}
	}

	func session(_ session: WCSession, didReceiveApplicationContext applicationContext: [String: Any]) {
		DispatchQueue.main.async {
			self.parseMessage(applicationContext)
		}
	}

	func sessionReachabilityDidChange(_ session: WCSession) {
		if session.isReachable { requestUpdate() }
	}

	private func parseMessage(_ data: [String: Any]) {
		if let recoveryData = data["recovery"] as? [String: Any],
		   let jsonData = try? JSONSerialization.data(withJSONObject: recoveryData),
		   let score = try? JSONDecoder().decode(WatchRecoveryScore.self, from: jsonData) {
			self.recoveryScore = score
		}

		if let exertionData = data["exertion"] as? [String: Any],
		   let jsonData = try? JSONSerialization.data(withJSONObject: exertionData),
		   let score = try? JSONDecoder().decode(WatchExertionScore.self, from: jsonData) {
			self.exertionScore = score
		}

		if let sleepData = data["sleep"] as? [String: Any],
		   let jsonData = try? JSONSerialization.data(withJSONObject: sleepData),
		   let analysis = try? JSONDecoder().decode(WatchSleepAnalysis.self, from: jsonData) {
			self.sleepAnalysis = analysis
		}

		if let stressData = data["stress"] as? [String: Any],
		   let jsonData = try? JSONSerialization.data(withJSONObject: stressData),
		   let score = try? JSONDecoder().decode(WatchStressScore.self, from: jsonData) {
			self.stressScore = score
		}

		if let workoutData = data["workout"] as? [String: Any] {
			let status = workoutData["status"] as? String
			if status == "ended" || status == "discarded" {
				let hadWorkout = self.activeWorkout != nil
				self.activeWorkout = nil
				self.persistActiveWorkout()
				if status == "discarded" {
					// Always discard: the phone-side discard leaves no authored workout to
					// preserve, and the watch's live session may exist without activeWorkout
					// being set (cold launch starts the session before any workout-update).
					self.healthStore?.discardWorkoutSession()
				} else if hadWorkout {
					self.healthStore?.stopWorkoutSession()
				}
			} else if let jsonData = try? JSONSerialization.data(withJSONObject: workoutData),
					  let state = try? JSONDecoder().decode(WatchWorkoutState.self, from: jsonData) {
				let wasNil = self.activeWorkout == nil
				let previousPaused = self.activeWorkout?.isPaused ?? false
				self.activeWorkout = state
				self.persistActiveWorkout()
				if wasNil {
					self.healthStore?.startWorkoutSession()
				}
				if state.isPaused != previousPaused {
					if state.isPaused { self.healthStore?.pauseWorkoutSession() }
					else { self.healthStore?.resumeWorkoutSession() }
				}
			}
		}
	}

	func requestUpdate() {
		guard WCSession.default.isReachable else { return }
		WCSession.default.sendMessage(["request": "update"]) { _ in } errorHandler: { _ in }
	}

	// MARK: - Persistence

	private func persistActiveWorkout() {
		if let state = activeWorkout,
		   let data = try? JSONEncoder().encode(state),
		   let jsonString = String(data: data, encoding: .utf8) {
			UserDefaults.standard.set(jsonString, forKey: "vector_watch_active_workout")
		} else {
			UserDefaults.standard.removeObject(forKey: "vector_watch_active_workout")
		}
	}

	private func restoreActiveWorkout() {
		if let jsonString = UserDefaults.standard.string(forKey: "vector_watch_active_workout"),
		   let data = jsonString.data(using: .utf8),
		   let state = try? JSONDecoder().decode(WatchWorkoutState.self, from: data) {
			self.activeWorkout = state
		}
	}
}
