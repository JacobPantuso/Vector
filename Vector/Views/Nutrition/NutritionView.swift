import SwiftUI
import UIKit

struct NutritionView: View {
    @Environment(HealthKitService.self) var service
    @Environment(FoodLogService.self) private var foodLogService
    @State private var imageService = FoodImageService.shared

    @AppStorage("nutritionTargetCalories") private var calorieTargetOverride = 0.0
    @AppStorage("nutritionTargetProtein") private var proteinTargetOverride = 0.0
    @AppStorage("nutritionTargetCarbs") private var carbTargetOverride = 0.0
    @AppStorage("nutritionTargetFat") private var fatTargetOverride = 0.0
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.weightKg) private var weightKg = 0.0
    @AppStorage(UserProfileStorage.heightCm) private var heightCm = 0.0

    @State private var showingLogSheet = false
    @State private var showingScheduleManager = false
    @State private var showingTargetsEditor = false
    @State private var logSheetInitialTab = 0
    @State private var editingEntry: FoodLogEntry?

    private var targets: NutritionTargets {
        let overrides = NutritionTargets(
            calories: calorieTargetOverride, protein: proteinTargetOverride,
            carbs: carbTargetOverride, fat: fatTargetOverride
        )
        return NutritionTargets.compute(
            goal: FitnessGoal(rawValue: goalRaw) ?? UserProfile.defaultGoal,
            ageRange: AgeRange(rawValue: ageRangeRaw) ?? UserProfile.defaultAgeRange,
            trainingDaysPerWeek: trainingDays,
            weightKg: weightKg, heightCm: heightCm,
            overrides: overrides
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    summarySection
                    schedulePromptSection
                    todayLogSection
                    healthKitNutritionSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .gradientHeader()
            .navigationTitle("Nutrition")
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    Button(action: { showingScheduleManager = true }) {
                        Image(systemName: "clock.badge.checkmark")
                    }
                    Menu {
                        Button { logSheetInitialTab = 0; showingLogSheet = true } label: { Label("Analyze with AI", systemImage: "sparkles") }
                        Button { logSheetInitialTab = 1; showingLogSheet = true } label: { Label("Log from Photo", systemImage: "camera.fill") }
                        Button { logSheetInitialTab = 2; showingLogSheet = true } label: { Label("Quick Add", systemImage: "bolt.fill") }
                        Divider()
                        Button { logSheetInitialTab = 3; showingLogSheet = true } label: { Label("My Recipes", systemImage: "book.closed.fill") }
                    } label: {
                        Image(systemName: "plus")
                    }
                }
            }
            .sheet(isPresented: $showingLogSheet) {
                FoodLogSheet(foodLogService: foodLogService, initialTab: logSheetInitialTab)
            }
            .sheet(isPresented: $showingScheduleManager) {
                NutritionScheduleManager(foodLogService: foodLogService)
            }
            .sheet(isPresented: $showingTargetsEditor) {
                TargetsEditorSheet()
            }
            .sheet(item: $editingEntry) { entry in
                FoodEntryEditSheet(entry: entry, foodLogService: foodLogService)
            }
            .task {
                await service.refreshIfStale()
                foodLogService.autoLogScheduledMealsIfNeeded()
            }
        }
    }

    // MARK: - Summary + targets rings

    private var summarySection: some View {
        let calConsumed = foodLogService.todayCalories + (service.nutritionSummary?.caloriesConsumed ?? 0)
        let p = foodLogService.todayProtein + (service.nutritionSummary?.protein ?? 0)
        let c = foodLogService.todayCarbs + (service.nutritionSummary?.carbs ?? 0)
        let f = foodLogService.todayFat + (service.nutritionSummary?.fat ?? 0)
        return GlassCard(tint: .green.opacity(0.18), cornerRadius: 24) {
            VStack(spacing: 18) {
                HStack(alignment: .top) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(String(format: "%.0f", calConsumed))
                            .font(.system(size: 34, weight: .bold, design: .rounded)).monospacedDigit()
                        Text(String(format: "of %.0f kcal  ·  %.0f left", targets.calories, max(0, targets.calories - calConsumed)))
                            .font(.caption).foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button(action: { showingTargetsEditor = true }) {
                        Image(systemName: "slider.horizontal.3").font(.title3).foregroundStyle(.green)
                    }
                    .buttonStyle(.plain)
                }
                ProgressView(value: min(calConsumed, targets.calories), total: max(1, targets.calories))
                    .tint(.green)
                HStack(spacing: 12) {
                    TargetRing(value: p, target: targets.protein, label: "Protein", color: .blue)
                    TargetRing(value: c, target: targets.carbs, label: "Carbs", color: .orange)
                    TargetRing(value: f, target: targets.fat, label: "Fat", color: .purple)
                }
            }
        }
    }

    @ViewBuilder
    private var schedulePromptSection: some View {
        let enabled = foodLogService.schedules.filter { $0.isEnabled && !$0.items.isEmpty }
        if !enabled.isEmpty {
            Button(action: { showingScheduleManager = true }) {
                HStack(spacing: 8) {
                    Image(systemName: "clock.badge.checkmark").foregroundStyle(.green)
                    Text("\(enabled.count) scheduled meal\(enabled.count == 1 ? "" : "s")")
                        .font(.caption.bold()).foregroundStyle(.primary)
                    Spacer()
                    Text("Manage").font(.caption).foregroundStyle(.secondary)
                    Image(systemName: "chevron.right").font(.caption2).foregroundStyle(.tertiary)
                }
                .padding(12)
                .glassEffect(.regular.tint(.green.opacity(0.12)), in: .rect(cornerRadius: 12))
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Today's log

    private var todayLogSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Today's Log").font(.title3.bold())

            if foodLogService.todayEntries.isEmpty {
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 12) {
                        Image(systemName: "fork.knife").font(.title).foregroundStyle(.secondary)
                        Text("No food logged yet").font(.subheadline.bold())
                        Text("Tap + to add").font(.caption).foregroundStyle(.secondary)
                    }
                    .frame(maxWidth: .infinity).padding(20)
                }
            } else {
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 0) {
                        ForEach(foodLogService.todayEntries) { entry in
                            Button(action: { editingEntry = entry }) {
                                HStack(spacing: 12) {
                                    foodThumb(entry)
                                    VStack(alignment: .leading, spacing: 2) {
                                        Text(entry.name).font(.body).foregroundStyle(.primary)
                                        sourceLabel(for: entry.source)
                                    }
                                    Spacer()
                                    Text("\(Int(entry.calories)) kcal")
                                        .font(.subheadline.bold()).monospacedDigit().foregroundStyle(.primary)
                                    Button(role: .destructive) {
                                        foodLogService.remove(entry)
                                    } label: {
                                        Image(systemName: "trash").font(.caption)
                                    }
                                    .buttonStyle(.plain)
                                }
                                .padding(.vertical, 10)
                            }
                            .buttonStyle(.plain)
                            if entry.id != foodLogService.todayEntries.last?.id { Divider() }
                        }
                    }
                }
            }
        }
    }

    private func foodThumb(_ entry: FoodLogEntry) -> some View {
        Group {
            if let img = imageService.image(for: entry.id) {
                Image(uiImage: img).resizable().scaledToFill()
            } else {
                ZStack {
                    Rectangle().fill(.green.opacity(0.12))
                    Image(systemName: "fork.knife").font(.caption).foregroundStyle(.green)
                }
            }
        }
        .frame(width: 44, height: 44)
        .clipShape(RoundedRectangle(cornerRadius: 10))
    }

    private func sourceLabel(for source: FoodLogSource) -> some View {
        let (label, color): (String, Color) = switch source {
        case .manual:   ("Typed", .secondary)
        case .photo:    ("Photo", .cyan)
        case .recipe:   ("Recipe", .purple)
        case .quickAdd: ("Quick Add", .orange)
        case .schedule: ("Auto", .green)
        }
        return Text(label)
            .font(.caption2.bold())
            .foregroundStyle(source == .manual ? Color.secondary : color)
    }

    private var healthKitNutritionSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("From Health App").font(.title3.bold())
            if let summary = service.nutritionSummary {
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(String(format: "%.0f", summary.caloriesConsumed))
                                    .font(.title2.bold()).monospacedDigit()
                                Text("kcal consumed").font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                        HStack(spacing: 12) {
                            macroGridItem(label: "Protein", value: summary.protein, color: .blue)
                            macroGridItem(label: "Carbs", value: summary.carbs, color: .orange)
                            macroGridItem(label: "Fat", value: summary.fat, color: .purple)
                        }
                    }
                }
            }
        }
    }

    private func macroGridItem(label: String, value: Double, color: Color) -> some View {
        VStack(spacing: 4) {
            Circle().fill(color).frame(width: 8, height: 8)
            Text(label).font(.caption2).foregroundStyle(.secondary)
            Text(String(format: "%.0fg", value)).font(.caption.bold()).monospacedDigit()
        }.frame(maxWidth: .infinity)
    }
}

