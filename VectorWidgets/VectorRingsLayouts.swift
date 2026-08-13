import SwiftUI
import WidgetKit

// MARK: - Layout Switch

enum RingsMediumLayout {
    case heroRail   // Direction A
    case statusLed  // Direction C
    case legacy     // the existing VectorRingsMediumView
    case quadRing   // Direction D

    /// Flip this to test a different layout.
    static let active: RingsMediumLayout = .quadRing
}

// MARK: - Shared Helpers

struct ScoreBand {
    static func word(for value: Int?, kind: VectorMetricKind, targetLow: Int? = nil, targetHigh: Int? = nil) -> String {
        guard let value = value else { return "—" }

        switch kind {
        case .recovery:
            if value <= 33 { return "Depleted" }
            if value <= 49 { return "Low" }
            if value <= 69 { return "Fair" }
            if value <= 84 { return "Ready" }
            return "Primed"

        case .sleep:
            if value <= 33 { return "Poor" }
            if value <= 49 { return "Short" }
            if value <= 69 { return "Fair" }
            if value <= 84 { return "Good" }
            return "Excellent"

        case .stress:
            if value <= 33 { return "Calm" }
            if value <= 49 { return "Steady" }
            if value <= 69 { return "Elevated" }
            if value <= 84 { return "High" }
            return "Strained"

        case .exertion:
            // Match app's ExertionLevel thresholds
            if value < 1 { return "No strain" }
            if value < 30 { return "Low" }
            if value < 60 { return "Moderate" }
            if value < 85 { return "High" }
            return "Extreme"
        }
    }
}

