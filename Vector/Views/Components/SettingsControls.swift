import SwiftUI

// MARK: - Tick Slider

/// A slider drawn as a labelled scale: capsule track, tick marks under it, and a
/// knob that snaps to `step`. The current value is echoed in the header row.
struct TickSlider: View {
    let title: String
    let systemImage: String
    let tint: Color
    let range: ClosedRange<Double>
    let step: Double
    /// Ticks at multiples of this value get a taller mark and a caption.
    let labelStride: Double
    let valueText: (Double) -> String
    let tickText: (Double) -> String
    @Binding var value: Double

    @State private var isDragging = false

    private let knob: CGFloat = 28
    private let trackHeight: CGFloat = 14
    private let scaleHeight: CGFloat = 24

    init(
        title: String,
        systemImage: String,
        tint: Color,
        value: Binding<Double>,
        in range: ClosedRange<Double>,
        step: Double,
        labelStride: Double,
        valueText: @escaping (Double) -> String,
        tickText: @escaping (Double) -> String
    ) {
        self.title = title
        self.systemImage = systemImage
        self.tint = tint
        self._value = value
        self.range = range
        self.step = step
        self.labelStride = labelStride
        self.valueText = valueText
        self.tickText = tickText
    }

    /// Convenience for whole-number settings backed by an `Int`.
    init(
        title: String,
        systemImage: String,
        tint: Color,
        value: Binding<Int>,
        in range: ClosedRange<Int>,
        labelStride: Int = 1,
        valueText: @escaping (Int) -> String,
        tickText: @escaping (Int) -> String = { "\($0)" }
    ) {
        self.init(
            title: title,
            systemImage: systemImage,
            tint: tint,
            value: Binding(
                get: { Double(value.wrappedValue) },
                set: { value.wrappedValue = Int($0.rounded()) }
            ),
            in: Double(range.lowerBound) ... Double(range.upperBound),
            step: 1,
            labelStride: Double(labelStride),
            valueText: { valueText(Int($0.rounded())) },
            tickText: { tickText(Int($0.rounded())) }
        )
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            header

            GeometryReader { geo in
                let travel = max(geo.size.width - knob, 1)

                VStack(spacing: 6) {
                    track(travel: travel)
                    scale(travel: travel)
                }
                .contentShape(.rect)
                .gesture(drag(travel: travel))
            }
            .frame(height: knob + 6 + scaleHeight)
        }
        .sensoryFeedback(.selection, trigger: value)
    }

    private var header: some View {
        HStack(spacing: 10) {
            Image(systemName: systemImage)
                .font(.caption.weight(.semibold))
                .foregroundStyle(tint)
                .frame(width: 26, height: 26)
                .background(tint.opacity(0.16), in: .circle)

            Text(title)
                .font(.subheadline.weight(.semibold))

            Spacer(minLength: 8)

            Text(valueText(value))
                .font(.subheadline.weight(.bold).monospacedDigit())
                .foregroundStyle(tint)
                .contentTransition(.numericText(value: value))
                .animation(.snappy(duration: 0.2), value: value)
        }
    }

    private func track(travel: CGFloat) -> some View {
        ZStack(alignment: .leading) {
            Capsule()
                .fill(.quaternary)
                .frame(height: trackHeight)

            Capsule()
                .fill(
                    LinearGradient(
                        colors: [tint.opacity(0.55), tint],
                        startPoint: .leading,
                        endPoint: .trailing
                    )
                )
                .frame(width: knob / 2 + travel * fraction(value), height: trackHeight)

            Circle()
                .fill(.background)
                .overlay(Circle().strokeBorder(tint, lineWidth: 4))
                .shadow(color: .black.opacity(0.2), radius: isDragging ? 6 : 3, y: 2)
                .frame(width: knob, height: knob)
                .scaleEffect(isDragging ? 1.12 : 1)
                .offset(x: travel * fraction(value))
        }
        .frame(height: knob)
        .animation(.snappy(duration: 0.18), value: value)
        .animation(.snappy(duration: 0.18), value: isDragging)
    }

    private func scale(travel: CGFloat) -> some View {
        ZStack(alignment: .topLeading) {
            ForEach(tickValues, id: \.self) { tick in
                let isMajor = isMajorTick(tick)
                VStack(spacing: 3) {
                    Capsule()
                        .fill(tick <= value ? AnyShapeStyle(tint.opacity(0.7)) : AnyShapeStyle(.quaternary))
                        .frame(width: 1.5, height: isMajor ? 8 : 4)

                    if isMajor {
                        Text(tickText(tick))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .fixedSize()
                    }
                }
                .frame(width: 44)
                .position(x: knob / 2 + travel * fraction(tick), y: scaleHeight / 2)
            }
        }
        .frame(height: scaleHeight)
        .allowsHitTesting(false)
    }

    private func drag(travel: CGFloat) -> some Gesture {
        DragGesture(minimumDistance: 0)
            .onChanged { gesture in
                isDragging = true
                let ratio = min(max((gesture.location.x - knob / 2) / travel, 0), 1)
                value = snap(range.lowerBound + ratio * span)
            }
            .onEnded { _ in
                isDragging = false
            }
    }

    // MARK: Math

    private var span: Double { range.upperBound - range.lowerBound }

    private func fraction(_ value: Double) -> CGFloat {
        guard span > 0 else { return 0 }
        return CGFloat(min(max((value - range.lowerBound) / span, 0), 1))
    }

    private func snap(_ raw: Double) -> Double {
        let steps = ((raw - range.lowerBound) / step).rounded()
        let snapped = range.lowerBound + steps * step
        return min(max((snapped * 1000).rounded() / 1000, range.lowerBound), range.upperBound)
    }

    /// All step positions, thinned out to minor ticks only when the scale is dense.
    private var tickValues: [Double] {
        let count = Int((span / step).rounded())
        guard count > 0 else { return [range.lowerBound] }
        let stride = count > 20 ? max(1, count / 20) : 1
        var values = Swift.stride(from: 0, through: count, by: stride).map { index in
            snap(range.lowerBound + Double(index) * step)
        }
        if values.last != range.upperBound { values.append(range.upperBound) }
        return values
    }

    private func isMajorTick(_ tick: Double) -> Bool {
        guard labelStride > 0 else { return false }
        let offset = (tick - range.lowerBound) / labelStride
        return abs(offset - offset.rounded()) < 0.001
    }
}

