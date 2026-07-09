import SwiftUI

struct SleepSnippetView: View {
    let hours: Double
    let quality: String

    var body: some View {
        HStack(spacing: 16) {
            Image(systemName: "moon.fill")
                .font(.title)
                .foregroundStyle(.blue)
                .frame(width: 64, height: 64)

            VStack(alignment: .leading, spacing: 4) {
                Text("Sleep")
                    .font(.headline)
                Text(String(format: "%.1fh · %@", hours, quality))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding()
    }
}
