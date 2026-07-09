import SwiftUI
import HealthKit
public import Combine
import FoundationModels

struct HomeView: View {
    @Environment(HealthKitService.self) var service
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.sleepTargetHours) private var sleepTargetHours = UserProfile.defaultSleepTargetHours
    @AppStorage(UserProfileStorage.firstName) private var firstName = ""
    @Environment(AdvisorPresenter.self) private var advisorPresenter
    @State private var showingCalendar = false
    @State private var selectedHistoricalDate = Date()
    @State private var now = Date()

    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private let columns = [
        GridItem(.flexible(), spacing: 16),
        GridItem(.flexible(), spacing: 16)
    ]

    private var lastSyncedLabel: String {
        guard let date = service.lastSyncedDate else { return "Not yet synced" }
        let interval = now.timeIntervalSince(date)
        if interval < 10 { return "Updated just now" }
        if interval < 60 { return "Updated \(Int(interval))s ago" }
        let mins = Int(interval / 60)
        if mins < 60 { return "Updated \(mins)m ago" }
        let hours = Int(mins / 60)
        if hours < 24 { return "Updated \(hours)h ago" }
        return "Updated \(Int(hours / 24))d ago"
    }

    private var greetingTitle: String {
        let hour = Calendar.current.component(.hour, from: now)
        let timeGreeting: String
        switch hour {
        case 0..<12:  timeGreeting = "Good morning"
        case 12..<17: timeGreeting = "Good afternoon"
        case 17..<21: timeGreeting = "Good evening"
        default:      timeGreeting = "Good night"
        }
        let name = firstName.trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? timeGreeting : "\(timeGreeting), \(name)"
    }

    private var profile: UserProfile {
        UserProfile(
            goal: FitnessGoal(rawValue: goalRaw) ?? UserProfile.defaultGoal,
            ageRange: AgeRange(rawValue: ageRangeRaw) ?? UserProfile.defaultAgeRange,
            trainingDaysPerWeek: trainingDays,
            sleepTargetHours: sleepTargetHours
        )
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    HStack {
                        VStack(alignment: .leading, spacing: 4) {
                            Text(greetingTitle)
                                .font(.largeTitle.bold())
                            Text(lastSyncedLabel)
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    summaryGrid
                    personalizedOverviewSection
                    todaySection
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 20)
            }
            .refreshable {
                await service.refreshToday()
                await generateOverview(force: true)
            }
            .navigationTitle("")
            .navigationBarTitleDisplayMode(.inline)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .gradientHeader()
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: service.isSyncing)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ModeToolbarMenu()
                }
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if service.isSyncing {
                        HStack(spacing: 6) {
                            ProgressView()
                                .scaleEffect(0.75)
                            Text("Syncing")
                                .font(.caption.weight(.medium))
                                .foregroundStyle(.secondary)
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    } else {
                        Button {
                            showingCalendar = true
                        } label: {
                            Image(systemName: "calendar")
                        }
                        .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    }
                    Button {
                        advisorPresenter.open()
                    } label: {
                        Image(systemName: "sparkles")
                    }
                }
            }
            .sheet(isPresented: $showingCalendar) {
                HistoricalDataSheet(selectedDate: $selectedHistoricalDate)
                    .presentationDetents([.medium, .large])
                    .presentationDragIndicator(.visible)
                    .environment(service)
            }
            .task {
                await service.refreshIfStale()
                await generateOverview()
            }
            .onReceive(timer) { now = $0 }
        }
    }

    private var recovery: RecoveryScore {
        service.recoveryScore ?? RecoveryScore(
            score: 0, hrvValue: 0, restingHeartRate: 0,
            sleepQuality: 0, hrvBaseline: 0, rhrBaseline: 0,
            hrr: nil, hrrBaseline: nil
        )
    }

    private var exertion: ExertionScore {
        service.exertionScore ?? ExertionScore(
            score: 0, acuteLoad: 0, chronicLoad: 0,
            todayStrain: 0,
            zoneSplits: (1...5).map { ZoneTime(zone: $0, duration: 0, percentage: 0.2) }
        )
    }

    private var sleep: SleepAnalysis {
        service.sleepAnalysis ?? SleepAnalysis(
            totalDuration: 0, remDuration: 0,
            deepDuration: 0, coreDuration: 0, awakeDuration: 0
        )
    }

    private var stress: StressScore {
        service.stressScore ?? StressScore(
            score: 0, hrvValue: 0, restingHeartRate: 0,
            hrvBaseline: 0, rhrBaseline: 0
        )
    }

    private var personalizedOverviewSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Vector Intelligence")
                    .font(.title3.bold())
                Spacer()
                if service.isGeneratingOverview {
                    HStack(spacing: 5) {
                        ProgressView().scaleEffect(0.65)
                        Text("Personalizing")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }
            }

            GlassCard(tint: .cyan.opacity(0.18), cornerRadius: 24) {
                VStack(alignment: .leading, spacing: 10) {
                    if service.isGeneratingOverview && service.generatedOverview == nil {
                        overviewSkeleton
                    } else {
                        Text(service.generatedOverview?.headline ?? staticFocusHeadline)
                            .font(.headline)
                        Text(service.generatedOverview?.body ?? staticFocusBody)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }

                    if !service.isGeneratingOverview {
                        HStack(spacing: 6) {
                            Text("Sources:")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                            sourceChip(icon: "moon.fill", label: "Sleep", color: .blue)
                            sourceChip(icon: "heart.fill", label: "Recovery", color: .red)
                            sourceChip(icon: "flame.fill", label: "Load", color: .orange)
                            sourceChip(icon: "person.fill", label: "Profile", color: .purple)
                        }
                    }
                }
            }
            .askVector(AdvisorTopic(
                title: "Today's Overview",
                icon: "sparkles",
                tintName: "cyan",
                contextLines: [
                    service.generatedOverview?.headline ?? staticFocusHeadline,
                    service.generatedOverview?.body ?? staticFocusBody
                ],
                suggestedPrompt: "Tell me more about today's overview and what I should prioritize."
            ))
        }
    }

    private var overviewSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.2))
                .frame(width: 220, height: 16)
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.15))
                .frame(maxWidth: .infinity, minHeight: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.12))
                .frame(width: 180, height: 12)
        }
        .redacted(reason: .placeholder)
        .shimmering()
    }

    private var staticFocusLabel: String {
        if exertion.todayStrain > 150 { return "High Load" }
        else if recovery.score >= 70  { return "Build" }
        else if recovery.score < 45   { return "Recover" }
        else                          { return "Steady" }
    }

    private var staticFocusHeadline: String {
        let r = recovery.score > 0 ? "\(recovery.level.label.lowercased()) recovery" : "low data"
        let s = exertion.todayStrain > 0 ? "\(exertion.exertionLevel.label.lowercased()) exertion" : "no exertion yet"
        switch staticFocusLabel {
        case "High Load": return "Heavy day — \(s) logged so far."
        case "Build":     return "Green light to push — \(r) and \(s)."
        case "Recover":   return "Easy day — only \(r) and your body needs it."
        default:          return "Steady conditions — \(r) and \(s) on the board."
        }
    }

    private var staticFocusBody: String {
        let h = sleep.totalDuration > 0 ? String(format: "%.1fh sleep", sleep.asleepDuration / 3600) : "sleep data pending"
        let l = exertion.loadStatus.label.lowercased()
        switch staticFocusLabel {
        case "High Load": return "You've accumulated significant strain. With \(h) and a \(l) weekly load, keep the next session light or skip it."
        case "Build":     return "You have \(h) and a clear \(l) trend — room to add load without accumulating debt."
        case "Recover":
            let disruptionHint = sleep.disruption?.isFlagged == true
                ? " Signals like these often mean your body is under extra strain right now — prioritize rest and hydration."
                : ""
            return "Today isn't the day to push. With \(h) and your HRV pointing to fatigue, active recovery or full rest wins.\(disruptionHint)"
        default:          return "Your load is at a \(l) level with \(h) in the tank. Stay consistent today — that's where compound gains come from."
        }
    }

    private var timeOfDayContext: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 0..<6:   return "late-night"
        case 6..<12:  return "morning"
        case 12..<17: return "afternoon"
        case 17..<21: return "evening"
        default:      return "night"
        }
    }

    private var timeOfDayFocus: String {
        switch timeOfDayContext {
        case "morning", "late-night":
            return "Focus on how the athlete recovered overnight and their sleep quality. Frame the day ahead as an opportunity."
        case "afternoon":
            return "Focus on nutrition intake so far, exertion and training load. Encourage smart fueling and pacing for the rest of the day."
        case "evening", "night":
            return "Focus on winding down — summarise what was accomplished today, acknowledge the effort, and encourage quality sleep and recovery tonight."
        default:
            return "Provide a balanced overview of recovery, exertion, and readiness."
        }
    }

    private func generateOverview(force: Bool = false) async {
        guard force || service.generatedOverview == nil else { return }
        guard force || !service.isGeneratingOverview else { return }
        guard SystemLanguageModel.default.availability == .available else { return }
        guard recovery.score > 0 || sleep.totalDuration > 0 || exertion.todayStrain > 0 else { return }

        let nutrition = service.nutritionSummary
        let nutritionBlock: String
        if let n = nutrition, n.caloriesConsumed > 0 {
            nutritionBlock = """
            Nutrition today: \(String(format: "%.0f", n.caloriesConsumed)) kcal consumed, \
            \(String(format: "%.0f", n.protein))g protein, \
            \(String(format: "%.0f", n.carbs))g carbs, \
            \(String(format: "%.0f", n.fat))g fat. \
            Energy balance: \(n.energyBalance.label.lowercased())
            """
        } else {
            nutritionBlock = "Nutrition today: no logged meals yet"
        }

        let prompt = """
        Time of day: \(timeOfDayContext)
        Day of week: \(now.formatted(.dateTime.weekday(.wide)))

        \(timeOfDayFocus)

        Today's data:
        Recovery: \(recovery.score > 0 ? recovery.level.label : "no data")
        HRV: \(recovery.hrvValue > 0 ? String(format: "%.0f ms", recovery.hrvValue) : "unknown")
        Resting HR: \(recovery.restingHeartRate > 0 ? String(format: "%.0f bpm", recovery.restingHeartRate) : "unknown")
        Wrist temp: \(recovery.wristTempDeviation.map { String(format: "%+.1f°C vs baseline", $0) } ?? "unknown")
        Blood oxygen: \(recovery.spo2.map { String(format: "%.0f%%", $0) } ?? "unknown")
        Sleep: \(sleep.totalDuration > 0 ? String(format: "%.1fh asleep (%.1fh in bed), %.1fh deep, %.1fh REM, %@ quality", sleep.asleepDuration / 3600, sleep.totalDuration / 3600, sleep.deepDuration / 3600, sleep.remDuration / 3600, sleep.qualityLevel.label) : "no data")
        Awake in bed: \(sleep.totalDuration > 0 ? String(format: "%.0f min", sleep.awakeDuration / 60) : "unknown")
        Overnight disruption: \(sleep.disruption.map { $0.isFlagged ? "\($0.headline) — \($0.signals.joined(separator: ", "))" : "none detected" } ?? "unknown")
        Today's exertion level: \(exertion.todayStrain > 0 ? "\(exertion.exertionLevel.label) (\(exertion.loadStatus.label.lowercased()) weekly load)" : "none yet")
        Weekly training load: \(exertion.acuteLoad > 0 ? String(format: "%.0f load (%@)", exertion.acuteLoad, exertion.loadStatus.label) : "no data")
        Stress level: \(stress.score > 0 ? "\(stress.score)/100 (\(stress.level.label))" : "unknown")
        \(nutritionBlock)

        This overview is about RIGHT NOW — today only. Never reference tomorrow, future days, or upcoming sessions. Every recommendation must be something the athlete can act on immediately. Use your knowledge of exercise science, sleep physiology, and nutrition to add depth. If recovery or sleep quality is low AND overnight signals are off (elevated resting heart rate or wrist temperature, suppressed HRV, elevated breathing rate, or a disruption flag), tell the athlete that something appears to be straining their body right now and recommend rest, hydration, and light activity. Never name a specific cause (no illness, no alcohol, no diagnosis) — just flag that the body seems under strain.
        """

        // Run in an unstructured Task so switching tabs (which cancels the view's
        // .task) doesn't cancel an in-flight generation and force a restart.
        let generation = Task {
            service.isGeneratingOverview = true
            defer { service.isGeneratingOverview = false }
            do {
                let overviewInstructions = """
                    You're a coach who knows this athlete well, checking in like a text from a friend — direct, warm, natural. No jargon, no motivational-poster language, no formal report tone. Second person. \
                    Everything you write is about right now, today only. Never mention tomorrow, next session, or anything upcoming. \
                    Match your tone and focus to the time of day you're given. \
                    Think step-by-step about what the data means before writing your answer. \
                    Headline: a short status phrase, 2-4 words. Never a command, never a raw stat. \
                    Body: say less. 1-2 sentences, 3 at most. Reference the data naturally as insight, not a report — never cite a raw strain, exertion, or recovery score number, describe it qualitatively instead (e.g. high/moderate/low). \
                    The body must obey the time-of-day focus you are given. Never fabricate any number, workout, or event that is not in the provided data. \
                    Use your broad knowledge of sports science, circadian rhythm, and nutrition to add context, briefly.
                    """ + "\n\nTone: \(AdvisorPersona.current.instruction)"
                let session = LanguageModelSession(
                    model: SystemLanguageModel.default,
                    instructions: overviewInstructions
                )
                let result = try await session.respond(to: prompt, generating: GeneratedOverview.self)
                service.generatedOverview = result.content
            } catch {
                // Fall through to static fallback
            }
        }
        await generation.value
    }

    private var summaryGrid: some View {
        LazyVGrid(columns: columns, spacing: 16) {
            NavigationLink {
                RecoveryDetailView(score: recovery)
            } label: {
                RecoveryCard(
                    score: recovery,
                    progress: Double(recovery.score) / 100
                )
            }
            .buttonStyle(.plain)
            .askVector(AdvisorTopic(
                title: "Recovery",
                icon: "heart.fill",
                tintName: "green",
                contextLines: [
                    "Recovery score \(recovery.score)/100 (\(recovery.level.label))",
                    String(format: "HRV %.0f ms (baseline %.0f ms)", recovery.hrvValue, recovery.hrvBaseline),
                    String(format: "Resting HR %.0f bpm (baseline %.0f bpm)", recovery.restingHeartRate, recovery.rhrBaseline)
                ],
                suggestedPrompt: "Explain my recovery score today and what's driving it."
            ))

            NavigationLink {
                ExertionDetailView(score: exertion)
            } label: {
                ExertionCard(
                    score: exertion,
                    progress: min(exertion.todayStrain / 150, 1),
                    deemphasizeTarget: AppModeStore.shared.currentMode.deemphasizesExertion
                )
            }
            .buttonStyle(.plain)
            .askVector(AdvisorTopic(
                title: "Exertion",
                icon: "flame.fill",
                tintName: "orange",
                contextLines: [
                    "Exertion score \(exertion.score)/100 (\(exertion.exertionLevel.label))",
                    String(format: "Today's strain: %.0f", exertion.todayStrain),
                    String(format: "Acute load: %.0f (%@)", exertion.acuteLoad, exertion.loadStatus.label)
                ],
                suggestedPrompt: "Explain my training load and exertion today — am I overreaching or detraining?"
            ))

            NavigationLink {
                SleepDetailView(analysis: sleep)
            } label: {
                SleepCard(
                    analysis: sleep,
                    progress: sleep.quality
                )
            }
            .buttonStyle(.plain)
            .askVector(AdvisorTopic(
                title: "Sleep",
                icon: "moon.fill",
                tintName: "blue",
                contextLines: [
                    "Sleep duration: \(String(format: "%.1fh asleep (%.1fh in bed)", sleep.asleepDuration / 3600, sleep.totalDuration / 3600))",
                    "Quality level: \(sleep.qualityLevel.label)",
                    sleep.deepDuration > 0 ? String(format: "Deep sleep: %.1fh", sleep.deepDuration / 3600) : "Deep sleep: unknown"
                ],
                suggestedPrompt: "Explain my sleep last night, my sleep debt, and how to improve it."
            ))

            NavigationLink {
                StressDetailView(score: stress)
            } label: {
                StressCard(
                    score: stress,
                    progress: Double(stress.score) / 100
                )
            }
            .buttonStyle(.plain)
            .askVector(AdvisorTopic(
                title: "Stress",
                icon: "waveform.path.ecg",
                tintName: "purple",
                contextLines: [
                    "Stress score \(stress.score)/100 (\(stress.level.label))",
                    String(format: "HRV: %.0f ms", stress.hrvValue),
                    String(format: "Resting HR: %.0f bpm", stress.restingHeartRate)
                ],
                suggestedPrompt: "Explain my stress level today and what's contributing to it."
            ))
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Today's Vitals")
                .font(.title3.bold())

            LazyVGrid(columns: columns, spacing: 12) {
                vitalTile(icon: "heart.fill", label: "Heart Rate",
                          value: service.latestHeartRate.map { String(format: "%.0f", $0) } ?? "--",
                          unit: "bpm", color: .red)
                    .askVector(AdvisorTopic(
                        title: "Heart Rate",
                        icon: "heart.fill",
                        tintName: "red",
                        contextLines: [
                            String(format: "Current: %.0f bpm", service.latestHeartRate ?? 0),
                            "A key indicator of cardiovascular stress and recovery status"
                        ],
                        suggestedPrompt: "Explain what my heart rate means for my recovery and training readiness."
                    ))

                vitalTile(icon: "waveform.path.ecg", label: "HRV",
                          value: service.latestHRV.map { String(format: "%.0f", $0) } ?? "--",
                          unit: "ms", color: .cyan)
                    .askVector(AdvisorTopic(
                        title: "Heart Rate Variability",
                        icon: "waveform.path.ecg",
                        tintName: "cyan",
                        contextLines: [
                            String(format: "Current HRV: %.0f ms", service.latestHRV ?? 0),
                            "Higher HRV indicates parasympathetic activation and better recovery"
                        ],
                        suggestedPrompt: "What does my HRV tell me about my recovery and stress levels?"
                    ))

                vitalTile(icon: "heart.text.square", label: "Resting HR",
                          value: service.latestRestingHR.map { String(format: "%.0f", $0) } ?? "--",
                          unit: "bpm", color: .pink)
                    .askVector(AdvisorTopic(
                        title: "Resting Heart Rate",
                        icon: "heart.text.square",
                        tintName: "pink",
                        contextLines: [
                            String(format: "Current RHR: %.0f bpm", service.latestRestingHR ?? 0),
                            "Resting HR reflects baseline cardiovascular fitness"
                        ],
                        suggestedPrompt: "How does my resting heart rate affect my overall fitness?"
                    ))

                vitalTile(icon: "bed.double.fill", label: "Sleep",
                          value: service.sleepAnalysis?.formattedDuration ?? "--",
                          unit: "", color: .blue)
                    .askVector(AdvisorTopic(
                        title: "Sleep Duration",
                        icon: "bed.double.fill",
                        tintName: "blue",
                        contextLines: [
                            "Sleep duration: \(service.sleepAnalysis?.formattedDuration ?? "No data")",
                            "Quality sleep is essential for recovery and adaptation"
                        ],
                        suggestedPrompt: "Is my sleep duration and quality adequate for my training?"
                    ))

                vitalTile(icon: "flame.fill", label: "Active Energy",
                          value: service.todayActiveCalories > 0 ? String(format: "%.0f", service.todayActiveCalories) : "--",
                          unit: "kcal", color: .orange)
                    .askVector(AdvisorTopic(
                        title: "Active Energy",
                        icon: "flame.fill",
                        tintName: "orange",
                        contextLines: [
                            String(format: "Active calories: %.0f kcal", service.todayActiveCalories),
                            "Energy burned through movement and exercise"
                        ],
                        suggestedPrompt: "How does my active energy expenditure compare to my goals?"
                    ))

                vitalTile(icon: "flame", label: "Resting Energy",
                          value: service.todayBasalCalories > 0 ? String(format: "%.0f", service.todayBasalCalories) : "--",
                          unit: "kcal", color: .red)
                    .askVector(AdvisorTopic(
                        title: "Resting Energy",
                        icon: "flame",
                        tintName: "red",
                        contextLines: [
                            String(format: "Resting calories: %.0f kcal", service.todayBasalCalories),
                            "Baseline energy required for basic body functions"
                        ],
                        suggestedPrompt: "What is my basal metabolic rate and how does it affect my nutrition?"
                    ))

                vitalTile(icon: "figure.walk", label: "Steps",
                          value: service.todaySteps > 0 ? String(format: "%.0f", service.todaySteps) : "--",
                          unit: "steps", color: .green)
                    .askVector(AdvisorTopic(
                        title: "Steps",
                        icon: "figure.walk",
                        tintName: "green",
                        contextLines: [
                            String(format: "Today's steps: %.0f", service.todaySteps),
                            "Daily movement is crucial for overall health"
                        ],
                        suggestedPrompt: "Am I hitting my daily activity targets?"
                    ))
            }
        }
    }


    private func vitalTile(icon: String, label: String, value: String, unit: String, color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon)
                .font(.body)
                .foregroundStyle(color)
                .frame(width: 24)

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                HStack(spacing: 3) {
                    Text(value)
                        .font(.subheadline.bold())
                        .monospacedDigit()
                    Text(unit)
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                }
            }

            Spacer()
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 14))
    }


    private func sourceChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular.tint(color.opacity(0.12)), in: .capsule)
    }
}

