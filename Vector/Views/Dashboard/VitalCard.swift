import SwiftUI

/// A premium health metric card matching Apple's Health "highlights" style.
/// Displays a vital sign with hero value, optional delta, status, and a visual (waveform, sparkline, gauge, or deviation bar).
struct VitalCard: View {
    let snapshot: VitalSnapshot
    var size: VitalCardSize = .small

    /// Word heroes ("Normal", "Elevated", "Very low") all render at one size, so two
    /// cards sitting side by side never disagree just because one word is longer.
    /// Numeric heroes still step down when they run long, since their width really does vary.
    private var heroFontSize: CGFloat {
        let value = snapshot.value
        let isNumeric = value.contains(where: \.isNumber) || !value.contains(where: \.isLetter)
        guard isNumeric else { return 28 }
        return value.count > 6 ? 28 : 34
    }

    private var minHeight: CGFloat {
        if size == .small {
            guard snapshot.hasVisualData else { return 104 }
            return snapshot.metric.visual == .sleepStages ? 174 : 150
        } else {
            return snapshot.hasVisualData ? 132 : 96
        }
    }

    @ViewBuilder
    private func textBlock(fillTrailing: Bool = true, bottomPadding: CGFloat = 16) -> some View {
        VStack(alignment: .leading, spacing: 12) {
            // Pill chip with title and icon
            HStack(spacing: 6) {
                Image(systemName: snapshot.metric.icon)
                    .font(.system(size: 9, weight: .semibold))
                    .foregroundStyle(snapshot.metric.tint)
                Text(snapshot.metric.title)
                    .font(.caption2.weight(.semibold))
                    .tracking(0.6)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)
            }
            .padding(.horizontal, 8)
            .padding(.vertical, 4)
            .background(Capsule().fill(.primary.opacity(0.08)))

            // Hero value and its status read as one unit, so they sit tight together
            VStack(alignment: .leading, spacing: 2) {
                // Hero value with unit and delta
                HStack(alignment: .lastTextBaseline, spacing: 2) {
                    Text(snapshot.value)
                        .font(.system(size: heroFontSize, weight: .semibold, design: .rounded))
                        .monospacedDigit()
                        .lineLimit(1)
                        .minimumScaleFactor(0.6)
                        .contentTransition(.numericText())
                        .animation(.snappy, value: snapshot.value)
                        .layoutPriority(1)

                    if !snapshot.unit.isEmpty || snapshot.delta != nil {
                        VStack(alignment: .leading, spacing: 2) {
                            Text(snapshot.unit)
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)

                            if let delta = snapshot.delta {
                                Text(delta)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(snapshot.deltaIsPositiveSignal ? .green : .orange)
                            }
                        }
                        .fixedSize(horizontal: true, vertical: false)
                    }

                    if fillTrailing {
                        Spacer()
                    }
                }

                // Status line (if present)
                if let status = snapshot.status {
                    Text(status)
                        .font(.caption.weight(.medium))
                        .foregroundStyle(snapshot.tone.color)
                        .lineLimit(1)
                }
            }
        }
        .padding(.horizontal, 16).padding(.top, 16).padding(.bottom, bottomPadding)
    }

    @ViewBuilder
    private var content: some View {
        if size == .small {
            VStack(alignment: .leading, spacing: 0) {
                textBlock(bottomPadding: snapshot.hasVisualData && visualBelowText ? 10 : 16)

                Spacer(minLength: 0)

                if snapshot.hasVisualData {
                    if visualBelowText {
                        visualView()
                            .frame(maxWidth: .infinity)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 18)
                    } else {
                        visualView()
                            .frame(height: visualHeight)
                            .padding(.horizontal, 16)
                            .padding(.bottom, 16)
                    }
                }
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, maxHeight: .infinity, alignment: .topLeading)
        } else {
            // Wide size — text left, visual right
            HStack(alignment: .center, spacing: 12) {
                textBlock(fillTrailing: false)

                if snapshot.hasVisualData {
                    visualView()
                        .frame(
                            minWidth: 150,
                            maxWidth: .infinity,
                            minHeight: wideVisualHeight,
                            maxHeight: wideVisualHeight
                        )
                        .layoutPriority(1)
                        .padding(.trailing, 16)
                        .padding(.vertical, visualFillsHeight ? 10 : 16)
                }
            }
            .frame(maxWidth: .infinity, minHeight: minHeight, alignment: .leading)
        }
    }

    var body: some View {
        content
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
            .clipShape(.rect(cornerRadius: 22))
            .shadow(color: .black.opacity(0.13), radius: 14, x: 0, y: 6)
            .shadow(color: .black.opacity(0.06), radius: 3, x: 0, y: 1)
    }

    @ViewBuilder
    private func visualView() -> some View {
        switch snapshot.metric.visual {
        case .waveform:
            VitalWaveform(values: snapshot.points, tint: snapshot.metric.tint)
        case .sparkline:
            VitalNodeSparkline(values: snapshot.points, tint: snapshot.metric.tint)
        case .arcGauge:
            switch snapshot.metric {
            case .wristTemp:
                VitalArcGauge(
                    fraction: snapshot.fraction ?? 0.5,
                    tint: snapshot.metric.tint,
                    lowLabel: "−1.0°",
                    highLabel: "+1.0°",
                    bandStart: 0.35,
                    bandEnd: 0.65,
                    showsMidTick: true,
                    valueLabel: snapshot.gaugeValue
                )
            default:
                VitalArcGauge(
                    fraction: snapshot.fraction ?? 0.5,
                    tint: snapshot.metric.tint,
                    lowLabel: "90%",
                    highLabel: "100%",
                    bandStart: 0.5,
                    bandEnd: 1.0,
                    valueLabel: snapshot.gaugeValue
                )
            }
        case .sleepStages:
            let stages = snapshot.sleepStages ?? SleepStageBreakdown(deep: 0, core: 0, rem: 0, awake: 0)
            if size == .wide {
                VitalSleepBars(stages: stages)
            } else {
                VitalSleepStages(stages: stages)
            }
        case .none:
            EmptyView()
        }
    }

    private var visualHeight: CGFloat {
        switch snapshot.metric.visual {
        case .arcGauge:
            return 92
        case .sleepStages:
            return 78
        default:
            return 54
        }
    }

    /// The dome gauge stretches to the card's height and sits at the bottom;
    /// line charts stay at their fixed height, vertically centred.
    private var visualFillsHeight: Bool {
        snapshot.metric.visual == .arcGauge || snapshot.metric.visual == .sleepStages
    }

    /// Domes and bar charts get a taller box than line charts, but always a bounded one —
    /// both are GeometryReader-based and would otherwise expand to any height offered.
    private var wideVisualHeight: CGFloat {
        visualFillsHeight ? 104 : 76
    }

    private var visualBelowText: Bool {
        snapshot.metric.visual == .sleepStages && size == .small
    }
}

