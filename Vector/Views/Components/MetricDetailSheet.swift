import SwiftUI
import Charts
import FoundationModels

struct MetricStat: Identifiable {
    var id: String { label }
    let label: String
    let value: String
    var valueColor: Color? = nil
}

/// Rich, non-fullscreen detail sheet shown when a metric card is tapped in a
/// score detail view: hero value, trend chart, key stats, score impact, and guidance.
struct MetricDetailSheet: View {
    let title: String
    let icon: String
    let tint: Color
    let value: String
    let statusLabel: String
    let isPositive: Bool
    var series: [MetricTrendPoint] = []
    var baseline: Double? = nil
    var valueFormat: (Double) -> String = { String(Int($0)) }
    var unit: String = ""
    var rangeLabel: String = "Last 14 days"
    var stats: [MetricStat] = []
    var contribution: Double? = nil
    var contributionCaption: String = "Impact on today's score"
    let explanation: String
    let actionItem: String

    @Environment(\.dismiss) private var dismiss
    @Environment(AdvisorPresenter.self) private var advisorPresenter: AdvisorPresenter?
    @State private var aiExplanation: String?
    @State private var isGeneratingExplanation = false

    private var statusColor: Color { isPositive ? .green : .orange }

    private var trendDelta: (icon: String, text: String)? {
        guard series.count >= 4, let last = series.last?.value else { return nil }
        let prior = series.dropLast().suffix(7).map(\.value)
        guard !prior.isEmpty else { return nil }
        let avg = prior.reduce(0, +) / Double(prior.count)
        guard avg != 0 else { return nil }
        let pct = (last - avg) / abs(avg) * 100
        if abs(pct) < 1 { return ("equal", "steady vs recent days") }
        return (pct > 0 ? "arrow.up.right" : "arrow.down.right",
                String(format: "%+.0f%% vs recent days", pct))
    }

