import WidgetKit
import SwiftUI

// MARK: - VectorLockCircularWidget

struct VectorLockCircularWidget: Widget {
    let kind: String = "VectorLockCircular"

    var body: some WidgetConfiguration {
        AppIntentConfiguration(kind: kind, intent: SelectMetricIntent.self, provider: VectorAppIntentTimelineProvider()) { entry in
            VectorLockCircularWidgetView(entry: entry)
                .clearWidgetBackground()
        }
        .configurationDisplayName("Vector Ring")
        .description("A single metric on your Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct VectorLockCircularWidgetView: View {
    let entry: VectorEntry
    var selectedKind: VectorMetricKind { entry.kind }

    var metricValue: Int? {
        entry.snapshot.value(for: selectedKind)
    }

    var body: some View {
        if !entry.hasData {
            Text("—")
                .font(.system(size: 14, weight: .semibold))
        } else {
            Gauge(value: Double(metricValue ?? 0), in: 0...100) {
                Image(systemName: selectedKind.symbol)
                    .font(.system(size: 10, weight: .semibold))
            } currentValueLabel: {
                Text(metricValue == nil ? "—" : "\(metricValue!)")
                    .font(.system(size: 16, weight: .semibold, design: .rounded))
            }
            .gaugeStyle(.accessoryCircularCapacity)
            .tint(selectedKind.tint)
            .widgetAccentable()
        }
    }
}

// MARK: - VectorLockRectangularWidget

struct VectorLockRectangularWidget: Widget {
    let kind: String = "VectorLockRectangular"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VectorTimelineProvider()) { entry in
            VectorLockRectangularWidgetView(entry: entry)
                .clearWidgetBackground()
        }
        .configurationDisplayName("Vector Summary")
        .description("Lock screen metric overview.")
        .supportedFamilies([.accessoryRectangular])
    }
}

struct VectorLockRectangularWidgetView: View {
    let entry: VectorEntry

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
            VStack(spacing: 6) {
                // Header
                HStack(spacing: 6) {
                    Image(systemName: "heart.fill")
                        .font(.system(size: 9, weight: .semibold))
                        .foregroundStyle(VectorMetricKind.recovery.tint)

                    Text("VECTOR")
                        .font(.system(size: 9, weight: .semibold))
                        .tracking(0.8)

                    Spacer()
                }

                // Metrics in a 2×2 grid or single row depending on space
                VStack(spacing: 4) {
                    // Row 1
                    HStack(spacing: 8) {
                        metricCell(
                            title: "REC",
                            value: entry.snapshot.recovery,
                            kind: .recovery
                        )

                        metricCell(
                            title: "EXR",
                            value: entry.snapshot.exertion,
                            kind: .exertion
                        )
                    }

                    // Row 2
                    HStack(spacing: 8) {
                        metricCell(
                            title: "SLP",
                            value: entry.snapshot.sleep,
                            kind: .sleep
                        )

                        metricCell(
                            title: "STR",
                            value: entry.snapshot.stress,
                            kind: .stress
                        )
                    }
                }
            }
        }
    }

    @ViewBuilder
    private func metricCell(title: String, value: Int?, kind: VectorMetricKind) -> some View {
        VStack(spacing: 2) {
            Text(title)
                .font(.system(size: 9, weight: .semibold))
                .tracking(0.5)
                .foregroundStyle(.secondary)

            HStack(spacing: 3) {
                Text(value == nil ? "—" : "\(value!)")
                    .font(.system(size: 15, weight: .semibold, design: .rounded))
                    .foregroundStyle(kind.tint)
                    .widgetAccentable()

                VectorCapsuleBar(value: value, kind: kind, width: 20, height: 2)
            }
        }
    }
}

// MARK: - VectorLockInlineWidget

struct VectorLockInlineWidget: Widget {
    let kind: String = "VectorLockInline"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VectorTimelineProvider()) { entry in
            VectorLockInlineWidgetView(entry: entry)
                .clearWidgetBackground()
        }
        .configurationDisplayName("Vector Inline")
        .description("Lock screen one-line summary.")
        .supportedFamilies([.accessoryInline])
    }
}

struct VectorLockInlineWidgetView: View {
    let entry: VectorEntry

    var body: some View {
        if !entry.hasData {
            HStack(spacing: 2) {
                Image(systemName: "heart.slash.fill")
                    .font(.system(size: 8, weight: .semibold))
                Text("No data")
                    .font(.system(size: 11, weight: .semibold))
            }
        } else {
            HStack(spacing: 3) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 10, weight: .semibold))
                    .foregroundStyle(VectorMetricKind.recovery.tint)
                    .widgetAccentable()

                Text("Rec \(entry.snapshot.recovery ?? 0)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))

                Text("·")
                    .foregroundStyle(.secondary)

                Text("Sleep \(entry.snapshot.sleep ?? 0)")
                    .font(.system(size: 10, weight: .semibold, design: .rounded))
            }
        }
    }
}

// MARK: - VectorLockRingsWidget

struct VectorLockRingsWidget: Widget {
    let kind: String = "VectorLockRings"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VectorTimelineProvider()) { entry in
            VectorLockRingsWidgetView(entry: entry)
                .clearWidgetBackground()
        }
        .configurationDisplayName("Vector Rings")
        .description("Recovery, exertion, and sleep as rings on your Lock Screen.")
        .supportedFamilies([.accessoryCircular])
    }
}

struct VectorLockRingsWidgetView: View {
    let entry: VectorEntry
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

// MARK: - Previews

#Preview("Lock Circular", as: .accessoryCircular) {
    VectorLockCircularWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder)
}

#Preview("Lock Rings", as: .accessoryCircular) {
    VectorLockRingsWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder)
}

#Preview("Lock Rectangular", as: .accessoryRectangular) {
    VectorLockRectangularWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder)
}

#Preview("Lock Inline", as: .accessoryInline) {
    VectorLockInlineWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder)
}
