import SwiftUI
import SafariServices
import Charts
import HealthKit

struct StressDetailView: View {
    let score: StressScore

    @Environment(HealthKitService.self) private var service
    @State private var animatedProgress: Double = 0
    @State private var selectedStressFactor: StressFactor? = nil
    @State private var stressHistory: [StressScore] = []
    @State private var showingStressHistory = false
    @State private var hrvSeries: [MetricTrendPoint] = []
    @State private var rhrSeries: [MetricTrendPoint] = []
    @State private var rrSeries: [MetricTrendPoint] = []
    @State private var wristTempSeries: [MetricTrendPoint] = []
    @State private var showingSafari = false
    @State private var safariURL: URL = URL(string: "https://www.heartandstroke.ca")!
    @State private var showingHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                headerSection
                rhythmEvaluationSection
                insightCard
                metricsGridSection
                resourcesSection

                Text("Stress is measured on a scale of 100")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(alignment: .top) {
            LinearGradient(
                colors: [score.level.color.opacity(0.45), Color.indigo.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)
            .ignoresSafeArea(edges: .top)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Stress")
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                Button {
                    showingHelp = true
                } label: {
                    Image(systemName: "questionmark.circle")
                }
            }
        }
        .sheet(isPresented: $showingSafari) {
            SafariView(url: safariURL)
                .ignoresSafeArea()
        }
        .sheet(isPresented: $showingHelp) {
            CardInfoSheet(cardID: "stress")
        }
        .sheet(item: $selectedStressFactor) { factor in
            MetricDetailSheet(
                title: factor.name,
                icon: factor.icon,
                tint: colorForStressFactor(factor.name),
                value: factor.value,
                statusLabel: factor.isElevating ? "Elevating stress" : "Keeping stress low",
                isPositive: !factor.isElevating,
                series: seriesForStressFactor(factor.name),
                baseline: baselineForStressFactor(factor.name),
                valueFormat: formatForStressFactor(factor.name),
                unit: unitForStressFactor(factor.name),
                contribution: factor.contribution,
                contributionCaption: "Contribution to stress score",
                explanation: factor.explanation,
                actionItem: factor.actionItem
            )
        }
        .sheet(isPresented: $showingStressHistory) {
            NavigationStack {
                ScrollView {
                    VStack(spacing: 20) {
                        stressHistorySection
                    }
                    .padding(.horizontal, 20)
                    .padding(.bottom, 32)
                }
                .navigationTitle("Today's Stress")
                .navigationBarTitleDisplayMode(.inline)
            }
            .presentationDetents([.medium, .fraction(0.85)])
            .presentationDragIndicator(.visible)
            .presentationCornerRadius(28)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedProgress = Double(score.score) / 100
            }
            stressHistory = StressHistoryStore.loadLast24Hours()
        }
        .task {
            async let hrvResult = service.dailyAverageSeries(for: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), days: 14)
            async let rhrResult = service.dailyAverageSeries(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 14)
            async let rrResult = service.dailyAverageSeries(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 14)
            async let wtResult = service.dailyAverageSeries(for: .appleSleepingWristTemperature, unit: HKUnit.degreeCelsius(), days: 21)
            let (hrv, rhr, rr, wt) = await (hrvResult, rhrResult, rrResult, wtResult)
            hrvSeries = hrv.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            rhrSeries = rhr.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            rrSeries = rr.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            wristTempSeries = wt.map { MetricTrendPoint(date: $0.date, value: $0.value) }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            TickRing(
                progress: animatedProgress,
                colors: [.indigo, score.level.color],
                size: 210
            ) {
                VStack(spacing: 2) {
                    Text("\(score.score)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    HStack(spacing: 3) {
                        Image(systemName: stressAverageIndicator.icon)
                            .font(.system(size: 8, weight: .bold))
                        Text(stressAverageIndicator.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(stressAverageIndicator.color)
                }
            }

            if let c = score.confidence {
                ConfidenceChip(confidence: c)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    // MARK: - Rhythm Evaluation

    @ViewBuilder
    private var rhythmEvaluationSection: some View {
        if score.circadianPhase == .earlyMorning || score.circadianPhase == .morning {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: score.circadianPhase.icon)
                        .font(.body.weight(.semibold))
                        .foregroundStyle(.orange)
                    Text("Rhythm Evaluation")
                        .font(.subheadline.weight(.semibold))
                    Spacer()
                    Text(score.circadianPhase.rawValue)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Text(score.circadianPhase.note)
                    .font(.caption)
                    .foregroundStyle(.secondary)

                if score.circadianAdjustmentApplied != 0 {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.circle.fill")
                            .font(.caption)
                            .foregroundStyle(.green)
                        Text("CAR adjustment: \(score.circadianAdjustmentApplied) pts applied to your score")
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.green)
                    }
                    .padding(.top, 2)
                }
            }
            .padding(14)
            .glassEffect(.regular.tint(Color.orange.opacity(0.12)), in: .rect(cornerRadius: 16))
        }
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(interpretationText)
                .font(.subheadline)
                .foregroundStyle(.primary)

            Divider()

            VStack(alignment: .leading, spacing: 8) {
                Text("Today's Priorities")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                ForEach(topActionItems, id: \.self) { item in
                    HStack(alignment: .top, spacing: 8) {
                        Circle()
                            .fill(score.level.color)
                            .frame(width: 6, height: 6)
                            .padding(.top, 5)
                        Text(item)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            if !stressConnections.isEmpty {
                Divider()
                ConnectionsBlock(insights: stressConnections)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Stress History

    @ViewBuilder
    private var stressHistorySection: some View {
        if stressHistory.count >= 2 {
            VStack {
                HStack {
                    Text("Today's Stress")
                        .font(.title3).bold()
                    Spacer()
                    Text("24 hours")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
                VStack(alignment: .leading, spacing: 12) {
                    StressHistoryChart(history: stressHistory)
                        .frame(height: 110)
                }
                .padding(16)
                .glassEffect(in: .rect(cornerRadius: 20))
            }
        }
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        VStack(alignment: .leading) {
                Text("Resources")
                    .font(.title3).bold()

                VStack(spacing: 10) {
                    ResourceRow(
                        title: "Coping with Stress",
                        source: "Health Canada",
                        icon: "leaf.fill",
                        color: .green
                    ) {
                        safariURL = URL(string: "https://www.canada.ca/en/health-canada/services/healthy-living/your-health/lifestyles/your-health-mental-health-coping-stress-health-canada-2008.html")!
                        showingSafari = true
                    }

                    ResourceRow(
                        title: "Manage Your Stress",
                        source: "Heart & Stroke Foundation",
                        icon: "heart.text.clipboard.fill",
                        color: .red
                    ) {
                        safariURL = URL(string: "https://www.heartandstroke.ca/healthy-living/reduce-stress/manage-your-stress")!
                        showingSafari = true
                    }
                }
            }
    }

    // MARK: - Advisor Topics

    private func topicForStressFactor(_ factor: StressFactor) -> AdvisorTopic {
        let series = seriesForStressFactor(factor.name)
        var context = ["\(factor.name): \(factor.value)"]
        let avgValue = series.count >= 7
            ? series.suffix(7).map(\.value).reduce(0, +) / Double(min(7, series.count))
            : nil
        if let avg = avgValue {
            context.append("7-day avg: \(String(format: "%.0f", avg))")
        }
        context.append(factor.isElevating ? "Status: Elevating stress" : "Status: Keeping stress low")
        return AdvisorTopic(
            title: factor.name,
            icon: factor.icon,
            tintName: colorNameForStressFactor(factor.name),
            contextLines: context,
            suggestedPrompt: "What does elevated \(factor.name.lowercased()) mean for my stress level?"
        )
    }

    private func colorNameForStressFactor(_ name: String) -> String {
        if name.contains("HRV") || name.contains("Variability") { return "indigo" }
        if name.contains("Daytime") { return "cyan" }
        if name.contains("Resting") || (name.contains("Heart Rate") && !name.contains("Daytime")) { return "red" }
        if name.contains("Sleep") { return "purple" }
        if name.contains("Respiratory") { return "cyan" }
        if name.contains("Temperature") || name.contains("Temp") { return "orange" }
        return "indigo"
    }

    private func topicForStressHistory() -> AdvisorTopic {
        var context = ["Current stress: \(score.score) pts"]
        context.append("Level: \(score.level.label)")
        if stressHistory.count >= 2 {
            let first = stressHistory.first?.score ?? 0
            let last = stressHistory.last?.score ?? 0
            let direction = last > first ? "increasing" : last < first ? "decreasing" : "stable"
            context.append("24-hour trend: \(direction)")
        }
        return AdvisorTopic(
            title: "Today's Stress",
            icon: "chart.xyaxis.line",
            tintName: "indigo",
            contextLines: context,
            suggestedPrompt: "How has my stress level changed over the last 24 hours?"
        )
    }

    // MARK: - Computed

    private var stressConnections: [ConnectionInsight] {
        CrossEngineInsight.forStress(stress: score, recovery: service.recoveryScore, sleep: service.sleepAnalysis)
    }

    private var stressAverageIndicator: (icon: String, label: String, color: Color) {
        let avg = ScoreHistoryStore.average(for: .stress) ?? 50
        let diff = score.score - avg
        if abs(diff) <= 5 {
            return ("equal", "Average", .secondary)
        } else if diff > 0 {
            return ("arrow.up.right", "Above Avg", .red)
        } else {
            return ("arrow.down.right", "Below Avg", .green)
        }
    }

    private var interpretationText: String {
        switch score.level {
        case .low:
            return "Your stress levels are low. HRV and resting heart rate are both within your baseline, which means your body is handling its current load well."
        case .moderate:
            return "Your body is showing mild stress. Some vitals are shifting from baseline, which could reflect training load, poor sleep, or accumulated daily tension."
        case .high:
            return "Your stress levels are high. Multiple signals are elevated, and your body needs dedicated recovery before taking on more intensity."
        }
    }

    private var topActionItems: [String] {
        var items: [String] = score.factors
            .filter { $0.isElevating }
            .map { $0.actionItem }
        if items.isEmpty {
            items = [
                "Low stress is a green light for quality training today.",
                "Keep your sleep and hydration habits consistent to stay here."
            ]
        }
        return Array(items.prefix(4))
    }

    private var metricsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            ForEach(score.factors) { factor in
                Button { selectedStressFactor = factor } label: {
                    MetricStatusCard(
                        title: factor.name,
                        status: factor.value,
                        statusColor: factor.isElevating ? .red : .green,
                        icon: factor.icon,
                        color: colorForStressFactor(factor.name),
                        series: seriesForStressFactor(factor.name).map(\.value)
                    )
                }
                .buttonStyle(.plain)
                .askVector(topicForStressFactor(factor))
            }

            if !stressHistory.isEmpty {
                Button { showingStressHistory = true } label: {
                    MetricStatusCard(
                        title: "Today's Stress",
                        status: "\(score.score) pts",
                        statusColor: score.level.color,
                        icon: "chart.xyaxis.line",
                        color: .indigo,
                        series: stressHistory.map { Double($0.score) }
                    )
                }
                .buttonStyle(.plain)
                .askVector(topicForStressHistory())
            }
        }
    }

    private func colorForStressFactor(_ name: String) -> Color {
        if name.contains("HRV") || name.contains("Variability") { return .indigo }
        if name.contains("Daytime") { return .cyan }
        if name.contains("Resting") || (name.contains("Heart Rate") && !name.contains("Daytime")) { return .red }
        if name.contains("Sleep") { return .purple }
        if name.contains("Respiratory") { return .cyan }
        if name.contains("Temperature") || name.contains("Temp") { return .orange }
        return .indigo
    }

    private func baselineForStressFactor(_ name: String) -> Double? {
        if name.contains("HRV") || name.contains("Variability") {
            return score.hrvBaseline > 0 ? score.hrvBaseline : nil
        }
        if name.contains("Daytime") {
            return score.restingHeartRate > 0 ? score.restingHeartRate : nil
        }
        if name.contains("Resting") || (name.contains("Heart Rate") && !name.contains("Daytime")) {
            return score.rhrBaseline > 0 ? score.rhrBaseline : nil
        }
        return nil
    }

    private func formatForStressFactor(_ name: String) -> (Double) -> String {
        if name.contains("Respiratory") || name.contains("Temp") {
            return { String(format: "%.1f", $0) }
        }
        return { String(Int($0)) }
    }

    private func unitForStressFactor(_ name: String) -> String {
        if name.contains("HRV") || name.contains("Variability") { return "ms" }
        if name.contains("Daytime") { return "bpm" }
        if name.contains("Resting") || name.contains("Heart Rate") { return "bpm" }
        if name.contains("Respiratory") { return "br/min" }
        if name.contains("Temperature") || name.contains("Temp") { return "°C" }
        if name.contains("Sleep") { return "%" }
        return ""
    }

    private func seriesForStressFactor(_ name: String) -> [MetricTrendPoint] {
        if name.contains("HRV") || name.contains("Variability") { return hrvSeries }
        if name.contains("Daytime") { return rhrSeries }  // Show resting HR trend as context for daytime elevation
        if name.contains("Heart Rate") || name.contains("Resting") { return rhrSeries }
        if name.contains("Respiratory") { return rrSeries }
        if name.contains("Temperature") || name.contains("Temp") { return wristTempSeries }
        if name.contains("Sleep") { return ScoreHistoryStore.series(for: .sleep).map { MetricTrendPoint(date: $0.date, value: Double($0.score)) } }
        return []
    }
}

// MARK: - Stress History Chart

private struct StressHistoryChart: View {
    let history: [StressScore]

    var body: some View {
        Chart {
            ForEach(history, id: \.date) { entry in
                LineMark(
                    x: .value("Hour", entry.date, unit: .hour),
                    y: .value("Stress", entry.score)
                )
                .foregroundStyle(Color.indigo.gradient)
                .interpolationMethod(.catmullRom)

                AreaMark(
                    x: .value("Hour", entry.date, unit: .hour),
                    yStart: .value("Min", 0),
                    yEnd: .value("Stress", entry.score)
                )
                .foregroundStyle(Color.indigo.opacity(0.1).gradient)
                .interpolationMethod(.catmullRom)
            }

            RectangleMark(yStart: .value("Low", 0), yEnd: .value("LowEnd", 40))
                .foregroundStyle(Color.green.opacity(0.05))

            RectangleMark(yStart: .value("ModStart", 40), yEnd: .value("ModEnd", 65))
                .foregroundStyle(Color.orange.opacity(0.05))

            RectangleMark(yStart: .value("HighStart", 65), yEnd: .value("HighEnd", 100))
                .foregroundStyle(Color.red.opacity(0.05))
        }
        .chartYScale(domain: 0...100)
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: 3)) { value in
                AxisValueLabel {
                    if let date = value.as(Date.self) {
                        Text(date.formatted(.dateTime.hour()))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .leading, values: [0, 40, 65, 100]) { value in
                AxisValueLabel {
                    if let v = value.as(Int.self) {
                        Text("\(v)")
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }
}

// MARK: - Resource Row

private struct ResourceRow: View {
    let title: String
    let source: String
    let icon: String
    let color: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                ZStack {
                    RoundedRectangle(cornerRadius: 8)
                        .fill(color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: icon)
                        .font(.body.weight(.medium))
                        .foregroundStyle(color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(title)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.primary)
                    Text(source)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Spacer()

                Image(systemName: "arrow.up.right")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            .padding(10)
            .glassEffect(.regular.interactive(), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Safari View

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = .systemIndigo
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        StressDetailView(score: .mock)
    }
    .environment(HealthKitService.preview)
}

