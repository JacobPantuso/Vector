import AppIntents
import SwiftUI

struct GetSleepSummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Sleep Summary"
    static var description: IntentDescription = "View last night's sleep summary."
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let hours = 7.4
        let quality = "Good"

        let dialog: IntentDialog = "You slept \(String(format: "%.1f", hours)) hours last night with \(quality.lowercased()) quality."

        return .result(dialog: dialog, view: SleepSnippetView(hours: hours, quality: quality))
    }
}
