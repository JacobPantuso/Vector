import WidgetKit
import SwiftUI

struct VectorRingsWidget: Widget {
    let kind: String = "VectorRings"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VectorTimelineProvider()) { entry in
            VectorRingsWidgetView(entry: entry)
                .widgetBackground()
        }
        .configurationDisplayName("Vector Rings")
        .description("Recovery, exertion, sleep, and stress at a glance.")
        .supportedFamilies([.systemSmall, .systemMedium])
    }
}

// MARK: - Small Widget View

struct VectorRingsSmallView: View {
    let snapshot: VectorWidgetSnapshot

    var body: some View {
        ZStack {
            // Outer ring: Recovery
            VectorRing(value: snapshot.recovery, kind: .recovery, lineWidth: 6)

            // Second ring: Exertion
            VectorRing(value: snapshot.exertion, kind: .exertion, lineWidth: 6)
                .padding(10)

            // Third ring: Sleep
            VectorRing(value: snapshot.sleep, kind: .sleep, lineWidth: 6)
                .padding(20)

            // Innermost ring: Stress
            VectorRing(value: snapshot.stress, kind: .stress, lineWidth: 6)
                .padding(30)

            // Center: Recovery value
            Text(snapshot.recovery == nil ? "—" : "\(snapshot.recovery!)")
                .font(.system(size: 24, weight: .semibold, design: .rounded))
                .foregroundStyle(VectorMetricKind.recovery.tint)
        }
        .aspectRatio(1, contentMode: .fit)
        .padding()
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }
}

// MARK: - Medium Widget View

struct VectorRingsMediumView: View {
    let snapshot: VectorWidgetSnapshot

    var body: some View {
        HStack(spacing: 16) {
            // Left: Recovery ring
            VStack(spacing: 0) {
                ZStack {
                    VectorRing(value: snapshot.recovery, kind: .recovery, lineWidth: 9)

                    VStack(spacing: 2) {
                        Text(snapshot.recovery == nil ? "—" : "\(snapshot.recovery!)")
                            .font(.system(size: 26, weight: .semibold, design: .rounded))
                            .foregroundStyle(VectorMetricKind.recovery.tint)
                        Text("REC")
                            .font(.system(size: 7, weight: .semibold))
                            .tracking(0.6)
                            .foregroundStyle(Color.white.opacity(0.55))
                    }
                }
                .frame(maxWidth: .infinity)
                .aspectRatio(1, contentMode: .fit)
            }

            // Right: Three metrics as rows
            VStack(spacing: 10) {
                // Exertion row
                HStack(spacing: 8) {
                    Image(systemName: VectorMetricKind.exertion.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VectorMetricKind.exertion.tint)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("EXR")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.55))
                        Text(snapshot.exertion == nil ? "—" : "\(snapshot.exertion!)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VectorCapsuleBar(value: snapshot.exertion, kind: .exertion, width: 40, height: 4)
                }

                // Sleep row
                HStack(spacing: 8) {
                    Image(systemName: VectorMetricKind.sleep.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VectorMetricKind.sleep.tint)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("SLP")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.55))
                        Text(snapshot.sleep == nil ? "—" : "\(snapshot.sleep!)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VectorCapsuleBar(value: snapshot.sleep, kind: .sleep, width: 40, height: 4)
                }

                // Stress row
                HStack(spacing: 8) {
                    Image(systemName: VectorMetricKind.stress.symbol)
                        .font(.system(size: 11, weight: .semibold))
                        .foregroundStyle(VectorMetricKind.stress.tint)
                        .frame(width: 12)

                    VStack(alignment: .leading, spacing: 2) {
                        Text("STR")
                            .font(.system(size: 9, weight: .semibold))
                            .tracking(0.5)
                            .foregroundStyle(Color.white.opacity(0.55))
                        Text(snapshot.stress == nil ? "—" : "\(snapshot.stress!)")
                            .font(.system(size: 15, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                    }

                    Spacer()

                    VectorCapsuleBar(value: snapshot.stress, kind: .stress, width: 40, height: 4)
                }

                Spacer()

                // Bottom: Updated time or sparkline
                if snapshot.recoveryHistory.count >= 2 {
                    HStack(spacing: 4) {
                        Text("Trend")
                            .font(.caption2)
                            .foregroundStyle(.secondary)

                        SparklineView(data: snapshot.recoveryHistory, tint: VectorMetricKind.recovery.tint)
                            .frame(height: 20)
                    }
                } else {
                    Text(relativeTime(snapshot.updated))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }
            .padding(.trailing, 2)
        }
        .padding()
    }

    private func relativeTime(_ date: Date) -> String {
        let interval = Date().timeIntervalSince(date)
        if interval < 60 {
            return "Just now"
        } else if interval < 3600 {
            let minutes = Int(interval / 60)
            return "\(minutes)m ago"
        } else if interval < 86400 {
            let hours = Int(interval / 3600)
            return "\(hours)h ago"
        } else {
            return "Earlier"
        }
    }
}

// MARK: - Container View

struct VectorRingsWidgetView: View {
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
            switch family {
            case .systemSmall:
                VectorRingsSmallView(snapshot: entry.snapshot)
            case .systemMedium:
                switch RingsMediumLayout.active {
                case .heroRail:
                    VectorRingsHeroRailView(snapshot: entry.snapshot)
                case .statusLed:
                    VectorRingsStatusLedView(snapshot: entry.snapshot)
                case .legacy:
                    VectorRingsMediumView(snapshot: entry.snapshot)
                case .quadRing:
                    VectorRingsQuadRingView(snapshot: entry.snapshot)
                }
            default:
                VectorRingsSmallView(snapshot: entry.snapshot)
            }
        }
    }
}

// MARK: - Previews

#Preview("Rings Small", as: .systemSmall) {
    VectorRingsWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder)
}

#Preview("Rings Small - High Exertion", as: .systemSmall) {
    VectorRingsWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: VectorWidgetSnapshot(updated: .now, recovery: 78, exertion: 137, exertionTargetLow: 55, exertionTargetHigh: 85, sleep: 72, sleepAsleepSeconds: 28800, stress: 38, hrv: 45.2, restingHR: 62, steps: 8234, recoveryHistory: [70, 72, 75, 78]))
}

#Preview("Rings Medium", as: .systemMedium) {
    VectorRingsWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder)
}

#Preview("Rings Medium - High Exertion", as: .systemMedium) {
    VectorRingsWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: VectorWidgetSnapshot(updated: .now, recovery: 78, exertion: 137, exertionTargetLow: 55, exertionTargetHigh: 85, sleep: 72, sleepAsleepSeconds: 28800, stress: 38, hrv: 45.2, restingHR: 62, steps: 8234, recoveryHistory: [70, 72, 75, 78]))
}
