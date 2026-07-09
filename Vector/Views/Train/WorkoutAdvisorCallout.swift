import SwiftUI

/// A clean, tappable glass card with a glowing purple border. Tapping auto-applies the
/// suggested progressive-overload weight to every set of the current exercise.
struct WorkoutAdvisorCallout: View {
    let insight: ProgressionInsight
    var onApply: (() -> Void)? = nil
    var onDismiss: (() -> Void)? = nil

    @State private var applied = false
    @State private var glow = false

    private var suggested: Double { insight.suggestedWeightKg ?? 0 }
    private var current: Double { max(0, suggested - insight.deltaKg) }
    private func lbs(_ v: Double) -> String { "\(Int(v.rounded())) lb" }

    var body: some View {
        Button {
            guard !applied else { return }
            withAnimation(.spring(response: 0.4, dampingFraction: 0.8)) {
                onApply?()
                applied = true
            }
            Task {
                try? await Task.sleep(for: .seconds(2.5))
                onDismiss?()
            }
        } label: {
            HStack(spacing: 12) {
                Image(systemName: applied ? "checkmark.circle.fill" : "sparkles")
                    .font(.system(size: 18, weight: .semibold))
                    .foregroundStyle(
                        applied
                        ? AnyShapeStyle(Color.green)
                        : AnyShapeStyle(LinearGradient(colors: [.purple, .indigo], startPoint: .topLeading, endPoint: .bottomTrailing))
                    )

                VStack(alignment: .leading, spacing: 2) {
                    Text(applied ? "Overload applied" : "Apply progressive overload")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    Text(applied ? "\(lbs(suggested)) across all sets" : "\(lbs(current)) → \(lbs(suggested)) · all sets")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Spacer(minLength: 0)

                if !applied {
                    Image(systemName: "arrow.up.forward")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.purple)
                }
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 14)
            .frame(maxWidth: .infinity)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
            .overlay {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(Color.purple.opacity(0.22), lineWidth: 1)
                    .opacity(applied ? 0.4 : 1)
            }
            .shadow(color: .purple.opacity(applied ? 0 : (glow ? 0.55 : 0.3)), radius: glow ? 16 : 10)
        }
        .buttonStyle(.plain)
        .disabled(applied)
        .askVector(topicForAdvisorCallout())
        .onAppear {
            withAnimation(.easeInOut(duration: 1.7).repeatForever(autoreverses: true)) {
                glow = true
            }
        }
    }

    private func topicForAdvisorCallout() -> AdvisorTopic {
        return AdvisorTopic(
            title: "Coach Suggestion",
            icon: "sparkles",
            tintName: "indigo",
            contextLines: [
                "Progressive overload suggestion",
                "\(lbs(current)) → \(lbs(suggested))",
                insight.headline
            ],
            suggestedPrompt: "Explain this training suggestion in more detail."
        )
    }
}

#if DEBUG
#Preview("Overload Callout") {
    VStack(spacing: 16) {
        WorkoutAdvisorCallout(
            insight: ProgressionInsight(kind: .readyToProgress, detail: "", suggestedWeightKg: 140, deltaKg: 5),
            onApply: {}
        )
        WorkoutAdvisorCallout(
            insight: ProgressionInsight(kind: .plateau, detail: "", suggestedWeightKg: 55, deltaKg: 5),
            onApply: {}
        )
    }
    .padding()
    .preferredColorScheme(.dark)
}
#endif
