import WidgetKit
import SwiftUI

struct VectorMetricWidget: Widget {
    let kind: String = "VectorMetric"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectMetricIntent.self, provider: VectorAppIntentTimelineProvider()) { entry in
            VectorMetricWidgetView(entry: entry)
                .widgetBackground()
        }
        .configurationDisplayName("Vector Metric")
        .description("A single metric with target or duration context.")
        .supportedFamilies([.systemSmall])
    }
}

// MARK: - Widget View

struct VectorMetricWidgetView: View {
    let entry: VectorEntry

    @Environment(\.widgetFamily) var family

    var body: some View {
        if !entry.hasData {
            VStack(spacing: 8) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 24))
                    .foregroundStyle(.secondary)
                Text("Open Vector")
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.secondary)
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity, alignment: .center)
        } else {
            VectorMetricSmallView(metric: entry.snapshot, selectedKind: entry.kind)
        }
    }
}

struct VectorMetricSmallView: View {
    let metric: VectorWidgetSnapshot
    let selectedKind: VectorMetricKind

    var body: some View {
        switch selectedKind {
        case .recovery:
            RecoverySmallView(metric: metric)
        case .exertion:
            ExertionSmallView(metric: metric)
        case .sleep:
            SleepSmallView(metric: metric)
        case .stress:
            StressSmallView(metric: metric)
        }
    }

    // MARK: - Recovery Layout
    private struct RecoverySmallView: View {
        let metric: VectorWidgetSnapshot

        var vitalString: String {
            var parts: [String] = []
            if let hrv = metric.hrv {
                parts.append(String(format: "HRV %.0f", hrv))
            }
            if let rhr = metric.restingHR {
                parts.append(String(format: "RHR %.0f", rhr))
            }
            return parts.joined(separator: " · ")
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: VectorMetricKind.recovery.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VectorMetricKind.recovery.tint)
                    Text(VectorMetricKind.recovery.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }

                Spacer(minLength: 4)

                ZStack {
                    VectorRing(value: metric.recovery, kind: .recovery, lineWidth: 6)
                        .frame(width: 62, height: 62)

                    Text(metric.recovery == nil ? "—" : "\(metric.recovery!)")
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(VectorMetricKind.recovery.tint)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 4)

                Text(ScoreBand.word(for: metric.recovery, kind: .recovery))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)

