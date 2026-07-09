import SwiftUI

struct WatchDashboardView: View {
    @Environment(WatchConnectivityService.self) private var connectivity

    var body: some View {
        ScrollView {
            VStack(spacing: 12) {
                LazyVGrid(columns: [GridItem(.flexible(), spacing: 10), GridItem(.flexible(), spacing: 10)], spacing: 10) {
                    DashCircle(
                        progress: recovery.progress,
                        score: "\(recovery.score)",
                        label: "Recovery",
                        color: .green
                    )
                    DashCircle(
                        progress: exertion.progress,
                        score: "\(exertion.score)",
                        label: "Exertion",
                        color: exertion.color,
                        overflowColor: Color(red: 0.35, green: 0.0, blue: 0.0)
                    )
                    DashCircle(
                        progress: sleep.progress,
                        score: sleep.label,
                        label: "Sleep",
                        color: .indigo
                    )
                    DashCircle(
                        progress: stress.progress,
                        score: "\(stress.score)",
                        label: "Stress",
                        color: stress.color
                    )
                }

                Button {
                    connectivity.requestUpdate()
                } label: {
                    Label("Sync", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(.cyan.opacity(0.12)), in: .capsule)
                }
                .buttonStyle(.plain)
                .padding(.bottom, 4)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
        .navigationTitle("Vector")
        .navigationBarTitleDisplayMode(.inline)
    }

    private var recovery: (progress: Double, score: Int) {
        guard let r = connectivity.recoveryScore else { return (0, 0) }
        return (Double(r.score) / 100, r.score)
    }

    private var exertion: (progress: Double, score: Int, color: Color) {
        guard let e = connectivity.exertionScore else { return (0, 0, .orange) }
        return (Double(e.score) / 100, e.score, e.exertionLevelColor)
    }

    private var sleep: (progress: Double, label: String) {
        guard let s = connectivity.sleepAnalysis else { return (0, "--") }
        let score = s.qualityScore ?? Int(s.quality * 100)
        return (s.quality, score > 0 ? "\(score)" : "--")
    }

    private var stress: (progress: Double, score: Int, color: Color) {
        guard let st = connectivity.stressScore else { return (0, 0, .green) }
        return (Double(st.score) / 100, st.score, st.color)
    }
}

private struct DashCircle: View {
    let progress: Double
    let score: String
    let label: String
    let color: Color
    var overflowColor: Color? = nil

    var body: some View {
        VStack(spacing: 4) {
            ZStack {
                Circle()
                    .stroke(color.opacity(0.2), lineWidth: 5)
                Circle()
                    .trim(from: 0, to: min(progress, 1))
                    .stroke(color, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.easeInOut(duration: 0.6), value: progress)
                if let overflowColor, progress > 1 {
                    Circle()
                        .trim(from: 0, to: min(progress - 1, 1))
                        .stroke(overflowColor, style: StrokeStyle(lineWidth: 5, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.easeInOut(duration: 0.6), value: progress)
                }
                VStack(spacing: 1) {
                    Text(score)
                        .font(.system(size: 16, weight: .bold, design: .rounded))
                        .foregroundStyle(.primary)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)
                }
            }
            .frame(width: 64, height: 64)

            Text(label)
                .font(.system(size: 10, weight: .medium))
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

#Preview {
    WatchDashboardView()
        .environment(WatchConnectivityService())
}
