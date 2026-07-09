import SwiftUI

struct NutritionCard: View {
    let summary: NutritionSummary
    let progress: Double

    var body: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Image(systemName: "fork.knife")
                    .font(.title3)
                    .foregroundStyle(.green)
                Spacer()
                Text("Nutrition")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.0f kcal", summary.caloriesConsumed))
                .font(.system(size: 40, weight: .bold, design: .rounded))
                .monospacedDigit()

            CardProgressBar(value: progress, tint: .green)

            HStack {
                Text(summary.energyBalance.label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
            }
        }
        .padding(16)
        .frame(maxWidth: .infinity, alignment: .leading)
        .aspectRatio(1, contentMode: .fit)
        .glassEffect(.regular.tint(.green.opacity(0.3)), in: .rect(cornerRadius: 20))
    }
}
