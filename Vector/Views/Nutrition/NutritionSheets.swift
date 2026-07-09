import SwiftUI
import PhotosUI
import Vision

// MARK: - Food Log Sheet

struct FoodLogSheet: View {
    let foodLogService: FoodLogService
    var initialTab: Int = 0
    @Environment(\.dismiss) private var dismiss
    @State private var selectedTab = 0
    @State private var descriptionText = ""
    @State private var selectedPhotoItem: PhotosPickerItem?
    @State private var selectedImage: UIImage?
    @State private var foodEstimate: FoodEstimate?
    @State private var estimateSource: NutritionSource?
    @State private var isAnalyzing = false
    @State private var errorMessage: String?

    @State private var quickName = ""
    @State private var quickCalories = ""
    @State private var quickProtein = ""
    @State private var quickCarbs = ""
    @State private var quickFat = ""

    @State private var showingNewRecipe = false

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                Picker("Method", selection: $selectedTab) {
                    Text("AI").tag(0)
                    Text("Photo").tag(1)
                    Text("Quick").tag(2)
                    Text("Recipes").tag(3)
                }
                .pickerStyle(.segmented)
                .padding()

                ScrollView {
                    VStack(spacing: 16) {
                        switch selectedTab {
                        case 0: aiEntryTab
                        case 1: photoEntryTab
                        case 2: quickAddTab
                        default: recipesTab
                        }
                    }
                    .padding()
                }
            }
            .navigationTitle("Log Food")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .navigationBarLeading) { Button("Done") { dismiss() } }
            }
            .onAppear { selectedTab = initialTab }
        }
    }

    private var aiEntryTab: some View {
        VStack(spacing: 16) {
            GlassCard(cornerRadius: 20) {
                TextField("e.g. chicken burrito bowl from Chipotle", text: $descriptionText, axis: .vertical)
                    .textFieldStyle(.plain).lineLimit(3...8)
            }
            Button(action: analyzeText) {
                HStack {
                    if isAnalyzing { ProgressView().scaleEffect(0.8) }
                    Image(systemName: "sparkles")
                    Text(isAnalyzing ? "Analyzing…" : "Analyze with AI")
                }
                .frame(maxWidth: .infinity).padding(12)
                .background(.blue).foregroundColor(.white).cornerRadius(12)
            }
            .disabled(descriptionText.isEmpty || isAnalyzing)
            if let error = errorMessage { errorView(error) }
            if let estimate = foodEstimate { previewCard(estimate: estimate, source: .manual) }
        }
    }

    private var photoEntryTab: some View {
        VStack(spacing: 16) {
            PhotosPicker(selection: $selectedPhotoItem, matching: .images) {
                HStack { Image(systemName: "photo.fill"); Text("Choose Photo") }
                    .frame(maxWidth: .infinity).padding(12)
                    .background(.blue).foregroundColor(.white).cornerRadius(12)
            }
            .onChange(of: selectedPhotoItem) { _, newValue in
                Task {
                    if let newValue, let data = try? await newValue.loadTransferable(type: Data.self),
                       let uiImage = UIImage(data: data) {
                        selectedImage = uiImage
                        await analyzePhoto(uiImage)
                    }
                }
            }
            if let image = selectedImage {
                Image(uiImage: image).resizable().scaledToFit().frame(height: 200).cornerRadius(12)
            }
            if isAnalyzing { HStack { ProgressView(); Text("Analyzing food…").font(.caption) } }
            if let error = errorMessage { errorView(error) }
            if let estimate = foodEstimate { previewCard(estimate: estimate, source: .photo) }
        }
    }

    private var quickAddTab: some View {
        VStack(spacing: 16) {
            GlassCard(cornerRadius: 20) {
                VStack(spacing: 12) {
                    TextField("Name (e.g. Protein Bar)", text: $quickName).textFieldStyle(.plain)
                    Divider()
                    quickRow("Calories", $quickCalories, "kcal")
                    quickRow("Protein", $quickProtein, "g")
                    quickRow("Carbs", $quickCarbs, "g")
                    quickRow("Fat", $quickFat, "g")
                }
            }
            Button(action: addQuickEntry) {
                Text("Add to Log").frame(maxWidth: .infinity).padding(12)
                    .background(.orange).foregroundColor(.white).cornerRadius(12)
            }
            .disabled(quickName.isEmpty || quickCalories.isEmpty)
        }
    }

    private func quickRow(_ label: String, _ text: Binding<String>, _ unit: String) -> some View {
        HStack {
            Text(label).foregroundStyle(.secondary)
            Spacer()
            TextField("0", text: text).multilineTextAlignment(.trailing).keyboardType(.decimalPad).frame(width: 70)
            Text(unit).foregroundStyle(.secondary)
        }
    }

    private var recipesTab: some View {
        VStack(spacing: 16) {
            Button(action: { showingNewRecipe = true }) {
                Label("Create New Recipe", systemImage: "plus.circle")
                    .frame(maxWidth: .infinity).padding(12)
                    .background(.purple.opacity(0.15)).foregroundColor(.purple).cornerRadius(12)
            }
            if foodLogService.customRecipes.isEmpty {
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 8) {
                        Image(systemName: "book.closed").font(.title2).foregroundStyle(.secondary)
                        Text("No saved recipes").font(.subheadline.bold())
                        Text("Create a recipe to reuse meals quickly.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                    }
                    .frame(maxWidth: .infinity).padding(20)
                }
            } else {
                ForEach(foodLogService.customRecipes) { recipe in
                    GlassCard(cornerRadius: 16) {
                        HStack {
                            VStack(alignment: .leading, spacing: 4) {
                                Text(recipe.name).font(.headline)
                                Text(String(format: "%.0f kcal  •  %.0fg P  •  %.0fg C  •  %.0fg F", recipe.totalCalories, recipe.totalProtein, recipe.totalCarbs, recipe.totalFat))
                                    .font(.caption).foregroundStyle(.secondary)
                                Text("\(recipe.ingredients.count) ingredient\(recipe.ingredients.count == 1 ? "" : "s")")
                                    .font(.caption2).foregroundStyle(.tertiary)
                            }
                            Spacer()
                            VStack(spacing: 8) {
                                Button(action: { foodLogService.logRecipe(recipe); dismiss() }) {
                                    Text("Log").font(.caption.bold())
                                        .padding(.horizontal, 12).padding(.vertical, 6)
                                        .background(.purple).foregroundColor(.white).cornerRadius(8)
                                }
                                Button(role: .destructive, action: { foodLogService.removeRecipe(recipe) }) {
                                    Image(systemName: "trash").font(.caption)
                                }
                            }
                        }
                    }
                }
            }
        }
        .sheet(isPresented: $showingNewRecipe) { NewRecipeSheet(foodLogService: foodLogService) }
    }

    private func errorView(_ message: String) -> some View {
        HStack { Image(systemName: "exclamationmark.circle"); Text(message).font(.caption) }
            .foregroundColor(.red).padding(12).background(Color.red.opacity(0.1)).cornerRadius(12)
    }

    private func previewCard(estimate: FoodEstimate, source: FoodLogSource) -> some View {
        VStack(spacing: 12) {
            GlassCard(cornerRadius: 20) {
                VStack(alignment: .leading, spacing: 12) {
                    HStack {
                        Text(estimate.name).font(.headline)
                        Spacer()
                        if let estimateSource {
                            HStack(spacing: 4) {
                                Image(systemName: estimateSource == .cloud ? "cloud.fill" : "iphone")
                                Text(estimateSource.rawValue)
                            }
                            .font(.caption2.weight(.semibold))
                            .foregroundStyle(estimateSource == .cloud ? .cyan : .secondary)
                            .padding(.horizontal, 8).padding(.vertical, 3)
                            .background((estimateSource == .cloud ? Color.cyan : Color.secondary).opacity(0.15))
                            .clipShape(Capsule())
                        }
                    }
                    Text(estimate.servingNote).font(.caption).foregroundStyle(.secondary)
                    Divider()
                    HStack(spacing: 12) {
                        macroCol("Calories", String(format: "%.0f kcal", estimate.calories))
                        macroCol("Protein", String(format: "%.0fg", estimate.protein))
                        macroCol("Carbs", String(format: "%.0fg", estimate.carbs))
                        macroCol("Fat", String(format: "%.0fg", estimate.fat))
                    }
                }
            }
            Button(action: { addEstimateToLog(estimate, source: source) }) {
                Text("Add to Log").frame(maxWidth: .infinity).padding(12)
                    .background(.green).foregroundColor(.white).cornerRadius(12)
            }
        }
    }

    private func macroCol(_ label: String, _ value: String) -> some View {
        VStack(alignment: .leading, spacing: 2) {
            Text(label).font(.caption).foregroundStyle(.secondary)
            Text(value).font(.subheadline.bold())
        }.frame(maxWidth: .infinity, alignment: .leading)
    }

    private func addQuickEntry() {
        let entry = FoodLogEntry(
            name: quickName.isEmpty ? "Quick Add" : quickName,
            calories: Double(quickCalories) ?? 0, protein: Double(quickProtein) ?? 0,
            carbs: Double(quickCarbs) ?? 0, fat: Double(quickFat) ?? 0, source: .quickAdd
        )
        foodLogService.add(entry)
        dismiss()
    }

    private func addEstimateToLog(_ estimate: FoodEstimate, source: FoodLogSource) {
        let entry = FoodLogEntry(name: estimate.name, calories: estimate.calories,
            protein: estimate.protein, carbs: estimate.carbs, fat: estimate.fat, source: source)
        foodLogService.add(entry)
        dismiss()
    }

    private func analyzeText() {
        guard !descriptionText.isEmpty else { return }
        isAnalyzing = true; errorMessage = nil
        Task {
            do {
                let result = try await NutritionAnalysisService.shared.analyze(description: descriptionText)
                foodEstimate = result.estimate
                estimateSource = result.source
            } catch {
                errorMessage = "Couldn't analyze that. Make sure Apple Intelligence is enabled."
            }
            isAnalyzing = false
        }
    }

    private func analyzePhoto(_ image: UIImage) async {
        isAnalyzing = true; errorMessage = nil
        let labels = await classifyFoodImage(image)
        do {
            let result = try await NutritionAnalysisService.shared.analyze(foodLabels: labels)
            foodEstimate = result.estimate
            estimateSource = result.source
        } catch {
            errorMessage = "Couldn't analyze that photo. Make sure Apple Intelligence is enabled."
        }
        isAnalyzing = false
    }

    private func classifyFoodImage(_ image: UIImage) async -> [String] {
        guard let cgImage = image.cgImage else { return [] }
        do {
            let request = ClassifyImageRequest()
            let observations = try await request.perform(on: cgImage, orientation: .up)
            return observations.prefix(5).filter { $0.confidence > 0.25 }.map { $0.identifier }
        } catch { return [] }
    }
}

