import Foundation

struct FoodLogEntry: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double
    let date: Date
    let source: FoodLogSource

    init(id: UUID = UUID(), name: String, calories: Double, protein: Double,
         carbs: Double, fat: Double, date: Date = Date(), source: FoodLogSource) {
        self.id = id
        self.name = name
        self.calories = calories
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.date = date
        self.source = source
    }
}

enum FoodLogSource: String, Codable, Sendable {
    case manual
    case photo
    case recipe
    case quickAdd
    case schedule
}

struct RecipeIngredient: Identifiable, Codable, Sendable {
    let id: UUID
    let name: String
    let calories: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let servingNote: String

    init(id: UUID = UUID(), name: String, calories: Double, protein: Double, carbs: Double, fat: Double, servingNote: String = "") {
        self.id = id; self.name = name; self.calories = calories
        self.protein = protein; self.carbs = carbs; self.fat = fat; self.servingNote = servingNote
    }
}

struct CustomRecipe: Identifiable, Codable, Sendable {
    let id: UUID
    var name: String
    var ingredients: [RecipeIngredient]

    init(id: UUID = UUID(), name: String, ingredients: [RecipeIngredient] = []) {
        self.id = id; self.name = name; self.ingredients = ingredients
    }

    var totalCalories: Double { ingredients.reduce(0) { $0 + $1.calories } }
    var totalProtein: Double  { ingredients.reduce(0) { $0 + $1.protein } }
    var totalCarbs: Double    { ingredients.reduce(0) { $0 + $1.carbs } }
    var totalFat: Double      { ingredients.reduce(0) { $0 + $1.fat } }
}

struct BreakfastSchedule: Codable, Sendable {
    var isEnabled: Bool
    var scheduledHour: Int
    var scheduledMinute: Int
    var items: [ScheduledItem]

    struct ScheduledItem: Identifiable, Codable, Sendable {
        let id: UUID
        let name: String
        let calories: Double
        let protein: Double
        let carbs: Double
        let fat: Double

        init(id: UUID = UUID(), name: String, calories: Double, protein: Double, carbs: Double, fat: Double) {
            self.id = id; self.name = name; self.calories = calories
            self.protein = protein; self.carbs = carbs; self.fat = fat
        }
    }

    var totalCalories: Double { items.reduce(0) { $0 + $1.calories } }

    static var `default`: BreakfastSchedule {
        BreakfastSchedule(isEnabled: false, scheduledHour: 8, scheduledMinute: 0, items: [])
    }
}