// MARK: - Option Card Picker

/// A grid of tappable cards — one per option — with an icon, title and optional
/// caption. Replaces a menu `Picker` when the choice is worth showing off.
struct OptionCardPicker<Option: Hashable>: View {
    let options: [Option]
    let columns: Int
    let title: (Option) -> String
    let subtitle: (Option) -> String?
    let icon: (Option) -> String
    let tint: (Option) -> Color
    @Binding var selection: Option

    var body: some View {
        LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: columns), spacing: 10) {
            ForEach(options, id: \.self) { option in
                card(option)
            }
        }
        .animation(.snappy(duration: 0.25), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }

    private func card(_ option: Option) -> some View {
        let isSelected = option == selection
        let color = tint(option)

        return Button {
            selection = option
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack(alignment: .top) {
                    Image(systemName: icon(option))
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(color))
                        .frame(width: 30, height: 30)
                        .background(isSelected ? AnyShapeStyle(color) : AnyShapeStyle(color.opacity(0.16)), in: .circle)

                    Spacer(minLength: 4)

                    Image(systemName: "checkmark.circle.fill")
                        .font(.footnote)
                        .foregroundStyle(color)
                        .opacity(isSelected ? 1 : 0)
                        .scaleEffect(isSelected ? 1 : 0.6)
                }

                Text(title(option))
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                if let subtitle = subtitle(option) {
                    Text(subtitle)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.leading)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .modifier(SelectionGlass(tint: isSelected ? color.opacity(0.3) : nil, cornerRadius: 18))
            .overlay {
                RoundedRectangle(cornerRadius: 18)
                    .strokeBorder(color.opacity(isSelected ? 0.7 : 0), lineWidth: 1.5)
            }
        }
        .buttonStyle(.plain)
    }
}

/// Applies the app's glass surface, tinted only when the option is selected.
private struct SelectionGlass: ViewModifier {
    let tint: Color?
    let cornerRadius: CGFloat

    func body(content: Content) -> some View {
        if let tint {
            content.glassEffect(.regular.tint(tint).interactive(), in: .rect(cornerRadius: cornerRadius))
        } else {
            content.glassEffect(.regular.interactive(), in: .rect(cornerRadius: cornerRadius))
        }
    }
}

// MARK: - Chip Picker

/// A wrapping row of capsule chips for short, self-explanatory options.
struct ChipPicker<Option: Hashable>: View {
    let options: [Option]
    let title: (Option) -> String
    let tint: Color
    @Binding var selection: Option

    var body: some View {
        LazyVGrid(columns: [GridItem(.adaptive(minimum: 84), spacing: 8)], spacing: 8) {
            ForEach(options, id: \.self) { option in
                let isSelected = option == selection
                Button {
                    selection = option
                } label: {
                    Text(title(option))
                        .font(.subheadline.weight(isSelected ? .semibold : .regular))
                        .foregroundStyle(isSelected ? AnyShapeStyle(.white) : AnyShapeStyle(.primary))
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 10)
                        .background {
                            Capsule()
                                .fill(isSelected ? AnyShapeStyle(tint) : AnyShapeStyle(.quaternary))
                        }
                }
                .buttonStyle(.plain)
            }
        }
        .animation(.snappy(duration: 0.25), value: selection)
        .sensoryFeedback(.selection, trigger: selection)
    }
}

// MARK: - Profile Option Styling

extension FitnessGoal {
    var icon: String {
        switch self {
        case .fatLoss: return "flame.fill"
        case .maintenance: return "equal.circle.fill"
        case .muscleGain: return "figure.strengthtraining.traditional"
        case .performance: return "bolt.fill"
        }
    }

    var tint: Color {
        switch self {
        case .fatLoss: return .orange
        case .maintenance: return .teal
        case .muscleGain: return .indigo
        case .performance: return .cyan
        }
    }
}

extension AgeRange {
    var icon: String {
        switch self {
        case .under18: return "figure.and.child.holdinghands"
        case .age18to24: return "figure.run"
        case .age25to34: return "figure.strengthtraining.functional"
        case .age35to44: return "figure.hiking"
        case .age45Plus: return "figure.cooldown"
        }
    }
}