// MARK: - New Recipe Sheet

struct NewRecipeSheet: View {
    let foodLogService: FoodLogService
    @Environment(\.dismiss) private var dismiss
    @State private var recipeName = ""
    @State private var ingredients: [RecipeIngredient] = []
    @State private var showingAddIngredient = false
    @State private var ingName = ""
    @State private var ingCalories = ""
    @State private var ingProtein = ""
    @State private var ingCarbs = ""
    @State private var ingFat = ""
    @State private var ingServing = ""

    var totalCalories: Double { ingredients.reduce(0) { $0 + $1.calories } }

    var body: some View {
        NavigationStack {
            Form {
                Section("Recipe Name") {
                    TextField("e.g. High Protein Oatmeal", text: $recipeName)
                }
                Section("Ingredients  (\(ingredients.count))") {
                    ForEach(ingredients) { ing in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(ing.name)
                                Text(String(format: "%.0f kcal", ing.calories)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { indices in ingredients.remove(atOffsets: indices) }
                    Button(action: { showingAddIngredient = true }) {
                        Label("Add Ingredient", systemImage: "plus.circle")
                    }
                }
                if !ingredients.isEmpty {
                    Section("Totals") {
                        HStack { Text("Calories"); Spacer(); Text(String(format: "%.0f kcal", totalCalories)).foregroundStyle(.secondary) }
                        HStack { Text("Protein"); Spacer(); Text(String(format: "%.0fg", ingredients.reduce(0) { $0 + $1.protein })).foregroundStyle(.secondary) }
                        HStack { Text("Carbs"); Spacer(); Text(String(format: "%.0fg", ingredients.reduce(0) { $0 + $1.carbs })).foregroundStyle(.secondary) }
                        HStack { Text("Fat"); Spacer(); Text(String(format: "%.0fg", ingredients.reduce(0) { $0 + $1.fat })).foregroundStyle(.secondary) }
                    }
                }
            }
            .navigationTitle("New Recipe")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        foodLogService.addRecipe(CustomRecipe(name: recipeName, ingredients: ingredients))
                        dismiss()
                    }
                    .disabled(recipeName.isEmpty || ingredients.isEmpty).fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddIngredient) { addIngredientSheet }
        }
    }

