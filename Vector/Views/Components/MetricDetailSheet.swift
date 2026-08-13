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
    let isPositive: Bool?
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
    var domainLimit: ClosedRange<Double>? = nil

    @Environment(\.dismiss) private var dismiss
    @Environment(AdvisorPresenter.self) private var advisorPresenter: AdvisorPresenter?
    @State private var aiExplanation: String?
    @State private var isGeneratingExplanation = false

    private var statusColor: Color {
        switch isPositive {
        case .some(true): .green
        case .some(false): .orange
        case .none: .secondary
        }
    }

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

    private var historyDigest: String? {
        guard series.count >= 3 else { return nil }

        var lines: [String] = []

        // Days of data
        lines.append("Days of data: \(series.count)")

        // Latest
        if let last = series.last {
            lines.append("Latest: \(valueFormat(last.value))\(unit.isEmpty ? "" : " " + unit)")
        }

        // 7-day average
        let recent = series.suffix(7)
        if !recent.isEmpty {
            let avg = recent.map(\.value).reduce(0, +) / Double(recent.count)
            lines.append("7-day average: \(valueFormat(avg))\(unit.isEmpty ? "" : " " + unit)")
        }

        // Range over the data window
        if series.count >= 2 {
            let values = series.map(\.value)
            let minValue = values.min() ?? 0
            let maxValue = values.max() ?? 0
            lines.append("Range over \(series.count) days: \(valueFormat(minValue))–\(valueFormat(maxValue))\(unit.isEmpty ? "" : " " + unit)")
        }

        // Direction: compare mean of first half to mean of second half
        if series.count >= 2 {
            let mid = series.count / 2
            let firstHalf = series[..<mid]
            let secondHalf = series[mid...]

            let firstMean = firstHalf.map(\.value).reduce(0, +) / Double(firstHalf.count)
            let secondMean = secondHalf.map(\.value).reduce(0, +) / Double(secondHalf.count)

            if firstMean != 0 {
                let pctChange = (secondMean - firstMean) / abs(firstMean) * 100
                if pctChange > 1 {
                    lines.append(String(format: "Direction: rising (+%.0f%% over the window)", pctChange))
                } else if pctChange < -1 {
                    lines.append(String(format: "Direction: falling (-%.0f%% over the window)", abs(pctChange)))
                } else {
                    lines.append("Direction: steady")
                }
            }
        }

        // Volatility: standard deviation as percentage of mean
        if series.count >= 2 {
            let values = series.map(\.value)
            let mean = values.reduce(0, +) / Double(values.count)
            if mean != 0 {
                let variance = values.map { pow($0 - mean, 2) }.reduce(0, +) / Double(values.count)
                let stdDev = sqrt(variance)
                let cv = stdDev / abs(mean) * 100

                let volatilityLabel: String
                if cv < 5 {
                    volatilityLabel = "steady"
                } else if cv <= 15 {
                    volatilityLabel = "moderate"
                } else {
                    volatilityLabel = "swingy"
                }
                lines.append("Day-to-day variation: \(volatilityLabel)")
            }
        }

        // Most recent reading vs the 7-day average
        if let delta = trendDelta {
            // delta.text is like "+5% vs recent days" or "-3% vs recent days"
            if let pctPart = delta.text.split(separator: " ").first {
                lines.append("Most recent reading vs the 7-day average: \(pctPart)")
            }
        }

        // Personal baseline
        if let baseline = baseline {
            lines.append("Personal baseline: \(valueFormat(baseline))\(unit.isEmpty ? "" : " " + unit)")
        }

        return lines.joined(separator: "\n")
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
        .task {
            await generateExplanation()
        }
    }

    /// The on-device model sometimes prefixes its answer with invented tool-call
    /// scaffolding ("tool:analyze_hrv_trend", "result: {…}") before the real prose,
    /// because this throwaway session has no tools to ground it. Keep only what
    /// the user should read.
    private func cleanedExplanation(_ raw: String) -> String? {
        var lines = raw.components(separatedBy: .newlines)
        // The scaffolding always precedes the answer, so drop through the last
        // line that looks like scratch work rather than trying to match each form.
        if let lastScaffold = lines.lastIndex(where: { line in
            let trimmed = line.trimmingCharacters(in: .whitespaces)
            let lower = trimmed.lowercased()
            return lower.hasPrefix("tool:")
                || lower.hasPrefix("result:")
                || lower.hasPrefix("action:")
                || lower.hasPrefix("thought:")
                || trimmed.hasPrefix("```")
                || trimmed.hasSuffix("}")
        }) {
            lines = Array(lines.dropFirst(lastScaffold + 1))
        }
        let cleaned = lines
            .joined(separator: "\n")
            .trimmingCharacters(in: .whitespacesAndNewlines)
        return cleaned.isEmpty ? nil : cleaned
    }

    /// Shared instruction prefix for explanation generation (iOS 26 and 27).
    private static let baseExplanationInstructions = "You are Vector, a concise on-device health and fitness coach explaining one metric inside the user's app. You are given the user's real measured history for this metric. Write 2-3 short sentences (under 55 words total) that say what this metric's RECENT PATTERN means for the user right now — reference the trend, not just today's number. Never restate the current value verbatim; the app already shows it. Do not use markdown, bullets, or headings. Do not invent numbers that are not in the data given to you. Speak directly to the user as \"you\". Reply with prose only."

    /// Builds an on-device explanation grounded in real history and the metric's
    /// baseline favorability (isPositive) so the model doesn't contradict the UI's status label.
    private func generateExplanation() async {
        guard SystemLanguageModel.default.availability == .available else { return }
        guard aiExplanation == nil else { return }
        isGeneratingExplanation = true
        defer { isGeneratingExplanation = false }

        let direction = switch isPositive {
        case .some(true): "This reading is currently a POSITIVE signal relative to baseline (status: \(statusLabel))."
        case .some(false): "This reading is currently a NEGATIVE signal relative to baseline (status: \(statusLabel))."
        case .none: "This reading is informational (status: \(statusLabel)); it is not being judged good or bad."
        }

        var promptParts: [String] = [
            "Metric: \(title)",
            "Current value: \(value)",
            direction
        ]

        if let historyDigest = historyDigest {
            promptParts.append(historyDigest)
        }

        if !actionItem.isEmpty {
            promptParts.append("App's guidance for this state: \(actionItem)")
        }

        let prompt = promptParts.joined(separator: "\n")

        do {
            let profile = LanguageModelSession.Profile {
                Instructions(Self.baseExplanationInstructions)
            }
            .reasoningLevel(AIModel.supportsReasoning ? .light : nil)
            .maximumResponseTokens(120)
            .toolCallingMode(.disallowed)
            let session = LanguageModelSession(profile: profile)
            let response = try await session.respond(to: prompt)
            aiExplanation = cleanedExplanation(response.content)
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
                    Image(systemName: isPositive == nil ? "info.circle.fill" : (isPositive == true ? "checkmark.circle.fill" : "exclamationmark.circle.fill"))
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

                HStack(spacing: 4) {
                    Text(rangeLabel)
                        .font(.caption)
                        .foregroundStyle(.tertiary)

                    if let summary = MetricStatus.trendSummary(series: series) {
                        Text("·")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                        Text(summary)
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                            .lineLimit(1)
                    }
                }
            }

            MetricTrendChart(
                points: series,
                baseline: baseline,
                tint: tint,
                valueFormat: valueFormat,
                modeAnnotations: series.isEmpty ? [] : AppModeHistoryStore.periods(overlapping: (series.first?.date ?? Date())...(series.last?.date ?? Date())),
                domainLimit: domainLimit,
                unit: unit
            )
                .frame(height: 150)

            if series.count >= 2 {
                Text("Touch and drag to explore")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
                    .frame(maxWidth: .infinity, alignment: .center)
            }
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
                Image(systemName: "sparkles")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))

                Text("Vector Intelligence")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))
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

            if !actionItem.isEmpty {
                Divider().padding(.vertical, 2)

                HStack(alignment: .top, spacing: 6) {
                    Image(systemName: "arrow.right.circle.fill")
                        .font(.caption)
                        .foregroundStyle(tint)

                    Text(actionItem)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .fixedSize(horizontal: false, vertical: true)
                }
            }
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
