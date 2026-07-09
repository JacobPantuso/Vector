import FoundationModels
import Foundation

// MARK: - Topic (user long-pressed item)

/// A subject the user long-pressed to ask about — rendered as a context chip in chat
/// and appended to the model prompt as a data block.
struct AdvisorTopic: Codable, Hashable, Identifiable {
    var id: UUID = UUID()
    var title: String          // e.g. "Recovery"
    var icon: String           // SF Symbol name
    var tintName: String       // color name: "green","red","cyan","orange","indigo","blue","purple","pink","mint","yellow" — view maps to Color
    var contextLines: [String] // real values, e.g. "HRV 62 ms (7-day avg 58 ms)"
    var suggestedPrompt: String
}

// MARK: - Message & role

enum MessageRole: String, Codable {
    case user, assistant
}

struct AdvisorStepRecord: Codable, Identifiable, Hashable {
    var id: UUID = UUID()
    var kind: String // "reasoning" | "tool"
    var text: String
}

@Generable
struct FollowUpSuggestions {
    @Guide(description: "Two or three short follow-up messages the user might send next, written in the user's first-person voice, each under 8 words")
    var replies: [String]
}

struct AdvisorMessage: Identifiable, Codable {
    let id: UUID
    let role: MessageRole
    var content: String
    let timestamp: Date
    var steps: [AdvisorStepRecord] = []   // persisted snapshot of AdvisorStep
    var actionSummaries: [String] = []    // persisted summaries of actions
    var topic: AdvisorTopic? = nil

    init(
        id: UUID = UUID(),
        role: MessageRole,
        content: String,
        timestamp: Date = Date(),
        steps: [AdvisorStepRecord] = [],
        actionSummaries: [String] = [],
        topic: AdvisorTopic? = nil
    ) {
        self.id = id
        self.role = role
        self.content = content
        self.timestamp = timestamp
        self.steps = steps
        self.actionSummaries = actionSummaries
        self.topic = topic
    }
}

// MARK: - VectorAdvisor (main class)

@MainActor
@Observable
final class VectorAdvisor {
    static let shared = VectorAdvisor()

    var messages: [AdvisorMessage] = []
    var isStreaming = false

    /// Tap-to-send follow-up suggestions for the latest assistant reply. Transient.
    var suggestedReplies: [String] = []

    var isOnDeviceAvailable: Bool {
        SystemLanguageModel.default.availability == .available
    }

    // MARK: - Private state

    private var session: LanguageModelSession?
    private var sessionDay: Date?
    private var sessionPersona: AdvisorPersona?
    private var lastSnapshotHash: Int?

