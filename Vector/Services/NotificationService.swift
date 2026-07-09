import Foundation
import UserNotifications

enum NotificationSettings {
    static let enabledKey = "notificationsEnabled"
    static let hourKey = "notificationHour"
    static let minuteKey = "notificationMinute"
    static let defaultHour = 7
    static let defaultMinute = 30
}

/// Schedules smart, gated morning notifications: a daily readiness/sleep briefing fired near the
/// user's wake time (suppressed when nothing meaningful changed) plus a one-off disrupted-night alert.
@MainActor
final class NotificationService {
    static let shared = NotificationService()
    private let center = UNUserNotificationCenter.current()

    private let readinessID = "vector.morningReadiness"
    private let disruptionID = "vector.disruptedNight"

    private init() {}

    @discardableResult
    func requestAuthorization() async -> Bool {
        do {
            return try await center.requestAuthorization(options: [.alert, .sound, .badge])
        } catch {
            return false
        }
    }

    func authorizationStatus() async -> UNAuthorizationStatus {
        await center.notificationSettings().authorizationStatus
    }

    /// Re-derives the morning notifications from the latest scores. Call after each health refresh.
    func refreshMorningNotifications(recovery: RecoveryScore?, sleep: SleepAnalysis?, exertion: ExertionScore?) async {
        center.removePendingNotificationRequests(withIdentifiers: [readinessID, disruptionID])

        guard UserDefaults.standard.bool(forKey: NotificationSettings.enabledKey) else { return }
        guard await authorizationStatus() == .authorized else { return }

        let (hour, minute) = morningTime(from: sleep)

        if let recovery, isMeaningful(recovery: recovery, sleep: sleep) {
            schedule(
                id: readinessID,
                title: "Morning Readiness",
                body: readinessBody(recovery: recovery, sleep: sleep, exertion: exertion),
                hour: hour, minute: minute, repeats: true
            )
        }

        if let flag = sleep?.disruption, flag.isFlagged {
            let detail = flag.signals.first.map { " (\($0))" } ?? ""
            schedule(
                id: disruptionID,
                title: flag.headline,
                body: "Last night looked off\(detail). Consider an easier day and an earlier night.",
                hour: hour, minute: minute, repeats: false
            )
        }
    }

    // MARK: - Helpers

    private func morningTime(from sleep: SleepAnalysis?) -> (Int, Int) {
        if let wake = sleep?.wakeTime {
            let comps = Calendar.current.dateComponents([.hour, .minute], from: wake)
            if let h = comps.hour, let m = comps.minute { return (h, m) }
        }
        let h = UserDefaults.standard.object(forKey: NotificationSettings.hourKey) as? Int ?? NotificationSettings.defaultHour
        let m = UserDefaults.standard.object(forKey: NotificationSettings.minuteKey) as? Int ?? NotificationSettings.defaultMinute
        return (h, m)
    }

    /// SWC/TE-style gate: only worth a notification if recovery deviates from the personal average,
    /// sleep debt is meaningful, the night was flagged, or recovery is low.
    private func isMeaningful(recovery: RecoveryScore, sleep: SleepAnalysis?) -> Bool {
        let avg = Double(ScoreHistoryStore.average(for: .recovery) ?? recovery.score)
        if abs(Double(recovery.score) - avg) >= 5 { return true }
        if (sleep?.sleepDebt ?? 0) >= 2 * 3600 { return true }
        if sleep?.disruption?.isFlagged == true { return true }
        if recovery.score < 50 { return true }
        return false
    }

    private func readinessBody(recovery: RecoveryScore, sleep: SleepAnalysis?, exertion: ExertionScore?) -> String {
        let descriptor: String
        let advice: String
        switch recovery.score {
        case ..<50:  descriptor = "Low";    advice = "Prioritize rest today."
        case ..<70:  descriptor = "Good";   advice = "A steady, moderate day fits well."
        case ..<85:  descriptor = "Strong"; advice = "Solid window to train."
        default:     descriptor = "Peak";   advice = "Great window to push if you want."
        }
        var parts = ["Recovery \(recovery.score) — \(descriptor)."]
        if let sleep { parts.append("Slept \(sleep.formattedDuration).") }
        parts.append(advice)
        return parts.joined(separator: " ")
    }

    private func schedule(id: String, title: String, body: String, hour: Int, minute: Int, repeats: Bool) {
        let content = UNMutableNotificationContent()
        content.title = title
        content.body = body
        content.sound = .default

        var comps = DateComponents()
        comps.hour = hour
        comps.minute = minute
        let trigger = UNCalendarNotificationTrigger(dateMatching: comps, repeats: repeats)
        center.add(UNNotificationRequest(identifier: id, content: content, trigger: trigger))
    }
}
