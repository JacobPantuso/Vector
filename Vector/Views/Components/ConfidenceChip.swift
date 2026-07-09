import SwiftUI

/// Small chip communicating how much personal history backs a score (0…1 confidence).
/// Reaches "High confidence" near ~21 days; below that it shows a calibrating countdown.
struct ConfidenceChip: View {
    let confidence: Double
    var fullDays: Int = 21
    @State private var showExplanation = false

    private var tier: ConfidenceTier { ConfidenceTier(confidence: confidence) }
    private var daysLogged: Int { Int((confidence * Double(fullDays)).rounded()) }
    private var daysRemaining: Int { max(0, fullDays - daysLogged) }
    private var tierColor: Color { tier == .low ? .orange : (tier == .moderate ? .yellow : .green) }

    var body: some View {
        Button {
            showExplanation = true
        } label: {
            HStack(spacing: 5) {
                Image(systemName: tier == .high ? "checkmark.seal.fill" : "hourglass")
                    .font(.caption2)
            }
            .foregroundStyle(.secondary)
            .padding(.horizontal, 10)
            .padding(.vertical, 5)
            .glassEffect(.regular.tint(tierColor), in: .capsule)
        }
        .buttonStyle(.plain)
        .accessibilityHint("Learn how confidence is calculated")
        .sheet(isPresented: $showExplanation) {
            ConfidenceExplanationSheet(
                confidence: confidence,
                tier: tier,
                daysLogged: daysLogged,
                daysRemaining: daysRemaining,
                fullDays: fullDays
            )
        }
    }
}

/// Sheet explaining the confidence score and how it's calculated.
private struct ConfidenceExplanationSheet: View {
    let confidence: Double
    let tier: ConfidenceTier
    let daysLogged: Int
    let daysRemaining: Int
    let fullDays: Int

    private var tierColor: Color {
        tier == .low ? .orange : (tier == .moderate ? .yellow : .green)
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                // Section A: Hero
                VStack(spacing: 14) {
                    Image(systemName: tier == .high ? "checkmark.seal.fill" : "hourglass")
                        .font(.system(size: 30, weight: .medium))
                        .foregroundStyle(tierColor.gradient)
                        .frame(width: 68, height: 68)
                        .background(tierColor.opacity(0.15), in: .circle)

                    Text(tier.label)
                        .font(.title3.bold())

                    Text("Vector gets smarter about you with every day of data.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }

                // Section B: Progress Card
                VStack(alignment: .leading, spacing: 12) {
                    HStack(alignment: .firstTextBaseline, spacing: 5) {
                        Text("\(daysLogged)")
                            .font(.title2.bold())
                            .foregroundStyle(tierColor)

                        Text("of \(fullDays) days of data")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)

                        Spacer()

                        if tier == .high {
                            Text("Complete")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.green)
                        } else {
                            Text("\(daysRemaining) to go")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    // Custom progress bar
                    GeometryReader { geo in
                        ZStack(alignment: .leading) {
                            Capsule()
                                .fill(.quaternary)

                            Capsule()
                                .fill(tierColor.gradient)
                                .frame(width: geo.size.width * min(max(confidence, 0), 1))
                        }
                    }
                    .frame(height: 10)
                }
                .padding(18)
                .background(.fill.tertiary, in: .rect(cornerRadius: 20))

                // Section C: How it works
                VStack(alignment: .leading, spacing: 20) {
                    infoRow(
                        icon: "calendar.badge.clock",
                        tint: .blue,
                        title: "Learns over 21 days",
                        detail: "Each new day of health data refines your personal baselines from your own history."
                    )

                    infoRow(
                        icon: "person.fill.checkmark",
                        tint: .purple,
                        title: "Personal, not average",
                        detail: "Higher confidence means your scores lean on your data instead of population defaults."
                    )

                    if tier == .high {
                        infoRow(
                            icon: "checkmark.seal.fill",
                            tint: .green,
                            title: "Fully personalized",
                            detail: "Your scores are now built entirely on your own baselines."
                        )
                    } else {
                        infoRow(
                            icon: "hourglass",
                            tint: .orange,
                            title: "\(daysRemaining) days to go",
                            detail: "Keep wearing your watch — your scores get more accurate as your history grows."
                        )
                    }
                }
            }
            .padding(.horizontal, 24)
            .padding(.top, 32)
            .padding(.bottom, 24)
        }
        .presentationDetents([.medium])
        .presentationDragIndicator(.visible)
        .presentationBackground(.regularMaterial)
    }

    @ViewBuilder
    private func infoRow(icon: String, tint: Color, title: String, detail: String) -> some View {
        HStack(alignment: .top, spacing: 14) {
            Image(systemName: icon)
                .font(.system(size: 15, weight: .semibold))
                .foregroundStyle(tint)
                .frame(width: 34, height: 34)
                .background(tint.opacity(0.12), in: .rect(cornerRadius: 10))

            VStack(alignment: .leading, spacing: 3) {
                Text(title)
                    .font(.subheadline.weight(.semibold))

                Text(detail)
                    .font(.footnote)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}
