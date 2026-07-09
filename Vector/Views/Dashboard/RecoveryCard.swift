import SwiftUI

struct RecoveryCard: View {
    let score: RecoveryScore
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(score.level.color.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: score.level.systemImage)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(score.level.color)
                }
                Spacer()
                Text("Recovery")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(score.score)")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("out of 100")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            CardProgressBar(value: progress, tint: score.level.color)

            HStack {
                Text(score.level.label)
                    .font(.caption.bold())
                    .foregroundStyle(score.level.color)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
        .glassEffect(.regular.tint(score.level.color.opacity(0.3)), in: .rect(cornerRadius: 20))
    }
}
