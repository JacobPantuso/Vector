import AppIntents

struct AskAdvisorIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Health Advisor"
    static var description: IntentDescription = "Open Vector's AI health advisor."
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        let healthService = HealthKitService()
        await VectorAdvisor.shared.send(
            "Tell me about my current health status based on today's data.",
            topic: nil,
            healthService: healthService
        )
        return .result()
    }
}