// MARK: - Target ring

private struct TargetRing: View {
    let value: Double
    let target: Double
    let label: String
    let color: Color

    private var pct: Double { target > 0 ? min(1, value / target) : 0 }

    var body: some View {
        VStack(spacing: 6) {
            ZStack {
                Circle().stroke(color.opacity(0.15), lineWidth: 7)
                Circle().trim(from: 0, to: pct)
                    .stroke(color.gradient, style: StrokeStyle(lineWidth: 7, lineCap: .round))
                    .rotationEffect(.degrees(-90))
                    .animation(.spring(duration: 0.4), value: pct)
                VStack(spacing: 0) {
                    Text("\(Int(value))").font(.subheadline.bold().monospacedDigit())
                    Text("/\(Int(target))g").font(.caption2).foregroundStyle(.secondary)
                }
            }
            .frame(width: 78, height: 78)
            Text(label).font(.caption2).foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Targets editor

private struct TargetsEditorSheet: View {
    @Environment(\.dismiss) private var dismiss
    @AppStorage("nutritionTargetCalories") private var calories = 0.0
    @AppStorage("nutritionTargetProtein") private var protein = 0.0
    @AppStorage("nutritionTargetCarbs") private var carbs = 0.0
    @AppStorage("nutritionTargetFat") private var fat = 0.0

    var body: some View {
        NavigationStack {
            Form {
                Section {
                    Text("Leave a field at 0 to use Vector's computed target based on your profile and goal.")
                        .font(.caption).foregroundStyle(.secondary)
                }
                Section("Daily Targets") {
                    targetRow("Calories", $calories, "kcal")
                    targetRow("Protein", $protein, "g")
                    targetRow("Carbs", $carbs, "g")
                    targetRow("Fat", $fat, "g")
                }
                Section {
                    Button("Reset to Computed", role: .destructive) {
                        calories = 0; protein = 0; carbs = 0; fat = 0
                    }
                }
            }
            .navigationTitle("Nutrition Targets")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .confirmationAction) { Button("Done") { dismiss() } }
            }
        }
    }

    private func targetRow(_ label: String, _ value: Binding<Double>, _ unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", value: value, format: .number)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit).foregroundStyle(.secondary)
        }
    }
}

