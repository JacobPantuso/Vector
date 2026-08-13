import SwiftUI
import WidgetKit

// MARK: - VectorMetricKind Extensions

extension VectorMetricKind {
    var title: String {
        switch self {
        case .recovery: "Recovery"
        case .exertion: "Exertion"
        case .sleep: "Sleep"
        case .stress: "Stress"
        }
    }

    var shortTitle: String {
        switch self {
        case .recovery: "REC"
        case .exertion: "EXR"
        case .sleep: "SLP"
        case .stress: "STR"
        }
    }

    var symbol: String {
        switch self {
        case .recovery: "heart.fill"
        case .exertion: "bolt.fill"
        case .sleep: "moon.stars.fill"
        case .stress: "waveform.path.ecg"
        }
    }

    var tint: Color {
        switch self {
        case .recovery: Color(red: 0.0, green: 0.8, blue: 0.65)      // Mint/Teal
        case .exertion: Color(red: 1.0, green: 0.6, blue: 0.35)      // Warm coral
        case .sleep: Color(red: 0.4, green: 0.35, blue: 0.95)        // Deep indigo
        case .stress: Color(red: 0.2, green: 0.85, blue: 0.9)        // Cyan
        }
    }

    var gradient: [Color] {
        switch self {
        case .recovery:
            [Color(red: 0.0, green: 0.75, blue: 0.6), Color(red: 0.0, green: 0.85, blue: 0.75)]
        case .exertion:
            [Color(red: 0.95, green: 0.55, blue: 0.2), Color(red: 1.0, green: 0.65, blue: 0.4)]
        case .sleep:
            [Color(red: 0.35, green: 0.3, blue: 0.9), Color(red: 0.5, green: 0.45, blue: 1.0)]
        case .stress:
            [Color(red: 0.15, green: 0.8, blue: 0.88), Color(red: 0.3, green: 0.7, blue: 0.95)]
        }
    }

    var angularGradient: AngularGradient {
        AngularGradient(
            gradient: Gradient(colors: gradient),
            center: .center,
            startAngle: .degrees(-90),
            endAngle: .degrees(270)
        )
    }

    var linearGradient: LinearGradient {
        LinearGradient(
            gradient: Gradient(colors: gradient),
            startPoint: .topLeading,
            endPoint: .bottomTrailing
        )
    }
}

// MARK: - VectorRing (with overflow support)

struct VectorRing: View {
    var value: Int?
    var kind: VectorMetricKind
    var lineWidth: CGFloat = 6
    /// nil = full color; non-nil = accented/vibrant brightness for this ring's position
    var monochromeOpacity: Double? = nil
    var targetLow: Int? = nil
    var targetHigh: Int? = nil

    @Environment(\.widgetRenderingMode) var renderingMode

    private var base: Double {
        let v = Double(value ?? 0)
        return min(v, 100) / 100
    }

    private var overflow: Double {
        let v = Double(value ?? 0)
        return max(0, min(v - 100, 100)) / 100  // Cap overflow at 1.0 (one full lap max)
    }

    private var overflowColor: Color {
        Color(hue: 0.0, saturation: 0.95, brightness: 0.5)
    }

    var body: some View {
        @ViewBuilder var ringContent: some View {
            // Track
            if monochromeOpacity == nil {
                Circle()
                    .stroke(kind.tint.opacity(0.14), lineWidth: lineWidth)
            } else {
                Circle()
                    .stroke(Color.white.opacity(monochromeOpacity! * 0.15), lineWidth: lineWidth)
            }

            // Target band (between track and base arc)
            if let low = targetLow, let high = targetHigh {
                let lowFraction = max(0, min(Double(low) / 100, 1))
                let highFraction = max(0, min(Double(high) / 100, 1))
                if highFraction > lowFraction {
                    Circle()
                        .trim(from: lowFraction, to: highFraction)
                        .stroke(
                            monochromeOpacity == nil ? Color.white.opacity(0.18) : Color.white.opacity(0.15),
                            style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                        )
                        .rotationEffect(.degrees(-90))
                }
            }

            // Base arc
            if monochromeOpacity == nil {
                Circle()
                    .trim(from: 0, to: base)
                    .stroke(kind.angularGradient, style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .shadow(color: kind.tint.opacity(0.5), radius: lineWidth * 0.8, x: 0, y: 0)
            } else {
                Circle()
                    .trim(from: 0, to: base)
                    .stroke(Color.white.opacity(monochromeOpacity!), style: StrokeStyle(lineWidth: lineWidth, lineCap: .round))
                    .rotationEffect(.degrees(-90))
            }

            // Overflow arc (second lap)
            if overflow > 0 {
                Circle()
                    .trim(from: 0, to: overflow)
                    .stroke(
                        monochromeOpacity == nil ? overflowColor : Color.white,
                        style: StrokeStyle(lineWidth: lineWidth, lineCap: .round)
                    )
                    .rotationEffect(.degrees(-90))
            }

            // 3D rounded head at end of overflow arc
            if overflow > 0 {
                GeometryReader { geo in
                    let S = min(geo.size.width, geo.size.height)
                    let r = (S - lineWidth) / 2
                    let centerX = S / 2
                    let centerY = S / 2
                    let θ = 2 * .pi * overflow - .pi / 2
                    let headX = centerX + r * cos(θ)
                    let headY = centerY + r * sin(θ)
                    let headRadius = lineWidth * 1.15 / 2

                    if monochromeOpacity == nil {
                        // Full color: radial gradient for 3D effect
                        Circle()
                            .fill(
                                RadialGradient(
                                    gradient: Gradient(colors: [
                                        .white.opacity(0.95),
                                        overflowColor,
                                        overflowColor.opacity(0.7)
                                    ]),
                                    center: UnitPoint(x: 0.32, y: 0.28),
                                    startRadius: 0,
                                    endRadius: headRadius
                                )
                            )
                            .frame(width: headRadius * 2, height: headRadius * 2)
                            .shadow(color: .black.opacity(0.38), radius: lineWidth * 0.4, x: 0, y: lineWidth * 0.18)
                            .position(x: headX, y: headY)
                    } else {
                        // Monochrome: flat white with subtle highlight
                        Circle()
                            .fill(Color.white)
                            .frame(width: headRadius * 2, height: headRadius * 2)
                            .position(x: headX, y: headY)
                    }
                }
            }

            // Tick at targetHigh (on top of everything)
            if let high = targetHigh {
                let highFraction = max(0, min(Double(high) / 100, 1))
                GeometryReader { geo in
                    let S = min(geo.size.width, geo.size.height)
                    let r = (S - lineWidth) / 2
                    Capsule()
                        .fill(monochromeOpacity == nil ? Color.white.opacity(0.85) : Color.white)
                        .frame(width: 1.5, height: lineWidth + 4)
                        .offset(y: -r)
                        .rotationEffect(.degrees(360 * highFraction))
                        .position(x: S / 2, y: S / 2)
                }
            }
        }

        return ZStack {
            ringContent
        }
    }
}