// MARK: - Previews

#Preview("Small card with waveform") {
    let snapshot = VitalSnapshot(
        metric: .heartRate,
        value: "72",
        unit: "BPM",
        delta: "+3",
        deltaIsPositiveSignal: false,
        status: "Within typical range",
        tone: .good,
        points: [65, 68, 72, 70, 75, 73, 71, 74, 72],
        hasData: true
    )
    VitalCard(snapshot: snapshot, size: .small)
        .padding(16)
}

#Preview("Small card with sparkline") {
    let snapshot = VitalSnapshot(
        metric: .hrv,
        value: "48",
        unit: "MS",
        delta: "+5",
        deltaIsPositiveSignal: true,
        status: "Slightly elevated",
        tone: .neutral,
        points: [42, 45, 48, 46, 50, 49, 47, 51, 48],
        hasData: true
    )
    VitalCard(snapshot: snapshot, size: .small)
        .padding(16)
}

#Preview("Wide card with arc gauge") {
    let snapshot = VitalSnapshot(
        metric: .spo2,
        value: "Normal",
        unit: "",
        delta: nil,
        deltaIsPositiveSignal: true,
        status: "Within your typical range",
        tone: .good,
        points: [],
        fraction: 0.7,
        gaugeValue: "97%",
        hasData: true
    )
    VitalCard(snapshot: snapshot, size: .wide)
        .padding(16)
}