func relativeUpdatedString(_ date: Date) -> String {
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

// MARK: - VectorTargetBar

struct VectorTargetBar: View {
    var value: Int?
    var kind: VectorMetricKind
    var targetLow: Int? = nil
    var targetHigh: Int? = nil
    var height: CGFloat = 5

    private var total: Double {
        Double(value ?? 0)
    }

    private var fillFraction: Double {
        guard let v = value else { return 0 }
        let tot = Double(v)
        return tot > 100 ? 1.0 : tot / 100
    }

    private var isOverflow: Bool {
        guard let v = value else { return false }
        return Double(v) > 100
    }

    private var overflowColor: Color {
        Color(hue: 0.0, saturation: 0.95, brightness: 0.42)
    }

    private var targetLowFraction: Double {
        guard let low = targetLow else { return 0 }
        return Double(low) / 100
    }

    private var targetHighFraction: Double {
        guard let high = targetHigh else { return 0 }
        return Double(high) / 100
    }

    var body: some View {
        GeometryReader { geo in
            ZStack(alignment: .leading) {
                // Track
                Capsule()
                    .fill(kind.tint.opacity(0.14))

                // Target band (if targets provided)
                if targetLow != nil && targetHigh != nil {
                    ZStack(alignment: .leading) {
                        Capsule()
                            .fill(Color.white.opacity(0.16))
                            .frame(maxWidth: geo.size.width * (targetHighFraction - targetLowFraction))
                    }
                    .offset(x: geo.size.width * targetLowFraction)

                    // Tick at targetHigh (absolute position)
                    Rectangle()
                        .fill(Color.white.opacity(0.55))
                        .frame(width: 1.5, height: height * 1.2)
                        .offset(x: geo.size.width * targetHighFraction)
                }

                // Fill
                if fillFraction > 0 {
                    Capsule()
                        .fill(kind.linearGradient)
                        .frame(maxWidth: geo.size.width * fillFraction)
                }

                // Overflow (if value > 100)
                if isOverflow {
                    let overflowFraction = (total - 100) / total
                    Capsule()
                        .fill(overflowColor)
                        .frame(maxWidth: geo.size.width * overflowFraction)
                }
            }
        }
        .frame(height: height)
    }
}

// MARK: - Direction A: VectorRingsHeroRailView

struct VectorRingsHeroRailView: View {
    let snapshot: VectorWidgetSnapshot

    var body: some View {
        HStack(spacing: 20) {
            // LEFT: Hero Recovery Ring
            VStack(spacing: 8) {
                ZStack {
                    VectorRing(value: snapshot.recovery, kind: .recovery, lineWidth: 8)

                    VStack(spacing: 0) {
                        Text(snapshot.recovery == nil ? "—" : "\(snapshot.recovery!)")
                            .font(.system(size: 30, weight: .semibold, design: .rounded))
                            .foregroundStyle(VectorMetricKind.recovery.tint)

                        Text(ScoreBand.word(for: snapshot.recovery, kind: .recovery))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.6))
                    }
                }
                .frame(width: 96)
                .aspectRatio(1, contentMode: .fit)

                Text("RECOVERY")
                    .font(.system(size: 8, weight: .semibold))
                    .tracking(0.8)
                    .foregroundStyle(Color.white.opacity(0.45))
            }

            // RIGHT: Rail with Grid
            VStack(alignment: .leading, spacing: 0) {
                Grid(alignment: .leading, horizontalSpacing: 8, verticalSpacing: 11) {
                    // Exertion row
                    GridRow {
                        Text("Exertion")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .gridColumnAlignment(.leading)

                        Text(snapshot.exertion == nil ? "—" : "\(snapshot.exertion!)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)

                        VectorTargetBar(
                            value: snapshot.exertion,
                            kind: .exertion,
                            targetLow: snapshot.exertionTargetLow,
                            targetHigh: snapshot.exertionTargetHigh
                        )
                        .gridCellColumns(1)
                        .frame(maxWidth: .infinity)
                    }

                    // Sleep row
                    GridRow {
                        Text("Sleep")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .gridColumnAlignment(.leading)

                        Text(snapshot.sleep == nil ? "—" : "\(snapshot.sleep!)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)

                        VectorTargetBar(value: snapshot.sleep, kind: .sleep)
                            .gridCellColumns(1)
                            .frame(maxWidth: .infinity)
                    }

                    // Stress row
                    GridRow {
                        Text("Stress")
                            .font(.system(size: 10, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.65))
                            .gridColumnAlignment(.leading)

                        Text(snapshot.stress == nil ? "—" : "\(snapshot.stress!)")
                            .font(.system(size: 16, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .gridColumnAlignment(.trailing)

                        VectorTargetBar(value: snapshot.stress, kind: .stress)
                            .gridCellColumns(1)
                            .frame(maxWidth: .infinity)
                    }
                }

                Spacer(minLength: 6)

                Rectangle()
                    .fill(Color.white.opacity(0.08))
                    .frame(height: 0.5)

                Text("Updated \(relativeUpdatedString(snapshot.updated))")
                    .font(.system(size: 9))
                    .foregroundStyle(Color.white.opacity(0.4))
                    .padding(.top, 6)
            }
        }
        .padding(14)
    }
}

// MARK: - Direction C: VectorRingsStatusLedView

struct VectorRingsStatusLedView: View {
    let snapshot: VectorWidgetSnapshot

    private var headline: String {
        guard let recovery = snapshot.recovery else { return "No data yet" }
        if recovery >= 85 { return "Primed to train" }
        if recovery >= 70 { return "Ready to train" }
        if recovery >= 50 { return "Train with care" }
        if recovery >= 34 { return "Take it easy" }
        return "Rest today"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            Text(headline)
                .font(.system(size: 21, weight: .semibold, design: .rounded))
                .foregroundStyle(.white)
                .lineLimit(1)
                .minimumScaleFactor(0.7)

            HStack(spacing: 4) {
                Text("Recovery \(snapshot.recovery == nil ? "—" : "\(snapshot.recovery!)")")
                    .font(.system(size: 11, weight: .medium))
                    .foregroundStyle(VectorMetricKind.recovery.tint)

                if let sleepSeconds = snapshot.sleepAsleepSeconds {
                    Text("·")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))

                    let hours = Int(sleepSeconds) / 3600
                    let minutes = (Int(sleepSeconds) % 3600) / 60
                    Text("\(hours)h \(minutes)m asleep")
                        .font(.system(size: 11, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.5))
                }
            }
            .padding(.top, 2)

            Spacer(minLength: 10)

            // Three metric rows
            VStack(spacing: 9) {
                // Exertion row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Exertion")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))

                        Spacer()

                        Text(ScoreBand.word(for: snapshot.exertion, kind: .exertion, targetLow: snapshot.exertionTargetLow, targetHigh: snapshot.exertionTargetHigh))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(VectorMetricKind.exertion.tint)

                        Text(snapshot.exertion == nil ? "—" : "\(snapshot.exertion!)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .padding(.leading, 5)
                    }

                    VectorTargetBar(
                        value: snapshot.exertion,
                        kind: .exertion,
                        targetLow: snapshot.exertionTargetLow,
                        targetHigh: snapshot.exertionTargetHigh,
                        height: 4
                    )
                    .frame(maxWidth: .infinity)
                }

                // Sleep row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Sleep")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))

                        Spacer()

                        Text(ScoreBand.word(for: snapshot.sleep, kind: .sleep))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(VectorMetricKind.sleep.tint)

                        Text(snapshot.sleep == nil ? "—" : "\(snapshot.sleep!)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .padding(.leading, 5)
                    }

                    VectorTargetBar(value: snapshot.sleep, kind: .sleep, height: 4)
                        .frame(maxWidth: .infinity)
                }

                // Stress row
                VStack(alignment: .leading, spacing: 4) {
                    HStack(spacing: 0) {
                        Text("Stress")
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(Color.white.opacity(0.55))

                        Spacer()

                        Text(ScoreBand.word(for: snapshot.stress, kind: .stress))
                            .font(.system(size: 9, weight: .medium))
                            .foregroundStyle(VectorMetricKind.stress.tint)

                        Text(snapshot.stress == nil ? "—" : "\(snapshot.stress!)")
                            .font(.system(size: 11, weight: .semibold, design: .rounded))
                            .foregroundStyle(.white)
                            .monospacedDigit()
                            .padding(.leading, 5)
                    }

                    VectorTargetBar(value: snapshot.stress, kind: .stress, height: 4)
                        .frame(maxWidth: .infinity)
                }
            }
        }
        .padding(14)
    }
}

