import SwiftUI
import UIKit

/// A circular ring built from radial tick marks. Ticks fill clockwise up to `progress`,
/// their color interpolated across `colors` (start of arc → tip). `overflow` > 0 pushes the
/// active ticks deep red, signalling a value past its max. Generalized from the Train tab's
/// exertion ring so detail views can share the same aesthetic.
struct TickRing<Center: View>: View {
    let progress: Double          // 0...1 portion of ticks that are active
    let colors: [Color]           // gradient stops for active ticks (arc start → tip)
    let overflow: Double          // >0 pushes active ticks deep red
    let highlightRange: ClosedRange<Double>?  // 0...1 fractions of the ring to emphasize
    let tickCount: Int
    let size: CGFloat
    @ViewBuilder let center: () -> Center

    init(
        progress: Double,
        colors: [Color] = [.cyan, .blue],
        overflow: Double = 0,
        highlightRange: ClosedRange<Double>? = nil,
        tickCount: Int = 72,
        size: CGFloat = 140,
        @ViewBuilder center: @escaping () -> Center
    ) {
        self.progress = progress
        self.colors = colors
        self.overflow = overflow
        self.highlightRange = highlightRange
        self.tickCount = tickCount
        self.size = size
        self.center = center
    }

    // Proportions anchored to the Train tab's 210pt ring so the look scales 1:1.
    private var tickHeight: CGFloat { size * 0.0714 }
    private var tickWidth: CGFloat { max(2, size * 0.0167) }
    private var inset: CGFloat { size * 0.0476 }

    var body: some View {
        ZStack {
            ForEach(0..<tickCount, id: \.self) { i in
                let fraction = Double(i) / Double(tickCount)
                let active = fraction < max(progress, 0.0001) && progress > 0
                tick(active: active, fraction: fraction, index: i)
            }
            if let range = highlightRange {
                let arcInset = inset + tickHeight + size * 0.02
                Circle()
                    .trim(from: range.lowerBound, to: range.upperBound)
                    .stroke(
                        Self.lerp(colors, (range.lowerBound + range.upperBound) / 2).opacity(0.7),
                        style: StrokeStyle(lineWidth: max(2, size * 0.012), lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
                    .padding(arcInset)
            }
            center()
        }
        .frame(width: size, height: size)
        .animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
    }

    private func tick(active: Bool, fraction: Double, index: Int) -> some View {
        // Spread the gradient across the active arc so the tip always shows the end color.
        let blend = fraction
        var height = tickHeight
        if let range = highlightRange, range.contains(fraction), range.upperBound > range.lowerBound {
            let t = (fraction - range.lowerBound) / (range.upperBound - range.lowerBound)
            let bell = sin(t * .pi)   // 0 at edges, 1 at middle
            height = tickHeight * (1 + 0.45 * bell)
        }
        let highlighted = highlightRange.map { $0.contains(fraction) } ?? false
        let activeColor = overflow > 0
            ? Color(hue: 0.0, saturation: 0.95, brightness: 0.5)
            : Self.lerp(colors, blend)
        let color = active ? activeColor : (highlighted ? Self.lerp(colors, blend).opacity(0.35) : Color.gray.opacity(0.16))
        return RoundedRectangle(cornerRadius: tickWidth / 2)
            .fill(color)
            .frame(width: tickWidth, height: height)
            .offset(y: -size / 2 + inset - (height - tickHeight) / 2)
            .rotationEffect(.degrees(Double(index) / Double(tickCount) * 360))
    }

    /// Linearly interpolate across an array of colors by `t` in 0...1.
    private static func lerp(_ colors: [Color], _ t: Double) -> Color {
        guard let first = colors.first else { return .gray }
        guard colors.count > 1 else { return first }
        let clamped = min(max(t, 0), 1)
        let scaled = clamped * Double(colors.count - 1)
        let lower = Int(scaled)
        let upper = min(lower + 1, colors.count - 1)
        return mix(colors[lower], colors[upper], scaled - Double(lower))
    }

    private static func mix(_ a: Color, _ b: Color, _ t: Double) -> Color {
        let ca = UIColor(a), cb = UIColor(b)
        var r1: CGFloat = 0, g1: CGFloat = 0, b1: CGFloat = 0, a1: CGFloat = 0
        var r2: CGFloat = 0, g2: CGFloat = 0, b2: CGFloat = 0, a2: CGFloat = 0
        ca.getRed(&r1, green: &g1, blue: &b1, alpha: &a1)
        cb.getRed(&r2, green: &g2, blue: &b2, alpha: &a2)
        let f = CGFloat(t)
        return Color(
            red: Double(r1 + (r2 - r1) * f),
            green: Double(g1 + (g2 - g1) * f),
            blue: Double(b1 + (b2 - b1) * f)
        )
    }
}