    private var addIngredientSheet: some View {
        NavigationStack {
            Form {
                Section("Ingredient") {
                    TextField("Name", text: $ingName)
                    TextField("Serving size", text: $ingServing)
                }
                Section("Nutrition") {
                    HStack { Text("Calories"); Spacer(); TextField("0", text: $ingCalories).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    HStack { Text("Protein (g)"); Spacer(); TextField("0", text: $ingProtein).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    HStack { Text("Carbs (g)"); Spacer(); TextField("0", text: $ingCarbs).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    HStack { Text("Fat (g)"); Spacer(); TextField("0", text: $ingFat).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                }
            }
            .navigationTitle("Add Ingredient")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showingAddIngredient = false } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        ingredients.append(RecipeIngredient(name: ingName, calories: Double(ingCalories) ?? 0,
                            protein: Double(ingProtein) ?? 0, carbs: Double(ingCarbs) ?? 0,
                            fat: Double(ingFat) ?? 0, servingNote: ingServing))
                        ingName = ""; ingCalories = ""; ingProtein = ""; ingCarbs = ""; ingFat = ""; ingServing = ""
                        showingAddIngredient = false
                    }
                    .disabled(ingName.isEmpty).fontWeight(.semibold)
                }
            }
        }
    }
}

// MARK: - Meal Schedule Manager (multiple custom schedules)

