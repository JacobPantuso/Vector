import AppIntents
import SwiftUI

struct GetWeeklySummaryIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Weekly Summary"
    static var description: IntentDescription = "View your weekly health summary."
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let dialog: IntentDialog = "Here's your weekly health summary. Your average recovery was 75% and you trained 4 times this week."

        return .result(dialog: dialog, view: WeeklySummarySnippetView())
    }
}
