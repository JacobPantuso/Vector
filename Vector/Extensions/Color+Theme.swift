import SwiftUI

enum VectorTheme {
    static let recovery = Color.green
    static let exertion = Color.orange
    static let sleep = Color.blue
    static let vitals = Color.purple
    static let nutrition = Color.pink
    static let accent = Color.cyan

    static func color(for category: String) -> Color {
        switch category.lowercased() {
        case "recovery":
            return recovery
        case "exertion":
            return exertion
        case "sleep":
            return sleep
        case "vitals":
            return vitals
        case "nutrition":
            return nutrition
        case "accent":
            return accent
        default:
            return accent
        }
    }
}

extension VectorTheme {
    /// The app's signature top-of-page gradient: indigo → cyan, fading to clear downward.
    static var brandGradient: LinearGradient {
        LinearGradient(
            stops: [
                .init(color: Color.indigo.opacity(0.30), location: 0.00),
                .init(color: Color(red: 0.40, green: 0.34, blue: 0.78).opacity(0.24), location: 0.14),
                .init(color: Color(red: 0.44, green: 0.38, blue: 0.82).opacity(0.18), location: 0.28),
                .init(color: Color(red: 0.42, green: 0.44, blue: 0.86).opacity(0.14), location: 0.42),
                .init(color: Color.blue.opacity(0.13), location: 0.52),
                .init(color: Color(red: 0.20, green: 0.65, blue: 0.85).opacity(0.10), location: 0.66),
                .init(color: Color.cyan.opacity(0.07), location: 0.78),
                .init(color: Color.cyan.opacity(0.03), location: 0.90),
                .init(color: Color.clear, location: 1.00)
            ],
            startPoint: .top,
            endPoint: .bottom
        )
    }

    /// Full-strength brand gradient for foreground elements (icons, text, CTAs): indigo → cyan, leading to trailing.
    static var brandForeground: LinearGradient {
        LinearGradient(
            colors: [.indigo, Color(red: 0.30, green: 0.55, blue: 0.90), .cyan],
            startPoint: .leading,
            endPoint: .trailing
        )
    }
}

/// Places the brand gradient behind the page, anchored to the top and fading downward.
/// Apply to a screen's root `NavigationStack` so it sits behind the nav bar and content.
/// Pass a `base` color (e.g. `Color(.systemGroupedBackground)`) for grouped-list screens
/// so inset rows stay distinguishable once the gradient fades out.
struct GradientHeaderModifier: ViewModifier {
    var base: Color?

    func body(content: Content) -> some View {
        content
            .scrollContentBackground(.hidden)
            .background(alignment: .top) {
                VectorTheme.brandGradient
                    .frame(maxWidth: .infinity)
                    .frame(height: 360)
                    .ignoresSafeArea()
                    .allowsHitTesting(false)
            }
            .background {
                if let base {
                    base.ignoresSafeArea()
                }
            }
    }
}

extension View {
    /// Adds the standard Vector top-of-page brand gradient.
    /// - Parameter base: Optional opaque color layered beneath the gradient
    ///   (use `Color(.systemGroupedBackground)` on grouped `List` screens).
    func gradientHeader(base: Color? = nil) -> some View {
        modifier(GradientHeaderModifier(base: base))
    }
}
