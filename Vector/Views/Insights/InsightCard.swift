import SwiftUI

struct InsightCard: View {
    let insight: HealthInsight

    private var severityColor: Color {
        switch insight.severity {
        case "warning":
            return .orange
        case "suggestion":
            return .green
        default:
            return .blue
        }
    }

    private var severityIcon: String {
        switch insight.severity {
        case "warning":
            return "exclamationmark.circle.fill"
        case "suggestion":
            return "lightbulb.fill"
        default:
            return "info.circle.fill"
        }
    }

    var body: some View {
        GlassCard(tint: severityColor) {
            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Image(systemName: severityIcon)
                        .font(.title3)
                        .foregroundStyle(severityColor)

                    Text(insight.category)
                        .font(.caption)
                        .fontWeight(.semibold)
                        .foregroundStyle(severityColor)

                    Spacer()

                    Text(insight.date, style: .relative)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }

                Text(insight.title)
                    .font(.headline)

                Text(insight.body)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                DisclosureGroup("Recommendation") {
                    Text(insight.recommendation)
                        .font(.caption)
                        .italic()
                        .foregroundStyle(.secondary)
                        .padding(.top, 8)
                }
                .font(.caption)
                .fontWeight(.semibold)
            }
        }
    }
}

#Preview {
    VStack(spacing: 16) {
        InsightCard(
            insight: HealthInsight(
                category: "Recovery",
                severity: "suggestion",
                title: "Time to rest",
                body: "Your recovery metrics suggest you need more time to recover.",
                recommendation: "Take a rest day and focus on sleep and hydration."
            )
        )

        InsightCard(
            insight: HealthInsight(
                category: "Training",
                severity: "warning",
                title: "High training load",
                body: "Your training load is above recommended levels.",
                recommendation: "Consider reducing intensity or duration of your workouts."
            )
        )

        InsightCard(
            insight: HealthInsight(
                category: "Sleep",
                severity: "info",
                title: "Sleep quality improving",
                body: "Your sleep quality has improved over the past week.",
                recommendation: "Continue your current sleep routine for optimal recovery."
            )
        )
    }
    .padding()
}
