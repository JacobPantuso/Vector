import Foundation
import WatchConnectivity

@Observable
final class WatchSyncService: NSObject, WCSessionDelegate {

    override init() {
        super.init()
        if WCSession.isSupported() {
            WCSession.default.delegate = self
            WCSession.default.activate()
        }
    }

    func syncScores(recovery: RecoveryScore?, exertion: ExertionScore?, sleep: SleepAnalysis?) {
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
           let dict = try? JSONSerialization.jsonObject(with: data) as? [String: Any] {
            payload["sleep"] = dict
        }

        guard !payload.isEmpty else { return }

        if WCSession.default.isReachable {
            WCSession.default.sendMessage(payload, replyHandler: nil, errorHandler: nil)
        } else {
            try? WCSession.default.updateApplicationContext(payload)
        }
    }

    func session(_ session: WCSession, activationDidCompleteWith activationState: WCSessionActivationState, error: Error?) {}
    func sessionDidBecomeInactive(_ session: WCSession) {}
    func sessionDidDeactivate(_ session: WCSession) { session.activate() }

    func session(_ session: WCSession, didReceiveMessage message: [String: Any]) {
        if message["request"] as? String == "update" {
            NotificationCenter.default.post(name: .watchRequestedSync, object: nil)
        }
    }
}

extension Notification.Name {
    static let watchRequestedSync = Notification.Name("com.vector.watchRequestedSync")
}
