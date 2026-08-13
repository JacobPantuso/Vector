import FoundationModels
import Foundation
import os

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

    private static let advisorLog = Logger(subsystem: "com.jacobpantuso.Vector", category: "VectorAdvisor")

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
            Self.advisorLog.error("Advisor send: session could not be created")
            #if DEBUG
            print("[VectorAdvisor] Advisor send: session could not be created")
            #endif
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
            Self.advisorLog.error("Advisor stream failed (first attempt): \(String(describing: error), privacy: .public) — \(error.localizedDescription, privacy: .public)")
            #if DEBUG
            print("[VectorAdvisor] Advisor stream failed (first attempt): \(String(describing: error)) — \(error.localizedDescription)")
            #endif
            self.session = nil
            ensureSession(healthService: healthService)
            guard let retrySession = self.session else {
                Self.advisorLog.error("Advisor send: retry session could not be created")
                #if DEBUG
                print("[VectorAdvisor] Advisor send: retry session could not be created")
                #endif
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
                Self.advisorLog.error("Advisor stream failed (retry attempt): \(String(describing: error), privacy: .public) — \(error.localizedDescription, privacy: .public)")
                #if DEBUG
                print("[VectorAdvisor] Advisor stream failed (retry attempt): \(String(describing: error)) — \(error.localizedDescription)")
                #endif
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
        lastSnapshotHash = nil
        AdvisorActivity.shared.reset()
        save()
    }

    // MARK: - Private helpers

    /// Build a plain history array of prompts and responses (no instructions entry)
    /// for use with the DynamicProfile path. Only complete exchanges are included.
    private func buildPlainHistory() -> [Transcript.Entry] {
        // Only complete exchanges belong in the history. The current user message
        // and empty assistant placeholder that `send` appends are submitted separately
        // via streamResponse, so they must not appear here to avoid duplication.
        guard let lastAnswered = messages.lastIndex(where: {
            $0.role == .assistant && !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty
        }) else { return [] }

        let recent = messages[...lastAnswered]
            .filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !recent.isEmpty else { return [] }

        var entries: [Transcript.Entry] = []

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

        return entries
    }

    private func ensureSession(healthService: HealthKitService) {
        let today = Calendar.current.startOfDay(for: Date())

        if session == nil || sessionDay != today {
            session = nil
            lastSnapshotHash = nil

            // iOS 27+ path: use DynamicProfile-based session
            let defaults = UserDefaults.standard
            let userProfile = UserProfile(
                goal: FitnessGoal(rawValue: defaults.string(forKey: UserProfileStorage.goal) ?? "") ?? UserProfile.defaultGoal,
                ageRange: AgeRange(rawValue: defaults.string(forKey: UserProfileStorage.ageRange) ?? "") ?? UserProfile.defaultAgeRange,
                trainingDaysPerWeek: defaults.object(forKey: UserProfileStorage.trainingDays) as? Int ?? UserProfile.defaultTrainingDays,
                sleepTargetHours: defaults.object(forKey: UserProfileStorage.sleepTargetHours) as? Double ?? UserProfile.defaultSleepTargetHours
            )

            let profile = AdvisorProfile(
                userProfile: userProfile,
                recoveryScore: healthService.recoveryScore,
                exertionScore: healthService.exertionScore
            )

            // Build plain history (prompts/responses only, no instructions entry)
            // The profile's .historyTransform handles suffix(12), so pass full history
            let plainHistory = buildPlainHistory()
            if !plainHistory.isEmpty {
                session = LanguageModelSession(profile: profile, history: plainHistory)
                session?.prewarm()
            } else {
                session = LanguageModelSession(profile: profile)
            }

            sessionDay = today

            #if DEBUG
            print("[VectorAdvisor] Model capabilities — reasoning: \(AIModel.supportsReasoning), toolCalling: \(SystemLanguageModel.default.capabilities.contains(.toolCalling)), guidedGeneration: \(SystemLanguageModel.default.capabilities.contains(.guidedGeneration))")
            #endif
        }

        // Always refresh live values, whether or not the session was rebuilt.
        // This ensures persona and memory changes mid-session reach the model immediately.
        session?.properties.advisorPersona = AdvisorPersona.current
        session?.properties.advisorMemories = AdvisorMemoryStore.shared.memories
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
            // Non-essential nicety — log but don't surface.
            Self.advisorLog.debug("Advisor suggested replies generation failed: \(String(describing: error), privacy: .public) — \(error.localizedDescription, privacy: .public)")
            #if DEBUG
            print("[VectorAdvisor] Advisor suggested replies generation failed: \(String(describing: error)) — \(error.localizedDescription)")
            #endif
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
