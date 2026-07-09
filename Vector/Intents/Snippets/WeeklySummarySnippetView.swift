import SwiftUI

struct WeeklySummarySnippetView: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Weekly Summary")
                .font(.headline)

            HStack(spacing: 16) {
                summaryItem(icon: "heart.fill", color: .green, label: "Recovery", value: "75%")
                summaryItem(icon: "flame.fill", color: .orange, label: "Exertion", value: "62")
                summaryItem(icon: "moon.fill", color: .blue, label: "Sleep", value: "7.2h")
            }
        }
        .padding()
    }

    private func summaryItem(icon: String, color: Color, label: String, value: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .foregroundStyle(color)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}
