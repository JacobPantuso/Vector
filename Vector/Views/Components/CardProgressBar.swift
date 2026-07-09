import SwiftUI

/// Uniform thin capsule progress bar used across the dashboard metric cards,
/// matching the thickness and track style of the Exertion card's bar.
struct CardProgressBar: View {
    let value: Double
    let tint: Color
    var height: CGFloat = 6
    var marker: Double? = nil

    var body: some View {
        GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(tint)
                    .frame(width: max(0, w * min(max(value, 0), 1)))
                if let marker = marker {
                    let clampedMarker = min(max(marker, 0), 1)
                    Capsule()
                        .fill(.primary)
                        .frame(width: 3, height: height + 6)
                        .offset(x: w * clampedMarker - 1.5)
                        .overlay(
                            Capsule()
                                .stroke(.white, lineWidth: 1)
                                .frame(width: 3, height: height + 6)
                                .offset(x: w * clampedMarker - 1.5)
                        )
                }
            }
        }
        .frame(height: height)
    }
}
