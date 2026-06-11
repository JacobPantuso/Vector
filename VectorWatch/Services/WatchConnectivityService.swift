import Foundation
import WatchConnectivity
import Observation

@Observable
final class WatchConnectivityService: NSObject, WCSessionDelegate {
	var recoveryScore: WatchRecoveryScore?
	var exertionScore: WatchExertionScore?
	var sleepAnalysis: WatchSleepAnalysis?

	override init() {
		super.init()
		if WCSession.isSupported() {
			WCSession.default.delegate = self
			WCSession.default.activate()
		}
	}

	func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}

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
	}

	func requestUpdate() {
		if WCSession.default.isReachable {
			WCSession.default.sendMessage(["request": "update"]) { _ in } errorHandler: { _ in }
		}
	}
}
