import FoundationModels
import Foundation

@Generable
struct FoodEstimate {
    @Guide(description: "Common name of the food") var name: String
    @Guide(description: "Estimated calories in kcal") var calories: Double
    @Guide(description: "Protein in grams") var protein: Double
    @Guide(description: "Carbohydrates in grams") var carbs: Double
    @Guide(description: "Total fat in grams") var fat: Double
    @Guide(description: "Serving size description") var servingNote: String
}

enum NutritionSource: String { case cloud = "Cloud", onDevice = "On-device" }

struct NutritionAnalysisResult {
    let estimate: FoodEstimate
    let source: NutritionSource
}

enum NutritionAnalysisError: Error { case unavailable }

/// Estimates nutrition using Apple's Private Cloud Compute model (broad world knowledge)
/// when available, gracefully falling back to the on-device model.
@MainActor
final class NutritionAnalysisService {
    static let shared = NutritionAnalysisService()

    private let instructions = "You are a nutrition expert with broad world knowledge of foods, brands, restaurant menu items, and typical portion sizes. Estimate nutrition as accurately as possible using realistic real-world values."

    var isAvailable: Bool {
        SystemLanguageModel.default.availability == .available
            || AIModel.isCloudAvailable
    }

    func analyze(description: String) async throws -> NutritionAnalysisResult {
        try await run(prompt: "Estimate the nutrition for: \(description)")
    }

    func analyze(foodLabels: [String]) async throws -> NutritionAnalysisResult {
        let prompt = foodLabels.isEmpty
            ? "Estimate nutritional content for a typical food serving."
            : "A photo shows: \(foodLabels.joined(separator: ", ")). Estimate nutrition for a typical serving of this meal."
        return try await run(prompt: prompt)
    }

    private func run(prompt: String) async throws -> NutritionAnalysisResult {
        guard SystemLanguageModel.default.availability == .available else {
            throw NutritionAnalysisError.unavailable
        }
        let session = LanguageModelSession(model: SystemLanguageModel.default, instructions: instructions)
        let result = try await session.respond(to: prompt, generating: FoodEstimate.self)
        return NutritionAnalysisResult(estimate: result.content, source: .onDevice)
    }
}
