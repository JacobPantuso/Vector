import FoundationModels
import Foundation

enum AdvisorPersona: String, CaseIterable, Codable, Sendable {
    case trainer = "Trainer"
    case friend = "Friend"
    case encouraging = "Encouraging"
    case direct = "Direct"

    static let storageKey = "advisorPersona"

    static var current: AdvisorPersona {
        AdvisorPersona(rawValue: UserDefaults.standard.string(forKey: storageKey) ?? "") ?? .trainer
    }

    var instruction: String {
        switch self {
        case .trainer:     return "Speak like a knowledgeable strength coach: confident, motivating, tactical."
        case .friend:      return "Speak like a supportive friend: warm, casual, conversational."
        case .encouraging: return "Speak in an encouraging, positive tone: celebrate wins, gently frame setbacks."
        case .direct:      return "Speak directly and factually: concise, no fluff."
        }
    }
}

struct HealthInsight: Identifiable, Codable, Sendable {
    let id: UUID
    let category: String
    let severity: String
    let title: String
    let body: String
    let recommendation: String
    let date: Date

    init(id: UUID = UUID(), category: String, severity: String, title: String, body: String, recommendation: String, date: Date = Date()) {
        self.id = id
        self.category = category
        self.severity = severity
        self.title = title
        self.body = body
        self.recommendation = recommendation
        self.date = date
    }
}


@MainActor
@Observable
class InsightEngine {
    var insights: [HealthInsight] = []
    var isGenerating = false

    var isOnDeviceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    func generateInsight(metrics: String) async {
        guard isOnDeviceAvailable else { return }
        isGenerating = true
        defer { isGenerating = false }

        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: "You are an expert health and fitness coach. Analyze the provided health metrics and generate a concise, actionable health insight. Respond with a short title, a brief analysis, and one specific recommendation."
        )

        do {
            let response = try await session.respond(to: "Analyze these health metrics and provide an insight:\n\(metrics)")
            let lines = response.content.split(separator: "\n", maxSplits: 2)
            let title = lines.first.map(String.init) ?? "Health Insight"
            let body = lines.count > 1 ? String(lines[1]) : response.content
            let rec = lines.count > 2 ? String(lines[2]) : ""
            insights.append(HealthInsight(category: "health", severity: "info", title: title, body: body, recommendation: rec))
        } catch {
            insights.append(HealthInsight(
                category: "health", severity: "info",
                title: "Keep tracking your metrics",
                body: "Continue logging your health data to get personalized insights.",
                recommendation: "Log your daily activity, sleep, and vitals regularly."
            ))
        }
    }

}