    private var resolvedStats: [MetricStat] {
        if !stats.isEmpty { return stats }
        let values = series.map(\.value)
        guard values.count >= 2, let last = values.last,
              let lo = values.min(), let hi = values.max() else { return [] }
        let recent = values.suffix(7)
        let avg = recent.reduce(0, +) / Double(recent.count)
        let suffix = unit.isEmpty ? "" : " \(unit)"
        return [
            MetricStat(label: "Latest", value: valueFormat(last) + suffix),
            MetricStat(label: "7-day avg", value: valueFormat(avg) + suffix),
            MetricStat(label: "Range", value: "\(valueFormat(lo))–\(valueFormat(hi))\(suffix)")
        ]
    }

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                heroValue
                chartCard
                statsCard
                insightCard
            }
            .padding(.horizontal, 20)
            .padding(.top, 24)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .presentationDetents([.medium, .fraction(0.85)])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
        .task { await generateExplanation() }
    }

    /// Builds a short "what this means" blurb on-device, grounded in whether
    /// this metric's baseline is favorable (isPositive) so the model doesn't
    /// guess at a direction that contradicts the UI's own status label.
    private func generateExplanation() async {
        guard SystemLanguageModel.default.availability == .available else { return }
        isGeneratingExplanation = true
        defer { isGeneratingExplanation = false }

        let baselineContext = baseline.map { "Baseline for this metric: \(valueFormat($0))." } ?? ""
        let direction = isPositive
            ? "This reading is currently a POSITIVE signal relative to baseline (status: \(statusLabel))."
            : "This reading is currently a NEGATIVE signal relative to baseline (status: \(statusLabel))."

        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: "You are a concise health and fitness coach explaining a single metric inside an app. Write 1-2 short sentences (under 40 words total) explaining what this specific value means for the user right now. Do not restate the number. Do not use markdown."
        )

        let prompt = """
        Metric: \(title)
        Current value: \(value)
        \(baselineContext)
        \(direction)
        """

        do {
            let response = try await session.respond(to: prompt)
            aiExplanation = response.content.trimmingCharacters(in: .whitespacesAndNewlines)
        } catch {
            aiExplanation = nil
        }
    }

    // MARK: - Sections

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [tint.opacity(0.28), tint.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                Image(systemName: icon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text(title)
                    .font(.title3.bold())
                HStack(spacing: 5) {
                    Image(systemName: isPositive ? "checkmark.circle.fill" : "exclamationmark.circle.fill")
                        .font(.caption2)
                    Text(statusLabel)
                        .font(.caption.weight(.semibold))
                }
                .foregroundStyle(statusColor)
                .padding(.horizontal, 8)
                .padding(.vertical, 4)
                .background(statusColor.opacity(0.14), in: Capsule())
            }

            Spacer()

            HStack(spacing: 8) {
                Button {
                    let topic = metricDetailTopic()
                    advisorPresenter?.ask(topic)
                    dismiss()
                } label: {
                    Image(systemName: "sparkles")
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(.cyan)
                        .frame(width: 30, height: 30)
                        .background(Color.cyan.opacity(0.12), in: Circle())
                }
                .buttonStyle(.plain)

                Button { dismiss() } label: {
                    Image(systemName: "xmark")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.secondary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
            }
        }
    }

    private var heroValue: some View {
        HStack(alignment: .firstTextBaseline, spacing: 10) {
            Text(value)
                .font(.system(size: 42, weight: .heavy, design: .rounded))
                .monospacedDigit()
                .lineLimit(1)
                .minimumScaleFactor(0.6)
            if let delta = trendDelta {
                HStack(spacing: 3) {
                    Image(systemName: delta.icon)
                        .font(.system(size: 9, weight: .bold))
                    Text(delta.text)
                        .font(.caption.weight(.medium))
                }
                .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .askVector(metricDetailTopic())
    }

    private var chartCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("Trend")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                Text(rangeLabel)
                    .font(.caption)
                    .foregroundStyle(.tertiary)
            }
            MetricTrendChart(
                points: series,
                baseline: baseline,
                tint: tint,
                valueFormat: valueFormat,
                modeAnnotations: series.isEmpty ? [] : AppModeHistoryStore.periods(overlapping: (series.first?.date ?? Date())...(series.last?.date ?? Date()))
            )
                .frame(height: 150)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    @ViewBuilder
    private var statsCard: some View {
        let items = resolvedStats
        if !items.isEmpty {
            HStack(spacing: 0) {
                ForEach(Array(items.enumerated()), id: \.element.id) { index, stat in
                    if index > 0 {
                        Divider().frame(height: 28)
                    }
                    VStack(spacing: 4) {
                        Text(stat.label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                        Text(stat.value)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(stat.valueColor ?? .primary)
                            .lineLimit(1)
                            .minimumScaleFactor(0.7)
                    }
                    .frame(maxWidth: .infinity)
                }
            }
            .padding(.vertical, 14)
            .padding(.horizontal, 8)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }

    private var insightCard: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text("What this means")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
                if isGeneratingExplanation && aiExplanation == nil {
                    ProgressView()
                        .controlSize(.mini)
                }
            }
            Text(aiExplanation ?? explanation)
                .font(.subheadline)
                .fixedSize(horizontal: false, vertical: true)
                .animation(.default, value: aiExplanation)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Advisor Topic

    private func metricDetailTopic() -> AdvisorTopic {
        var context = ["\(title): \(value)"]
        context.append("Status: \(statusLabel)")
        let stats = resolvedStats
        for stat in stats.prefix(2) {
            context.append("\(stat.label): \(stat.value)")
        }
        return AdvisorTopic(
            title: title,
            icon: icon,
            tintName: colorNameForColor(tint),
            contextLines: context,
            suggestedPrompt: "Explain my \(title.lowercased()) and what it means for my training."
        )
    }

    private func colorNameForColor(_ color: Color) -> String {
        if color == .green { return "green" }
        else if color == .red { return "red" }
        else if color == .orange { return "orange" }
        else if color == .yellow { return "yellow" }
        else if color == .blue { return "blue" }
        else if color == .cyan { return "cyan" }
        else if color == .purple { return "purple" }
        else if color == .pink { return "pink" }
        else if color == .mint { return "mint" }
        else if color == .indigo { return "indigo" }
        return "indigo"
    }
}
