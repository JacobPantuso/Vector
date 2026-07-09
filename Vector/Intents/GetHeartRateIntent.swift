import AppIntents
import SwiftUI

struct GetHeartRateIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Heart Rate"
    static var description: IntentDescription = "View your current heart rate."
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog {
        let hr = 72

        let dialog: IntentDialog = "Your latest heart rate is \(hr) beats per minute."

        return .result(dialog: dialog)
    }
}
