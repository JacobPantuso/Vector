import SwiftUI

/// One cross-engine connection line: a tinted icon + explanatory text.
struct ConnectionInsightRow: View {
    let insight: ConnectionInsight

    var body: some View {
        HStack(alignment: .top, spacing: 10) {
            Image(systemName: insight.icon)
                .font(.caption)
                .foregroundStyle(insight.tint)
                .frame(width: 18)
            Text(insight.text)
                .font(.caption)
                .foregroundStyle(.secondary)
                .fixedSize(horizontal: false, vertical: true)
            Spacer(minLength: 0)
        }
        .askVector(topicForConnection(insight))
    }

    private func topicForConnection(_ insight: ConnectionInsight) -> AdvisorTopic {
        return AdvisorTopic(
            title: "Data Connection",
            icon: insight.icon,
            tintName: colorNameForColor(insight.tint),
            contextLines: [insight.text],
            suggestedPrompt: "Tell me more about this connection in my data."
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

/// A titled "Connections" group to drop inside a detail view's top insight card.
/// Renders nothing when there are no insights.
struct ConnectionsBlock: View {
    let insights: [ConnectionInsight]

    var body: some View {
        if !insights.isEmpty {
            VStack(alignment: .leading, spacing: 8) {
                Text("Connections")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ForEach(insights) { insight in
                    ConnectionInsightRow(insight: insight)
                }
            }
        }
    }
}
