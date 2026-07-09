import SwiftUI
import SafariServices
import Charts
import HealthKit

struct RecoveryDetailView: View {
    let score: RecoveryScore

    @Environment(HealthKitService.self) private var service
    @State private var animatedProgress: Double = 0
    @State private var hrvSeries: [MetricTrendPoint] = []
    @State private var rhrSeries: [MetricTrendPoint] = []
    @State private var rrSeries: [MetricTrendPoint] = []
    @State private var wristTempSeries: [MetricTrendPoint] = []
    @State private var spo2Series: [MetricTrendPoint] = []
    @State private var hrrSeries: [MetricTrendPoint] = []
    @State private var selectedRecoveryFactor: RecoveryFactor? = nil
    @State private var showingSafari = false
    @State private var safariURL: URL = URL(string: "https://www.sleepfoundation.org")!
    @State private var showingHelp = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                headerSection
                recoveryReadinessCard
                metricsGridSection
                resourcesSection

                Text("Recovery is measured on a scale of 100")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(alignment: .top) {
            LinearGradient(
                colors: [score.level.color.opacity(0.45), Color.cyan.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)
            .ignoresSafeArea(edges: .top)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Recovery")
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
            CardInfoSheet(cardID: "recovery")
        }
        .sheet(item: $selectedRecoveryFactor) { factor in
            MetricDetailSheet(
                title: factor.name,
                icon: factor.icon,
                tint: colorForRecoveryFactor(factor.name),
                value: factor.value,
                statusLabel: factor.statusLabel,
                isPositive: factor.isPositive,
                series: factor.series,
                baseline: factor.baseline,
                valueFormat: factor.valueFormat,
                unit: factor.unit,
                contribution: factor.contribution,
                contributionCaption: "Impact on recovery score",
                explanation: factor.explanation,
                actionItem: factor.actionItem
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedProgress = Double(score.score) / 100
            }
        }
        .task {
            async let hrvResult = service.dailyAverageSeries(for: .heartRateVariabilitySDNN, unit: HKUnit.secondUnit(with: .milli), days: 14)
            async let rhrResult = service.dailyAverageSeries(for: .restingHeartRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 14)
            async let rrResult = service.dailyAverageSeries(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 14)
            async let wtResult = service.dailyAverageSeries(for: .appleSleepingWristTemperature, unit: HKUnit.degreeCelsius(), days: 21)
            async let spo2Result = service.dailyAverageSeries(for: .oxygenSaturation, unit: HKUnit.percent(), days: 14)
            async let hrrResult = service.dailyAverageSeries(for: .heartRateRecoveryOneMinute, unit: HKUnit.count().unitDivided(by: .minute()), days: 14)
            let (hrv, rhr, rr, wt, spo2, hrr) = await (hrvResult, rhrResult, rrResult, wtResult, spo2Result, hrrResult)
            hrvSeries = hrv.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            rhrSeries = rhr.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            rrSeries = rr.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            wristTempSeries = wt.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            spo2Series = spo2.map { MetricTrendPoint(date: $0.date, value: $0.value * 100) }
            hrrSeries = hrr.map { MetricTrendPoint(date: $0.date, value: $0.value) }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            TickRing(
                progress: animatedProgress,
                colors: [score.level.color, Color.cyan],
                size: 210
            ) {
                VStack(spacing: 2) {
                    Text("\(score.score)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    HStack(spacing: 3) {
                        Image(systemName: recoveryAverageIndicator.icon)
                            .font(.system(size: 8, weight: .bold))
                        Text(recoveryAverageIndicator.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(recoveryAverageIndicator.color)
                }
            }

            if let c = score.confidence {
                ConfidenceChip(confidence: c)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var recoveryAverageIndicator: (icon: String, label: String, color: Color) {
        let avg = ScoreHistoryStore.average(for: .recovery) ?? 50
        let diff = score.score - avg
        if abs(diff) <= 5 {
            return ("equal", "Average", .secondary)
        } else if diff > 0 {
            return ("arrow.up.right", "Above Avg", .green)
        } else {
            return ("arrow.down.right", "Below Avg", .orange)
        }
    }

    // MARK: - Recovery Readiness Card

    private var recoveryReadinessCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            
            Text(interpretationText)
                .font(.subheadline)
                .foregroundStyle(.primary)

            if !recoveryConnections.isEmpty {
                Divider()
                ConnectionsBlock(insights: recoveryConnections)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Metrics Grid

    private var metricsGridSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Recovery Factors")
                .font(.title3).bold()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(recoveryFactors) { factor in
                    Button { selectedRecoveryFactor = factor } label: {
                        MetricStatusCard(
                            title: factor.name,
                            status: factor.value,
                            statusColor: factor.isPositive ? .green : .red,
                            icon: factor.icon,
                            color: colorForRecoveryFactor(factor.name),
                            series: factor.series.map(\.value)
                        )
                    }
                    .buttonStyle(.plain)
                    .askVector(topicForRecoveryFactor(factor))
                }
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
                    title: "Recovery & Sleep Optimization",
                    source: "Sleep Foundation",
                    icon: "moon.stars.fill",
                    color: .purple
                ) {
                    safariURL = URL(string: "https://www.sleepfoundation.org/physical-health/athletic-performance-and-sleep")!
                    showingSafari = true
                }

                ResourceRow(
                    title: "Understanding HRV",
                    source: "Harvard Health",
                    icon: "heart.text.clipboard.fill",
                    color: .red
                ) {
                    safariURL = URL(string: "https://www.health.harvard.edu/blog/heart-rate-variability-new-way-track-well-2017112212789")!
                    showingSafari = true
                }
            }
        }
    }

    // MARK: - Computed Properties

    private func colorForRecoveryFactor(_ name: String) -> Color {
        if name.contains("HRV") { return .indigo }
        if name.contains("Resting") || name.contains("Heart Rate") { return .red }
        if name.contains("Sleep") { return .purple }
        if name.contains("Respiratory") { return .cyan }
        if name.contains("Temperature") || name.contains("Temp") { return .orange }
        if name.contains("Oxygen") { return .blue }
        return .indigo
    }

    private var recoveryConnections: [ConnectionInsight] {
        CrossEngineInsight.forRecovery(recovery: score, sleep: service.sleepAnalysis, exertion: service.exertionScore, stress: service.stressScore)
    }

    private var interpretationText: String {
        switch score.level {
        case .superior:
            return "Your recovery is excellent. All vitals are favorable, indicating your body is ready for challenging training and your sleep quality is supporting optimal adaptation."
        case .excellent:
            return "Your recovery is strong. HRV and resting heart rate are close to or above baseline, showing good regeneration. Maintain your sleep and nutrition habits."
        case .good:
            return "Your recovery is moderate. Some vitals show minor deviations from baseline. Focus on consistent sleep and gentle movement today before progressive training."
        case .poor:
            return "Your recovery is low. Multiple signals suggest your body needs dedicated rest. Prioritize sleep, hydration, and avoid high-intensity training today."
        }
    }

    private func topicForRecoveryFactor(_ factor: RecoveryFactor) -> AdvisorTopic {
        let latest = factor.series.last.map { String(format: "%.0f", $0.value) } ?? factor.value
        let avgValue = factor.series.count >= 7
            ? factor.series.suffix(7).map(\.value).reduce(0, +) / Double(min(7, factor.series.count))
            : nil
        var context = ["\(factor.name): \(factor.value)"]
        if let avg = avgValue {
            context.append("7-day avg: \(String(format: "%.0f", avg))")
        }
        if let baseline = factor.baseline {
            context.append("Baseline: \(String(format: "%.0f", baseline))")
        }
        context.append(factor.statusLabel)

        return AdvisorTopic(
            title: factor.name,
            icon: factor.icon,
            tintName: colorNameForRecoveryFactor(factor.name),
            contextLines: context,
            suggestedPrompt: "What does my \(factor.name.lowercased()) mean and how can I improve it?"
        )
    }

    private func colorNameForRecoveryFactor(_ name: String) -> String {
        if name.contains("HRV") { return "indigo" }
        if name.contains("Resting") || name.contains("Heart Rate") { return "red" }
        if name.contains("Sleep") { return "purple" }
        if name.contains("Respiratory") { return "cyan" }
        if name.contains("Temperature") || name.contains("Temp") { return "orange" }
        if name.contains("Oxygen") { return "blue" }
        return "indigo"
    }

    private var recoveryFactors: [RecoveryFactor] {
        let hrvContribution = abs(score.hrvDeviation) / 100.0
        let hrvPositive = score.hrvValue > score.hrvBaseline
        let hrvExplanation = hrvPositive
            ? "Higher HRV indicates better heart rate variability and parasympathetic tone, supporting recovery readiness."
            : "Lower HRV may indicate sympathetic dominance or accumulated fatigue. Consider extra rest."
        let hrvAction = hrvPositive
            ? "Maintain current sleep and stress management practices."
            : "Add 10 minutes of breathing work or meditation today."

        let rhrContribution = abs(score.rhrDeviation) / 100.0
        let rhrPositive = score.restingHeartRate < score.rhrBaseline
        let rhrExplanation = rhrPositive
            ? "Your resting heart rate is lower than baseline, indicating good recovery and cardiovascular adaptation."
            : "Elevated resting heart rate may signal fatigue or incomplete recovery. Allow extra rest."
        let rhrAction = rhrPositive
            ? "You're well-recovered—this is a good day for training."
            : "Take it easy today; prioritize sleep and hydration."

        let sleepContribution = max(0, min(1, score.sleepQuality / 0.65))
        let sleepPositive = score.sleepQuality > 0.65
        let sleepExplanation = sleepPositive
            ? "Your sleep quality is supporting recovery well. Continue current sleep habits."
            : "Sleep quality is below optimal for recovery. Improve sleep environment and consistency."
        let sleepAction = sleepPositive
            ? "Great sleep is fueling your recovery—keep this going."
            : "Aim for consistent bedtime and screen-free 30 min before sleep."

        var factors: [RecoveryFactor] = [
            RecoveryFactor(
                name: "HRV",
                icon: "waveform.path.ecg",
                value: "\(String(format: "%.0f", score.hrvValue)) ms",
                contribution: hrvContribution,
                isPositive: hrvPositive,
                explanation: hrvExplanation,
                actionItem: hrvAction,
                series: hrvSeries,
                baseline: score.hrvBaseline > 0 ? score.hrvBaseline : nil,
                statusLabel: hrvPositive ? "Above baseline" : "Below baseline",
                unit: "ms"
            ),
            RecoveryFactor(
                name: "Resting Heart Rate",
                icon: "heart.fill",
                value: "\(String(format: "%.0f", score.restingHeartRate)) bpm",
                contribution: rhrContribution,
                isPositive: rhrPositive,
                explanation: rhrExplanation,
                actionItem: rhrAction,
                series: rhrSeries,
                baseline: score.rhrBaseline > 0 ? score.rhrBaseline : nil,
                statusLabel: rhrPositive ? "Below baseline" : "Elevated",
                unit: "bpm"
            ),
            RecoveryFactor(
                name: "Sleep Quality",
                icon: "moon.fill",
                value: "\(String(format: "%.0f", score.sleepQuality * 100))%",
                contribution: sleepContribution,
                isPositive: sleepPositive,
                explanation: sleepExplanation,
                actionItem: sleepAction,
                series: ScoreHistoryStore.series(for: .sleep).map { MetricTrendPoint(date: $0.date, value: Double($0.score)) },
                statusLabel: sleepPositive ? "Supporting recovery" : "Below optimal",
                unit: "%"
            )
        ]

        if let rr = score.respiratoryRate, let deviation = score.respiratoryDeviation {
            let baseline = score.respiratoryBaseline ?? rr
            let rrPositive = deviation <= 0   // at or below baseline = good for recovery
            factors.append(RecoveryFactor(
                name: "Respiratory Rate",
                icon: "lungs.fill",
                value: "\(String(format: "%.1f", rr)) br/min",
                contribution: min(1, abs(deviation) / 100.0 * 4),
                isPositive: rrPositive,
                explanation: rrPositive
                    ? "Your overnight breathing rate is at or below your \(String(format: "%.1f", baseline)) br/min baseline, a sign of good recovery and low physiological strain."
                    : "Your overnight breathing rate is \(abs(Int(deviation)))% above your \(String(format: "%.1f", baseline)) br/min baseline. Elevated breathing during sleep can signal incomplete recovery, strain, or early illness.",
                actionItem: rrPositive
                    ? "Breathing is steady—keep your recovery routine consistent."
                    : "Prioritize rest and hydration today, and monitor for signs of illness or overtraining.",
                series: rrSeries,
                baseline: score.respiratoryBaseline,
                statusLabel: rrPositive ? "At baseline" : "Above baseline",
                valueFormat: { String(format: "%.1f", $0) },
                unit: "br/min"
            ))
        }

        if let dev = score.wristTempDeviation {
            let tempPositive = abs(dev) <= 0.3   // near baseline = good
            factors.append(RecoveryFactor(
                name: "Wrist Temperature",
                icon: "thermometer.medium",
                value: String(format: "%+.1f°C", dev),
                contribution: min(1, abs(dev) / 0.5),
                isPositive: tempPositive,
                explanation: tempPositive
                    ? "Your overnight wrist temperature is close to baseline, a sign your body is well-regulated and recovering normally."
                    : String(format: "Your overnight wrist temperature deviated %+.1f°C from baseline. Notable shifts can signal strain, illness, or poor recovery.", dev),
                actionItem: tempPositive
                    ? "Temperature is stable—maintain your routine."
                    : "Monitor for signs of illness, prioritize rest and hydration, and keep training light until it normalizes.",
                series: wristTempSeries,
                statusLabel: tempPositive ? "Near baseline" : "Deviating",
                valueFormat: { String(format: "%.1f", $0) },
                unit: "°C"
            ))
        }

        if let ox = score.spo2 {
            let spo2Positive = ox >= 95
            let baselineText = score.spo2Baseline.map { String(format: "%.0f%%", $0) } ?? "your baseline"
            factors.append(RecoveryFactor(
                name: "Blood Oxygen",
                icon: "lungs.fill",
                value: String(format: "%.0f%%", ox),
                contribution: min(1, max(0, (97 - ox) / 5)),
                isPositive: spo2Positive,
                explanation: spo2Positive
                    ? "Your overnight blood oxygen is healthy (vs \(baselineText) baseline), supporting muscle repair and recovery."
                    : "Your overnight blood oxygen is lower than ideal. Persistently low readings can impair recovery—consider your sleep environment and altitude.",
                actionItem: spo2Positive
                    ? "Oxygen levels look good—no action needed."
                    : "Ensure good airflow while sleeping; if low readings persist, consider consulting a clinician.",
                series: spo2Series,
                baseline: score.spo2Baseline,
                statusLabel: spo2Positive ? "Healthy range" : "Lower than ideal",
                unit: "%"
            ))
        }

        if let hrr = score.hrr {
            let hrrPositive = score.hrrBaseline.map { hrr >= $0 * 0.9 } ?? (hrr >= 25)
            factors.append(RecoveryFactor(
                name: "Heart Rate Recovery",
                icon: "heart.arrow.up",
                value: "\(Int(hrr)) bpm",
                contribution: min(1, max(0, (hrr - 15) / 20)),
                isPositive: hrrPositive,
                explanation: hrrPositive
                    ? "Your heart rate dropped \(Int(hrr)) bpm in the minute after exercise — a strong autonomic recovery signal."
                    : "Heart-rate recovery is below your baseline, which can indicate accumulated fatigue.",
                actionItem: hrrPositive
                    ? "Continue Zone 2 training; recovery is excellent."
                    : "Favor Zone 2 work until recovery rebounds.",
                series: hrrSeries,
                baseline: score.hrrBaseline,
                statusLabel: hrrPositive ? "Solid recovery" : "Below baseline",
                unit: "bpm"
            ))
        }

        return factors
    }

}

// MARK: - Recovery Factor

private struct RecoveryFactor: Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let value: String
    let contribution: Double
    let isPositive: Bool
    let explanation: String
    let actionItem: String
    var series: [MetricTrendPoint] = []
    var baseline: Double? = nil
    let statusLabel: String
    var valueFormat: (Double) -> String = { String(Int($0)) }
    var unit: String = ""
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
        RecoveryDetailView(score: .mock)
    }
    .environment(HealthKitService.preview)
}