#Preview("Small card with arc gauge") {
    let snapshot = VitalSnapshot(
        metric: .wristTemp,
        value: "Normal",
        unit: "",
        delta: nil,
        deltaIsPositiveSignal: false,
        status: "Below your baseline",
        tone: .neutral,
        points: [],
        fraction: 0.4,
        gaugeValue: "-0.2°",
        hasData: true
    )
    VitalCard(snapshot: snapshot, size: .small)
        .padding(16)
}

#Preview("Word heroes side by side") {
    let temp = VitalSnapshot(
        metric: .wristTemp,
        value: "Elevated",
        unit: "",
        status: "Above your baseline",
        tone: .neutral,
        fraction: 0.75,
        gaugeValue: "+0.5°",
        hasData: true
    )
    let oxygen = VitalSnapshot(
        metric: .spo2,
        value: "Normal",
        unit: "",
        status: "Within your typical range",
        tone: .good,
        fraction: 0.8,
        gaugeValue: "97%",
        hasData: true
    )

    return HStack(spacing: 16) {
        VitalCard(snapshot: temp, size: .small)
        VitalCard(snapshot: oxygen, size: .small)
    }
    .padding(16)
}

#Preview("No data card") {
    let snapshot = VitalSnapshot(
        metric: .vo2Max,
        value: "--",
        unit: "ML/KG",
        hasData: false
    )
    VitalCard(snapshot: snapshot, size: .small)
        .padding(16)
}

#Preview("No chart data — shrinks") {
    let snapshot = VitalSnapshot(
        metric: .heartRate,
        value: "50",
        unit: "BPM",
        delta: "-2",
        deltaIsPositiveSignal: false,
        status: "Below typical range",
        tone: .neutral,
        points: [],
        hasData: true
    )
    VitalCard(snapshot: snapshot, size: .small)
        .padding(16)
}

#Preview("Grid layout") {
    let smallCards = [
        VitalSnapshot(
            metric: .heartRate,
            value: "72",
            unit: "BPM",
            delta: "+3",
            deltaIsPositiveSignal: false,
            status: "Within typical range",
            tone: .good,
            points: [65, 68, 72, 70, 75, 73, 71],
            hasData: true
        ),
        VitalSnapshot(
            metric: .restingHR,
            value: "58",
            unit: "BPM",
            delta: "-2",
            deltaIsPositiveSignal: true,
            status: "Improving",
            tone: .good,
            points: [62, 60, 59, 58],
            hasData: true
        )
    ]

    let wideCards = [
        VitalSnapshot(
            metric: .spo2,
            value: "Normal",
            unit: "",
            status: "Within your typical range",
            tone: .good,
            fraction: 0.8,
            gaugeValue: "97%",
            hasData: true
        ),
        VitalSnapshot(
            metric: .wristTemp,
            value: "Normal",
            unit: "",
            delta: nil,
            status: "Below your baseline",
            tone: .neutral,
            fraction: 0.4,
            gaugeValue: "-0.2°",
            hasData: true
        )
    ]

    return ScrollView {
        VStack(spacing: 16) {
            // Row 1: Two small cards
            HStack(spacing: 16) {
                ForEach(smallCards, id: \.id) { snapshot in
                    VitalCard(snapshot: snapshot, size: .small)
                }
            }

            // Row 2: Wide card (full width)
            VitalCard(snapshot: wideCards[0], size: .wide)

            // Row 3: Wide card (full width)
            VitalCard(snapshot: wideCards[1], size: .wide)
        }
        .padding(16)
    }
}

#Preview("Sleep card") {
    let snapshot = VitalSnapshot(
        metric: .sleep,
        value: "7h 30m",
        unit: "asleep",
        delta: nil,
        deltaIsPositiveSignal: true,
        status: "Restful night",
        tone: .good,
        points: [],
        fraction: nil,
        sleepStages: SleepStageBreakdown(deep: 5400, core: 14400, rem: 7200, awake: 3600),
        hasData: true
    )
    VitalCard(snapshot: snapshot, size: .wide)
        .padding(16)
}
