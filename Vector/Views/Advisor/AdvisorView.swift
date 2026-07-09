import SwiftUI

struct AdvisorView: View {
    @Environment(HealthKitService.self) var healthService
    @Environment(AdvisorPresenter.self) private var presenter: AdvisorPresenter?

    var isMinimized: Bool = false

    @State private var advisor = VectorAdvisor.shared
    @State private var messageText = ""
    @State private var editingMeal: EditingMeal?

    private struct EditingMeal: Identifiable { let id: UUID }
    @State private var showingResetConfirmation = false

    private var accent: LinearGradient {
        LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private var canSend: Bool {
        !messageText.trimmingCharacters(in: .whitespaces).isEmpty && !advisor.isStreaming
    }

    // MARK: - Suggestion Chips

    private var suggestionChips: [String] {
        var chips: [String] = []

        // recovery < 50 → rest or train
        if let recovery = healthService.recoveryScore, recovery.score < 50 {
            chips.append("Should I rest or train today?")
        }

        // sleep debt check
        if let sleep = healthService.sleepAnalysis {
            if sleep.qualityLevel == .poor || (sleep.sleepDebt ?? 0) > 3600 {
                chips.append("How do I pay down my sleep debt?")
            }
        }

        // check for plateaus in exercises
        var plateaudExercise: String?
        for template in WorkoutStorageService.shared.savedWorkouts {
            for exercise in template.exercises {
                if let insight = ProgressionAdvisor.insight(for: exercise),
                   insight.kind == .plateau {
                    plateaudExercise = exercise.name
                    break
                }
            }
            if plateaudExercise != nil { break }
        }
        if let exerciseName = plateaudExercise {
            chips.append("How do I break my \(exerciseName) plateau?")
        }

        // exertion load status check (overtraining or overreaching)
        if let exertion = healthService.exertionScore {
            let status = exertion.loadStatus.label.lowercased()
            if status.contains("overtraining") || status.contains("overreaching") {
                chips.append("Am I overtraining this week?")
            }
        }

        // fill remaining with defaults
        let defaults = ["Build me a 45-min push day", "What should I focus on today?"]
        for def in defaults {
            if chips.count >= 4 { break }
            if !chips.contains(def) {
                chips.append(def)
            }
        }

        return Array(chips.prefix(4))
    }

    // MARK: - Body

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                readinessStrip
                    .animation(.easeInOut(duration: 0.2), value: isMinimized)

                ScrollViewReader { proxy in
                    ScrollView {
                        VStack(spacing: 12) {
                            if advisor.messages.isEmpty {
                                EmptyStateHero()

                                VStack(spacing: 8) {
                                    ForEach(suggestionChips, id: \.self) { chip in
                                        SuggestionChip(text: chip) {
                                            Task { await sendMessage(chip) }
                                        }
                                    }
                                }
                                .padding(.horizontal, 16)
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
                }

                inputBar
            }
            .navigationTitle("Vector Intelligence")
            .containerBackground(isMinimized ? AnyShapeStyle(.clear) : AnyShapeStyle(.background), for: .navigation)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showingResetConfirmation = true
                    } label: {
                        Image(systemName: "square.and.pencil")
                    }
                    .disabled(advisor.messages.isEmpty)
                    .confirmationDialog(
                        "Start a new conversation?",
                        isPresented: $showingResetConfirmation
                    ) {
                        Button("Start New", role: .destructive) {
                            advisor.resetConversation()
                        }
                    }
                }
            }
            .sheet(item: $editingMeal) { item in
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

    // MARK: - Readiness Strip

    private var readinessStrip: some View {
        HStack(spacing: 10) {
            ReadinessPill(
                label: "Recovery",
                value: healthService.recoveryScore.map { "\($0.score)" } ?? "--",
                icon: "heart.fill",
                tintColor: .green
            )

            ReadinessPill(
                label: "Load",
                value: healthService.exertionScore?.loadStatus.label ?? "--",
                icon: "bolt.fill",
                tintColor: .orange
            )

            ReadinessPill(
                label: "Sleep",
                value: healthService.sleepAnalysis?.qualityLevel.label ?? "--",
                icon: "moon.stars.fill",
                tintColor: .blue
            )
        }
        .padding(12)
        .background(isMinimized ? AnyShapeStyle(.clear) : AnyShapeStyle(.bar))
    }

    // MARK: - Message List

    @ViewBuilder
    private func messageList(_ proxy: ScrollViewProxy) -> some View {
        ForEach(Array(advisor.messages.enumerated()), id: \.element.id) { index, message in
            Group {
                // Day separator
                if index > 0,
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
                            .glassEffect(.regular.tint(.cyan.opacity(0.18)), in: .rect(cornerRadius: 16))
                    }
                    .id(message.id)
                } else {
                    // Assistant message
                    let isLast = message.id == advisor.messages.last?.id
                    let isStreaming = isLast && advisor.isStreaming

                    VStack(alignment: .leading, spacing: 8) {
                        // Live activity while streaming
                        if isStreaming {
                            LiveActivityView(
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
                                .glassEffect(.regular, in: .rect(cornerRadius: 16))
                        } else if isStreaming {
                            HStack {
                                ThinkingDots()
                                Text("Thinking…")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                                Spacer()
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .glassEffect(.regular, in: .rect(cornerRadius: 16))
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
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)
                    .id(message.id)
                }
            }
        }
    }

    // MARK: - Input Bar

    private var inputBar: some View {
        VStack(spacing: 10) {
            if !advisor.isStreaming {
                SkillRow { skill in
                    if skill.prefillsOnly {
                        messageText = skill.prompt
                    } else {
                        Task { await sendMessage(skill.prompt) }
                    }
                }
            }

            HStack(spacing: 12) {
                TextField("Ask Vector anything…", text: $messageText)
                    .padding(12)
                    .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
                            .scaleEffect(0.7)
                            .frame(width: 42, height: 42)
                    } else {
                        Image(systemName: "arrow.up")
                            .font(.system(size: 18, weight: .bold))
                            .foregroundStyle(.white)
                            .frame(width: 42, height: 42)
                            .background(Circle().fill(accent))
                            .opacity(canSend ? 1 : 0.4)
                    }
                }
                .buttonStyle(.plain)
                .disabled(!canSend)
            }
            .padding(.horizontal)
        }
        .padding(.top, 12)
        .padding(.bottom, 20)
        .background(isMinimized ? AnyShapeStyle(.clear) : AnyShapeStyle(.bar))
    }

    // MARK: - Send Message

    private func sendMessage(_ text: String, topic: AdvisorTopic? = nil) async {
        let trimmed = text.trimmingCharacters(in: .whitespaces)
        guard !trimmed.isEmpty else { return }
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