struct NutritionScheduleManager: View {
    let foodLogService: FoodLogService
    @Environment(\.dismiss) private var dismiss
    @State private var editing: MealSchedule?

    var body: some View {
        NavigationStack {
            List {
                if foodLogService.schedules.isEmpty {
                    Section {
                        VStack(spacing: 8) {
                            Image(systemName: "clock.badge.questionmark").font(.title2).foregroundStyle(.secondary)
                            Text("No scheduled meals").font(.subheadline.bold())
                            Text("Add meals that auto-log at set times each day.").font(.caption).foregroundStyle(.secondary).multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity).padding(.vertical, 8)
                    }
                }
                ForEach(foodLogService.schedules) { schedule in
                    Button(action: { editing = schedule }) {
                        HStack {
                            VStack(alignment: .leading, spacing: 3) {
                                HStack(spacing: 6) {
                                    Text(schedule.name).font(.body.weight(.semibold)).foregroundStyle(.primary)
                                    if !schedule.isEnabled {
                                        Text("OFF").font(.caption2.bold()).foregroundStyle(.secondary)
                                            .padding(.horizontal, 5).padding(.vertical, 1)
                                            .background(Color.secondary.opacity(0.15)).clipShape(Capsule())
                                    }
                                }
                                Text("\(schedule.timeLabel)  ·  \(schedule.items.count) item\(schedule.items.count == 1 ? "" : "s")  ·  \(Int(schedule.totalCalories)) kcal")
                                    .font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                            Image(systemName: "chevron.right").font(.caption).foregroundStyle(.tertiary)
                        }
                    }
                }
                .onDelete { indices in
                    for i in indices { foodLogService.removeSchedule(foodLogService.schedules[i]) }
                }
            }
            .navigationTitle("Meal Schedules")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Done") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { editing = MealSchedule(name: "New Meal") } label: { Image(systemName: "plus") }
                }
            }
            .sheet(item: $editing) { schedule in
                AddEditScheduleSheet(foodLogService: foodLogService, schedule: schedule)
            }
        }
    }
}

