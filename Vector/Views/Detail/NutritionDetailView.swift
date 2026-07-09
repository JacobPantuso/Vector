import SwiftUI
import Charts

struct NutritionDetailView: View {
    let summary: NutritionSummary

    private var totalMacros: Double {
        summary.protein + summary.carbs + summary.fat
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 24) {
                headerSection
                interpretationSection
                macroChartSection
                energyBalanceSection
                macroBreakdownSection
            }
            .padding(.horizontal, 20)
            .padding(.bottom, 20)
        }
        .navigationTitle("Nutrition")
    }

    private var headerSection: some View {
        HStack(spacing: 20) {
            TickRing(
                progress: min(summary.caloriesConsumed / 2500, 1),
                colors: [.green, .mint],
                size: 150
            ) {
                VStack(spacing: 2) {
                    Text(String(format: "%.0f", summary.caloriesConsumed))
                        .font(.system(size: 28, weight: .bold, design: .rounded))
                        .monospacedDigit()
                    Text("kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            VStack(alignment: .leading, spacing: 12) {
                Label {
                    Text("Energy Intake")
                        .font(.headline)
                } icon: {
                    Image(systemName: "fork.knife")
                        .foregroundStyle(.green)
                }

                Text("You're in a \(summary.energyBalance.label.lowercased()) today with a net of \(String(format: "%.0f", summary.netEnergy)) kcal.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(.green.opacity(0.2)), in: .rect(cornerRadius: 20))
    }

    private var interpretationSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("What this means")
                .font(.headline)

            Text("Calories tell the broad picture, but the macro split shows how well you're supporting your goal. Use this alongside your goal and training day to decide whether to eat more, less, or stay steady.")
                .font(.subheadline)
                .foregroundStyle(.secondary)

            HStack(spacing: 12) {
                infoChip(title: "Net", value: String(format: "%+.0f kcal", summary.netEnergy))
                infoChip(title: "Goal", value: summary.energyBalance.label)
                infoChip(title: "Protein", value: String(format: "%.0fg", summary.protein))
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var macroChartSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Macronutrients")
                .font(.headline)

            Chart {
                SectorMark(angle: .value("Protein", summary.protein), innerRadius: .ratio(0.6))
                    .foregroundStyle(.blue)

                SectorMark(angle: .value("Carbs", summary.carbs), innerRadius: .ratio(0.6))
                    .foregroundStyle(.orange)

                SectorMark(angle: .value("Fat", summary.fat), innerRadius: .ratio(0.6))
                    .foregroundStyle(.teal)
            }
            .frame(height: 200)

            HStack(spacing: 16) {
                legendItem("Protein", .blue)
                legendItem("Carbs", .orange)
                legendItem("Fat", .teal)
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var energyBalanceSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Energy Balance")
                .font(.headline)

            HStack(spacing: 0) {
                VStack(spacing: 4) {
                    Image(systemName: "arrow.down.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.green)
                    Text(String(format: "%.0f", summary.caloriesConsumed))
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("Consumed")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Image(systemName: "arrow.up.circle.fill")
                        .font(.title2)
                        .foregroundStyle(.red)
                    Text(String(format: "%.0f", summary.caloriesBurned))
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("Burned")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)

                VStack(spacing: 4) {
                    Image(systemName: "equal.circle.fill")
                        .font(.title2)
                        .foregroundStyle(summary.energyBalance.color)
                    Text(String(format: "%+.0f", summary.netEnergy))
                        .font(.title3.bold())
                        .monospacedDigit()
                    Text("Net")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private var macroBreakdownSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Macro Breakdown")
                .font(.headline)

            macroRow("Protein", grams: summary.protein, color: .blue, calsPerGram: 4)
            macroRow("Carbohydrates", grams: summary.carbs, color: .orange, calsPerGram: 4)
            macroRow("Fat", grams: summary.fat, color: .teal, calsPerGram: 9)
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private func macroRow(_ label: String, grams: Double, color: Color, calsPerGram: Double) -> some View {
        HStack(spacing: 12) {
            Circle()
                .fill(color)
                .frame(width: 10, height: 10)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.subheadline)
                Text(String(format: "%.0f kcal", grams * calsPerGram))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Text(String(format: "%.0fg", grams))
                .font(.subheadline.bold())
                .monospacedDigit()

            if totalMacros > 0 {
                Text(String(format: "%.0f%%", (grams / totalMacros) * 100))
                    .font(.caption)
                    .monospacedDigit()
                    .foregroundStyle(.secondary)
                    .frame(width: 36, alignment: .trailing)
            }
        }
    }

    private func legendItem(_ label: String, _ color: Color) -> some View {
        HStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
    }

    private func infoChip(title: String, value: String) -> some View {
        VStack(alignment: .leading, spacing: 4) {
            Text(title)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold())
                .monospacedDigit()
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }
}

#if DEBUG
#Preview {
    NavigationStack {
        NutritionDetailView(summary: .mock)
    }
    .environment(HealthKitService.preview)
}
#endif
