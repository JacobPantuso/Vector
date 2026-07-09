import Foundation
import SwiftUI

enum EnergyBalance: Sendable {
    case deficit, balanced, surplus

    var color: Color {
        switch self {
        case .deficit:
            return .green
        case .balanced:
            return .green
        case .surplus:
            return .green
        }
    }

    var label: String {
        switch self {
        case .deficit:
            return "Deficit"
        case .balanced:
            return "Balanced"
        case .surplus:
            return "Surplus"
        }
    }
}

struct NutritionSummary: Identifiable, Codable, Sendable {
    let id: UUID
    let caloriesConsumed: Double
    let caloriesBurned: Double
    let protein: Double
    let carbs: Double
    let fat: Double
    let date: Date

    var netEnergy: Double {
        return caloriesConsumed - caloriesBurned
    }

    var energyBalance: EnergyBalance {
        let net = netEnergy
        if net < -100 {
            return .deficit
        } else if net <= 100 {
            return .balanced
        } else {
            return .surplus
        }
    }

    init(id: UUID = UUID(), caloriesConsumed: Double, caloriesBurned: Double, protein: Double, carbs: Double, fat: Double, date: Date = Date()) {
        self.id = id
        self.caloriesConsumed = caloriesConsumed
        self.caloriesBurned = caloriesBurned
        self.protein = protein
        self.carbs = carbs
        self.fat = fat
        self.date = date
    }
}
