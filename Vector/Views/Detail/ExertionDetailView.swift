import SwiftUI
import SafariServices
import Charts
import HealthKit

struct ExertionDetailView: View {
    let score: ExertionScore

    @Environment(HealthKitService.self) private var service
    @State private var animatedProgress: Double = 0
    @State private var animatedOverflow: Double = 0
    @State private var strainSeries: [MetricTrendPoint] = []
    @State private var caloriesSeries: [MetricTrendPoint] = []
    @State private var stepsSeries: [MetricTrendPoint] = []
    @State private var exerciseMinutesSeries: [MetricTrendPoint] = []
    @State private var selectedExertionFactor: ExertionFactor? = nil
    @State private var showingSafari = false
    @State private var safariURL: URL = URL(string: "https://www.nsca.com")!
    @State private var showingHelp = false
    @State private var showingEffortInfo = false

    var body: some View {
        ScrollView {
            VStack(spacing: 30) {
                headerSection
                trainingLoadInsight
                loadRatioGaugeSection
                exertionFactorsSection
                resourcesSection

                Text("Exertion is measured on a scale of 100")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 32)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        .background(alignment: .top) {
            LinearGradient(
                colors: [Color.orange.opacity(0.45), Color.red.opacity(0.2), .clear],
                startPoint: .top,
                endPoint: .bottom
            )
            .frame(height: 380)
            .ignoresSafeArea(edges: .top)
        }
        .toolbarBackground(.hidden, for: .navigationBar)
        .navigationTitle("Exertion")
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
            CardInfoSheet(cardID: "exertion")
        }
        .sheet(isPresented: $showingEffortInfo) {
            PhysicalEffortInfoSheet()
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
        }
        .sheet(item: $selectedExertionFactor) { factor in
            MetricDetailSheet(
                title: factor.name,
                icon: factor.icon,
                tint: .orange,
                value: factor.value,
                statusLabel: factor.statusLabel,
                isPositive: factor.isPositive,
                series: factor.series,
                baseline: factor.baseline,
                valueFormat: factor.valueFormat,
                unit: factor.unit,
                contribution: factor.contribution,
                contributionCaption: "Impact on exertion score",
                explanation: factor.explanation,
                actionItem: factor.actionItem
            )
        }
        .onAppear {
            withAnimation(.spring(response: 0.8, dampingFraction: 0.7).delay(0.1)) {
                let total = Double(score.score)
                let isOver = total > 100
                animatedProgress = isOver ? 1 : total / 100
                animatedOverflow = isOver ? (total - 100) / total : 0
            }
            strainSeries = ScoreHistoryStore.series(for: .exertion).map { MetricTrendPoint(date: $0.date, value: Double($0.score)) }
        }
        .task {
            async let calories = service.dailySumSeries(for: .activeEnergyBurned, unit: .kilocalorie(), days: 14)
            async let steps = service.dailySumSeries(for: .stepCount, unit: .count(), days: 14)
            async let exercise = service.dailySumSeries(for: .appleExerciseTime, unit: .minute(), days: 14)
            let (cal, stp, ex) = await (calories, steps, exercise)
            caloriesSeries = cal.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            stepsSeries = stp.map { MetricTrendPoint(date: $0.date, value: $0.value) }
            exerciseMinutesSeries = ex.map { MetricTrendPoint(date: $0.date, value: $0.value) }
        }
    }

    // MARK: - Header

    private var headerSection: some View {
        let isOver = Double(score.score) > 100
        return VStack(spacing: 12) {
            TickRing(
                progress: animatedProgress,
                colors: [.orange, .red],
                overflow: isOver ? animatedOverflow : 0,
                highlightRange: AppModeStore.shared.currentMode.deemphasizesExertion ? nil : score.optimalTargetRange.map { range in
                    let lower = min(max(range.lowerBound / 100, 0), 1)
                    let upper = min(max(range.upperBound / 100, 0), 1)
                    return lower...max(lower, upper)
                },
                size: 210
            ) {
                VStack(spacing: 2) {
                    Text("\(score.score)")
                        .font(.system(size: 52, weight: .heavy, design: .rounded))
                        .monospacedDigit()
                    HStack(spacing: 3) {
                        Image(systemName: exertionAverageIndicator.icon)
                            .font(.system(size: 8, weight: .bold))
                        Text(exertionAverageIndicator.label)
                            .font(.system(size: 9, weight: .medium))
                    }
                    .foregroundStyle(exertionAverageIndicator.color)
                }
            }

            if let c = score.confidence {
                ConfidenceChip(confidence: c, fullDays: 28)
                    .padding(.top, 8)
            }

        }
        .frame(maxWidth: .infinity)
        .padding(.top, 20)
    }