// MARK: - VectorPurpleBackground

struct VectorPurpleBackground: View {
    @Environment(\.widgetRenderingMode) var renderingMode

    var body: some View {
        ZStack {
            // Dark base gradient
            LinearGradient(
                gradient: Gradient(colors: [
                    Color(white: 0.04),
                    Color(white: 0.01)
                ]),
                startPoint: .topLeading,
                endPoint: .bottomTrailing
            )

            // Radial glow: purple-violet at top-trailing
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.55, green: 0.35, blue: 0.95).opacity(0.22),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.85, y: 0.1),
                startRadius: 0,
                endRadius: 140
            )

            // Radial glow: indigo at bottom-leading (weaker)
            RadialGradient(
                gradient: Gradient(colors: [
                    Color(red: 0.35, green: 0.3, blue: 0.9).opacity(0.08),
                    Color.clear
                ]),
                center: UnitPoint(x: 0.1, y: 0.95),
                startRadius: 0,
                endRadius: 120
            )
        }
        .overlay(
            renderingMode == .accented || renderingMode == .vibrant
                ? nil
                : LinearGradient(
                    gradient: Gradient(colors: [Color.white.opacity(0.01), Color.clear]),
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
        )
    }
}

extension View {
    func purpleWidgetBackground() -> some View {
        self.containerBackground(for: .widget) {
            VectorPurpleBackground()
        }
    }
}

// MARK: - Direction D: VectorRingsQuadRingView

struct VectorRingsQuadRingView: View {
    let snapshot: VectorWidgetSnapshot

    @Environment(\.widgetRenderingMode) var renderingMode

    private var timeOfDay: TimeOfDay {
        let hour = Calendar.current.component(.hour, from: Date())
        if hour >= 5 && hour < 12 { return .morning }
        if hour >= 12 && hour < 17 { return .afternoon }
        if hour >= 17 && hour < 21 { return .evening }
        return .night
    }

    private enum TimeOfDay {
        case morning, afternoon, evening, night
    }

    private var greetingSymbol: String {
        switch timeOfDay {
        case .morning: "sunrise.fill"
        case .afternoon: "sun.max.fill"
        case .evening: "sunset.fill"
        case .night: "moon.stars.fill"
        }
    }

    private var greetingSymbolColor: Color {
        switch timeOfDay {
        case .morning, .afternoon:
            Color(red: 1.0, green: 0.75, blue: 0.35)
        case .evening:
            Color(red: 1.0, green: 0.6, blue: 0.45)
        case .night:
            Color(red: 0.6, green: 0.55, blue: 1.0)
        }
    }

    private var greetingText: String {
        let period: String = {
            switch timeOfDay {
            case .morning: "Good morning"
            case .afternoon: "Good afternoon"
            case .evening: "Good evening"
            case .night: "Good night"
            }
        }()

        if let name = snapshot.name, !name.isEmpty {
            return "\(period), \(name)"
        }
        return period
    }

