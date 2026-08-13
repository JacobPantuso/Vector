import WidgetKit
import SwiftUI

// MARK: - VectorWatchEntry

struct VectorWatchEntry: TimelineEntry {
    let date: Date
    let snapshot: VectorWidgetSnapshot
    var hasData: Bool { !snapshot.isEmpty }
}

// MARK: - VectorWatchTimelineProvider

struct VectorWatchTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VectorWatchEntry {
        VectorWatchEntry(date: .now, snapshot: .placeholder)
    }

    func getSnapshot(in context: Context, completion: @escaping (VectorWatchEntry) -> Void) {
        let snapshot = context.isPreview ? .placeholder : (VectorWidgetStore.load() ?? .placeholder)
        let entry = VectorWatchEntry(date: .now, snapshot: snapshot)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VectorWatchEntry>) -> Void) {
        let snapshot = VectorWidgetStore.load() ?? .placeholder
        let entry = VectorWatchEntry(date: .now, snapshot: snapshot)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
        completion(timeline)
    }
}

// MARK: - VectorWatchRingsWidget

struct VectorWatchRingsWidget: Widget {
    let kind: String = "VectorWatchRings"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VectorWatchTimelineProvider()) { entry in
            VectorWatchRingsEntryView(entry: entry)
                .containerBackground(.clear, for: .widget)
        }
        .configurationDisplayName("Vector Rings")
        .description("Recovery, exertion, and sleep as rings.")
        .supportedFamilies([.accessoryCircular, .accessoryCorner, .accessoryRectangular])
    }
}

// MARK: - VectorWatchRingsEntryView

struct VectorWatchRingsEntryView: View {
    let entry: VectorWatchEntry
    @Environment(\.widgetFamily) var family

    var body: some View {
        switch family {
        case .accessoryCorner:
            VectorWatchCornerView(entry: entry)
        case .accessoryRectangular:
            VectorWatchRectangularView(entry: entry)
        default:
            VectorWatchCircularView(entry: entry)
        }
    }
}

// MARK: - Circular

struct VectorWatchCircularView: View {
    let entry: VectorWatchEntry
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        let hasDisplayedMetrics = entry.snapshot.recovery != nil || entry.snapshot.exertion != nil || entry.snapshot.sleep != nil

        if !hasDisplayedMetrics {
            // No data: single dim full circle outline
            Circle()
                .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                .padding(4)
        } else {
            ZStack {
                // Outer ring: Exertion (padding 0)
                ringLayer(value: entry.snapshot.exertion, kind: .exertion, outerPadding: 0, opacity: 1.0)

                // Middle ring: Recovery (padding 7)
                ringLayer(value: entry.snapshot.recovery, kind: .recovery, outerPadding: 7, opacity: 0.72)

                // Inner ring: Sleep (padding 14)
                ringLayer(value: entry.snapshot.sleep, kind: .sleep, outerPadding: 14, opacity: 0.45)
            }
            .aspectRatio(1, contentMode: .fit)
            .padding(2)
        }
    }

    @ViewBuilder
    private func ringLayer(value: Int?, kind: VectorMetricKind, outerPadding: CGFloat, opacity: Double) -> some View {
        VectorRing(
            value: value,
            kind: kind,
            lineWidth: 4.5,
            monochromeOpacity: renderingMode == .fullColor ? nil : opacity
        )
        .padding(outerPadding)
    }
}

// MARK: - Corner

struct VectorWatchCornerView: View {
    let entry: VectorWatchEntry
    @Environment(\.widgetRenderingMode) var renderingMode

    private var recoveryText: String {
        guard let recovery = entry.snapshot.recovery else { return "—" }
        return "\(recovery)"
    }

    var body: some View {
        let hasDisplayedMetrics = entry.snapshot.recovery != nil || entry.snapshot.exertion != nil || entry.snapshot.sleep != nil

        Group {
            if !hasDisplayedMetrics {
                Circle()
                    .stroke(Color.white.opacity(0.3), lineWidth: 1.5)
                    .padding(2)
            } else {
                ZStack {
                    ringLayer(value: entry.snapshot.exertion, kind: .exertion, outerPadding: 0, opacity: 1.0)
                    ringLayer(value: entry.snapshot.recovery, kind: .recovery, outerPadding: 4, opacity: 0.72)
                    ringLayer(value: entry.snapshot.sleep, kind: .sleep, outerPadding: 8, opacity: 0.45)
                }
                .aspectRatio(1, contentMode: .fit)
                .padding(1)
            }
        }
        .widgetLabel {
            Text(recoveryText)
        }
    }

    @ViewBuilder
    private func ringLayer(value: Int?, kind: VectorMetricKind, outerPadding: CGFloat, opacity: Double) -> some View {
        VectorRing(
            value: value,
            kind: kind,
            lineWidth: 3,
            monochromeOpacity: renderingMode == .fullColor ? nil : opacity
        )
        .padding(outerPadding)
    }
}

// MARK: - Rectangular

struct VectorWatchRectangularView: View {
    let entry: VectorWatchEntry
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        if !entry.hasData {
            VStack(alignment: .leading, spacing: 4) {
                Text("VECTOR")
                    .font(.system(size: 10, weight: .semibold))
                    .tracking(1.0)
                Text("No data")
                    .font(.system(size: 11, weight: .semibold))
            }
        } else {
            HStack(spacing: 8) {
                ZStack {
                    ringLayer(value: entry.snapshot.exertion, kind: .exertion, outerPadding: 0, opacity: 1.0)
                    ringLayer(value: entry.snapshot.recovery, kind: .recovery, outerPadding: 5, opacity: 0.72)
                    ringLayer(value: entry.snapshot.sleep, kind: .sleep, outerPadding: 10, opacity: 0.45)
                }
                .frame(width: 44, height: 44)

                VStack(alignment: .leading, spacing: 2) {
                    metricRow(title: VectorMetricKind.recovery.shortTitle, value: entry.snapshot.recovery, kind: .recovery)
                    metricRow(title: VectorMetricKind.exertion.shortTitle, value: entry.snapshot.exertion, kind: .exertion)
                    metricRow(title: VectorMetricKind.sleep.shortTitle, value: entry.snapshot.sleep, kind: .sleep)
                }

                Spacer(minLength: 0)
            }
        }
    }

    @ViewBuilder
    private func ringLayer(value: Int?, kind: VectorMetricKind, outerPadding: CGFloat, opacity: Double) -> some View {
        VectorRing(
            value: value,
            kind: kind,
            lineWidth: 3,
            monochromeOpacity: renderingMode == .fullColor ? nil : opacity
        )
        .padding(outerPadding)
    }

    @ViewBuilder
    private func metricRow(title: String, value: Int?, kind: VectorMetricKind) -> some View {
        HStack(spacing: 4) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.4)
                .foregroundStyle(.secondary)

            Text(value == nil ? "—" : "\(value!)")
                .font(.system(size: 12, weight: .semibold, design: .rounded))
                .foregroundStyle(kind.tint)
                .widgetAccentable()
        }
    }
}

// MARK: - Previews

#Preview("Circular", as: .accessoryCircular) {
    VectorWatchRingsWidget()
} timeline: {
    VectorWatchEntry(date: .now, snapshot: .placeholder)
}

#Preview("Corner", as: .accessoryCorner) {
    VectorWatchRingsWidget()
} timeline: {
    VectorWatchEntry(date: .now, snapshot: .placeholder)
}

#Preview("Rectangular", as: .accessoryRectangular) {
    VectorWatchRingsWidget()
} timeline: {
    VectorWatchEntry(date: .now, snapshot: .placeholder)
}