    /// Transient undo actions keyed by message ID. Not persisted, cleared on relaunch.
    /// Views read this to render Undo buttons; restored messages only show actionSummaries.
    var liveActions: [UUID: [AdvisorAction]] = [:]

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("advisor-conversation.json")
    }

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    // MARK: - Public API

    func prewarm(healthService: HealthKitService) {
        ensureSession(healthService: healthService)
        if let session {
            session.prewarm()
        }
    }

    func send(_ text: String, topic: AdvisorTopic? = nil, healthService: HealthKitService) async {
        suggestedReplies = []
        // Capture recap state BEFORE appending anything: a recap is only needed when
        // there is no live session (fresh launch) but restored messages exist.
        let needsRecap = session == nil && !messages.isEmpty
        let priorMessages = messages

        // Append user message
        let userMessage = AdvisorMessage(role: .user, content: text, topic: topic)
        messages.append(userMessage)

        // Guard on-device availability; fall back to local reply if unavailable
        guard isOnDeviceAvailable else {
            let localReply = localAdvisorReply(for: text, healthService: healthService)
            let assistantMessage = AdvisorMessage(role: .assistant, content: localReply)
            messages.append(assistantMessage)
            save()
            return
        }

        // Reset activity tracker and start streaming
        AdvisorActivity.shared.reset()
        isStreaming = true
        defer { isStreaming = false }

        let messageId = UUID()
        let assistantMessage = AdvisorMessage(id: messageId, role: .assistant, content: "")
        messages.append(assistantMessage)

        ensureSession(healthService: healthService)
        guard let activeSession = session else {
            if let idx = messages.lastIndex(where: { $0.id == messageId }) {
                messages[idx].content = "Something went wrong generating a response. Try asking again."
            }
            save()
            return
        }

        // Build prompt with optional recap and snapshot
        let snapshot = AdvisorContext.snapshot(healthService)
        var userPrompt = text

        // Prepend recap of the restored conversation on the first turn of a new session
        if needsRecap {
            let recap = priorMessages.suffix(3)
                .map { String($0.content.prefix(60)) }
                .joined(separator: " / ")
            userPrompt = "[Recap of earlier conversation: \(recap)]\n\n" + userPrompt
        }

        // Prepend snapshot if hash changed or first turn
        let currentHash = snapshot.hashValue
        if lastSnapshotHash == nil || lastSnapshotHash != currentHash {
            userPrompt = "[Current data]\n\(snapshot)\n\n\(userPrompt)"
            lastSnapshotHash = currentHash
        }

        // Append topic context if provided
        if let topic {
            userPrompt += "\n\n[About: \(topic.title)]\n" + topic.contextLines.joined(separator: "\n")
        }

        // Stream response
        do {
            let stream = activeSession.streamResponse(to: userPrompt)
            for try await partial in stream {
                if let idx = messages.lastIndex(where: { $0.id == messageId }) {
                    messages[idx].content = partial.content
                    // Mirror AdvisorActivity steps into message
                    messages[idx].steps = AdvisorActivity.shared.steps.map { step in
                        AdvisorStepRecord(id: step.id, kind: step.kind == .reasoning ? "reasoning" : "tool", text: step.text)
                    }
                }
            }
        } catch {
            // Retry once after recreating session
            self.session = nil
            ensureSession(healthService: healthService)
            guard let retrySession = self.session else {
                if let idx = messages.lastIndex(where: { $0.id == messageId }) {
                    messages[idx].content = "Something went wrong generating a response. Try asking again."
                }
                save()
                return
            }

            AdvisorActivity.shared.reset()
            do {
                let stream = retrySession.streamResponse(to: userPrompt)
                for try await partial in stream {
                    if let idx = messages.lastIndex(where: { $0.id == messageId }) {
                        messages[idx].content = partial.content
                        messages[idx].steps = AdvisorActivity.shared.steps.map { step in
                            AdvisorStepRecord(id: step.id, kind: step.kind == .reasoning ? "reasoning" : "tool", text: step.text)
                        }
                    }
                }
            } catch {
                if let idx = messages.lastIndex(where: { $0.id == messageId }) {
                    messages[idx].content = "Something went wrong generating a response. Try asking again."
                }
            }
        }

        // Snapshot steps and actions to message
        if let idx = messages.lastIndex(where: { $0.id == messageId }) {
            messages[idx].steps = AdvisorActivity.shared.steps.map { step in
                AdvisorStepRecord(id: step.id, kind: step.kind == .reasoning ? "reasoning" : "tool", text: step.text)
            }
            messages[idx].actionSummaries = AdvisorActivity.shared.actions.map { $0.summary }
            liveActions[messageId] = AdvisorActivity.shared.actions
        }

        save()

        // Generate tap-to-send follow-up suggestions off the final answer.
        if let idx = messages.lastIndex(where: { $0.id == messageId }),
           !messages[idx].content.isEmpty,
           !messages[idx].content.hasPrefix("Something went wrong") {
            let answer = messages[idx].content
            Task { [weak self] in
                await self?.generateSuggestedReplies(question: text, answer: answer, expecting: messageId)
            }
        }
    }

    func resetConversation() {
        messages.removeAll()
        liveActions.removeAll()
        suggestedReplies = []
        session = nil
        sessionDay = nil
        sessionPersona = nil
        lastSnapshotHash = nil
        AdvisorActivity.shared.reset()
        save()
    }

    // MARK: - Private helpers

    private func ensureSession(healthService: HealthKitService) {
        let currentPersona = AdvisorPersona.current
        let today = Calendar.current.startOfDay(for: Date())
        let sessionStale = session == nil || sessionDay != today || sessionPersona != currentPersona

        guard sessionStale else { return }

        session = nil
        lastSnapshotHash = nil

        let instructions = buildInstructions(healthService: healthService)
        let tools = buildTools(healthService: healthService)

        session = LanguageModelSession(
            model: SystemLanguageModel.default,
            tools: tools,
            instructions: instructions
        )
        sessionDay = today
        sessionPersona = currentPersona
    }

    private func buildInstructions(healthService: HealthKitService) -> String {
        let baseInstructions = """
        You are Vector, a personal health and fitness advisor with tool access. You can see the user's health data, training history, and nutrition. When the user asks you to log meals, generate workouts, set targets, or look up history, CALL THE TOOL — do not just describe it. Use your knowledge of nutrition and exercise science to fill in details. After acting, briefly confirm what you changed. Be conversational and concise—under 150 words unless asked for depth.
        """
        let personaInstruction = "\n\nTone: \(AdvisorPersona.current.instruction)"
        return baseInstructions + personaInstruction
    }

    private func buildTools(healthService: HealthKitService) -> [any Tool] {
        let defaults = UserDefaults.standard
        let profile = UserProfile(
            goal: FitnessGoal(rawValue: defaults.string(forKey: UserProfileStorage.goal) ?? "") ?? UserProfile.defaultGoal,
            ageRange: AgeRange(rawValue: defaults.string(forKey: UserProfileStorage.ageRange) ?? "") ?? UserProfile.defaultAgeRange,
            trainingDaysPerWeek: defaults.object(forKey: UserProfileStorage.trainingDays) as? Int ?? UserProfile.defaultTrainingDays,
            sleepTargetHours: defaults.object(forKey: UserProfileStorage.sleepTargetHours) as? Double ?? UserProfile.defaultSleepTargetHours
        )

        var tools: [any Tool] = [
            GenerateWorkoutTool(profile: profile, recovery: healthService.recoveryScore, exertion: healthService.exertionScore),
            SetSleepTargetTool(),
            SetFitnessProfileTool(),
            GetWorkoutHistoryTool(),
            GetProgressionTool()
        ]

        if FeatureFlags.nutritionEnabled {
            tools.insert(LogMealTool(), at: 0)
            tools.insert(RemoveMealTool(), at: 1)
            tools.insert(EditMealTool(), at: 2)
            tools.insert(SetBreakfastTool(), at: 3)
            tools.insert(SetNutritionTargetTool(), at: 4)
        }

        return tools
    }

    /// Generates 2-3 short follow-up prompts the user can tap to send. Uses a
    /// throwaway session so suggestions don't pollute the main conversation context.
    private func generateSuggestedReplies(question: String, answer: String, expecting messageId: UUID) async {
        guard isOnDeviceAvailable else { return }
        let session = LanguageModelSession(
            model: SystemLanguageModel.default,
            instructions: "You suggest short follow-up messages a user might send next in a health & fitness coaching chat. Write them in the user's voice, each under 8 words, actionable and specific to the answer given."
        )
        do {
            let prompt = "The user asked: \(String(question.prefix(200)))\n\nThe coach answered: \(String(answer.prefix(600)))\n\nSuggest 2-3 follow-up messages the user might tap to send."
            let result = try await session.respond(to: prompt, generating: FollowUpSuggestions.self)
            // Only surface if the conversation hasn't moved on.
            guard messages.last?.id == messageId, !isStreaming else { return }
            suggestedReplies = Array(result.content.replies.prefix(3))
        } catch {
            // Non-essential nicety — fail silently.
        }
    }

    private func localAdvisorReply(for text: String, healthService: HealthKitService) -> String {
        let lowercased = text.lowercased()
        let recovery = healthService.recoveryScore?.score ?? 0
        let load = healthService.exertionScore?.loadStatus.label ?? "unknown"
        let sleep = healthService.sleepAnalysis?.qualityLevel.label.lowercased() ?? "unknown"

        if lowercased.contains("sleep") {
            return "Your sleep looks \(sleep). Keep tonight's routine consistent, and let recovery decide how hard you push tomorrow."
        } else if lowercased.contains("train") || lowercased.contains("workout") {
            return "Based on your current load (\(load)) and recovery (\(recovery)), choose a session that matches today's readiness."
        } else if lowercased.contains("recover") {
            return "Recovery is at \(recovery). Hydrate, keep movement light, and protect the next workout window."
        } else {
            return "You're tracking well. Use your current recovery, load, and sleep context to guide today's decision."
        }
    }

    // MARK: - Persistence

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([AdvisorMessage].self, from: data) else {
            return
        }
        messages = decoded
    }

    private func save() {
        // Cap at most recent 60 messages
        let capped = messages.count > 60 ? Array(messages.suffix(60)) : messages
        guard let data = try? encoder.encode(capped) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
