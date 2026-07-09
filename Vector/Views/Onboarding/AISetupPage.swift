import SwiftUI
import FoundationModels

struct AISetupPage: View {
    var onComplete: () -> Void

    private var onDeviceModel = SystemLanguageModel.default

    var body: some View {
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: 28) {
                Spacer().frame(height: 40)

                Image(systemName: "apple.intelligence")
                    .font(.system(size: 56))
                    .foregroundStyle(
                        LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                    )
                    .frame(width: 80, height: 80)

                VStack(spacing: 10) {
                    Text("Smart Insights")
                        .font(.title.bold())

                    Text("Vector uses Apple Intelligence to turn your health data into personalized advice. Everything is processed privately — your data never leaves your control.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }

                VStack(spacing: 12) {
                    aiStatusRow(
                        icon: "apple.intelligence",
                        title: "Siri AI",
                        subtitle: "Uses on-device foundational models to run analysis on your health metrics.",
                        isAvailable: onDeviceModel.availability == .available
                    )

                    aiStatusRow(
                        icon: "cloud.fill",
                        title: "Private Cloud Compute",
                        subtitle: "More powerful reasoning when Vector needs it.",
                        isAvailable: AIModel.isCloudAvailable,
                        note: "Requires iCloud+ and iPhone 17 Pro or later"
                    )
                }
                .padding(.horizontal)

                if onDeviceModel.availability != .available {
                    HStack(spacing: 10) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.yellow)
                        Text("To use smart insights, turn on Apple Intelligence in Settings. All health tracking works without it.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 12))
                    .padding(.horizontal)
                }

                Spacer().frame(height: 120)
            }
            .frame(minHeight: geo.size.height)
        }
        .scrollIndicators(.hidden)
        .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private func aiStatusRow(icon: String, title: String, subtitle: String, isAvailable: Bool, note: String? = nil) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.title3)
                .frame(width: 36, height: 36)
                .foregroundStyle(isAvailable ? .green : .yellow)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(title)
                        .font(.headline)

                    Image(systemName: isAvailable ? "checkmark.circle.fill" : "exclamationmark.triangle.fill")
                        .font(.caption)
                        .foregroundStyle(isAvailable ? .green : .yellow)
                }

                Text(subtitle)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                if let note {
                    Text(note)
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                }
            }

            Spacer()
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 16))
    }
}