                if !vitalString.isEmpty {
                    Text(vitalString)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text(relativeUpdatedString(metric.updated))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Exertion Layout
    private struct ExertionSmallView: View {
        let metric: VectorWidgetSnapshot

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: VectorMetricKind.exertion.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VectorMetricKind.exertion.tint)
                    Text(VectorMetricKind.exertion.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }

                Spacer(minLength: 4)

                ZStack {
                    VectorRing(
                        value: metric.exertion,
                        kind: .exertion,
                        lineWidth: 6,
                        targetLow: metric.exertionTargetLow,
                        targetHigh: metric.exertionTargetHigh
                    )
                    .frame(width: 62, height: 62)

                    Text(metric.exertion == nil ? "—" : "\(metric.exertion!)")
                        .font(.system(size: 21, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(VectorMetricKind.exertion.tint)
                }
                .frame(maxWidth: .infinity)

                Spacer(minLength: 4)

                Text(ScoreBand.word(for: metric.exertion, kind: .exertion))
                    .font(.system(size: 11, weight: .semibold))
                    .foregroundStyle(.white)

                if let low = metric.exertionTargetLow, let high = metric.exertionTargetHigh {
                    Text("Target \(low)–\(high)")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                } else {
                    Text(relativeUpdatedString(metric.updated))
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Sleep Stage Bar Component
    private struct SleepStageBar: View {
        let deep: Double?
        let rem: Double?
        let core: Double?
        let awake: Double?
        var height: CGFloat = 7

        private var total: Double {
            let values = [deep, rem, core, awake].compactMap { $0 }
            return values.reduce(0, +)
        }

        var body: some View {
            if total > 0 {
                GeometryReader { geo in
                    HStack(spacing: 1) {
                        // Deep (first)
                        if let d = deep, d > 0 {
                            Capsule()
                                .fill(Color(red: 0.6, green: 0.4, blue: 1))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .frame(maxWidth: geo.size.width * (d / total))
                        }

                        // Core (second)
                        if let c = core, c > 0 {
                            Capsule()
                                .fill(Color(red: 0.2, green: 0.6, blue: 1))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .frame(maxWidth: geo.size.width * (c / total))
                        }

                        // REM (third)
                        if let r = rem, r > 0 {
                            Capsule()
                                .fill(.cyan)
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .frame(maxWidth: geo.size.width * (r / total))
                        }

                        // Awake (fourth)
                        if let a = awake, a > 0 {
                            Capsule()
                                .fill(Color.red.opacity(0.7))
                                .frame(maxWidth: .infinity, maxHeight: .infinity)
                                .frame(maxWidth: geo.size.width * (a / total))
                        }
                    }
                    .clipShape(Capsule())
                }
                .frame(height: height)
            }
        }
    }

    // MARK: - Sleep Layout
    private struct SleepSmallView: View {
        let metric: VectorWidgetSnapshot

        var durationString: String {
            guard let seconds = metric.sleepAsleepSeconds else { return "—" }
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            return "\(hours)h \(minutes)m"
        }

        var qualityText: String {
            if let sleep = metric.sleep {
                let word = ScoreBand.word(for: sleep, kind: .sleep)
                return "Quality \(sleep) · \(word)"
            }
            return "Quality —"
        }

        private func formatStageDuration(_ seconds: Double?) -> String {
            guard let seconds = seconds, seconds > 0 else { return "—" }
            let hours = Int(seconds / 3600)
            let minutes = Int((seconds.truncatingRemainder(dividingBy: 3600)) / 60)
            if hours > 0 {
                return "\(hours)h\(minutes)m"
            } else {
                return "\(minutes)m"
            }
        }

        var hasStageData: Bool {
            let total = (metric.sleepDeepSeconds ?? 0) + (metric.sleepRemSeconds ?? 0) +
                        (metric.sleepCoreSeconds ?? 0) + (metric.sleepAwakeSeconds ?? 0)
            return total > 0
        }

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: VectorMetricKind.sleep.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VectorMetricKind.sleep.tint)
                    Text(VectorMetricKind.sleep.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }

                Spacer(minLength: 6)

                VStack(alignment: .center, spacing: 0) {
                    Text(durationString)
                        .font(.system(size: 30, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .foregroundStyle(VectorMetricKind.sleep.tint)
                        .minimumScaleFactor(0.7)
                        .lineLimit(1)

                    Text("asleep")
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                }
                .frame(maxWidth: .infinity, alignment: .center)

                Spacer(minLength: 6)

                if hasStageData {
                    Spacer(minLength: 4)

                    SleepStageBar(
                        deep: metric.sleepDeepSeconds,
                        rem: metric.sleepRemSeconds,
                        core: metric.sleepCoreSeconds,
                        awake: metric.sleepAwakeSeconds,
                        height: 7
                    )
                    .frame(maxWidth: .infinity)

                    Spacer(minLength: 4)

                    // 6-column Legend Grid for proper alignment
                    Grid(horizontalSpacing: 0, verticalSpacing: 3) {
                        // Row 1: Deep, Core
                        GridRow {
                            // Deep chip
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(red: 0.6, green: 0.4, blue: 1))
                                .frame(width: 5, height: 5)
                                .padding(.trailing, 2)

                            // Deep name
                            Text("Deep")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                                .gridColumnAlignment(.leading)
                                .padding(.trailing, 3)

                            // Deep value
                            Text(formatStageDuration(metric.sleepDeepSeconds))
                                .font(.system(size: 7, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .gridColumnAlignment(.leading)
                                .padding(.trailing, 8)

                            // Core chip
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color(red: 0.2, green: 0.6, blue: 1))
                                .frame(width: 5, height: 5)
                                .padding(.trailing, 2)

                            // Core name
                            Text("Core")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                                .gridColumnAlignment(.leading)
                                .padding(.trailing, 3)

                            // Core value
                            Text(formatStageDuration(metric.sleepCoreSeconds))
                                .font(.system(size: 7, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .gridColumnAlignment(.leading)
                        }

                        // Row 2: REM, Awake
                        GridRow {
                            // REM chip
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(.cyan)
                                .frame(width: 5, height: 5)
                                .padding(.trailing, 2)

                            // REM name
                            Text("REM")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                                .gridColumnAlignment(.leading)
                                .padding(.trailing, 3)

                            // REM value
                            Text(formatStageDuration(metric.sleepRemSeconds))
                                .font(.system(size: 7, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .gridColumnAlignment(.leading)
                                .padding(.trailing, 8)

                            // Awake chip
                            RoundedRectangle(cornerRadius: 1.5)
                                .fill(Color.red.opacity(0.7))
                                .frame(width: 5, height: 5)
                                .padding(.trailing, 2)

                            // Awake name
                            Text("Awake")
                                .font(.system(size: 7, weight: .medium))
                                .foregroundStyle(.white.opacity(0.5))
                                .lineLimit(1)
                                .gridColumnAlignment(.leading)
                                .padding(.trailing, 3)

                            // Awake value
                            Text(formatStageDuration(metric.sleepAwakeSeconds))
                                .font(.system(size: 7, weight: .semibold))
                                .monospacedDigit()
                                .foregroundStyle(.white.opacity(0.8))
                                .lineLimit(1)
                                .fixedSize(horizontal: true, vertical: false)
                                .layoutPriority(1)
                                .gridColumnAlignment(.leading)
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .center)

                    Spacer(minLength: 3)
                } else {
                    VectorTargetBar(value: metric.sleep, kind: .sleep, height: 5)
                        .frame(maxWidth: .infinity)

                    Text(qualityText)
                        .font(.system(size: 9, weight: .medium))
                        .foregroundStyle(.white.opacity(0.55))
                        .lineLimit(1)
                        .minimumScaleFactor(0.8)
                        .frame(maxWidth: .infinity, alignment: .center)

                    Spacer()
                }
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 2)
        }
    }

    // MARK: - Stress Layout
    private struct StressSmallView: View {
        let metric: VectorWidgetSnapshot

        var body: some View {
            VStack(alignment: .leading, spacing: 0) {
                HStack(spacing: 5) {
                    Image(systemName: VectorMetricKind.stress.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VectorMetricKind.stress.tint)
                    Text(VectorMetricKind.stress.title)
                        .font(.system(size: 12, weight: .semibold))
                        .foregroundStyle(.white.opacity(0.9))
                    Spacer()
                }

                Spacer(minLength: 6)

                Text(metric.stress == nil ? "—" : "\(metric.stress!)")
                    .font(.system(size: 34, weight: .semibold, design: .rounded))
                    .monospacedDigit()
                    .foregroundStyle(VectorMetricKind.stress.tint)
                    .frame(maxWidth: .infinity)

                Text(ScoreBand.word(for: metric.stress, kind: .stress))
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.75))
                    .frame(maxWidth: .infinity)

                Spacer(minLength: 6)

                VectorTargetBar(value: metric.stress, kind: .stress, height: 5)
                    .frame(maxWidth: .infinity)

                Spacer()
            }
            .frame(maxWidth: .infinity, maxHeight: .infinity)
            .padding(.horizontal, 2)
        }
    }
}

// MARK: - Previews

#Preview("Metric · Recovery", as: .systemSmall) {
    VectorMetricWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder, kind: .recovery)
}

#Preview("Metric · Exertion", as: .systemSmall) {
    VectorMetricWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder, kind: .exertion)
}

#Preview("Metric · Sleep", as: .systemSmall) {
    VectorMetricWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder, kind: .sleep)
}

#Preview("Metric · Stress", as: .systemSmall) {
    VectorMetricWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder, kind: .stress)
}