private struct AddEditScheduleSheet: View {
    let foodLogService: FoodLogService
    @Environment(\.dismiss) private var dismiss
    @State var schedule: MealSchedule
    @State private var showingAddItem = false
    @State private var newItemName = ""
    @State private var newItemCalories = ""
    @State private var newItemProtein = ""
    @State private var newItemCarbs = ""
    @State private var newItemFat = ""

    private var isExisting: Bool { foodLogService.schedules.contains { $0.id == schedule.id } }

    var body: some View {
        NavigationStack {
            List {
                Section {
                    TextField("Meal name (e.g. Lunch)", text: $schedule.name)
                    Toggle("Auto-log this meal", isOn: $schedule.isEnabled)
                    HStack {
                        Text("Log at")
                        Spacer()
                        DatePicker("", selection: scheduleTime, displayedComponents: .hourAndMinute).labelsHidden()
                    }
                }
                Section("Items") {
                    ForEach(schedule.items) { item in
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(item.name).font(.body)
                                Text(String(format: "%.0f kcal", item.calories)).font(.caption).foregroundStyle(.secondary)
                            }
                            Spacer()
                        }
                    }
                    .onDelete { indices in schedule.items.remove(atOffsets: indices) }
                    Button(action: { showingAddItem = true }) { Label("Add Item", systemImage: "plus.circle") }
                }
                if !foodLogService.customRecipes.isEmpty {
                    Section("Add from Recipes") {
                        ForEach(foodLogService.customRecipes) { recipe in
                            Button(action: { addFromRecipe(recipe) }) {
                                HStack {
                                    Text(recipe.name)
                                    Spacer()
                                    Text(String(format: "%.0f kcal", recipe.totalCalories)).font(.caption).foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                }
            }
            .navigationTitle(isExisting ? "Edit Meal" : "New Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { dismiss() } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        if isExisting { foodLogService.updateSchedule(schedule) }
                        else { foodLogService.addSchedule(schedule) }
                        dismiss()
                    }
                    .disabled(schedule.name.trimmingCharacters(in: .whitespaces).isEmpty)
                    .fontWeight(.semibold)
                }
            }
            .sheet(isPresented: $showingAddItem) { addItemSheet }
        }
    }

    private var scheduleTime: Binding<Date> {
        Binding(
            get: {
                var comps = Calendar.current.dateComponents([.year, .month, .day], from: Date())
                comps.hour = schedule.scheduledHour
                comps.minute = schedule.scheduledMinute
                return Calendar.current.date(from: comps) ?? Date()
            },
            set: { date in
                schedule.scheduledHour = Calendar.current.component(.hour, from: date)
                schedule.scheduledMinute = Calendar.current.component(.minute, from: date)
            }
        )
    }

    private var addItemSheet: some View {
        NavigationStack {
            Form {
                Section("Item") { TextField("Name (e.g. Oatmeal)", text: $newItemName) }
                Section("Nutrition") {
                    HStack { Text("Calories"); Spacer(); TextField("0", text: $newItemCalories).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    HStack { Text("Protein (g)"); Spacer(); TextField("0", text: $newItemProtein).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    HStack { Text("Carbs (g)"); Spacer(); TextField("0", text: $newItemCarbs).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                    HStack { Text("Fat (g)"); Spacer(); TextField("0", text: $newItemFat).multilineTextAlignment(.trailing).keyboardType(.decimalPad) }
                }
            }
            .navigationTitle("Add Item")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) { Button("Cancel") { showingAddItem = false } }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Add") {
                        schedule.items.append(BreakfastSchedule.ScheduledItem(
                            name: newItemName, calories: Double(newItemCalories) ?? 0,
                            protein: Double(newItemProtein) ?? 0, carbs: Double(newItemCarbs) ?? 0,
                            fat: Double(newItemFat) ?? 0))
                        newItemName = ""; newItemCalories = ""; newItemProtein = ""; newItemCarbs = ""; newItemFat = ""
                        showingAddItem = false
                    }
                    .disabled(newItemName.isEmpty).fontWeight(.semibold)
                }
            }
        }
    }

    private func addFromRecipe(_ recipe: CustomRecipe) {
        schedule.items.append(BreakfastSchedule.ScheduledItem(
            name: recipe.name, calories: recipe.totalCalories, protein: recipe.totalProtein,
            carbs: recipe.totalCarbs, fat: recipe.totalFat))
    }
}
