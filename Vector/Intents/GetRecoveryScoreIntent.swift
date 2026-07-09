import AppIntents
import SwiftUI

struct GetRecoveryScoreIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Recovery Score"
    static var description: IntentDescription = "View your current recovery score with key health metrics."
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let score = 78
        let hrv = 45.2
        let rhr = 58.0

        let dialog: IntentDialog = "Your recovery is \(score)%, which is above your baseline. HRV is \(String(format: "%.0f", hrv)) milliseconds and resting heart rate is \(String(format: "%.0f", rhr)) bpm."

        return .result(dialog: dialog, view: RecoverySnippetView(score: score, hrv: hrv, rhr: rhr))
    }
}
