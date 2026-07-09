import SwiftUI
import SafariServices
import Charts
import HealthKit

struct SleepDetailView: View {
    let analysis: SleepAnalysis

    @Environment(HealthKitService.self) private var service
    @State private var animatedProgress: Double = 0
    @State private var qualitySeries: [MetricTrendPoint] = []
    @State private var sleepRRSeries: [MetricTrendPoint] = []
    @State private var sleepWristTempSeries: [MetricTrendPoint] = []
    @State private var sleepEfficiencySeries: [MetricTrendPoint] = []
    @State private var sleepBedtimeSeries: [MetricTrendPoint] = []
    @State private var selectedStage: SleepStage? = nil
    @State private var showingSafari = false
    @State private var safariURL: URL = URL(string: "https://www.sleepfoundation.org")!
    @State private var showingHelp = false
    @State private var selectedSleepMetric: SleepMetricDetail? = nil

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                headerSection
                insightCard
                sleepNeedDebtSection
                sleepArchitectureSection
                stageDistributionChart
                metricsGridSection
                resourcesSection

                Text("Sleep quality is measured as a percentage of optimal rest")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color.indigo.opacity(0.45), Color.purple.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)
            .ignoresSafeArea(edges: .top)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Sleep")
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
            CardInfoSheet(cardID: "sleep")
        }
        .sheet(item: $selectedSleepMetric) { metric in
            sleepMetricDetailSheet(metric)
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                animatedProgress = analysis.quality
            }
            qualitySeries = ScoreHistoryStore.series(for: .sleep).map { MetricTrendPoint(date: $0.date, value: Double($0.score)) }
        }
        .task {
            async let rrResult = service.dailyAverageSeries(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 14)
            async let wtResult = service.dailyAverageSeries(for: .appleSleepingWristTemperature, unit: HKUnit.degreeCelsius(), days: 21)
            let (rr, wt) = await (rrResult, wtResult)
            sleepRRSeries = rr.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            sleepWristTempSeries = wt.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            sleepEfficiencySeries = ScoreHistoryStore.series(for: .sleepEfficiency).map { MetricTrendPoint(date: $0.date, value: Double($0.score)) }
            sleepBedtimeSeries = ScoreHistoryStore.series(for: .bedtime).map { MetricTrendPoint(date: $0.date, value: Double($0.score)) }
            qualitySeries = ScoreHistoryStore.series(for: .sleep).map { MetricTrendPoint(date: $0.date, value: Double($0.score)) }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        VStack(spacing: 12) {
            TickRing(
                progress: animatedProgress,
                colors: [.indigo, .purple],
                size: 210
            ) {
                VStack(spacing: 2) {
                    Text("\(Int(analysis.quality * 100))")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    HStack(spacing: 3) {
                        Image(systemName: sleepAverageIndicator.icon)
                            .font(.system(size: 8, weight: .bold))
                        Text(sleepAverageIndicator.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(sleepAverageIndicator.color)
                }
            }

            if let c = analysis.confidence {
                ConfidenceChip(confidence: c)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private var sleepAverageIndicator: (icon: String, label: String, color: Color) {
        let score = Int(analysis.quality * 100)
        let avg = ScoreHistoryStore.average(for: .sleep) ?? 65
        let diff = score - avg
        if abs(diff) <= 5 {
            return ("equal", "Average", .secondary)
        } else if diff > 0 {
            return ("arrow.up.right", "Above Avg", .green)
        } else {
            return ("arrow.down.right", "Below Avg", .orange)
        }
    }

    // MARK: - Insight Card

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text(interpretationText)
                .font(.subheadline)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    infoChip(label: "Duration", value: analysis.formattedDuration, color: .blue)
                    infoChip(label: "Efficiency", value: "\(Int(analysis.efficiency * 100))%", color: .purple)
                    infoChip(label: "Quality", value: analysis.qualityLevel.label, color: analysis.qualityLevel.color)
                }
            }
            .padding(.top, 4)

            if !sleepConnections.isEmpty {
                Divider()
                ConnectionsBlock(insights: sleepConnections)
            }

            if let flag = analysis.disruption, flag.isFlagged {
                Divider()
                VStack(alignment: .leading, spacing: 8) {
                    HStack(spacing: 8) {
                        Image(systemName: flag.likelyAlcohol ? "wineglass" : "exclamationmark.triangle.fill")
                            .foregroundStyle(.orange)
                        Text(flag.headline)
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(flag.severity.label)
                            .font(.caption.weight(.medium))
                            .foregroundStyle(.secondary)
                    }
                    ForEach(flag.signals, id: \.self) { signal in
                        HStack(spacing: 6) {
                            Image(systemName: "circle.fill")
                                .font(.system(size: 4))
                                .foregroundStyle(.secondary)
                            Text(signal)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                    Text("A hypothesis from your overnight metrics — ask Vector to confirm what happened.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private var sleepNeedDebtSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Debt")
                .font(.title3).bold()
            HStack(spacing: 0) {
                needDebtStat(label: "Need", value: hoursText(analysis.sleepNeed), color: .indigo)
                Divider().frame(height: 32)
                needDebtStat(label: "Debt", value: hoursText(analysis.sleepDebt),
                             color: (analysis.sleepDebt ?? 0) >= 3600 ? .orange : .secondary)
                Divider().frame(height: 32)
                needDebtStat(label: "Consistency",
                             value: analysis.consistency.map { "\(Int($0 * 100))%" } ?? "--",
                             color: .cyan)
            }
            .padding(.vertical, 8)
            SleepNeedDebtChart(targetHours: analysis.sleepTargetHours)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private func needDebtStat(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.title3.weight(.bold).monospacedDigit())
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }

    private func hoursText(_ interval: TimeInterval?) -> String {
        guard let interval, interval > 0 else { return "--" }
        let h = Int(interval) / 3600
        let m = (Int(interval) % 3600) / 60
        return m > 0 ? "\(h)h \(m)m" : "\(h)h"
    }

    // MARK: - Sleep Architecture

    private var sleepArchitectureSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Sleep Breakdown")
                .font(.title3).bold()

            VStack(spacing: 0) {
                ForEach(Array(sleepStages.enumerated()), id: \.offset) { index, stage in
                    SleepStageRow(stage: stage, isSelected: selectedStage?.id == stage.id)
                        .onTapGesture {
                            withAnimation(.spring(response: 0.3)) {
                                selectedStage = selectedStage?.id == stage.id ? nil : stage
                            }
                        }

                    if index < sleepStages.count - 1 {
                        Divider().padding(.leading, 52)
                    }
                }
            }
            .padding(.vertical, 4)
            .glassEffect(in: .rect(cornerRadius: 20))
        }
    }

    // MARK: - Sleep Timeline Chart

    private var stageDistributionChart: some View {
        VStack {
            HStack {
                Text("Sleep Stages")
                    .font(.title3).bold()
                Spacer()
                Text("Timeline")
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }

            VStack(alignment: .leading, spacing: 12) {
                if analysis.segments.isEmpty {
                    Text("Detailed sleep stages weren't recorded for this night. Wear your Apple Watch to bed to see your hypnogram.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .leading)
                        .padding(.vertical, 8)
                } else {
                    SleepTimelineChart(analysis: analysis)
                        .frame(height: 140)
                    HStack(spacing: 16) {
                        Spacer()
                        stageChartLegend(color: .red.opacity(0.7), label: "Awake")
                        stageChartLegend(color: .cyan, label: "REM")
                        stageChartLegend(color: Color(red: 0.2, green: 0.6, blue: 1), label: "Core")
                        stageChartLegend(color: Color(red: 0.6, green: 0.4, blue: 1), label: "Deep")
                        Spacer()
                    }
                }
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 20))
        }
    }

    // MARK: - Metrics Grid

    private var metricsGridSection: some View {
        LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
            Button { selectedSleepMetric = .efficiency } label: {
                MetricStatusCard(
                    title: "Efficiency",
                    status: "\(Int(analysis.efficiency * 100))%",
                    statusColor: analysis.efficiency >= 0.90 ? .green : analysis.efficiency >= 0.85 ? .yellow : .orange,
                    icon: "bed.double.fill",
                    color: .purple,
                    series: sleepEfficiencySeries.map(\.value)
                )
            }
            .buttonStyle(.plain)
            .askVector(topicForSleepMetric(title: "Sleep Efficiency", value: "\(Int(analysis.efficiency * 100))%", icon: "bed.double.fill", tintName: "purple", series: sleepEfficiencySeries))

            if analysis.respiratoryRate != nil {
                Button { selectedSleepMetric = .respiratoryRate } label: {
                    let rr = analysis.respiratoryRate!
                    let baseline = analysis.respiratoryBaseline ?? rr
                    let deviationPct = (rr - baseline) / max(baseline, 1) * 100
                    let isStable = deviationPct <= 5
                    MetricStatusCard(
                        title: "Resp Rate",
                        status: String(format: "%.1f br/min", rr),
                        statusColor: isStable ? .green : .orange,
                        icon: "lungs.fill",
                        color: .cyan,
                        series: sleepRRSeries.map(\.value)
                    )
                }
                .buttonStyle(.plain)
                .askVector(topicForSleepMetric(title: "Respiratory Rate", value: String(format: "%.1f br/min", analysis.respiratoryRate ?? 0), icon: "lungs.fill", tintName: "cyan", series: sleepRRSeries))
            }

            if analysis.wristTempDeviation != nil {
                Button { selectedSleepMetric = .wristTemp } label: {
                    let dev = analysis.wristTempDeviation!
                    let isStable = abs(dev) <= 0.3
                    MetricStatusCard(
                        title: "Wrist Temp",
                        status: String(format: "%+.1f°C", dev),
                        statusColor: isStable ? .green : .orange,
                        icon: "thermometer.medium",
                        color: .orange,
                        series: sleepWristTempSeries.map(\.value)
                    )
                }
                .buttonStyle(.plain)
                .askVector(topicForSleepMetric(title: "Wrist Temperature", value: String(format: "%+.1f°C", analysis.wristTempDeviation ?? 0), icon: "thermometer.medium", tintName: "orange", series: sleepWristTempSeries))
            }

            Button { selectedSleepMetric = .timing } label: {
                MetricStatusCard(
                    title: "Timing",
                    status: bedtimeFormatted,
                    statusColor: .indigo,
                    icon: "clock.fill",
                    color: .indigo,
                    series: sleepBedtimeSeries.map(\.value)
                )
            }
            .buttonStyle(.plain)
            .askVector(topicForSleepMetric(title: "Sleep Timing", value: bedtimeFormatted, icon: "clock.fill", tintName: "indigo", series: sleepBedtimeSeries))

            Button { selectedSleepMetric = .qualityTrend } label: {
                MetricStatusCard(
                    title: "Quality Trend",
                    status: qualitySeries.isEmpty ? "No Data" : "\(Int((qualitySeries.last?.value ?? 0))) pts",
                    statusColor: .indigo,
                    icon: "chart.line.uptrend.xyaxis",
                    color: .indigo,
                    series: qualitySeries.map(\.value)
                )
            }
            .buttonStyle(.plain)
            .askVector(topicForSleepMetric(title: "Quality Trend", value: qualitySeries.isEmpty ? "No Data" : "\(Int((qualitySeries.last?.value ?? 0))) pts", icon: "chart.line.uptrend.xyaxis", tintName: "indigo", series: qualitySeries))
        }
    }

    @ViewBuilder
    private func sleepMetricDetailSheet(_ metric: SleepMetricDetail) -> some View {
        switch metric {
        case .efficiency:
            MetricDetailSheet(
                title: "Sleep Efficiency",
                icon: "bed.double.fill",
                tint: .purple,
                value: "\(Int(analysis.efficiency * 100))%",
                statusLabel: analysis.efficiency >= 0.90 ? "Excellent" : analysis.efficiency >= 0.85 ? "Good" : "Fragmented",
                isPositive: analysis.efficiency >= 0.85,
                series: sleepEfficiencySeries,
                rangeLabel: "Recent nights",
                stats: [
                    MetricStat(label: "Asleep", value: formatTimeInterval(analysis.totalDuration - analysis.awakeDuration)),
                    MetricStat(label: "Awake", value: formatTimeInterval(analysis.awakeDuration)),
                    MetricStat(label: "In Bed", value: analysis.formattedDuration)
                ],
                explanation: efficiencyInterpretation,
                actionItem: analysis.efficiency >= 0.85 ? "Your routine is working—keep bedtime and wake time consistent." : "Wind down screen-free before bed and keep your room cool and dark to cut awakenings."
            )

        case .respiratoryRate:
            if let rr = analysis.respiratoryRate, let baseline = analysis.respiratoryBaseline, baseline > 0 {
                let deviationPct = (rr - baseline) / baseline * 100
                let isStable = deviationPct <= 5
                MetricDetailSheet(
                    title: "Respiratory Rate",
                    icon: "lungs.fill",
                    tint: .cyan,
                    value: String(format: "%.1f br/min", rr),
                    statusLabel: isStable ? "Steady overnight" : "Elevated",
                    isPositive: isStable,
                    series: sleepRRSeries,
                    baseline: baseline,
                    valueFormat: { String(format: "%.1f", $0) },
                    rangeLabel: "Recent nights",
                    stats: [
                        MetricStat(label: "Overnight", value: String(format: "%.1f", rr)),
                        MetricStat(label: "Baseline", value: String(format: "%.1f", baseline)),
                        MetricStat(label: "Stability", value: "\(Int(analysis.respiratoryStability.map { $0 * 100 } ?? 100))%", valueColor: isStable ? .green : .orange)
                    ],
                    explanation: isStable
                        ? "Your breathing rate stayed steady through the night, a marker of restful, recovered sleep."
                        : "Your breathing rate ran \(abs(Int(deviationPct)))% above your baseline overnight. Elevated sleeping respiratory rate can accompany poor recovery, strain, alcohol, or early illness.",
                    actionItem: isStable
                        ? "Breathing is steady—keep your recovery routine consistent."
                        : "Prioritize rest and hydration, and monitor for illness or overtraining."
                )
            } else {
                MetricDetailSheet(
                    title: "Respiratory Rate",
                    icon: "lungs.fill",
                    tint: .cyan,
                    value: "—",
                    statusLabel: "No data",
                    isPositive: true,
                    series: [],
                    explanation: "Respiratory rate data unavailable.",
                    actionItem: "Wear your watch overnight to capture breathing rate."
                )
            }

        case .wristTemp:
            if let dev = analysis.wristTempDeviation {
                let isStable = abs(dev) <= 0.3
                MetricDetailSheet(
                    title: "Wrist Temperature",
                    icon: "thermometer.medium",
                    tint: .orange,
                    value: String(format: "%+.1f°C", dev),
                    statusLabel: isStable ? "Near baseline" : "Deviating",
                    isPositive: isStable,
                    series: sleepWristTempSeries,
                    baseline: analysis.wristTempBaseline,
                    valueFormat: { String(format: "%.1f", $0) },
                    rangeLabel: "Last 21 days",
                    stats: [
                        MetricStat(label: "Overnight", value: analysis.wristTempOvernight.map { String(format: "%.1f°C", $0) } ?? String(format: "%+.1f°C", dev)),
                        MetricStat(label: "Baseline", value: analysis.wristTempBaseline.map { String(format: "%.1f°C", $0) } ?? "—"),
                        MetricStat(label: "Stability", value: "\(Int(analysis.temperatureStability.map { $0 * 100 } ?? 100))%", valueColor: isStable ? .green : .orange)
                    ],
                    explanation: isStable
                        ? "Your wrist temperature held close to baseline overnight, a sign your body was well-regulated and recovering normally."
                        : String(format: "Your wrist temperature deviated %+.1f°C from baseline overnight. Notable shifts can accompany strain, illness, alcohol, or incomplete recovery.", dev),
                    actionItem: isStable
                        ? "Temperature is stable—maintain your routine."
                        : "Monitor for illness, prioritize rest, and keep training light until it normalizes."
                )
            } else {
                MetricDetailSheet(
                    title: "Wrist Temperature",
                    icon: "thermometer.medium",
                    tint: .orange,
                    value: "—",
                    statusLabel: "No data",
                    isPositive: true,
                    series: [],
                    explanation: "Wrist temperature data unavailable.",
                    actionItem: "Wear your watch overnight to capture temperature."
                )
            }

        case .timing:
            MetricDetailSheet(
                title: "Sleep Timing",
                icon: "clock.fill",
                tint: .indigo,
                value: bedtimeFormatted,
                statusLabel: "Last night",
                isPositive: true,
                series: sleepBedtimeSeries,
                rangeLabel: "Consistency trend",
                stats: [
                    MetricStat(label: "Bedtime", value: bedtimeFormatted),
                    MetricStat(label: "Wake Time", value: wakeTimeFormatted),
                    MetricStat(label: "In Bed", value: analysis.formattedDuration)
                ],
                explanation: "Having a consistent sleep schedule that meets your needs can often improve sleep quality and how rested you feel. Consistency matters more than duration.",
                actionItem: "Anchor your wake time first—the same alarm every day makes a consistent bedtime follow naturally."
            )

        case .qualityTrend:
            MetricDetailSheet(
                title: "Quality Trend",
                icon: "chart.line.uptrend.xyaxis",
                tint: .indigo,
                value: "\(Int(analysis.quality * 100))",
                statusLabel: analysis.qualityLevel.label,
                isPositive: analysis.quality >= 0.65,
                series: qualitySeries,
                rangeLabel: "Recent nights",
                explanation: interpretationText,
                actionItem: sleepPriorities.first ?? "Keep your sleep habits consistent to maintain this quality."
            )
        }
    }

    // MARK: - Quality Trend

    private var sleepConnections: [ConnectionInsight] {
        CrossEngineInsight.forSleep(sleep: analysis, recovery: service.recoveryScore, stress: service.stressScore)
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        VStack(alignment: .leading) {
            Text("Resources")
                .font(.title3).bold()

            VStack(spacing: 10) {
                ResourceRow(
                    title: "Healthy Sleep Habits",
                    source: "Sleep Foundation",
                    icon: "book.fill",
                    color: .indigo
                ) {
                    safariURL = URL(string: "https://www.sleepfoundation.org/sleep-hygiene")!
                    showingSafari = true
                }

                ResourceRow(
                    title: "Sleep & Athletic Recovery",
                    source: "NCBI / PMC",
                    icon: "heart.fill",
                    color: .pink
                ) {
                    safariURL = URL(string: "https://pmc.ncbi.nlm.nih.gov/articles/PMC6988893/")!
                    showingSafari = true
                }
            }
        }
    }

    // MARK: - Advisor Topics

    private func topicForSleepMetric(title: String, value: String, icon: String, tintName: String, series: [MetricTrendPoint]) -> AdvisorTopic {
        var context = ["\(title): \(value)"]
        let avgValue = series.count >= 7
            ? series.suffix(7).map(\.value).reduce(0, +) / Double(min(7, series.count))
            : nil
        if let avg = avgValue {
            context.append("7-day avg: \(String(format: "%.0f", avg))")
        }
        if !series.isEmpty, let latest = series.last?.value, let oldest = series.first?.value {
            let direction = latest > oldest ? "increasing" : latest < oldest ? "decreasing" : "stable"
            context.append("Trend: \(direction)")
        }
        return AdvisorTopic(
            title: title,
            icon: icon,
            tintName: tintName,
            contextLines: context,
            suggestedPrompt: "Tell me more about my \(title.lowercased()) and how it affects my sleep quality."
        )
    }

    // MARK: - Computed Properties

    private var sleepStages: [SleepStage] {
        [
            SleepStage(
                name: "Deep Sleep",
                icon: "moon.stars.fill",
                color: Color(red: 0.6, green: 0.4, blue: 1),
                duration: analysis.deepDuration,
                totalDuration: analysis.totalDuration,
                explanation: "Deep sleep is when your body recovers physically and your brain consolidates memories. This is when growth hormone peaks.",
                targetRange: (0.15, 0.25)
            ),
            SleepStage(
                name: "Core Sleep",
                icon: "bed.double.fill",
                color: Color(red: 0.2, green: 0.6, blue: 1),
                duration: analysis.coreDuration,
                totalDuration: analysis.totalDuration,
                explanation: "Core sleep is light to moderate sleep where your body temperature drops and your brain processes emotions and information.",
                targetRange: (0.45, 0.55)
            ),
            SleepStage(
                name: "REM Sleep",
                icon: "sparkles",
                color: .cyan,
                duration: analysis.remDuration,
                totalDuration: analysis.totalDuration,
                explanation: "REM is when most vivid dreams occur and your brain consolidates emotional and procedural memories.",
                targetRange: (0.20, 0.25)
            ),
            SleepStage(
                name: "Awake",
                icon: "eye.fill",
                color: .red,
                duration: analysis.awakeDuration,
                totalDuration: analysis.totalDuration,
                explanation: "Awake periods are normal, especially in the first and last sleep cycles. High awake time may indicate sleep fragmentation.",
                targetRange: (0, 0.05)
            )
        ]
    }

    private var interpretationText: String {
        let hours = analysis.asleepDuration / 3600
        if hours < 6 {
            return "You got \(Int(hours)) hours of sleep. This is below the recommended 7-9 hours, so prioritize recovery tonight."
        } else if hours < 7 {
            return "You got \(Int(hours)) hours. A bit short of optimal—aim for 7-9 hours to fully restore your physical and mental reserves."
        } else if hours <= 9 {
            return "Your sleep duration is in the healthy range. Your body got solid recovery time last night."
        } else {
            return "You got over 9 hours of sleep. While recovery is important, consistently oversleeping may affect daytime energy."
        }
    }

    private var sleepPriorities: [String] {
        var items: [String] = []

        let hours = analysis.asleepDuration / 3600
        if hours < 7 {
            items.append("Sleep longer—aim for 7+ hours tonight")
        }

        if analysis.efficiency < 0.85 {
            items.append("Reduce nighttime awakenings—create a calm sleep environment")
        }

        let deepPct = analysis.deepDuration / analysis.totalDuration
        if deepPct < 0.15 {
            items.append("Increase deep sleep—exercise earlier in the day and cool your bedroom")
        }

        let remPct = analysis.remDuration / analysis.totalDuration
        if remPct < 0.20 {
            items.append("Support REM sleep—avoid alcohol before bed to improve dream sleep")
        }

        if items.isEmpty {
            items = [
                "Keep your sleep habits consistent to maintain this quality",
                "Prioritize the same bedtime and wake time every day"
            ]
        }

        return Array(items.prefix(4))
    }

    private var efficiencyInterpretation: String {
        let efficiency = analysis.efficiency
        if efficiency >= 0.90 {
            return "Excellent—your sleep is highly consolidated with minimal interruptions."
        } else if efficiency >= 0.85 {
            return "Good—your sleep efficiency is solid. Minor optimizations could help."
        } else {
            return "Needs improvement—too many awakenings are fragmenting your sleep."
        }
    }

    private var bedtimeFormatted: String {
        analysis.bedtime.formatted(date: .omitted, time: .shortened)
    }

    private var wakeTimeFormatted: String {
        analysis.wakeTime.formatted(date: .omitted, time: .shortened)
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }

    private func infoChip(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 2) {
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.callout.weight(.semibold))
                .foregroundStyle(color)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
        .padding(.horizontal, 10)
        .background(color.opacity(0.1))
        .cornerRadius(8)
    }

    private func priorityColor(for item: String) -> Color {
        if item.contains("long") || item.contains("consistent") {
            return .green
        }
        return .orange
    }

    private func stageChartLegend(color: Color, label: String) -> some View {
        HStack(spacing: 4) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 12, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

private enum SleepMetricDetail: String, Identifiable {
    case efficiency, respiratoryRate, wristTemp, timing, qualityTrend
    var id: String { rawValue }
}

// MARK: - Sleep Timeline Chart

private struct SleepTimelineChart: View {
    let analysis: SleepAnalysis

    private func stageColor(_ stage: Int) -> Color {
        switch stage {
        case 0: .red.opacity(0.7)
        case 1: .cyan
        case 2: Color(red: 0.2, green: 0.6, blue: 1)
        case 3: Color(red: 0.6, green: 0.4, blue: 1)
        default: .gray
        }
    }

    var body: some View {
        let bedtime = analysis.bedtime
        let hours = analysis.totalDuration / 3600
        let strideCount = hours > 8 ? 2 : 1

        Chart {
            ForEach(analysis.segments) { segment in
                BarMark(
                    xStart: .value("Start", segment.start),
                    xEnd: .value("End", segment.end),
                    y: .value("Stage", stageLabel(segment.stage))
                )
                .foregroundStyle(stageColor(segment.stage))
            }
        }
        .chartXScale(domain: bedtime...analysis.wakeTime)
        .chartYScale(domain: ["Awake", "REM", "Core", "Deep"])
        .chartYAxis(.hidden )
        .chartXAxis {
            AxisMarks(values: .stride(by: .hour, count: strideCount)) { value in
                if let date = value.as(Date.self), date >= bedtime, date <= analysis.wakeTime {
                    AxisValueLabel {
                        Text(date.formatted(.dateTime.hour(.defaultDigits(amPM: .abbreviated))))
                            .font(.system(size: 9))
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
    }

    private func stageLabel(_ stage: Int) -> String {
        switch stage {
        case 0: "Awake"
        case 1: "REM"
        case 2: "Core"
        case 3: "Deep"
        default: "Core"
        }
    }
}

// MARK: - Sleep Need & Debt Chart

/// Overlays a rolling sleep-debt trend on the personalized sleep-need line
/// (need rises with exertion), reconstructed from persisted nightly sleep and
/// per-day exertion history so it mirrors the engine's own figures.
private struct SleepNeedDebtChart: View {
    let targetHours: Double

    private struct Point: Identifiable {
        let id = UUID()
        let date: Date
        let need: Double
        let debt: Double
    }

    private var points: [Point] {
        let nights = SleepDebtStore.recentNights(days: 14).sorted { $0.date < $1.date }
        guard !nights.isEmpty else { return [] }
        return nights.map { night in
            // Need = base target + an exertion strain bump (matches the engine).
            let exertion = Double(ScoreHistoryStore.score(for: .exertion, on: night.date) ?? 0)
            let strainBump = min(0.75, exertion / 100.0 * 0.75)
            let need = targetHours + strainBump

            // Debt = recency-weighted average shortfall vs the base target, as of this night.
            let window = nights.filter { $0.date <= night.date }
                .sorted { $0.date > $1.date }
                .prefix(14)
            var weightedShortfall = 0.0
            var weightTotal = 0.0
            for (i, n) in window.enumerated() {
                let w = pow(0.85, Double(i))
                weightedShortfall += max(0, targetHours - n.asleepHours) * w
                weightTotal += w
            }
            let debt = weightTotal > 0 ? weightedShortfall / weightTotal : 0
            return Point(date: night.date, need: need, debt: debt)
        }
    }

    /// Debt is drawn hanging directly beneath the need line rather than
    /// building up from zero on its own scale — its "0h" mark sits right on
    /// the need line, and the band's depth below it reads as the shortfall.
    private var needDomainMax: Double {
        let maxNeed = points.map(\.need).max() ?? targetHours
        return maxNeed * 1.15
    }

    private var needDomainMin: Double {
        let minFloor = points.map { $0.need - $0.debt }.min() ?? 0
        return max(0, min(minFloor * 0.9, needDomainMax * 0.7))
    }

    private func axisLabel(_ hours: Double) -> String {
        hours.rounded() == hours ? "\(Int(hours))h" : String(format: "%.1fh", hours)
    }

    var body: some View {
        let data = points
        if data.count < 2 {
            Text("Keep logging sleep to see your debt trend.")
                .font(.caption)
                .foregroundStyle(.secondary)
                .frame(maxWidth: .infinity, minHeight: 120, alignment: .center)
        } else {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 14) {
                    legendItem(color: .indigo, label: "Sleep need")
                    legendItem(color: .orange, label: "Sleep debt")
                }
                Chart {
                    ForEach(data) { p in
                        AreaMark(
                            x: .value("Day", p.date),
                            yStart: .value("NeedLessDebt", p.need - p.debt),
                            yEnd: .value("Need", p.need)
                        )
                        .foregroundStyle(
                            .linearGradient(
                                colors: [.orange.opacity(0.32), .orange.opacity(0.04)],
                                startPoint: .top, endPoint: .bottom
                            )
                        )
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(data) { p in
                        LineMark(
                            x: .value("Day", p.date),
                            y: .value("Value", p.need - p.debt),
                            series: .value("Series", "Debt")
                        )
                        .foregroundStyle(.orange)
                        .interpolationMethod(.catmullRom)
                    }
                    ForEach(data) { p in
                        LineMark(
                            x: .value("Day", p.date),
                            y: .value("Value", p.need),
                            series: .value("Series", "Need")
                        )
                        .foregroundStyle(.indigo)
                        .interpolationMethod(.catmullRom)
                        .lineStyle(StrokeStyle(lineWidth: 2, dash: [4, 3]))
                    }
                }
                .chartYScale(domain: needDomainMin...needDomainMax)
                .chartYAxis {
                    AxisMarks(position: .leading) { value in
                        AxisGridLine()
                        AxisValueLabel {
                            if let h = value.as(Double.self) {
                                Text(axisLabel(h))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .chartXAxis {
                    AxisMarks(values: .stride(by: .day, count: 3)) { value in
                        AxisValueLabel {
                            if let date = value.as(Date.self) {
                                Text(date.formatted(.dateTime.month(.abbreviated).day()))
                                    .font(.system(size: 9))
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
                .frame(height: 150)
            }
        }
    }

    private func legendItem(color: Color, label: String) -> some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 1)
                .fill(color)
                .frame(width: 12, height: 3)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }
}

// MARK: - Sleep Stage Row

private struct SleepStageRow: View {
    let stage: SleepStage
    let isSelected: Bool

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            HStack(spacing: 12) {
                ZStack {
                    Circle()
                        .fill(stage.color.opacity(0.15))
                        .frame(width: 36, height: 36)
                    Image(systemName: stage.icon)
                        .font(.body.weight(.medium))
                        .foregroundStyle(stage.color)
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(stage.name)
                        .font(.subheadline.weight(.medium))
                }

                Spacer()

                HStack(spacing: 6) {
                    Text(formatTimeInterval(stage.duration))
                        .font(.subheadline.weight(.medium))
                        .monospacedDigit()
                    Image(systemName: isSelected ? "chevron.down" : "chevron.left")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 12)

            if isSelected {
                VStack(alignment: .leading, spacing: 8) {
                    Text(stage.explanation)
                        .font(.caption)
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Image(systemName: stage.targetStatusIcon)
                            .font(.caption2)
                        Text(stage.targetStatusText)
                            .font(.caption.weight(.medium))
                    }
                    .foregroundStyle(stage.targetStatusColor)
                }
                .padding(.horizontal, 16)
                .padding(.bottom, 14)
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
    }

    private func formatTimeInterval(_ interval: TimeInterval) -> String {
        let hours = Int(interval) / 3600
        let minutes = (Int(interval) % 3600) / 60
        if hours > 0 {
            return "\(hours)h \(minutes)m"
        } else {
            return "\(minutes)m"
        }
    }
}

// MARK: - Sleep Stage Model

private struct SleepStage: Identifiable {
    var id: String { name }
    let name: String
    let icon: String
    let color: Color
    let duration: TimeInterval
    let totalDuration: TimeInterval
    let explanation: String
    let targetRange: (Double, Double)

    var percentage: Double {
        guard totalDuration > 0 else { return 0 }
        return duration / totalDuration
    }

    var isOnTarget: Bool {
        percentage >= targetRange.0 && percentage <= targetRange.1
    }

    var targetStatusText: String {
        let pct = Int(percentage * 100)
        if isOnTarget {
            return "On target (\(pct)% — target \(Int(targetRange.0 * 100))–\(Int(targetRange.1 * 100))%)"
        } else if percentage < targetRange.0 {
            let diff = Int((targetRange.0 - percentage) * 100)
            return "\(diff)% below target (\(pct)% — target \(Int(targetRange.0 * 100))–\(Int(targetRange.1 * 100))%)"
        } else {
            let diff = Int((percentage - targetRange.1) * 100)
            return "\(diff)% above target (\(pct)% — target \(Int(targetRange.0 * 100))–\(Int(targetRange.1 * 100))%)"
        }
    }

    var targetStatusIcon: String {
        if isOnTarget {
            return "checkmark.circle.fill"
        } else if percentage < targetRange.0 {
            return "arrow.down.circle.fill"
        } else {
            return "arrow.up.circle.fill"
        }
    }

    var targetStatusColor: Color {
        isOnTarget ? .green : .orange
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

#if DEBUG
#Preview {
    NavigationStack {
        SleepDetailView(analysis: .mock)
    }
    .environment(HealthKitService.preview)
}
#endif
