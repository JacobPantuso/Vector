import SwiftUI

struct WatchDashboardView: View {
    @Environment(WatchConnectivityService.self) private var connectivityService

    var body: some View {
        ScrollView {
            VStack(spacing: 10) {
                Text("VECTOR")
                    .font(.system(size: 11, weight: .semibold))
                    .tracking(2)
                    .foregroundStyle(.secondary)

                WatchScoreRing(
                    progress: recovery.progress,
                    score: recovery.score,
                    label: "Recovery",
                    color: .green,
                    size: 90
                )

                HStack(spacing: 10) {
                    WatchScoreRing(
                        progress: exertion.progress,
                        score: exertion.score,
                        label: "Exertion",
                        color: .orange,
                        size: 64
                    )

                    WatchScoreRing(
                        progress: sleep.progress,
                        score: sleep.hours,
                        label: "Sleep",
                        color: .blue,
                        size: 64
                    )
                }

                Button {
                    connectivityService.requestUpdate()
                } label: {
                    Label("Sync", systemImage: "arrow.clockwise")
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(.cyan)
                        .padding(.horizontal, 12)
                        .padding(.vertical, 6)
                        .glassEffect(.regular.tint(.cyan.opacity(0.12)), in: .capsule)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 6)
        }
    }

    private var recovery: (progress: Double, score: Int) {
        guard let r = connectivityService.recoveryScore else { return (0, 0) }
        return (Double(r.score) / 100, r.score)
    }

    private var exertion: (progress: Double, score: Int) {
        guard let e = connectivityService.exertionScore else { return (0, 0) }
        return (Double(e.score) / 100, e.score)
    }

    private var sleep: (progress: Double, hours: Int) {
        guard let s = connectivityService.sleepAnalysis else { return (0, 0) }
        return (min(s.totalDuration / (8 * 3600), 1), Int(s.totalDuration / 3600))
    }
}

#Preview {
    WatchDashboardView()
        .environment(WatchConnectivityService())
}
