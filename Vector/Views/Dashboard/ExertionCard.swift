import SwiftUI

struct ExertionCard: View {
    let score: ExertionScore
    let progress: Double
    var deemphasizeTarget: Bool = false

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.orange.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: "flame.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.orange)
                }
                Spacer()
                Text("Exertion")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(score.score)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("total exertion score")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            exertionBar
                .frame(height: 6)

            HStack {
                Text(score.exertionLevel.label)
                    .font(.caption.bold())
                    .foregroundStyle(score.exertionLevel.color)
                Spacer()
            }

        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
        .glassEffect(.regular.tint(.orange.opacity(0.3)), in: .rect(cornerRadius: 20))
    }

    private var exertionBar: some View {
        // At or below 100 the bar fills proportionally. Above 100 the bar stays
        // nearly full (a small gap remains at the end as headroom) and the amount
        // over 100 is shown as a dark-red chunk at the START of the bar, layered
        // over the level-coloured fill.
        let total = Double(score.score)
        let isOver = total > 100
        let fillFraction = isOver ? 1 : total / 100
        let overflowFraction = isOver ? (total - 100) / total : 0
        let baseColor = score.exertionLevel.color
        let overflowColor = Color(hue: 0.0, saturation: 0.95, brightness: 0.42)
        let targetBand = deemphasizeTarget ? nil : score.optimalTargetRange.map {
            (lo: min(max($0.lowerBound / 100, 0), 1), hi: min(max($0.upperBound / 100, 0), 1))
        }
        return GeometryReader { geo in
            let w = geo.size.width
            ZStack(alignment: .leading) {
                Capsule()
                    .fill(Color.secondary.opacity(0.18))
                Capsule()
                    .fill(baseColor)
                    .frame(width: max(0, w * fillFraction))
                if isOver {
                    Capsule()
                        .fill(overflowColor)
                        .frame(width: max(0, w * overflowFraction))
                }
                if let band = targetBand {
                    Capsule()
                        .fill(.primary.opacity(0.55))
                        .frame(width: max(2, w * (band.hi - band.lo)))
                        .overlay(
                            Capsule()
                                .stroke(.white.opacity(0.7), lineWidth: 1)
                        )
                        .offset(x: w * band.lo)
                }
            }
        }
    }
}