    private var statusSentence: String {
        // Priority order: FIRST match wins
        if snapshot.recovery == nil && snapshot.exertion == nil && snapshot.sleep == nil && snapshot.stress == nil {
            return "Open Vector to sync your data"
        }
        if let stress = snapshot.stress, stress >= 70 {
            return "Something is straining your system"
        }
        if let recovery = snapshot.recovery, recovery <= 33 {
            return "Your body needs rest today"
        }
        if let sleep = snapshot.sleep, sleep <= 40 {
            return "Last night's sleep is holding you back"
        }
        if let exertion = snapshot.exertion,
           let targetHigh = snapshot.exertionTargetHigh,
           exertion > targetHigh {
            return "You're past your training target today"
        }
        // Past ~21:00 a prompt to go train reads wrong, so the two forward-looking
        // training lines become wind-down lines. The branches above still win at
        // night: high stress, poor recovery, and overshooting the target are all
        // just as true at 11pm as at noon.
        if timeOfDay == .night {
            if let recovery = snapshot.recovery, recovery >= 70 {
                return "Wind down — you're set for tomorrow"
            }
            if let recovery = snapshot.recovery, recovery >= 50 {
                return "Time to unwind and rest"
            }
        }
        // By afternoon the useful question stops being "should I train?" and becomes
        // "have I done enough today?", so once a target band exists we speak to the
        // day's actual load instead of recovery. Overshoot is handled above; anything
        // reaching here is at or under the top of the band. Needs a target band, so a
        // user with no training history falls through to the recovery lines.
        if timeOfDay == .afternoon || timeOfDay == .evening,
           let exertion = snapshot.exertion,
           let targetLow = snapshot.exertionTargetLow {
            if exertion >= targetLow {
                return "You've hit today's training target"
            }
            if Double(exertion) < Double(targetLow) * 0.25 {
                // Calling the day a rest day is a verdict on a finished day. In the
                // evening that's fair; at 1pm it's premature, so afternoon falls
                // through and lets the recovery lines say whether it's a day to train.
                if timeOfDay == .evening {
                    return "A rest day so far"
                }
            } else {
                return timeOfDay == .evening ? "Still room to move tonight" : "Still room to move today"
            }
        }
        if let recovery = snapshot.recovery, recovery >= 70 {
            return "Your body is ready for training"
        }
        if let recovery = snapshot.recovery, recovery >= 50 {
            return "Train, but keep it moderate"
        }
        return "Here's where your body stands"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            // Row 1: Greeting
            HStack(spacing: 5) {
                Image(systemName: greetingSymbol)
                    .font(.system(size: 12, weight: .semibold))
                    .foregroundStyle(greetingSymbolColor)

                Text(greetingText)
                    .font(.system(size: 14, weight: .semibold))
                    .foregroundStyle(.white.opacity(0.9))
                    .lineLimit(1)
                    .minimumScaleFactor(0.8)

                Spacer()

                Text(relativeUpdatedString(snapshot.updated))
                    .font(.system(size: 8))
                    .foregroundStyle(Color.white.opacity(0.38))
                    .lineLimit(1)
            }

            // Row 2: Status sentence
            Text(statusSentence)
                .font(.system(size: 14, weight: .semibold, design: .rounded))
                .foregroundStyle(Color.white.opacity(0.6))
                .lineLimit(2)
                .minimumScaleFactor(0.75)
                .fixedSize(horizontal: false, vertical: true)
                .padding(.top, 4)

            // Row 3: Four rings
            Spacer(minLength: 10)

            HStack(spacing: 0) {
                // Exertion
                VStack(spacing: 6) {
                    ZStack {
                        VectorRing(value: snapshot.exertion, kind: .exertion, lineWidth: 5,
                                   targetLow: snapshot.exertionTargetLow, targetHigh: snapshot.exertionTargetHigh)

                        Text(snapshot.exertion == nil ? "—" : "\(snapshot.exertion!)")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(VectorMetricKind.exertion.tint)
                            .monospacedDigit()
                    }
                    .frame(width: 54, height: 54)

                    Text(ScoreBand.word(for: snapshot.exertion, kind: .exertion, targetLow: snapshot.exertionTargetLow, targetHigh: snapshot.exertionTargetHigh))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)

                // Recovery
                VStack(spacing: 6) {
                    ZStack {
                        VectorRing(value: snapshot.recovery, kind: .recovery, lineWidth: 5)

                        Text(snapshot.recovery == nil ? "—" : "\(snapshot.recovery!)")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(VectorMetricKind.recovery.tint)
                            .monospacedDigit()
                    }
                    .frame(width: 54, height: 54)

                    Text(ScoreBand.word(for: snapshot.recovery, kind: .recovery))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)

                // Sleep
                VStack(spacing: 6) {
                    ZStack {
                        VectorRing(value: snapshot.sleep, kind: .sleep, lineWidth: 5)

                        Text(snapshot.sleep == nil ? "—" : "\(snapshot.sleep!)")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(VectorMetricKind.sleep.tint)
                            .monospacedDigit()
                    }
                    .frame(width: 54, height: 54)

                    Text(ScoreBand.word(for: snapshot.sleep, kind: .sleep))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)

                // Stress
                VStack(spacing: 6) {
                    ZStack {
                        VectorRing(value: snapshot.stress, kind: .stress, lineWidth: 5)

                        Text(snapshot.stress == nil ? "—" : "\(snapshot.stress!)")
                            .font(.system(size: 17, weight: .semibold, design: .rounded))
                            .foregroundStyle(VectorMetricKind.stress.tint)
                            .monospacedDigit()
                    }
                    .frame(width: 54, height: 54)

                    Text(ScoreBand.word(for: snapshot.stress, kind: .stress))
                        .font(.system(size: 8, weight: .medium))
                        .foregroundStyle(Color.white.opacity(0.6))
                        .lineLimit(1)
                        .minimumScaleFactor(0.75)
                }
                .frame(maxWidth: .infinity)
            }

            Spacer(minLength: 0)
                .frame(maxHeight: 3)
        }
        .frame(maxWidth: .infinity, maxHeight: .infinity)
        .padding(.horizontal, 2)
    }
}

