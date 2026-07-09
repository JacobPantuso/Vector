import Foundation

@Observable
class FoodLogService {
    static let shared = FoodLogService()

    private(set) var entries: [FoodLogEntry] = []
    private(set) var customRecipes: [CustomRecipe] = []
    var breakfastSchedule: BreakfastSchedule = .default
    private(set) var schedules: [MealSchedule] = []

    private let entriesKey = "foodLogEntries"
    private let recipesKey = "foodLogRecipes"
    private let scheduleKey = "breakfastSchedule"
    private let schedulesKey = "mealSchedules"
    private let migratedKey = "mealSchedulesMigrated"

    init() {
        loadEntries()
        loadRecipes()
        loadSchedule()
        loadSchedules()
    }

    // MARK: - Entries

    func add(_ entry: FoodLogEntry) {
        entries.append(entry)
        saveEntries()
        generateImage(for: entry)
    }

    func remove(_ entry: FoodLogEntry) {
        entries.removeAll { $0.id == entry.id }
        saveEntries()
    }

    func update(_ entry: FoodLogEntry) {
        if let i = entries.firstIndex(where: { $0.id == entry.id }) {
            entries[i] = entry
            saveEntries()
            generateImage(for: entry)
        }
    }

    private func generateImage(for entry: FoodLogEntry) {
        Task { @MainActor in
            FoodImageService.shared.generate(for: entry)
        }
    }

    var todayEntries: [FoodLogEntry] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return entries.filter { $0.date >= startOfDay }
    }

    var todayCalories: Double { todayEntries.reduce(0) { $0 + $1.calories } }
    var todayProtein: Double  { todayEntries.reduce(0) { $0 + $1.protein } }
    var todayCarbs: Double    { todayEntries.reduce(0) { $0 + $1.carbs } }
    var todayFat: Double      { todayEntries.reduce(0) { $0 + $1.fat } }

    // MARK: - Recipes

    func addRecipe(_ recipe: CustomRecipe) { customRecipes.append(recipe); saveRecipes() }
    func removeRecipe(_ recipe: CustomRecipe) { customRecipes.removeAll { $0.id == recipe.id }; saveRecipes() }
    func logRecipe(_ recipe: CustomRecipe) {
        let entry = FoodLogEntry(
            name: recipe.name,
            calories: recipe.totalCalories,
            protein: recipe.totalProtein,
            carbs: recipe.totalCarbs,
            fat: recipe.totalFat,
            source: .recipe
        )
        add(entry)
    }

    // MARK: - Schedules (multiple)

    func addSchedule(_ schedule: MealSchedule) { schedules.append(schedule); saveSchedules() }
    func updateSchedule(_ schedule: MealSchedule) {
        if let i = schedules.firstIndex(where: { $0.id == schedule.id }) {
            schedules[i] = schedule
            saveSchedules()
        }
    }
    func removeSchedule(_ schedule: MealSchedule) { schedules.removeAll { $0.id == schedule.id }; saveSchedules() }

    func saveSchedules() {
        if let data = try? JSONEncoder().encode(schedules) {
            UserDefaults.standard.set(data, forKey: schedulesKey)
        }
    }

    private func loadSchedules() {
        if let data = UserDefaults.standard.data(forKey: schedulesKey),
           let decoded = try? JSONDecoder().decode([MealSchedule].self, from: data) {
            schedules = decoded
        }
        // One-time migration of the legacy single breakfast schedule into the new list.
        if !UserDefaults.standard.bool(forKey: migratedKey) {
            if (breakfastSchedule.isEnabled || !breakfastSchedule.items.isEmpty),
               !schedules.contains(where: { $0.name == "Breakfast" }) {
                schedules.append(MealSchedule(
                    name: "Breakfast",
                    isEnabled: breakfastSchedule.isEnabled,
                    scheduledHour: breakfastSchedule.scheduledHour,
                    scheduledMinute: breakfastSchedule.scheduledMinute,
                    items: breakfastSchedule.items
                ))
                saveSchedules()
            }
            UserDefaults.standard.set(true, forKey: migratedKey)
        }
    }

    // MARK: - Auto-log

    func autoLogScheduledMealsIfNeeded() {
        let now = Date()
        let calendar = Calendar.current
        let currentMinutes = calendar.component(.hour, from: now) * 60 + calendar.component(.minute, from: now)
        let startOfDay = calendar.startOfDay(for: now)
        var didLog = false

        for schedule in schedules where schedule.isEnabled && !schedule.items.isEmpty {
            let scheduledMinutes = schedule.scheduledHour * 60 + schedule.scheduledMinute
            guard currentMinutes >= scheduledMinutes else { continue }
            let lastKey = "scheduleLastLogged_\(schedule.id.uuidString)"
            if let last = UserDefaults.standard.object(forKey: lastKey) as? Date, last >= startOfDay { continue }
            for item in schedule.items {
                let entry = FoodLogEntry(
                    name: item.name,
                    calories: item.calories,
                    protein: item.protein,
                    carbs: item.carbs,
                    fat: item.fat,
                    source: .schedule
                )
                entries.append(entry)
                generateImage(for: entry)
                didLog = true
            }
            UserDefaults.standard.set(now, forKey: lastKey)
        }
        if didLog { saveEntries() }
    }

    /// Back-compat alias for older call sites.
    func autoLogBreakfastIfNeeded() { autoLogScheduledMealsIfNeeded() }

    func saveSchedule() {
        if let data = try? JSONEncoder().encode(breakfastSchedule) {
            UserDefaults.standard.set(data, forKey: scheduleKey)
        }
    }

    // MARK: - Persistence

    private func saveEntries() {
        if let data = try? JSONEncoder().encode(entries) {
            UserDefaults.standard.set(data, forKey: entriesKey)
        }
    }

    private func loadEntries() {
        if let data = UserDefaults.standard.data(forKey: entriesKey),
           let decoded = try? JSONDecoder().decode([FoodLogEntry].self, from: data) {
            entries = decoded
        }
    }

    private func saveRecipes() {
        if let data = try? JSONEncoder().encode(customRecipes) {
            UserDefaults.standard.set(data, forKey: recipesKey)
        }
    }

    private func loadRecipes() {
        if let data = UserDefaults.standard.data(forKey: recipesKey),
           let decoded = try? JSONDecoder().decode([CustomRecipe].self, from: data) {
            customRecipes = decoded
        }
    }

    private func loadSchedule() {
        if let data = UserDefaults.standard.data(forKey: scheduleKey),
           let decoded = try? JSONDecoder().decode(BreakfastSchedule.self, from: data) {
            breakfastSchedule = decoded
        }
    }
}
