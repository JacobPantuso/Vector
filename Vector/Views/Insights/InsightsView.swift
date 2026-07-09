import SwiftUI

struct InsightsView: View {
    @State private var insightEngine = InsightEngine()

    var body: some View {
        NavigationStack {
            if insightEngine.insights.isEmpty {
                VStack(spacing: 24) {
                    Spacer()

                    Image(systemName: "sparkles")
                        .font(.system(size: 64))
                        .foregroundStyle(
                            LinearGradient(colors: [.yellow, .orange], startPoint: .topLeading, endPoint: .bottomTrailing)
                        )
                        .padding(40)
                        .glassEffect(in: .circle)

                    VStack(spacing: 8) {
                        Text("No insights yet")
                            .font(.title2)
                            .fontWeight(.bold)

                        Text("Generate your first insight")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    Button(action: generateSampleInsight) {
                        Label("Generate Insight", systemImage: "sparkles")
                            .fontWeight(.semibold)
                    }
                    .buttonStyle(.glassProminent)

                    Spacer()
                }
                .frame(maxWidth: .infinity)
                .navigationTitle("Insights")
            } else {
                ScrollView {
                    LazyVStack(spacing: 12) {
                        ForEach(insightEngine.insights.reversed()) { insight in
                            InsightCard(insight: insight)
                        }
                    }
                    .padding()
                }
                .navigationTitle("Insights")
                .toolbar {
                    ToolbarItem(placement: .confirmationAction) {
                        Button(action: generateSampleInsight) {
                            Image(systemName: "plus")
                                .fontWeight(.semibold)
                                .foregroundStyle(.secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func generateSampleInsight() {
        let sampleMetrics = "Heart rate: 72 bpm, Steps: 8,500, Sleep: 7.5 hours, Recovery: 75%, Training load: moderate"
        Task {
            await insightEngine.generateInsight(metrics: sampleMetrics)
        }
    }
}

#Preview {
    InsightsView()
}
