import SwiftUI

struct SleepCard: View {
    let analysis: SleepAnalysis
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                ZStack {
                    Circle()
                        .fill(Color.blue.opacity(0.18))
                        .frame(width: 32, height: 32)
                    Image(systemName: "moon.fill")
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.blue)
                }
                Spacer()
                Text("Sleep")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text("\(Int((analysis.quality * 100).rounded()))")
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text("out of 100")
                .font(.caption2)
                .foregroundStyle(.tertiary)
                .padding(.bottom, 2)

            CardProgressBar(value: progress, tint: .blue)

            HStack {
                Text(analysis.qualityLevel.label)
                    .font(.caption.bold())
                    .foregroundStyle(analysis.qualityLevel.color)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
        .glassEffect(.regular.tint(.blue.opacity(0.3)), in: .rect(cornerRadius: 20))
    }
}