// MARK: - Entry edit

private struct FoodEntryEditSheet: View {
    let entry: FoodLogEntry
    let foodLogService: FoodLogService
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") { TextField("Name", text: $name) }
                Section("Nutrition") {
                    field("Calories", $calories, "kcal")
                    field("Protein", $protein, "g")
                    field("Carbs", $carbs, "g")
                    field("Fat", $fat, "g")
                }
            }
            .navigationTitle("Edit Entry")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .confirmationAction) { Button("Save") { save(); dismiss() } }
            }
            .onAppear(perform: load)
            .presentationDetents([.medium, .large])
        }
    }

    private func field(_ label: String, _ text: Binding<String>, _ unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text).keyboardType(.decimalPad).multilineTextAlignment(.trailing).frame(maxWidth: 90)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private func load() {
        name = entry.name
        calories = String(format: "%.0f", entry.calories)
        protein = String(format: "%.0f", entry.protein)
        carbs = String(format: "%.0f", entry.carbs)
        fat = String(format: "%.0f", entry.fat)
    }

    private func save() {
        var updated = entry
        updated.name = name.isEmpty ? entry.name : name
        updated.calories = Double(calories) ?? entry.calories
        updated.protein = Double(protein) ?? entry.protein
        updated.carbs = Double(carbs) ?? entry.carbs
        updated.fat = Double(fat) ?? entry.fat
        foodLogService.update(updated)
    }
}

#if DEBUG
#Preview {
    NutritionView()
        .environment(HealthKitService())
        .environment(FoodLogService.shared)
}
#endif