struct HistoricalDataSheet: View {
    @Binding var selectedDate: Date
    @Environment(HealthKitService.self) var service
    @State private var sleep: SleepAnalysis?
    @State private var steps: Double = 0
    @State private var activeCalories: Double = 0
    @State private var isLoading = false

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    DatePicker(
                        "Select Date",
                        selection: $selectedDate,
                        in: ...Date(),
                        displayedComponents: .date
                    )
                    .datePickerStyle(.graphical)
                    .padding(.horizontal, 4)

                    recoveryHeatmapStrip

                    if isLoading {
                        ProgressView("Loading data…")
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 20)
                    } else {
                        historicalSummary
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 20)
            }
            .navigationTitle(selectedDate.formatted(date: .abbreviated, time: .omitted))
            .navigationBarTitleDisplayMode(.inline)
        }
        .task(id: selectedDate) {
            await fetchData(for: selectedDate)
        }
    }

    @ViewBuilder
    private var recoveryHeatmapStrip: some View {
        let series = Array(ScoreHistoryStore.series(for: .recovery).suffix(14))
        if !series.isEmpty {
            VStack(alignment: .leading, spacing: 6) {
                Text("Recovery · last 14 days")
                    .font(.caption).foregroundStyle(.secondary)
                HStack(spacing: 4) {
                    ForEach(series, id: \.date) { entry in
                        RoundedRectangle(cornerRadius: 4)
                            .fill(heatColor(entry.score))
                            .frame(maxWidth: .infinity)
                            .frame(height: 30)
                            .overlay(
                                Text("\(entry.score)")
                                    .font(.system(size: 9, weight: .bold))
                                    .foregroundStyle(.white)
                            )
                            .onTapGesture { selectedDate = entry.date }
                    }
                }
            }
            .padding(12)
            .glassEffect(in: .rect(cornerRadius: 14))
        }
    }

    private func heatColor(_ s: Int) -> Color {
        switch s {
        case ..<50: return .red
        case ..<70: return .orange
        case ..<85: return .green
        default:    return .mint
        }
    }

    private var scoresGrid: some View {
        let recovery = ScoreHistoryStore.score(for: .recovery, on: selectedDate)
        let stress = ScoreHistoryStore.score(for: .stress, on: selectedDate)
        let exertion = ScoreHistoryStore.score(for: .exertion, on: selectedDate)
        let sleepScore = sleep.map { Int($0.quality * 100) } ?? ScoreHistoryStore.score(for: .sleep, on: selectedDate)
        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            historicalScoreTile("Recovery", recovery, "heart.fill", .green)
            historicalScoreTile("Sleep", sleepScore, "moon.fill", .blue)
            historicalScoreTile("Exertion", exertion, "flame.fill", .orange)
            historicalScoreTile("Stress", stress, "waveform.path.ecg", .indigo)
        }
    }

    private func historicalScoreTile(_ label: String, _ score: Int?, _ icon: String, _ color: Color) -> some View {
        HStack(spacing: 10) {
            Image(systemName: icon).foregroundStyle(color).frame(width: 24)
            VStack(alignment: .leading, spacing: 2) {
                Text(label).font(.caption).foregroundStyle(.secondary)
                Text(score.map(String.init) ?? "—").font(.title3.bold().monospacedDigit())
            }
            Spacer()
        }
        .padding(12)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    private var historicalSummary: some View {
        VStack(spacing: 14) {
            scoresGrid
            if let sleep {
                HStack(spacing: 10) {
                    Image(systemName: "moon.fill")
                        .foregroundStyle(.blue)
                        .frame(width: 28)
                    VStack(alignment: .leading, spacing: 2) {
                        Text("Sleep")
                            .font(.caption).foregroundStyle(.secondary)
                        Text(sleep.formattedDuration)
                            .font(.subheadline.bold())
                    }
                    Spacer()
                    Text(sleep.qualityLevel.label)
                        .font(.caption.bold())
                        .foregroundStyle(sleep.qualityLevel.color)
                }
                .padding(12)
                .glassEffect(in: .rect(cornerRadius: 14))
            }

            HStack(spacing: 10) {
                Image(systemName: "figure.walk")
                    .foregroundStyle(.green)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Steps")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(steps > 0 ? String(format: "%.0f", steps) : "No data")
                        .font(.subheadline.bold()).monospacedDigit()
                }
                Spacer()
                Image(systemName: "flame.fill")
                    .foregroundStyle(.orange)
                    .frame(width: 28)
                VStack(alignment: .leading, spacing: 2) {
                    Text("Active Cal")
                        .font(.caption).foregroundStyle(.secondary)
                    Text(activeCalories > 0 ? String(format: "%.0f kcal", activeCalories) : "No data")
                        .font(.subheadline.bold()).monospacedDigit()
                }
            }
            .padding(12)
            .glassEffect(in: .rect(cornerRadius: 14))

            if sleep == nil && steps == 0 && activeCalories == 0
                && ScoreHistoryStore.score(for: .recovery, on: selectedDate) == nil
                && ScoreHistoryStore.score(for: .exertion, on: selectedDate) == nil
                && ScoreHistoryStore.score(for: .stress, on: selectedDate) == nil {
                Text("No health data found for this date.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.vertical, 16)
            }
        }
    }

    private func fetchData(for date: Date) async {
        isLoading = true
        defer { isLoading = false }
        async let sleepResult = service.fetchSleepAnalysis(for: date)
        async let stepsResult = service.fetchStatistic(for: .stepCount, unit: .count(), on: date)
        async let caloriesResult = service.fetchStatistic(for: .activeEnergyBurned, unit: .kilocalorie(), on: date)
        let (s, st, ac) = await (sleepResult, stepsResult, caloriesResult)
        sleep = s
        steps = st
        activeCalories = ac
    }
}