    private func topicForLoadRatio() -> AdvisorTopic {
        var context = [String(format: "Load ratio: %.2f", score.loadRatio)]
        context.append(String(format: "Acute (7-day): %.0f kcal", score.acuteLoad))
        context.append(String(format: "Chronic (28-day): %.0f kcal", score.chronicLoad))
        context.append("Status: \(score.loadStatus)")
        return AdvisorTopic(
            title: "Load Ratio",
            icon: "chart.xyaxis.line",
            tintName: "orange",
            contextLines: context,
            suggestedPrompt: "What does my acute-to-chronic load ratio mean for my training?"
        )
    }

    private var exertionAverageIndicator: (icon: String, label: String, color: Color) {
        let avg = ScoreHistoryStore.average(for: .exertion) ?? 50
        let diff = score.score - avg
        if abs(diff) <= 5 {
            return ("equal", "Average", .secondary)
        } else if diff > 0 {
            return ("arrow.up.right", "Above Avg", .orange)
        } else {
            return ("arrow.down.right", "Below Avg", .blue)
        }
    }

    private var exertionConnections: [ConnectionInsight] {
        CrossEngineInsight.forExertion(exertion: score, recovery: service.recoveryScore, stress: service.stressScore)
    }

    // MARK: - Training Load Insight

