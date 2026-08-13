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
    private var sessionMemoryHash: Int?

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
        // A conversation from an earlier day is archived; today's is resumed so the
        // advisor picks up where the user left off instead of forgetting everything.
        if let last = messages.last?.timestamp,
           !Calendar.current.isDateInToday(last) {
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

        // Always log a data-review step so every reply shows a thought process.
        let reviewStep = AdvisorActivity.shared.beginStep("Reading your health data…")
        AdvisorActivity.shared.finishStep(reviewStep, result: "Read your recovery, sleep & training")

        // Build prompt: always prepend current readings, optionally add background data
        let currentReadings = AdvisorContext.currentReadings(healthService)
        var userPrompt = currentReadings + "\n\n" + text

        // Prepend snapshot if hash changed or first turn
        let snapshot = AdvisorContext.build(healthService)
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
            let retryReviewStep = AdvisorActivity.shared.beginStep("Reading your health data…")
            AdvisorActivity.shared.finishStep(retryReviewStep, result: "Read your recovery, sleep & training")

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
        sessionMemoryHash = nil
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

    /// Rebuilds a model transcript from the persisted conversation so a new
    /// session picks up the thread instead of starting blank. Only complete exchanges
    /// (messages with actual responses) are included; the in-flight user message and
    /// empty assistant placeholder that `send` appends are submitted separately via
    /// `streamResponse(to:)`, so they must not appear in the transcript to avoid duplication.
    private func rehydratedTranscript(
        instructions: String,
        tools: [any Tool]
    ) -> Transcript? {
        // Only complete exchanges belong in the transcript. `send` appends the current
        // user message and an empty assistant placeholder before this runs; the live
        // prompt is sent separately via streamResponse, so anything after the last
        // answered turn would be sent twice.
        guard let lastAnswered = messages.lastIndex(where: {
            $0.role == .assistant && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else { return nil }

        let recent = messages[...lastAnswered]
            .suffix(12)
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !recent.isEmpty else { return nil }

        var entries: [Transcript.Entry] = []

        // Add instructions entry first (required)
        let instructionsSegment = Transcript.TextSegment(id: UUID().uuidString, content: instructions)
        let toolDefs: [Transcript.ToolDefinition] = tools.map { tool in
            Transcript.ToolDefinition(tool: tool)
        }
        let instructionsEntry = Transcript.Instructions(
            id: UUID().uuidString,
            segments: [.text(instructionsSegment)],
            toolDefinitions: toolDefs
        )
        entries.append(.instructions(instructionsEntry))

        // Add conversation entries
        for message in recent {
            switch message.role {
            case .user:
                let promptSegment = Transcript.TextSegment(id: UUID().uuidString, content: message.content)
                let prompt = Transcript.Prompt(
                    id: UUID().uuidString,
                    segments: [.text(promptSegment)]
                )
                entries.append(.prompt(prompt))

            case .assistant:
                let responseSegment = Transcript.TextSegment(id: UUID().uuidString, content: message.content)
                let response = Transcript.Response(
                    id: UUID().uuidString,
                    assetIDs: [],
                    segments: [.text(responseSegment)]
                )
                entries.append(.response(response))
            }
        }

        return Transcript(entries: entries)
    }

    private func ensureSession(healthService: HealthKitService) {
        let currentPersona = AdvisorPersona.current
        let today = Calendar.current.startOfDay(for: Date())

        // Compute current memory hash
        let memoryCount = AdvisorMemoryStore.shared.memories.count
        let memoryTexts = AdvisorMemoryStore.shared.memories.map { $0.text }.joined()
        var hasher = Hasher()
        hasher.combine(memoryCount)
        hasher.combine(memoryTexts)
        let currentMemoryHash = hasher.finalize()

        let sessionStale = session == nil
            || sessionDay != today
            || sessionPersona != currentPersona
            || sessionMemoryHash != currentMemoryHash

        guard sessionStale else { return }

        session = nil
        lastSnapshotHash = nil
        sessionMemoryHash = currentMemoryHash

        let instructions = buildInstructions(healthService: healthService)
        let tools = buildTools(healthService: healthService)

        // Try to rehydrate from persisted messages; fall back to fresh session
        if let transcript = rehydratedTranscript(instructions: instructions, tools: tools) {
            session = LanguageModelSession(
                model: SystemLanguageModel.default,
                tools: tools,
                transcript: transcript
            )
            session?.prewarm()
        } else {
            session = LanguageModelSession(
                model: SystemLanguageModel.default,
                tools: tools,
                instructions: instructions
            )
        }

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
        - The [Current readings] block is the live data that supersedes all earlier numbers. Always cite from the most recent [Current readings] block.
        - The [Background data] block is reference the app hands you. The user did not say it and cannot see it. Never read it back, never restate it as a list, and never open with a summary of their metrics.
        - Match the reply to what was actually asked. Greetings and small talk get one or two warm, human sentences — no metrics, no bullets, no coaching agenda. If someone says "hey how are you", answer like a person would.
        - The health data describes the USER, never you. If they ask how you are doing, answer about yourself in one short sentence and hand the conversation back — never describe their recovery, sleep, or strain as your own state.
        - Never state a number you were not given. Every figure you cite must come from the most recent [Current readings] block, the [Background data] block, or a tool result — if a value isn't there, say you don't have it rather than estimating. When readings appear more than once, the most recent block wins.
        - Only bring up a number when it directly answers the question, and bring up at most one or two, in plain prose with a short reason it matters.
        - Write in prose. Use bullets only for genuine lists, like the exercises in a workout.
        - Do not end every reply with a question. Ask one only when you genuinely need something from the user to continue.

        MEMORY: When the user tells you something lasting about themselves — an injury, their equipment, where they train, a schedule, something they refuse to do — call rememberPreference so it survives into future chats. When they say a remembered fact no longer applies, call forgetPreference.
        """
        let personaInstruction = "\n\nTone: \(AdvisorPersona.current.instruction)"
        let nutritionNote = FeatureFlags.nutritionEnabled
            ? ""
            : "\n\nNutrition tracking is not yet active in this app. Do not offer to log meals, set nutrition targets, or discuss nutrition tracking features — if asked, explain that nutrition tracking isn't available yet."

        var fullInstructions = baseInstructions + personaInstruction + nutritionNote

        // Inject persisted memories if any
        if let memoryBlock = AdvisorMemoryStore.shared.promptBlock {
            fullInstructions += "\n\nWHAT YOU REMEMBER ABOUT THIS USER (from earlier conversations — treat as true, honor it without being asked, and never present it back as if they just said it):\n\(memoryBlock)"
        }

        return fullInstructions
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
            UpdateExerciseLoadTool(recoveryScore: healthService.recoveryScore?.score),
            RememberPreferenceTool(),
            ForgetPreferenceTool()
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