// MARK: - Generated Overview Model

@Generable
struct GeneratedOverview {
    @Guide(description: "Think step-by-step: consider the time of day, what metrics stand out, and what actionable advice fits this athlete's current state")
    var reasoningSteps: String
    @Guide(description: "A short 2-4 word summary of today's status as a noun phrase, like 'Recovery Day', 'Primed to Build', or 'Steady Effort'. Never an imperative command (never 'ACT NOW', 'PUSH HARD'), never a raw stat.")
    var headline: String
    @Guide(description: "1-2 sentences, 3 at most — say less. Natural, direct phrasing, like a coach who knows you texting a quick check-in, not a report. Second person, grounded ONLY in the numbers provided. Match the time-of-day focus. Do not invent metrics, workouts, meals, or events that are not in the provided data.")
    var body: String
    @Guide(description: "A 1-2 word status label that matches the recommendation, e.g. Build, Recover, Steady, Push, Rest Day")
    var status: String
}

// MARK: - Shimmer modifier

private extension View {
    @ViewBuilder func shimmering() -> some View {
        self.overlay {
            GeometryReader { geo in
                LinearGradient(
                    colors: [.clear, .white.opacity(0.35), .clear],
                    startPoint: .leading,
                    endPoint: .trailing
                )
                .frame(width: geo.size.width * 0.6)
                .offset(x: -geo.size.width)
            }
        }
        .clipped()
    }
}

#if DEBUG
#Preview {
    HomeView()
        .environment(HealthKitService.preview)
}
#endif
