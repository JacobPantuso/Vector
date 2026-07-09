import SwiftUI

struct SignalTileView: View {
    let insight: HealthInsight
    var onTap: (() -> Void)? = nil

    var body: some View {
        VStack(spacing: 0) {
            // Top: Icon and category label
            HStack(spacing: 8) {
                Image(systemName: iconName)
                    .font(.system(size: 16, weight: .semibold))
                    .foregroundStyle(tileColor)

                Text(insight.category.capitalized)
                    .font(.caption2)
                    .foregroundStyle(tileColor)

                Spacer()
            }

            Spacer()

            // Middle: Large title text
            VStack(alignment: .leading, spacing: 0) {
                Text(insight.title)
                    .font(.headline)
                    .fontWeight(.bold)
                    .lineLimit(2)
            }

            Spacer()

            // Bottom: Severity badge
            HStack(spacing: 0) {
                Capsule()
                    .fill(tileColor.opacity(0.2))
                    .overlay(
                        Text(insight.severity.capitalized)
                            .font(.caption2)
                            .foregroundStyle(tileColor)
                            .padding(.horizontal, 10)
                            .padding(.vertical, 4)
                    )
                    .frame(height: 20)

                Spacer()
            }
        }
        .padding(14)
        .aspectRatio(1, contentMode: .fit)
        .glassEffect(.regular.tint(tileColor.opacity(0.22)), in: .rect(cornerRadius: 18))
        .onTapGesture {
            onTap?()
        }
    }

    private var tileColor: Color {
        switch insight.severity.lowercased() {
        case "warning":
            return .orange
        case "suggestion":
            return .green
        default:
            return .cyan
        }
    }

    private var iconName: String {
        switch insight.severity.lowercased() {
        case "warning":
            return "exclamationmark.triangle.fill"
        case "suggestion":
            return "lightbulb.fill"
        default:
            return "info.circle.fill"
        }
    }
}

struct SignalDetailSheet: View {
    let insight: HealthInsight
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    // Header GlassCard
                    GlassCard(tint: tileColor.opacity(0.2), cornerRadius: 22, isInteractive: false) {
                        HStack(spacing: 12) {
                            Image(systemName: iconName)
                                .font(.title)
                                .foregroundStyle(tileColor)

                            VStack(alignment: .leading, spacing: 4) {
                                Text(insight.title)
                                    .font(.title3.bold())

                                Text(insight.category.capitalized)
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            Spacer()
                        }
                    }

                    // Body section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What this means")
                            .font(.title3.bold())

                        Text(insight.body)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .glassEffect(.regular, in: .rect(cornerRadius: 16))

                    // Recommendation section
                    VStack(alignment: .leading, spacing: 12) {
                        Text("What to do")
                            .font(.title3.bold())

                        Text(insight.recommendation)
                            .font(.body)
                            .foregroundStyle(.secondary)
                    }
                    .padding(16)
                    .glassEffect(.regular.tint(tileColor.opacity(0.15)), in: .rect(cornerRadius: 16))
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .navigationTitle(insight.category.capitalized)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button(action: { dismiss() }) {
                        Image(systemName: "xmark.circle.fill")
                            .font(.title3)
                            .foregroundStyle(.secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }

    private var tileColor: Color {
        switch insight.severity.lowercased() {
        case "warning":
            return .orange
        case "suggestion":
            return .green
        default:
            return .cyan
        }
    }

    private var iconName: String {
        switch insight.severity.lowercased() {
        case "warning":
            return "exclamationmark.triangle.fill"
        case "suggestion":
            return "lightbulb.fill"
        default:
            return "info.circle.fill"
        }
    }
}

#Preview("SignalTileView - Info") {
    let sampleInsight = HealthInsight(
        category: "sleep",
        severity: "info",
        title: "Good sleep consistency",
        body: "Your sleep schedule has been consistent this week.",
        recommendation: "Maintain your current bedtime routine."
    )

    return SignalTileView(insight: sampleInsight)
        .padding()
}

#Preview("SignalTileView - Warning") {
    let sampleInsight = HealthInsight(
        category: "hydration",
        severity: "warning",
        title: "Low water intake",
        body: "You haven't reached your daily hydration goal.",
        recommendation: "Drink more water throughout the day."
    )

    return SignalTileView(insight: sampleInsight)
        .padding()
}

#Preview("SignalTileView - Suggestion") {
    let sampleInsight = HealthInsight(
        category: "activity",
        severity: "suggestion",
        title: "Increase movement",
        body: "You could benefit from more daily activity.",
        recommendation: "Try a 10-minute walk after lunch."
    )

    return SignalTileView(insight: sampleInsight)
        .padding()
}

#Preview("SignalDetailSheet") {
    let sampleInsight = HealthInsight(
        category: "heart rate",
        severity: "warning",
        title: "Elevated resting heart rate",
        body: "Your average resting heart rate has increased by 8 bpm compared to last week, which may indicate increased stress or reduced fitness.",
        recommendation: "Consider meditation, yoga, or stress management techniques. Ensure adequate rest and recovery."
    )

    return SignalDetailSheet(insight: sampleInsight)
}
