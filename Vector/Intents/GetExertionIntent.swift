import AppIntents
import SwiftUI

struct GetExertionIntent: AppIntent {
    static var title: LocalizedStringResource = "Get Exertion Score"
    static var description: IntentDescription = "View your current training load and exertion."
    static var openAppWhenRun = false

    func perform() async throws -> some IntentResult & ProvidesDialog & ShowsSnippetView {
        let score = 62
        let status = "Optimal"

        let dialog: IntentDialog = "Your exertion score is \(score) with an \(status.lowercased()) training load."

        return .result(dialog: dialog, view: ExertionSnippetView(score: score, status: status))
    }
}
