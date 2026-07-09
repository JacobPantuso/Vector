import SwiftUI

struct RecoverySnippetView: View {
    let score: Int
    let hrv: Double
    let rhr: Double

    private var color: Color {
        score > 66 ? .green : score > 33 ? .orange : .red
    }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 8)
                Circle()
                    .trim(from: 0, to: Double(score) / 100)
                    .stroke(color, style: StrokeStyle(lineWidth: 8, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                Text("\(score)")
                    .font(.title2.bold())
                    .monospacedDigit()
            }
            .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("Recovery")
                    .font(.headline)
                HStack(spacing: 12) {
                    Label(String(format: "%.0f ms", hrv), systemImage: "waveform.path.ecg")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Label(String(format: "%.0f bpm", rhr), systemImage: "heart.fill")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding()
    }
}