    private var trainingLoadInsight: some View {
        let mode = AppModeStore.shared.currentMode
        let cardContent = VStack(alignment: .leading, spacing: 12) {
            Text(loadInterpretation)
                .font(.subheadline)
                .foregroundStyle(.primary)

            VStack(spacing: 8) {
                HStack(spacing: 12) {
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("Weekly Load")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(score.acuteLoad)) kcals")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("Chronic Load")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text("\(Int(score.chronicLoad)) kcals")
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                    VStack(alignment: .center, spacing: 2) {
                        Text("Today")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(score.todayStrainLevel)
                            .font(.subheadline.weight(.semibold))
                    }
                    Spacer()
                }
            }
            .padding(.vertical, 12)

            if !exertionConnections.isEmpty {
                Divider()
                ConnectionsBlock(insights: exertionConnections)
            }
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))

        if let statusMessage = mode.statusMessage {
            return AnyView(
                ZStack {
                    cardContent
                        .blur(radius: 8)

                    VStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.title2)
                            .foregroundStyle(mode.color)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity)
            )
        } else {
            return AnyView(cardContent)
        }
    }

    // MARK: - Load Ratio Gauge

    private var loadRatioGaugeSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Load Ratio")
                .font(.title3).bold()

            VStack(spacing: 16) {
                HStack(spacing: 0) {
                    Text(String(format: "%.2f", score.loadRatio))
                        .font(.system(size: 32, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text(" A:C")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                }

                GeometryReader { geo in
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(
                                LinearGradient(
                                    colors: [.blue, .green, .orange, .red],
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                            )
                            .frame(height: 8)

                        Circle()
                            .fill(.white)
                            .frame(width: 14, height: 14)
                            .shadow(radius: 2)
                            .offset(x: calculateGaugePosition(geo.size.width) - 7)
                    }
                }
                .frame(height: 14)

                HStack(spacing: 0) {
                    Text("Detraining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Optimal")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("Overtraining")
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(ratioExplanation)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(3)
            }
            .padding(16)
            .glassEffect(in: .rect(cornerRadius: 20))
        }
        .askVector(topicForLoadRatio())
    }

    // MARK: - Exertion Factors

    private var exertionFactorsSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Exertion Factors")
                .font(.title3).bold()

            LazyVGrid(columns: [GridItem(.flexible(), spacing: 14), GridItem(.flexible(), spacing: 14)], spacing: 14) {
                ForEach(exertionFactors) { factor in
                    Button { selectedExertionFactor = factor } label: {
                        MetricStatusCard(
                            title: factor.name,
                            status: factor.value,
                            statusColor: factor.isPositive ? .green : .orange,
                            icon: factor.icon,
                            color: .orange,
                            series: factor.series.map(\.value)
                        )
                    }
                    .buttonStyle(.plain)
                    .askVector(topicForExertionFactor(factor))
                }
            }
        }
    }

    private var exertionFactors: [ExertionFactor] {
        var factors: [ExertionFactor] = []

        if !strainSeries.isEmpty {
            factors.append(ExertionFactor(
                name: "Exertion Trend",
                icon: "chart.line.uptrend.xyaxis",
                value: "\(score.score)",
                contribution: 0.5,
                isPositive: exertionAverageIndicator.color != .orange,
                explanation: "Your exertion trend reflects how your daily training strain is tracking over the past two weeks relative to your average.",
                actionItem: "Review your Load Ratio below for detraining/overtraining risk.",
                series: strainSeries,
                baseline: nil,
                statusLabel: exertionAverageIndicator.label,
                valueFormat: { String(Int($0)) },
                unit: ""
            ))
        }

        if let mets = service.todayPhysicalEffort, !service.physicalEffortSeries.isEmpty {
            factors.append(ExertionFactor(
                name: "Physical Effort",
                icon: "bolt.fill",
                value: String(format: "%.1f METs", mets),
                contribution: 0.5,
                isPositive: true,
                explanation: "METs (Metabolic Equivalent of Task) estimate how much energy your body uses versus sitting at rest — this captures strength-training strain that heart rate alone under-counts.",
                actionItem: "Rising effort with stable recovery is a good sign your fitness is improving.",
                series: service.physicalEffortSeries.map { MetricTrendPoint(date: $0.date, value: $0.value) },
                baseline: nil,
                statusLabel: "Measured by Apple Watch",
                valueFormat: { String(format: "%.1f", $0) },
                unit: "METs"
            ))
        }

        if !caloriesSeries.isEmpty {
            factors.append(ExertionFactor(
                name: "Active Calories",
                icon: "flame.fill",
                value: "\(Int(service.todayActiveCalories)) kcal",
                contribution: 0.5,
                isPositive: true,
                explanation: "Active calories reflect energy burned above your resting baseline today, driven by movement and workouts.",
                actionItem: "Consistent daily activity supports steady training adaptation.",
                series: caloriesSeries,
                baseline: nil,
                statusLabel: "Burned today",
                valueFormat: { String(Int($0)) },
                unit: "kcal"
            ))
        }

        if !stepsSeries.isEmpty {
            factors.append(ExertionFactor(
                name: "Steps",
                icon: "figure.walk",
                value: "\(Int(service.todaySteps))",
                contribution: 0.5,
                isPositive: true,
                explanation: "Step count captures overall daily movement, a component of non-exercise activity that contributes to total strain.",
                actionItem: "Aim for consistent daily movement alongside structured training.",
                series: stepsSeries,
                baseline: nil,
                statusLabel: "Steps today",
                valueFormat: { String(Int($0)) },
                unit: "steps"
            ))
        }

        if !exerciseMinutesSeries.isEmpty {
            factors.append(ExertionFactor(
                name: "Exercise Minutes",
                icon: "stopwatch.fill",
                value: "\(Int(exerciseMinutesSeries.last?.value ?? 0)) min",
                contribution: 0.5,
                isPositive: true,
                explanation: "Apple's Exercise minutes count time spent at a brisk pace or higher, a proxy for meaningful training volume.",
                actionItem: "Balance exercise minutes with adequate recovery days.",
                series: exerciseMinutesSeries,
                baseline: nil,
                statusLabel: "Minutes today",
                valueFormat: { String(Int($0)) },
                unit: "min"
            ))
        }

        return factors
    }

    private func topicForExertionFactor(_ factor: ExertionFactor) -> AdvisorTopic {
        var context = ["\(factor.name): \(factor.value)"]
        if factor.series.count >= 7 {
            let avg = factor.series.suffix(7).map(\.value).reduce(0, +) / Double(min(7, factor.series.count))
            context.append("7-day avg: \(String(format: "%.0f", avg))")
        }
        context.append(factor.statusLabel)
        return AdvisorTopic(
            title: factor.name,
            icon: factor.icon,
            tintName: "orange",
            contextLines: context,
            suggestedPrompt: "What does my \(factor.name.lowercased()) mean for my training?"
        )
    }

    // MARK: - Resources

    private var resourcesSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Resources")
                .font(.title3).bold()

            VStack(spacing: 10) {
                ResourceRow(
                    title: "Periodization & Load Management",
                    source: "NSCA",
                    icon: "chart.line.uptrend.xyaxis",
                    color: .orange
                ) {
                    safariURL = URL(string: "https://www.nsca.com/education/articles/kinetic-select/the-concept-of-periodization/")!
                    showingSafari = true
                }

                ResourceRow(
                    title: "Signs of Overtraining",
                    source: "Hospital for Special Surgery",
                    icon: "exclamationmark.triangle.fill",
                    color: .red
                ) {
                    safariURL = URL(string: "https://www.hss.edu/article_overtraining.asp")!
                    showingSafari = true
                }
            }
        }
    }

    // MARK: - Helpers

    private func calculateGaugePosition(_ width: CGFloat) -> CGFloat {
        let clamped = min(max(score.loadRatio, 0.4), 2.0)
        let normalized = (clamped - 0.4) / (2.0 - 0.4)
        return width * normalized
    }

    private var loadInterpretation: String {
        switch score.loadStatus {
        case .detraining:
            return "Your acute load is low relative to your chronic baseline. This presents an opportunity to gradually increase training intensity to rebuild fitness."
        case .optimal:
            return "Your training load is perfectly balanced. You're building fitness while maintaining recovery capacity."
        case .overreaching:
            return "Your acute load is elevated but manageable. Monitor recovery closely and ensure adequate sleep and nutrition."
        case .overtraining:
            return "Your acute load is significantly high. Your body needs structured recovery to prevent performance decline and injury."
        }
    }

    private var ratioExplanation: String {
        "The A:C ratio compares your 7-day load to your 28-day average. Lower ratios suggest detraining; optimal is 0.8–1.3; higher indicates overtraining risk."
    }
}

