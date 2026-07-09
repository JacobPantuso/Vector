import Foundation

/// Daily nutrition targets computed from the user's baselines and goal, with optional manual overrides.
struct NutritionTargets: Sendable {
    var calories: Double
    var protein: Double
    var carbs: Double
    var fat: Double

    /// Computes targets. Uses Mifflin-St Jeor when weight & height are known, otherwise the coarse profile estimate.
    /// Any override value > 0 replaces the computed value.
    static func compute(
        goal: FitnessGoal,
        ageRange: AgeRange,
        trainingDaysPerWeek: Int,
        weightKg: Double,
        heightCm: Double,
        overrides: NutritionTargets? = nil
    ) -> NutritionTargets {
        let baseCalories: Double
        if weightKg > 0 && heightCm > 0 {
            let age = Double(ageRange.approxAge)
            let bmr = 10 * weightKg + 6.25 * heightCm - 5 * age + 5
            let activity = 1.2 + min(0.6, Double(trainingDaysPerWeek) * 0.075)
            baseCalories = bmr * activity + Double(goal.calorieAdjustment)
        } else {
            baseCalories = Double(UserProfile(goal: goal, ageRange: ageRange, trainingDaysPerWeek: trainingDaysPerWeek, sleepTargetHours: 8).calorieTargetEstimate)
        }
        let calories = max(1400, baseCalories)

        let proteinPerKg: Double = switch goal {
        case .fatLoss: 2.2
        case .muscleGain: 2.0
        case .performance: 1.8
        case .maintenance: 1.6
        }
        let weightForProtein = weightKg > 0 ? weightKg : 75
        let protein = proteinPerKg * weightForProtein

        let fatPct: Double = goal == .fatLoss ? 0.28 : 0.27
        let fat = (calories * fatPct) / 9
        let carbs = max(0, (calories - protein * 4 - fat * 9) / 4)

        var result = NutritionTargets(calories: calories.rounded(), protein: protein.rounded(), carbs: carbs.rounded(), fat: fat.rounded())
        if let o = overrides {
            if o.calories > 0 { result.calories = o.calories }
            if o.protein > 0 { result.protein = o.protein }
            if o.carbs > 0 { result.carbs = o.carbs }
            if o.fat > 0 { result.fat = o.fat }
        }
        return result
    }
}

extension AgeRange {
    var approxAge: Int {
        switch self {
        case .under18: 16
        case .age18to24: 21
        case .age25to34: 29
        case .age35to44: 39
        case .age45Plus: 50
        }
    }
}
