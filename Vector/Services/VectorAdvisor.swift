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
    @Guide(description: "Up to three messages the USER would type next to their coach, first person, each under 8 words. Like 'Build me a push day' or 'Why is my HRV down?'. Never questions the coach would ask the user. Empty list if nothing fits.")
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

    /// Whether this device supports the on-device model at all. Used to decide
    /// whether to surface Vector Intelligence UI.
    static var isSupported: Bool {
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

    /// Transient workout recommendations keyed by message ID. Not persisted, cleared on relaunch.
    var liveRecommendations: [UUID: [AdvisorRecommendation]] = [:]

    /// Transient exercise-load update suggestions keyed by message ID. Not persisted, cleared on relaunch.
    var liveExerciseUpdates: [UUID: [AdvisorExerciseUpdate]] = [:]

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
        // Each cold launch opens a fresh chat; the previous conversation is
        // archived to history rather than resumed.
        if !messages.isEmpty {
            startNewChat()
        }
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
        let snapshot = AdvisorContext.build(healthService)

        // Always log a data-review step so every reply shows a thought process.
        let reviewStep = AdvisorActivity.shared.beginStep("Reading your health data…")
        AdvisorActivity.shared.finishStep(reviewStep, result: "Read your recovery, sleep & training")
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
            userPrompt = "[Background data — reference only. The user has not seen this and did not say it. Do not read it back.]\n\(snapshot)\n\n\(userPrompt)"
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
            let updates = AdvisorActivity.shared.exerciseUpdates
            liveExerciseUpdates[messageId] = updates
            // Existing-first rule: if we found saved workouts to update, don't also show a freshly generated workout.
            liveRecommendations[messageId] = updates.isEmpty ? AdvisorActivity.shared.recommendations : []
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
        liveRecommendations.removeAll()
        liveExerciseUpdates.removeAll()
        suggestedReplies = []
        session = nil
        sessionDay = nil
        sessionPersona = nil
        lastSnapshotHash = nil
        AdvisorActivity.shared.reset()
        save()
    }

    /// Archive the current conversation to history, then start fresh.
    func startNewChat() {
        ConversationHistoryStore.shared.archive(messages)
        resetConversation()
    }

    /// Load an archived conversation back into the advisor (starts a fresh model session on the next turn).
    func restore(_ conversation: ArchivedConversation) {
        messages = conversation.messages
        liveActions.removeAll()
        liveRecommendations.removeAll()
        liveExerciseUpdates.removeAll()
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
        let dataAccessDescription = FeatureFlags.nutritionEnabled
            ? "You can see the user's health data, training history, and nutrition."
            : "You can see the user's health data and training history."
        let baseInstructions = """
        You are Vector, a personal health and fitness advisor with tool access. \(dataAccessDescription) When the user asks you to \(FeatureFlags.nutritionEnabled ? "log meals, " : "")generate workouts, set targets, or look up history, CALL THE TOOL — do not just describe it. If the user mentions past workouts, saved templates, training volume, or their progress over time, call getWorkoutHistory before answering rather than guessing. To progress, add weight to, or break a plateau on a specific exercise the user already trains, call updateExerciseLoad ONLY — never generateWorkout for that; only use generateWorkout to build a brand-new workout. Use your knowledge of nutrition and exercise science to fill in details. When you recommend a workout, first explain the training strategy behind it in one or two plain sentences (for example, using progressive overload to break a plateau) and how it addresses the user's question. Do not append a 'Progress update' or 'Changed' summary line — the app already shows what changed as a card. For other actions, briefly confirm what you changed. Be concise — under 150 words unless asked for depth.

        CONVERSATION STYLE — this matters as much as accuracy:
        - The [Background data] block is reference the app hands you. The user did not say it and cannot see it. Never read it back, never restate it as a list, and never open with a summary of their metrics.
        - Match the reply to what was actually asked. Greetings and small talk get one or two warm, human sentences — no metrics, no bullets, no coaching agenda. If someone says "hey how are you", answer like a person would.
        - The health data describes the USER, never you. If they ask how you are doing, answer about yourself in one short sentence and hand the conversation back — never describe their recovery, sleep, or strain as your own state.
        - Only bring up a number when it directly answers the question, and bring up at most one or two, in plain prose with a short reason it matters.
        - Write in prose. Use bullets only for genuine lists, like the exercises in a workout.
        - Do not end every reply with a question. Ask one only when you genuinely need something from the user to continue.
        """
        let personaInstruction = "\n\nTone: \(AdvisorPersona.current.instruction)"
        let nutritionNote = FeatureFlags.nutritionEnabled
            ? ""
            : "\n\nNutrition tracking is not yet active in this app. Do not offer to log meals, set nutrition targets, or discuss nutrition tracking features — if asked, explain that nutrition tracking isn't available yet."
        return baseInstructions + personaInstruction + nutritionNote
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
            GetProgressionTool(recoveryScore: healthService.recoveryScore?.score),
            UpdateExerciseLoadTool(recoveryScore: healthService.recoveryScore?.score)
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
            instructions: "You write the USER's next chat message to their fitness coach — never the coach's message to the user. Speak as the user, first person, under 8 words each. Good: 'Build me a push day', 'Why is my recovery low?', 'Give me something easier'. Bad, because these are the coach talking and must never be produced: 'How's your recovery going?', 'Want to tweak your routine?', 'Feeling any strain today?'. Tie each one to what the coach just said, and avoid generic filler like 'Focus on form'. If the exchange was small talk, a greeting, or has no natural follow-up, return an empty list."
        )
        do {
            let prompt = "The user asked: \(String(question.prefix(200)))\n\nThe coach answered: \(String(answer.prefix(600)))\n\nSuggest up to 3 follow-up messages the user might tap to send. Return an empty list if none would feel natural here."
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
