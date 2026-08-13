import SwiftUI

/// How a Vector sheet relates to the content behind it. Full-height sheets shrink
/// the root away; half sheets leave it alone so the two layers don't fight.
enum VectorSheetStyle {
    case full
    case half
}

/// Tracks which Vector sheets are currently on screen so the root content can
/// shrink behind them. Presentations are tracked by token so nested sheets and
/// repeated state updates stay balanced.
@Observable
final class SheetPresentationState {
    static let shared = SheetPresentationState()
    private var tokens: Set<UUID> = []
    var isPresenting: Bool { !tokens.isEmpty }
    func present(_ token: UUID) { tokens.insert(token) }
    func dismiss(_ token: UUID) { tokens.remove(token) }
    private init() {}
}

/// Wraps the `isPresented:` form of `.sheet()` and reports presentation state.
private struct SheetTrackingModifier<SheetContent: View>: ViewModifier {
    @State private var token = UUID()
    var isPresented: Binding<Bool>
    var onDismiss: (() -> Void)?
    var style: VectorSheetStyle
    var content: () -> SheetContent

    func body(content: Content) -> some View {
        content
            .sheet(isPresented: isPresented, onDismiss: onDismiss) {
                self.content()
            }
            .onChange(of: isPresented.wrappedValue, initial: true) { _, isNowPresented in
                if isNowPresented {
                    if style == .full { SheetPresentationState.shared.present(token) }
                } else {
                    SheetPresentationState.shared.dismiss(token)
                }
            }
            .onDisappear {
                SheetPresentationState.shared.dismiss(token)
            }
    }
}

/// Wraps the `item:` form of `.sheet()` and reports presentation state.
private struct SheetItemTrackingModifier<Item: Identifiable, SheetContent: View>: ViewModifier {
    @State private var token = UUID()
    var item: Binding<Item?>
    var onDismiss: (() -> Void)?
    var style: VectorSheetStyle
    var content: (Item) -> SheetContent

    func body(content: Content) -> some View {
        content
            .sheet(item: item, onDismiss: onDismiss) { item in
                self.content(item)
            }
            .onChange(of: item.wrappedValue != nil, initial: true) { _, isNowPresented in
                if isNowPresented {
                    if style == .full { SheetPresentationState.shared.present(token) }
                } else {
                    SheetPresentationState.shared.dismiss(token)
                }
            }
            .onDisappear {
                SheetPresentationState.shared.dismiss(token)
            }
    }
}

extension View {
    /// Full-height sheets shrink and dim the root behind them. Sheets that use a `.medium`,
    /// `.fraction(...)`, or `.height(...)` presentation detent should pass `style: .half`
    /// so the root stays put.
    func vectorSheet<Content: View>(
        isPresented: Binding<Bool>,
        onDismiss: (() -> Void)? = nil,
        style: VectorSheetStyle = .full,
        @ViewBuilder content: @escaping () -> Content
    ) -> some View {
        modifier(SheetTrackingModifier(isPresented: isPresented, onDismiss: onDismiss, style: style, content: content))
    }

    /// Full-height sheets shrink and dim the root behind them. Sheets that use a `.medium`,
    /// `.fraction(...)`, or `.height(...)` presentation detent should pass `style: .half`
    /// so the root stays put.
    func vectorSheet<Item: Identifiable, Content: View>(
        item: Binding<Item?>,
        onDismiss: (() -> Void)? = nil,
        style: VectorSheetStyle = .full,
        @ViewBuilder content: @escaping (Item) -> Content
    ) -> some View {
        modifier(SheetItemTrackingModifier(item: item, onDismiss: onDismiss, style: style, content: content))
    }
}

/// Applied once to the app's root content: shrinks, rounds and dims everything
/// behind a presented sheet so the sheet reads as a distinct layer.
private struct SheetBackdropScaling: ViewModifier {
    @State private var state = SheetPresentationState.shared

    func body(content: Content) -> some View {
        let active = state.isPresenting
        return ZStack {
            Color.black
            content
                .overlay {
                    Color.black
                        .opacity(active ? 0.32 : 0)
                        .allowsHitTesting(false)
                }
                .clipShape(RoundedRectangle(cornerRadius: active ? 44 : 0, style: .continuous))
                .scaleEffect(active ? 0.925 : 1, anchor: .center)
                .offset(y: active ? -12 : 0)
                .animation(.spring(response: 0.4, dampingFraction: 0.92), value: active)
        }
        .ignoresSafeArea(.container)
    }
}

extension View {
    func sheetBackdropScaling() -> some View { modifier(SheetBackdropScaling()) }
}
