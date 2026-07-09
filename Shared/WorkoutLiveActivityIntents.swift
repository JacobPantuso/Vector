import AppIntents
import Foundation

// Compiled into BOTH the Vector app target and the VectorWidgets extension.
// The widget references these types to build interactive buttons; the app
// executes perform() in its own process and posts the existing watch-command
// notifications, reusing the active-workout view's handlers.
//
// Raw notification names are used intentionally: the Notification.Name
// extension that defines these lives in the app target only, but this file
// also compiles into the widget extension.

struct LogSetIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Log Set"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("com.vector.watchCommandCompleteSet"),
                object: nil
            )
        }
        return .result()
    }
}

struct SkipRestIntent: LiveActivityIntent {
    static let title: LocalizedStringResource = "Skip Rest"

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(
                name: Notification.Name("com.vector.watchCommandSkipRest"),
                object: nil
            )
        }
        return .result()
    }
}
