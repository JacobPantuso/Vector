import SwiftUI

extension View {
    func askVector(_ topic: @autoclosure @escaping () -> AdvisorTopic) -> some View {
        self.modifier(AskVectorModifier(topic: topic))
    }
}

private struct AskVectorModifier: ViewModifier {
    @Environment(AdvisorPresenter.self) private var presenter: AdvisorPresenter?
    let topic: () -> AdvisorTopic

    func body(content: Content) -> some View {
        content.contextMenu {
            Button {
                presenter?.ask(topic())
            } label: {
                Label("Ask Vector about this", systemImage: "sparkles")
            }
        }
    }
}
