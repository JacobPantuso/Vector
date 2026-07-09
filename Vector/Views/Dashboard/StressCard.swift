import SwiftUI

struct StressCard: View {
    let score: StressScore
    let progress: Double

    private let cardColor: Color = .indigo

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(cardColor.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: "waveform.path.ecg")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(cardColor)
                }
                Spacer()
                Text("Stress")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(score.score == 0 ? "--" : "\(score.score)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("stress index")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            CardProgressBar(value: progress, tint: score.level.color)

            HStack {
                Text(score.score == 0 ? "No data" : score.level.label)
                    .font(.caption.bold())
                    .foregroundStyle(score.score == 0 ? .secondary : score.level.color)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
        .glassEffect(.regular.tint(cardColor.opacity(0.25)), in: .rect(cornerRadius: 20))
    }
}
