import SwiftUI

struct AdvisorView: View {
    @Environment(HealthKitService.self) var healthService
    @Environment(AdvisorPresenter.self) private var presenter: AdvisorPresenter?

    var isMinimized: Bool = false

    @State private var advisor = VectorAdvisor.shared
    @State private var messageText = ""
    @State private var editingMeal: EditingMeal?
    @FocusState private var inputFocused: Bool

    private struct EditingMeal: Identifiable { let id: UUID }
    @State private var showHistory = false

    /// Height of the compose field / send button. Deliberately compact so the
    /// conversation gets the vertical space.
    private let barControlHeight: CGFloat = 42

    private var accent: LinearGradient {
        VectorTheme.brandForeground
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty && !advisor.isStreaming
    }

    // MARK: - Suggestions

    /// Prebuilt openers for the empty state. Context-aware ones come first,
    /// then generic fallbacks. Titles stay short — the full question goes in
    /// `prompt`, not on screen.
    private var suggestions: [AdvisorSuggestion] {
        var items: [AdvisorSuggestion] = []

        if let recovery = healthService.recoveryScore, recovery.score < 50 {
            items.append(AdvisorSuggestion(
                icon: "heart.fill",
                tint: .green,
                title: "Rest or train today?",
                subtitle: "Recovery is \(Int(recovery.score))",
                prompt: "My recovery is \(Int(recovery.score)) today — should I rest or train?"
            ))
        }

        if let sleep = healthService.sleepAnalysis {
            let debtHours = (sleep.sleepDebt ?? 0) / 3600
            if sleep.qualityLevel == .poor || debtHours > 1 {
                items.append(AdvisorSuggestion(
                    icon: "moon.stars.fill",
                    tint: .blue,
                    title: "Pay down sleep debt",
                    subtitle: debtHours >= 1 ? String(format: "%.1f h behind", debtHours) : "Last night scored low",
                    prompt: "How do I pay down my sleep debt?"
                ))
            }
        }

        var plateaued: String?
        outer: for template in WorkoutStorageService.shared.savedWorkouts {
            for exercise in template.exercises {
                if let insight = ProgressionAdvisor.insight(for: exercise, recoveryScore: healthService.recoveryScore?.score),
                   insight.kind == .plateau {
                    plateaued = exercise.name
                    break outer
                }
            }
        }
        if let name = plateaued {
            items.append(AdvisorSuggestion(
                icon: "chart.line.flattrend.xyaxis",
                tint: .orange,
                title: "Break a plateau",
                subtitle: name,
                prompt: "How do I break my \(name) plateau?"
            ))
        }

        if let exertion = healthService.exertionScore {
            let status = exertion.loadStatus.label.lowercased()
            if status.contains("overtraining") || status.contains("overreaching") {
                items.append(AdvisorSuggestion(
                    icon: "exclamationmark.triangle.fill",
                    tint: .red,
                    title: "Am I overtraining?",
                    subtitle: exertion.loadStatus.label,
                    prompt: "Am I overtraining this week?"
                ))
            }
        }

        let fallbacks = [
            AdvisorSuggestion(
                icon: "dumbbell.fill",
                tint: .indigo,
                title: "Build today's workout",
                subtitle: "Matched to your recovery",
                prompt: "Build me a workout for today based on my recovery."
            ),
            AdvisorSuggestion(
                icon: "target",
                tint: .cyan,
                title: "What should I focus on?",
                subtitle: "Today's priority",
                prompt: "What should I focus on today?"
            )
        ]
        for fallback in fallbacks where items.count < 3 {
            if !items.contains(where: { $0.prompt == fallback.prompt }) {
                items.append(fallback)
            }
        }

        return Array(items.prefix(3))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if advisor.messages.isEmpty {
                                EmptyStateHero()

                                VStack(spacing: 8) {
                                    ForEach(suggestions) { suggestion in
                                        SuggestionCard(suggestion: suggestion) {
                                            Task { await sendMessage(suggestion.prompt) }
                                        }
                                    }
                                }
                                .padding(.horizontal, 4)
                                .transition(.opacity)
                            } else {
                                messageList(proxy)

                                if !advisor.isStreaming, !advisor.suggestedReplies.isEmpty {
                                    VStack(alignment: .trailing, spacing: 8) {
                                        ForEach(advisor.suggestedReplies, id: \.self) { reply in
                                            Button {
                                                Task { await sendMessage(reply) }
                                            } label: {
                                                Text(reply)
                                                    .font(.subheadline)
                                                    .padding(.horizontal, 14)
                                                    .padding(.vertical, 9)
                                                    .glassEffect(.regular.tint(.indigo.opacity(0.12)), in: .capsule)
                                            }
                                            .buttonStyle(.plain)
                                        }
                                    }
                                    .frame(maxWidth: .infinity, alignment: .trailing)
                                    .id("suggested-replies")
                                    .transition(.opacity.combined(with: .move(edge: .bottom)))
                                }
                            }
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 12)
                    }
                    .onChange(of: advisor.messages.count) {
                        scrollToLast(proxy)
                    }
                    .onChange(of: advisor.messages.last?.content) {
                        scrollToLast(proxy)
                    }
                    .onChange(of: advisor.suggestedReplies) {
                        if !advisor.suggestedReplies.isEmpty {
                            withAnimation(.easeOut(duration: 0.25)) {
                                proxy.scrollTo("suggested-replies", anchor: .bottom)
                            }
                        }
                    }
                    .scrollEdgeEffectStyle(.soft, for: .all)
                    .safeAreaBar(edge: .bottom) {
                        inputBar
                    }
                }
            }
            .navigationTitle("")
            .toolbarTitleDisplayMode(.inline)
            .containerBackground(isMinimized ? AnyShapeStyle(.clear) : AnyShapeStyle(.background), for: .navigation)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button {
                        showHistory = true
                    } label: {
                        Image(systemName: "clock.arrow.circlepath")
                    }
                }
                ToolbarItem(placement: .principal) {
                    Text("Vector Intelligence")
                        .font(.headline)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        advisor.startNewChat()
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(advisor.messages.isEmpty)
                }
            }
            .vectorSheet(isPresented: $showHistory) {
                AdvisorHistorySheet { conversation in
                    advisor.restore(conversation)
                } onConfigure: {
                    presenter?.openProfile()
                }
            }
            .vectorSheet(item: $editingMeal) { item in
                MealEditSheet(mealID: item.id)
            }
            .task {
                advisor.prewarm(healthService: healthService)

                if let topic = presenter?.pendingTopic {
                    presenter?.pendingTopic = nil
                    await sendMessage(
                        topic.suggestedPrompt,
                        topic: topic
                    )
                }
            }
            .onChange(of: presenter?.pendingTopic) {
                Task {
                    if let topic = presenter?.pendingTopic {
                        presenter?.pendingTopic = nil
                        await sendMessage(
                            topic.suggestedPrompt,
                            topic: topic
                        )
                    }
                }
            }
        }
    }

    // MARK: - Message List

    @ViewBuilder
    private func messageList(_ proxy: ScrollViewProxy) -> some View {
        ForEach(Array(advisor.messages.enumerated()), id: \.element.id) { index, message in
            Group {
                // Day separator
                if index > 0,
                   advisor.messages.indices.contains(index - 1),
                   !Calendar.current.isDate(advisor.messages[index - 1].timestamp, inSameDayAs: message.timestamp) {
                    DaySeparator(date: message.timestamp)
                        .id("separator-\(message.id)")
                }

                if message.role == .user {
                    // Context chip if topic exists
                    if let topic = message.topic {
                        ContextChipCard(topic: topic)
                            .frame(maxWidth: .infinity, alignment: .trailing)
                    }

                    // User message
                    HStack {
                        Spacer()
                        Text(message.content)
                            .font(.body)
                            .padding()
                            .glassEffect(.regular.tint(.cyan.opacity(0.18)), in: ChatBubble(side: .trailing))
                    }
                    .id(message.id)
                } else {
                    // Assistant message
                    let isLast = message.id == advisor.messages.last?.id
                    let isStreaming = isLast && advisor.isStreaming

                    VStack(alignment: .leading, spacing: 8) {
                        // Live activity while streaming
                        if isStreaming {
                            ThinkingTrailView(
                                steps: AdvisorActivity.shared.steps,
                                liveReasoning: AdvisorActivity.shared.liveReasoning
                            )
                        } else if !message.steps.isEmpty {
                            ThoughtProcessView(steps: message.steps)
                        }

                        // Content
                        if !message.content.isEmpty {
                            MarkdownText(content: message.content)
                                .padding()
                                .glassEffect(.regular, in: ChatBubble(side: .leading))
                        }

                        // Action rows (undo-able or plain)
                        if let actions = advisor.liveActions[message.id] {
                            ForEach(actions) { action in
                                ActionRowView(action: action) { mealID in
                                    editingMeal = EditingMeal(id: mealID)
                                }
                            }
                        } else {
                            ForEach(message.actionSummaries, id: \.self) { summary in
                                HStack(spacing: 10) {
                                    Image(systemName: "checkmark.seal.fill")
                                        .foregroundStyle(.green)
                                    Text(summary)
                                        .font(.caption)
                                        .foregroundStyle(.primary)
                                    Spacer()
                                }
                                .padding(10)
                                .glassEffect(.regular.tint(.green.opacity(0.10)), in: .rect(cornerRadius: 12))
                            }
                        }

                        // Workout recommendation cards (Add / Dismiss)
                        if let recommendations = advisor.liveRecommendations[message.id] {
                            ForEach(recommendations) { recommendation in
                                RecommendationCardView(recommendation: recommendation)
                            }
                        }

                        // Existing-workout progressive-overload cards (select & Update)
                        if let updates = advisor.liveExerciseUpdates[message.id] {
                            ForEach(updates) { update in
                                ExerciseUpdateCardView(update: update)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(message.id)
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 8) {
            // Skill shortcuts are only useful once a conversation exists — in the
            // empty state the suggestion cards already cover the same ground.
            if !advisor.messages.isEmpty, !advisor.isStreaming {
                SkillRow { skill in
                    if skill.prefillsOnly {
                        messageText = skill.prompt
                    } else {
                        Task { await sendMessage(skill.prompt) }
                    }
                }
                .transition(.opacity)
            }

            HStack(alignment: .bottom, spacing: 8) {
                TextField("Ask Vector anything…", text: $messageText, axis: .vertical)
                    .focused($inputFocused)
                    .font(.subheadline)
                    .lineLimit(1...5)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 11)
                    .frame(minHeight: barControlHeight)
                    .glassEffect(.regular, in: .capsule)
                    .textInputAutocapitalization(.sentences)
                    .onSubmit {
                        let text = messageText.trimmingCharacters(in: .whitespaces)
                        if !text.isEmpty {
                            Task { await sendMessage(text) }
                        }
                    }

                Button {
                    Task {
                        await sendMessage(messageText)
                    }
                } label: {
                    if advisor.isStreaming {
                        ProgressView()
                            .controlSize(.small)
                            .frame(width: barControlHeight, height: barControlHeight)
                            .glassEffect(.regular, in: .circle)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 16, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: barControlHeight, height: barControlHeight)
                            .background(Circle().fill(accent))
                            .opacity(canSend ? 1 : 0.35)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
                .animation(.spring(response: 0.3, dampingFraction: 0.8), value: canSend)
            }
            .padding(.horizontal, 16)
        }
        .padding(.top, 8)
        .padding(.bottom, 6)
        .animation(.easeInOut(duration: 0.2), value: advisor.messages.isEmpty)
    }

    // MARK: - Send Message

    private func sendMessage(_ text: String, topic: AdvisorTopic? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
        inputFocused = false
        messageText = ""

        await advisor.send(trimmed, topic: topic, healthService: healthService)
    }

    private func scrollToLast(_ proxy: ScrollViewProxy) {
        if let lastId = advisor.messages.last?.id {
            withAnimation(.easeOut(duration: 0.25)) {
                proxy.scrollTo(lastId, anchor: .bottom)
            }
        }
    }
}

#Preview {
    let healthService = HealthKitService()
    return AdvisorView()
        .environment(healthService)
}
