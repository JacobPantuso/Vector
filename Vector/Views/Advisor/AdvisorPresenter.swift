import SwiftUI
import UIKit

@MainActor
@Observable
final class AdvisorPresenter {
    var isPresented = false
    var pendingTopic: AdvisorTopic?

    func open() { isPresented = true }

    func ask(_ topic: AdvisorTopic) {
        pendingTopic = topic
        // Advisor already open — AdvisorView's onChange picks up pendingTopic.
        guard !isPresented else { return }
        // The advisor sheet is attached to the root TabView. If another sheet
        // (metric detail, workout detail, …) is presented, presenting from the
        // root silently fails — dismiss it first, then present the advisor.
        let root = UIApplication.shared.connectedScenes
            .compactMap { ($0 as? UIWindowScene)?.keyWindow }
            .first?.rootViewController
        if let root, root.presentedViewController != nil {
            root.dismiss(animated: true) {
                Task { @MainActor in self.isPresented = true }
            }
        } else {
            isPresented = true
        }
    }
}

extension AdvisorTopic {
    var tint: Color {
        switch tintName {
        case "green": return .green
        case "red": return .red
        case "cyan": return .cyan
        case "orange": return .orange
        case "indigo": return .indigo
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "mint": return .mint
        case "yellow": return .yellow
        default: return .indigo
        }
    }
}
