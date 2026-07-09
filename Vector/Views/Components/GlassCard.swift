import SwiftUI

struct GlassCard<Content: View>: View {
    let tint: Color?
    let cornerRadius: CGFloat
    let isInteractive: Bool
    @ViewBuilder let content: Content

    init(
        tint: Color? = nil,
        cornerRadius: CGFloat = 20,
        isInteractive: Bool = true,
        @ViewBuilder content: () -> Content
    ) {
        self.tint = tint
        self.cornerRadius = cornerRadius
        self.isInteractive = isInteractive
        self.content = content()
    }

    var body: some View {
        content
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .modifier(GlassModifier(tint: tint, cornerRadius: cornerRadius, isInteractive: isInteractive))
    }
}

private struct GlassModifier: ViewModifier {
    let tint: Color?
    let cornerRadius: CGFloat
    let isInteractive: Bool

    func body(content: Content) -> some View {
        if let tint {
            content.glassEffect(.regular.tint(tint).interactive(isInteractive), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.glassEffect(.regular.interactive(isInteractive), in: .rect(cornerRadius: cornerRadius))
        }
    }
}
