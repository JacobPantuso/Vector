import SwiftUI

struct MetricRing<Content: View>: View {
    let progress: Double
    let lineWidth: CGFloat
    let gradient: LinearGradient
    let size: CGFloat
    @ViewBuilder let content: Content

    init(
        progress: Double,
        lineWidth: CGFloat = 12,
        gradient: LinearGradient = LinearGradient(colors: [.blue, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing),
        size: CGFloat = 120,
        @ViewBuilder content: () -> Content
    ) {
        self.progress = max(0, min(progress, 1))
        self.lineWidth = lineWidth
        self.gradient = gradient
        self.size = size
        self.content = content()
    }

    var body: some View {
        ZStack {
            Circle()
                .stroke(Color.gray.opacity(0.2), lineWidth: lineWidth)

            Circle()
                .trim(from: 0, to: progress)
                .stroke(gradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                .rotationEffect(.degrees(-90))

            content
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }
}