// MARK: - Exertion Factor

private struct ExertionFactor: Identifiable {
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

// MARK: - Physical Effort Info Sheet

private struct PhysicalEffortInfoSheet: View {
    var body: some View {
        VStack(spacing: 0) {
            ScrollView {
                VStack(alignment: .leading, spacing: 24) {
                    VStack(alignment: .center, spacing: 12) {
                        ZStack {
                            Circle()
                                .fill(
                                    LinearGradient(
                                        colors: [.orange.opacity(0.9), .orange.opacity(0.6)],
                                        startPoint: .topLeading,
                                        endPoint: .bottomTrailing
                                    )
                                )
                                .frame(width: 64, height: 64)

                            Image(systemName: "bolt.fill")
                                .font(.system(size: 28, weight: .bold))
                                .foregroundStyle(.white)
                        }
                        .frame(maxWidth: .infinity)

                        Text("Physical Effort")
                            .font(.title2).bold()
                            .foregroundStyle(.primary)

                        Text("Measured in METs by Apple Watch")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    VStack(alignment: .leading, spacing: 16) {
                        InfoRow(
                            icon: "figure.run",
                            title: "What it measures",
                            caption: "METs (Metabolic Equivalent of Task) estimate how much energy your body uses versus sitting at rest. 1 MET = resting; walking ≈ 3; running ≈ 8+."
                        )

                        InfoRow(
                            icon: "gauge.with.needle",
                            title: "How Vector uses it",
                            caption: "Effort feeds your Exertion score alongside heart rate. It captures strength training strain that heart rate alone under-counts."
                        )

                        InfoRow(
                            icon: "applewatch",
                            title: "Automatic",
                            caption: "Apple Watch records physical effort continuously during the day and workouts — no logging needed."
                        )

                        InfoRow(
                            icon: "chart.line.uptrend.xyaxis",
                            title: "Reading the chart",
                            caption: "The trend shows your daily average effort over three weeks. Rising effort with stable recovery means your fitness is improving."
                        )
                    }
                }
                .padding(24)
            }
        }
    }
}

private struct InfoRow: View {
    let icon: String
    let title: String
    let caption: String

    var body: some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(.orange)
                .frame(width: 32, alignment: .center)

            VStack(alignment: .leading, spacing: 4) {
                Text(title)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

                Text(caption)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(5)
            }

            Spacer()
        }
    }
}

// MARK: - Safari View

private struct SafariView: UIViewControllerRepresentable {
    let url: URL

    func makeUIViewController(context: Context) -> SFSafariViewController {
        let config = SFSafariViewController.Configuration()
        config.entersReaderIfAvailable = true
        let vc = SFSafariViewController(url: url, configuration: config)
        vc.preferredControlTintColor = .systemOrange
        return vc
    }

    func updateUIViewController(_ uiViewController: SFSafariViewController, context: Context) {}
}

#Preview {
    NavigationStack {
        ExertionDetailView(score: .mock)
    }
    .environment(HealthKitService.preview)
}