// MARK: - Preview Wrapper Widgets (private scaffolding)

private struct HeroRailPreviewWidget: Widget {
    let kind: String = "HeroRailPreview"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VectorTimelineProvider()) { entry in
            VectorRingsHeroRailView(snapshot: entry.snapshot)
                .widgetBackground()
        }
        .supportedFamilies([.systemMedium])
    }
}

private struct StatusLedPreviewWidget: Widget {
    let kind: String = "StatusLedPreview"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VectorTimelineProvider()) { entry in
            VectorRingsStatusLedView(snapshot: entry.snapshot)
                .widgetBackground()
        }
        .supportedFamilies([.systemMedium])
    }
}

private struct QuadRingPreviewWidget: Widget {
    let kind: String = "QuadRingPreview"

    var body: some WidgetConfiguration {
        StaticConfiguration(kind: kind, provider: VectorTimelineProvider()) { entry in
            VectorRingsQuadRingView(snapshot: entry.snapshot)
                .purpleWidgetBackground()
        }
        .supportedFamilies([.systemMedium])
    }
}

// MARK: - Previews

#Preview("A · Hero Rail", as: .systemMedium) {
    HeroRailPreviewWidget()
} timeline: {
    let snapshot = VectorWidgetSnapshot.placeholder
    VectorEntry(date: .now, snapshot: snapshot)
}

#Preview("A · Hero Rail (Over target)", as: .systemMedium) {
    HeroRailPreviewWidget()
} timeline: {
    let snapshot = VectorWidgetSnapshot(
        updated: .now,
        recovery: 78,
        exertion: 137,
        exertionTargetLow: 55,
        exertionTargetHigh: 85,
        sleep: 72,
        sleepAsleepSeconds: 28800,
        stress: 38,
        hrv: 45.2,
        restingHR: 62,
        steps: 8234,
        recoveryHistory: [70, 72, 75, 78]
    )
    VectorEntry(date: .now, snapshot: snapshot)
}

#Preview("C · Status Led", as: .systemMedium) {
    StatusLedPreviewWidget()
} timeline: {
    let snapshot = VectorWidgetSnapshot.placeholder
    VectorEntry(date: .now, snapshot: snapshot)
}

#Preview("C · Status Led (Over target)", as: .systemMedium) {
    StatusLedPreviewWidget()
} timeline: {
    let snapshot = VectorWidgetSnapshot(
        updated: .now,
        recovery: 78,
        exertion: 137,
        exertionTargetLow: 55,
        exertionTargetHigh: 85,
        sleep: 72,
        sleepAsleepSeconds: 28800,
        stress: 38,
        hrv: 45.2,
        restingHR: 62,
        steps: 8234,
        recoveryHistory: [70, 72, 75, 78]
    )
    VectorEntry(date: .now, snapshot: snapshot)
}

#Preview("D · Quad Ring", as: .systemMedium) {
    QuadRingPreviewWidget()
} timeline: {
    VectorEntry(date: .now, snapshot: .placeholder)
}

#Preview("D · Quad Ring (Strained)", as: .systemMedium) {
    QuadRingPreviewWidget()
} timeline: {
    let snapshot = VectorWidgetSnapshot(
        updated: .now,
        recovery: 44,
        exertion: 137,
        exertionTargetLow: 55,
        exertionTargetHigh: 85,
        sleep: 38,
        stress: 78,
        recoveryHistory: [70, 72, 75, 78],
        name: "Jacob"
    )
    VectorEntry(date: .now, snapshot: snapshot)
}
