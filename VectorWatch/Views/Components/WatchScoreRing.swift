import SwiftUI

struct WatchScoreRing: View {
	let progress: Double
	let score: Int
	let label: String
	let color: Color
	let size: CGFloat

	var body: some View {
		ZStack {
			Circle()
				.stroke(.gray.opacity(0.15), lineWidth: size * 0.1)

			Circle()
				.trim(from: 0, to: min(max(progress, 0), 1))
				.stroke(color, style: StrokeStyle(lineWidth: size * 0.1, lineCap: .round))
				.rotationEffect(.degrees(-90))

			VStack(spacing: 2) {
				Text("\(score)")
					.font(.system(size: size * 0.28, weight: .bold, design: .rounded))
					.foregroundColor(.primary)

				Text(label)
					.font(.system(size: size * 0.12, weight: .semibold))
					.foregroundColor(.secondary)
			}
		}
		.frame(width: size, height: size)
		.animation(.spring(response: 0.6, dampingFraction: 0.8), value: progress)
	}
}

#Preview {
	VStack {
		HStack {
			WatchScoreRing(progress: 0.75, score: 75, label: "Recovery", color: .green)
			WatchScoreRing(progress: 0.42, score: 42, label: "Exertion", color: .orange)
		}
		WatchScoreRing(progress: 0.6, score: 60, label: "Sleep", color: .blue)
	}
	.padding()
}
