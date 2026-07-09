import AppIntents

struct AskAdvisorIntent: AppIntent {
    static var title: LocalizedStringResource = "Ask Vector Intelligence"
    static var description: IntentDescription = "Open Vector Intelligence, Vector's on-device health advisor."
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
