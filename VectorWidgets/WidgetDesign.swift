import SwiftUI
import WidgetKit

// MARK: - GlassBackground

struct GlassBackground: View {
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        ZStack {
            // Dark base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(white: 0.05),
                    Color(white: 0.02)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Subtle radial glow (top-trailing corner)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.2, green: 0.85, blue: 0.9).opacity(0.16),
                    Color(red: 0.35, green: 0.3, blue: 0.9).opacity(0.06),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.9, y: 0.05),
                startRadius: 0,
                endRadius: 150
            )
        }
        .overlay(
            renderingMode == .accented || renderingMode == .vibrant
                ? nil
                : LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.02), Color.clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        )
    }
}

// MARK: - Sparkline

struct Sparkline: Shape {
    let data: [Int]

    func path(in rect: CGRect) -> Path {
        guard data.count >= 2 else { return Path() }

        let maxValue = CGFloat(data.max() ?? 100)
        let minValue = CGFloat(data.min() ?? 0)
        let range = maxValue - minValue > 0 ? maxValue - minValue : 1

        let width = rect.width / CGFloat(data.count - 1)
        let height = rect.height

        var path = Path()
        var points: [CGPoint] = []

        for (index, value) in data.enumerated() {
            let normalizedY = 1 - (CGFloat(value) - minValue) / range
            let x = rect.minX + CGFloat(index) * width
            let y = rect.minY + normalizedY * height
            points.append(CGPoint(x: x, y: y))
        }

        guard points.count >= 2 else { return Path() }

        // Quadratic smoothing
        path.move(to: points[0])

        for i in 1..<points.count {
            let previous = points[i - 1]
            let current = points[i]
            let next = i < points.count - 1 ? points[i + 1] : current

            let cp1 = CGPoint(
                x: previous.x + (current.x - previous.x) / 2,
                y: previous.y + (current.y - previous.y) / 2
            )

            let cp2 = CGPoint(
                x: current.x - (next.x - current.x) / 2,
                y: current.y - (next.y - current.y) / 2
            )

            path.addCurve(to: current, control1: cp1, control2: cp2)
        }

        return path
    }
}

struct SparklineView: View {
    let data: [Int]
    let tint: Color

    var body: some View {
        if data.count >= 2 {
            Sparkline(data: data)
                .stroke(tint, lineWidth: 1.5)
        }
    }
}

// MARK: - Widget Container Background

// MARK: - Capsule Progress Bar with Overflow

struct VectorCapsuleBar: View {
    var value: Int?
    var kind: VectorMetricKind
    var width: CGFloat = 40
    var height: CGFloat = 4

    private var total: Double {
        Double(value ?? 0)
    }

    private var isOver: Bool {
        total > 100
    }

    private var fillFraction: Double {
        isOver ? 1.0 : total / 100
    }

    private var overflowFraction: Double {
        isOver ? (total - 100) / total : 0
    }

    private var overflowColor: Color {
        Color(hue: 0.0, saturation: 0.95, brightness: 0.42)
    }

    var body: some View {
        Capsule()
            .fill(kind.tint.opacity(0.14))
            .frame(width: width, height: height)
            .overlay(alignment: .leading) {
                Capsule()
                    .fill(kind.linearGradient)
                    .frame(maxWidth: width * fillFraction)
            }
            .overlay(alignment: .leading) {
                if isOver {
                    Capsule()
                        .fill(overflowColor)
                        .frame(maxWidth: width * overflowFraction)
                }
            }
    }
}

extension View {
    func widgetBackground() -> some View {
        self.containerBackground(for: .widget) {
            GlassBackground()
        }
    }

    func clearWidgetBackground() -> some View {
        self.containerBackground(.clear, for: .widget)
    }
}
