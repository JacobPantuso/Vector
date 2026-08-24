import SwiftUI
import HealthKit
public import Combine
import FoundationModels
import os

struct HomeView: View {
    @Environment(HealthKitService.self) var service
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.sleepTargetHours) private var sleepTargetHours = UserProfile.defaultSleepTargetHours
    @AppStorage(UserProfileStorage.firstName) private var firstName = ""
    @Environment(AdvisorPresenter.self) private var advisorPresenter
    @Environment(\.accessibilityReduceMotion) private var reduceMotion
    @Environment(\.scenePhase) private var scenePhase
    @State private var showingCalendar = false
    @State private var selectedHistoricalDate = Date()
    @State private var now = Date()
    @State private var headerScroll = HeaderScrollState()
    @State private var vitalsLayout = VitalsLayoutStore.shared
    @State private var vitalsSeries = VitalsSeriesStore()
    @State private var bodySignals = BodySignalMonitor.shared
    @State private var checkInQueue: [StrainPatternDetector.StrainEpisode] = []
    @State private var showingBodyCheckIn = false
    /// Episode keys already offered this session, so a swipe-dismiss doesn't
    /// immediately re-present the same prompt.
    @State private var promptedKeys: Set<String> = []
    @State private var showingVitalsCustomize = false
    @State private var vitalsContentWidth: CGFloat = 0

    private static let overviewLog = Logger(subsystem: "com.jacobpantuso.Vector", category: "DashboardOverview")

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

    private var greetingEmoji: String {
        let hour = Calendar.current.component(.hour, from: now)
        switch hour {
        case 0..<12:  return "☀️"
        case 12..<17: return "🌤️"
        case 17..<21: return "🌆"
        default:      return "🌙"
        }
    }

    private var greetingHeadline: String {
        "\(greetingTitle) \(greetingEmoji)"
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
                    VStack(alignment: .leading, spacing: 18) {
                        expandedHeader
                        gradientOverviewHeader
                    }
                    summaryGrid
                    bodyPatternsSection
                    todaySection
                }
                .padding(.horizontal, 20)
                .padding(.top, 10)
                .padding(.bottom, 20)
            }
            .onScrollGeometryChange(for: CGFloat.self) {
                $0.contentOffset.y
            } action: { _, new in
                headerScroll.offset = new
            }
            .refreshable {
                await service.refreshToday()
                await generateOverview(force: true)
                await vitalsSeries.load(service: service, force: true)
                await bodySignals.refresh(service: service, force: true)
            }
            .toolbar(.hidden, for: .navigationBar)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .gradientHeader(height: 460)
            .animation(.spring(response: 0.3, dampingFraction: 0.7), value: service.isSyncing)
            .animation(.spring(duration: 0.3), value: showingCalendar)
            .overlay(alignment: .top) {
                CompactHeaderBar(
                    scroll: headerScroll,
                    date: now,
                    isSyncing: service.isSyncing,
                    onTapDate: {
                        selectedHistoricalDate = Date()
                        showingCalendar = true
                    }
                )
            }
            .vectorSheet(isPresented: $showingCalendar) {
                HistoricalDataSheet(selectedDate: $selectedHistoricalDate)
                    .environment(service)
            }
            .vectorSheet(isPresented: $showingVitalsCustomize) {
                VitalsCustomizeSheet(store: vitalsLayout)
                    .presentationDetents([.large])
                    .presentationDragIndicator(.visible)
            }
            .vectorSheet(isPresented: $showingBodyCheckIn, style: .half) {
                BodyCheckInSheet(episodes: checkInQueue) {
                    showingBodyCheckIn = false
                }
            }
            .task {
                await service.refreshIfStale()
                await generateOverview()
                await vitalsSeries.load(service: service)
                await bodySignals.refresh(service: service)
                if let live = bodySignals.liveEpisode, !promptedKeys.contains(live.key) {
                    promptedKeys.insert(live.key)
                    checkInQueue = [live]
                    showingBodyCheckIn = true
                }
            }
            .onReceive(timer) { now = $0 }
            .onChange(of: timeOfDayContext) {
                // The guards in generateOverview() compare against lastOverviewContext,
                // so this regenerates exactly once per rollover rather than repeatedly.
                Task { await generateOverview() }
            }
            .onChange(of: scenePhase) { _, newPhase in
                guard newPhase == .active else { return }
                // The timer is suspended in the background, so `now` — and therefore
                // timeOfDayContext — is stale until it is refreshed here.
                now = Date()
                Task { await generateOverview() }
            }
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

    /// Only show the skeleton when there is nothing to show yet. A background
    /// regeneration must never replace text that is already on screen.
    private var isOverviewLoading: Bool {
        service.isGeneratingOverview && service.generatedOverview == nil
    }

    private var headerStatusControls: some View {
        HStack(spacing: 8) {
            if service.isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular, in: .circle)
                    .transition(.opacity.combined(with: .scale(scale: 0.8)))
            }
            ModeToolbarMenu(style: .headerChip)
        }
    }

    private var expandedHeader: some View {
        HStack(alignment: .center, spacing: 12) {
            Button {
                selectedHistoricalDate = Date()
                showingCalendar = true
            } label: {
                VStack(alignment: .leading, spacing: 0) {
                    Text(now.formatted(.dateTime.weekday(.wide)))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)

                    HStack(spacing: 6) {
                        Text(now.formatted(.dateTime.month(.wide).day()))
                            .font(.system(size: 28, weight: .bold))
                        Image(systemName: "chevron.down")
                            .font(.system(size: 13, weight: .bold))
                            .foregroundStyle(.secondary)
                            .rotationEffect(.degrees(showingCalendar && !reduceMotion ? 180 : 0))
                    }
                }
                .foregroundStyle(.primary)
                .frame(maxWidth: .infinity, alignment: .leading)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View historical data")
            .accessibilityHint("Opens a calendar to browse past days")

            headerStatusControls
        }
    }

    private var gradientOverviewHeader: some View {
        VStack(alignment: .leading, spacing: 10) {
            if isOverviewLoading {
                overviewSkeleton
            } else {
                Text(greetingHeadline)
                    .font(.title3.weight(.semibold))
                    .transition(.opacity.combined(with: .move(edge: .top)))

                Text(service.generatedOverview?.body ?? staticFocusBody)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
                    .transition(.opacity.combined(with: .move(edge: .top)))
            }

            if !isOverviewLoading {
                HStack(spacing: 6) {
                    Group {
                        sourceChip(icon: "moon.fill", label: "Sleep", color: .blue)
                        sourceChip(icon: "heart.fill", label: "Recovery", color: .red)
                        sourceChip(icon: "flame.fill", label: "Load", color: .orange)
                        sourceChip(icon: "person.fill", label: "Profile", color: .purple)
                    }
                    .transition(.opacity.combined(with: .scale(scale: 0.9)))
                    Spacer()
                    Text(lastSyncedLabel)
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .truncationMode(.tail)
                }
                .transition(.opacity)
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .animation(.smooth(duration: 0.35), value: isOverviewLoading)
        .animation(.spring(duration: 0.3), value: isOverviewLoading)
        .askVector(AdvisorTopic(
            title: "Today's Overview",
            icon: "sparkles",
            tintName: "cyan",
            contextLines: [
                staticFocusHeadline,
                service.generatedOverview?.body ?? staticFocusBody
            ],
            suggestedPrompt: "Tell me more about today's overview and what I should prioritize."
        ))
    }

    private var overviewSkeleton: some View {
        VStack(alignment: .leading, spacing: 8) {
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.3))
                .frame(maxWidth: .infinity, minHeight: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.26))
                .frame(width: 180, height: 12)
            RoundedRectangle(cornerRadius: 4)
                .fill(.secondary.opacity(0.22))
                .frame(width: 120, height: 12)
        }
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
        case "late-night":
            return "It is the middle of the night and the athlete is awake right now. Keep it short and calm. Focus on rest and getting back to sleep. Do not prescribe training, and do not frame this as the start of a new day."
        case "morning":
            return "Focus on how the athlete recovered overnight and their sleep quality. Frame the day ahead as an opportunity."
        case "afternoon":
            if FeatureFlags.nutritionEnabled {
                return "Focus on nutrition intake so far, exertion and training load. Encourage smart fueling and pacing for the rest of the day."
            } else {
                return "Focus on exertion and training load so far. Encourage smart pacing for the rest of the day."
            }
        case "evening":
            return "Focus on winding down — summarise what was accomplished today, acknowledge the effort, and encourage quality sleep and recovery tonight."
        case "night":
            return "It is late in the evening. Focus on closing out the day and protecting tonight's sleep. Acknowledge the day's effort briefly and steer toward getting to bed rather than any further training."
        default:
            return "Provide a balanced overview of recovery, exertion, and readiness."
        }
    }

    private func generateOverview(force: Bool = false) async {
        guard !service.isGeneratingOverview else { return }
        // Regenerate when the time-of-day bucket rolls over: the prompt is explicitly
        // scoped to morning/afternoon/evening, so a morning overview is stale by night.
        guard force || service.generatedOverview == nil || service.lastOverviewContext != timeOfDayContext else { return }
        // A tab return re-runs this view's `.task`; without this an attempt that
        // bailed early (no data, model unavailable, error) would re-fire the
        // skeleton every time Home reappears. Scoped to the bucket so a failed
        // attempt recovers at the next rollover instead of being stuck all day.
        guard force || !service.hasAttemptedOverview(for: timeOfDayContext) else { return }
        guard SystemLanguageModel.default.availability == .available else {
            Self.overviewLog.error("Overview skipped: model unavailable (\(String(describing: SystemLanguageModel.default.availability), privacy: .public))")
            #if DEBUG
            print("[DashboardOverview] skipped: model unavailable — \(String(describing: SystemLanguageModel.default.availability))")
            #endif
            return
        }
        guard recovery.score > 0 || sleep.totalDuration > 0 || exertion.todayStrain > 0 else {
            Self.overviewLog.error("Overview skipped: no data yet (recovery \(recovery.score, privacy: .public), sleep \(sleep.totalDuration, privacy: .public), strain \(exertion.todayStrain, privacy: .public))")
            #if DEBUG
            print("[DashboardOverview] skipped: no data yet — recovery \(recovery.score), sleep \(sleep.totalDuration), strain \(exertion.todayStrain)")
            #endif
            return
        }

        let nutritionBlock: String
        if FeatureFlags.nutritionEnabled {
            let nutrition = service.nutritionSummary
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
        } else {
            nutritionBlock = ""
        }

        let nutritionLine = nutritionBlock.isEmpty ? "" : "\n\(nutritionBlock)"
        let prompt = """
        Right now: \(timeOfDayContext), \(now.formatted(date: .omitted, time: .shortened)) local time
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
        Overnight disruption: \(sleep.disruption.map { $0.isFlagged ? "\($0.modelSafeHeadline) — \($0.signals.joined(separator: ", "))" : "none detected" } ?? "unknown")
        Today's exertion level: \(exertion.todayStrain > 0 ? "\(exertion.exertionLevel.label) (\(exertion.loadStatus.label.lowercased()) weekly load)" : "none yet")
        Weekly training load: \(exertion.acuteLoad > 0 ? String(format: "%.0f load (%@)", exertion.acuteLoad, exertion.loadStatus.label) : "no data")
        Stress level: \(stress.score > 0 ? "\(stress.score)/100 (\(stress.level.label))" : "unknown")\(nutritionLine)

        This overview is about RIGHT NOW — today only. Never reference tomorrow, future days, or upcoming sessions. Every recommendation must be something the athlete can act on immediately. Use your knowledge of exercise science and sleep physiology to add depth. When recovery or sleep quality is low and the overnight readings sit away from their usual baselines, explain it from the training data above. If weekly training load is moderate or high, or there was meaningful exertion today, treat it as accumulated training stress — the body is still absorbing recent work — and suggest an easy day, fluids, and light movement. If training load is low, absent, or has no data and the overnight readings are still away from baseline, do not attribute it to training; say the readings suggest the body is recovering from something outside of training, and suggest an easy day, fluids, and holding off on hard efforts. Describe what the readings show and leave the cause open.
        """

        // A guardrail refusal is deterministic, so the retry must not resend the same
        // text. This trimmed prompt keeps the metrics and the time-of-day focus but
        // drops the interpretive paragraph that is most likely to trip the filter.
        let fallbackPrompt = """
        Right now: \(timeOfDayContext), \(now.formatted(date: .omitted, time: .shortened)) local time

        \(timeOfDayFocus)

        Today's data:
        Recovery: \(recovery.score > 0 ? recovery.level.label : "no data")
        Sleep: \(sleep.totalDuration > 0 ? String(format: "%.1fh asleep, %@ quality", sleep.asleepDuration / 3600, sleep.qualityLevel.label) : "no data")
        Today's exertion level: \(exertion.todayStrain > 0 ? exertion.exertionLevel.label : "none yet")
        Weekly training load: \(exertion.acuteLoad > 0 ? exertion.loadStatus.label : "no data")

        Write a short, encouraging check-in about today only. Describe the numbers qualitatively, never as raw scores.
        """

        // Run in an unstructured Task so switching tabs (which cancels the view's
        // .task) doesn't cancel an in-flight generation and force a restart.
        let generation = Task {
            service.isGeneratingOverview = true
            defer { service.isGeneratingOverview = false }

            let overviewInstructionsHead = "You're a coach who knows this athlete well, checking in like a text from a friend — direct, warm, natural. No jargon, no motivational-poster language, no formal report tone. Second person. Everything you write is about right now, today only. Never mention tomorrow, next session, or anything upcoming. Match your tone and focus to the time of day you're given. "
            let stepByStepLine = AIModel.supportsReasoning ? "" : "Think step-by-step about what the data means before writing your answer. "
            let overviewInstructionsTail = "Headline: a short status phrase, 2-4 words. Never a command, never a raw stat. Body: say less. 1-2 sentences, 3 at most. Reference the data naturally as insight, not a report — never cite a raw strain, exertion, or recovery score number, describe it qualitatively instead (e.g. high/moderate/low). The body must obey the time-of-day focus you are given. Never fabricate any number, workout, or event that is not in the provided data. Use your broad knowledge of sports science and circadian rhythm to add context, briefly. When the readings show strain, training load is the default explanation — but only when the training data actually supports it. If the athlete has trained little and the overnight readings are still away from baseline, say the body appears to be recovering from something outside of training rather than forcing a training explanation. Keep every suggestion within training, sleep, hydration, and rest, and describe what the readings show rather than why."

            let buildProfile = {
                LanguageModelSession.Profile {
                    Instructions(overviewInstructionsHead + stepByStepLine + overviewInstructionsTail)
                    if !FeatureFlags.nutritionEnabled {
                        Instructions("Nutrition tracking is not active in this app. Never mention food, meals, calories, macros, or nutrition tracking. If the data is sparse, never suggest nutrition as a factor.")
                    }
                    Instructions("Tone: \(AdvisorPersona.current.instruction)")
                }
                .reasoningLevel(AIModel.supportsReasoning ? .moderate : nil)
            }

            let startTime = Date()

            do {
                let profile = buildProfile()
                let session = LanguageModelSession(profile: profile)
                let result = try await session.respond(to: prompt, generating: GeneratedOverview.self)
                service.generatedOverview = result.content
                service.markOverviewAttempted(context: timeOfDayContext)
                service.persistDashboardSnapshot()
                let elapsed = Date().timeIntervalSince(startTime)
                Self.overviewLog.info("Overview generated in \(String(format: "%.1f", elapsed))s")
                #if DEBUG
                print("[DashboardOverview] generated in \(String(format: "%.1f", elapsed))s")
                #endif
            } catch {
                Self.overviewLog.error("Overview generation failed (first attempt): \(String(describing: error), privacy: .public) — \(error.localizedDescription, privacy: .public)")
                #if DEBUG
                print("[DashboardOverview] generation failed (first attempt): \(String(describing: error)) — \(error.localizedDescription)")
                #endif

                // Retry once with a fresh session
                do {
                    let profile = buildProfile()
                    let session = LanguageModelSession(profile: profile)
                    let result = try await session.respond(to: fallbackPrompt, generating: GeneratedOverview.self)
                    service.generatedOverview = result.content
                    service.markOverviewAttempted(context: timeOfDayContext)
                    service.persistDashboardSnapshot()
                    let elapsed = Date().timeIntervalSince(startTime)
                    Self.overviewLog.info("Overview generated (retry) in \(String(format: "%.1f", elapsed))s")
                    #if DEBUG
                    print("[DashboardOverview] generated (retry) in \(String(format: "%.1f", elapsed))s")
                    #endif
                } catch {
                    Self.overviewLog.error("Overview generation failed (retry attempt): \(String(describing: error), privacy: .public) — \(error.localizedDescription, privacy: .public)")
                    #if DEBUG
                    print("[DashboardOverview] generation failed (retry attempt): \(String(describing: error)) — \(error.localizedDescription)")
                    #endif
                    service.markOverviewAttempted(context: timeOfDayContext)
                    // Fall through to static fallback
                }
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
                    "Exertion score \(exertion.score) (\(exertion.exertionLevel.label))",
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

    @ViewBuilder
    private var bodyPatternsSection: some View {
        let reviewable = bodySignals.reviewableEpisodes
        if !reviewable.isEmpty {
            BodyPatternsCard(pendingCount: reviewable.count) {
                checkInQueue = reviewable
                showingBodyCheckIn = true
            }
        }
    }

    private var todaySection: some View {
        VStack(alignment: .leading, spacing: 16) {
            HStack(alignment: .center, spacing: 12) {
                Text("Today's Vitals")
                    .font(.title3.bold())
                Spacer()
                Button(action: { showingVitalsCustomize = true }) {
                    Image(systemName: "slider.horizontal.3")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(Color.primary)
                }
                .buttonStyle(.plain)
                .frame(width: 30, height: 30)
                .glassEffect(.regular, in: .circle)
            }

            if vitalsLayout.visibleMetrics.isEmpty {
                VStack(spacing: 8) {
                    Text("No vitals selected — tap the slider icon to add some.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 24)
                .glassEffect(in: .rect(cornerRadius: 14))
            } else {
                VStack(spacing: 16) {
                    ForEach(Array(vitalCardRows.enumerated()), id: \.offset) { _, row in
                        if row.count == 1, let metric = row.first {
                            let resolvedSize = vitalsLayout.sizes[metric] ?? metric.defaultSize
                            if resolvedSize == .wide {
                                vitalCard(for: metric, size: .wide)
                                    .askVector(advisorTopic(for: metric))
                            } else {
                                HStack(spacing: 16) {
                                    vitalCard(for: metric, size: .small)
                                        .askVector(advisorTopic(for: metric))
                                        .frame(width: loneSmallCardWidth, alignment: .leading)
                                    Spacer(minLength: 0)
                                }
                                .frame(maxWidth: .infinity)
                            }
                        } else {
                            HStack(spacing: 16) {
                                ForEach(row, id: \.self) { metric in
                                    vitalCard(for: metric, size: .small)
                                        .askVector(advisorTopic(for: metric))
                                        .frame(maxWidth: .infinity, maxHeight: .infinity)
                                }
                            }
                            .frame(maxWidth: .infinity)
                        }
                    }
                }
                .onGeometryChange(for: CGFloat.self) { proxy in
                    proxy.size.width
                } action: { newValue in
                    vitalsContentWidth = newValue
                }
            }
        }
    }

    private var vitalCardRows: [[VitalMetric]] {
        var rows: [[VitalMetric]] = []
        var currentRow: [VitalMetric] = []

        for metric in vitalsLayout.visibleMetrics {
            let size = vitalsLayout.sizes[metric] ?? metric.defaultSize

            if size == .wide {
                if !currentRow.isEmpty {
                    rows.append(currentRow)
                    currentRow = []
                }
                rows.append([metric])
            } else {
                if currentRow.count == 2 {
                    rows.append(currentRow)
                    currentRow = []
                }
                currentRow.append(metric)
            }
        }

        if !currentRow.isEmpty {
            rows.append(currentRow)
        }

        return rows
    }

    /// Exactly half of the vitals row, so a lone small card matches a paired one.
    private var loneSmallCardWidth: CGFloat? {
        guard vitalsContentWidth > 0 else { return nil }
        return (vitalsContentWidth - 16) / 2
    }

    private func vitalCard(for metric: VitalMetric, size: VitalCardSize) -> some View {
        VitalCard(
            snapshot: VitalSnapshotBuilder.snapshot(
                for: metric,
                service: service,
                series: vitalsSeries.series[metric] ?? [],
                paceSeries: vitalsSeries.paceSeries[metric] ?? []
            ),
            size: size
        )
    }

    private func advisorTopic(for metric: VitalMetric) -> AdvisorTopic {
        switch metric {
        case .heartRate:
            return AdvisorTopic(
                title: "Heart Rate",
                icon: "heart.fill",
                tintName: "red",
                contextLines: [
                    String(format: "Current: %.0f bpm", service.latestHeartRate ?? 0),
                    "A key indicator of cardiovascular stress and recovery status"
                ],
                suggestedPrompt: "Explain what my heart rate means for my recovery and training readiness."
            )

        case .hrv:
            return AdvisorTopic(
                title: "Heart Rate Variability",
                icon: "waveform.path.ecg",
                tintName: "cyan",
                contextLines: [
                    String(format: "Current HRV: %.0f ms", service.latestHRV ?? 0),
                    "Higher HRV indicates parasympathetic activation and better recovery"
                ],
                suggestedPrompt: "What does my HRV tell me about my recovery and stress levels?"
            )

        case .restingHR:
            return AdvisorTopic(
                title: "Resting Heart Rate",
                icon: "heart.text.square",
                tintName: "pink",
                contextLines: [
                    String(format: "Current RHR: %.0f bpm", service.latestRestingHR ?? 0),
                    "Resting HR reflects baseline cardiovascular fitness"
                ],
                suggestedPrompt: "How does my resting heart rate affect my overall fitness?"
            )

        case .sleep:
            return AdvisorTopic(
                title: "Sleep Duration",
                icon: "bed.double.fill",
                tintName: "blue",
                contextLines: [
                    "Sleep duration: \(service.sleepAnalysis?.formattedDuration ?? "No data")",
                    "Quality sleep is essential for recovery and adaptation"
                ],
                suggestedPrompt: "Is my sleep duration and quality adequate for my training?"
            )

        case .activeEnergy:
            return AdvisorTopic(
                title: "Active Energy",
                icon: "flame.fill",
                tintName: "orange",
                contextLines: [
                    String(format: "Active calories: %.0f kcal", service.todayActiveCalories),
                    "Energy burned through movement and exercise"
                ],
                suggestedPrompt: "How does my active energy expenditure compare to my goals?"
            )

        case .restingEnergy:
            return AdvisorTopic(
                title: "Resting Energy",
                icon: "flame",
                tintName: "red",
                contextLines: [
                    String(format: "Resting calories: %.0f kcal", service.todayBasalCalories),
                    "Baseline energy required for basic body functions"
                ],
                suggestedPrompt: "What is my basal metabolic rate and how does it affect my nutrition?"
            )

        case .steps:
            return AdvisorTopic(
                title: "Steps",
                icon: "figure.walk",
                tintName: "green",
                contextLines: [
                    String(format: "Today's steps: %.0f", service.todaySteps),
                    "Daily movement is crucial for overall health"
                ],
                suggestedPrompt: "Am I hitting my daily activity targets?"
            )

        case .vo2Max:
            return AdvisorTopic(
                title: "VO2 Max",
                icon: "lungs.fill",
                tintName: "mint",
                contextLines: [
                    String(format: "Current VO2 Max: %.1f ml/kg·min", service.latestVO2Max ?? 0),
                    "VO2 Max measures your aerobic capacity and cardiovascular fitness"
                ],
                suggestedPrompt: "How does my VO2 Max compare to my fitness level and what does it mean for my training?"
            )

        case .wristTemp:
            return AdvisorTopic(
                title: "Temperature Deviation",
                icon: "thermometer",
                tintName: "orange",
                contextLines: [
                    String(format: "Deviation: %+.1f°C", service.latestWristTempDeviation ?? 0),
                    "Wrist temperature deviation from your baseline can indicate stress or illness"
                ],
                suggestedPrompt: "What does my wrist temperature tell me about my current health and recovery state?"
            )

        case .spo2:
            return AdvisorTopic(
                title: "Blood Oxygen",
                icon: "drop.fill",
                tintName: "teal",
                contextLines: [
                    String(format: "Current SpO2: %.0f%%", service.latestSpO2 ?? 0),
                    "Blood oxygen saturation reflects your cardiovascular and respiratory health"
                ],
                suggestedPrompt: "What does my blood oxygen level tell me about my respiratory and cardiovascular health?"
            )

        case .respiratoryRate:
            let rr = service.sleepAnalysis?.respiratoryRate ?? 0
            return AdvisorTopic(
                title: "Respiratory Rate",
                icon: "lungs",
                tintName: "indigo",
                contextLines: [
                    String(format: "Current RR: %.1f breaths/min", rr),
                    "Respiratory rate is an indicator of stress levels and cardiovascular fitness"
                ],
                suggestedPrompt: "What does my respiratory rate tell me about my stress and physical condition?"
            )

        case .physicalEffort:
            return AdvisorTopic(
                title: "Physical Effort",
                icon: "bolt.fill",
                tintName: "purple",
                contextLines: [
                    String(format: "Today's effort: %.1f METs", service.todayPhysicalEffort ?? 0),
                    "Physical effort measures the intensity and volume of your daily activity"
                ],
                suggestedPrompt: "How does my physical effort today compare to my typical training intensity?"
            )

        case .hrr:
            return AdvisorTopic(
                title: "HR Recovery",
                icon: "arrow.down.heart",
                tintName: "yellow",
                contextLines: [
                    String(format: "Current HRR: %.0f bpm", service.latestHRR ?? 0),
                    "Heart rate recovery measures how quickly your heart rate drops after effort"
                ],
                suggestedPrompt: "What does my heart rate recovery tell me about my cardiovascular fitness?"
            )
        }
    }


    private func sourceChip(icon: String, label: String, color: Color) -> some View {
        HStack(spacing: 4) {
            Image(systemName: icon)
                .font(.system(size: 9, weight: .semibold))
                .foregroundStyle(color)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .fixedSize(horizontal: true, vertical: false)
        }
        .padding(.horizontal, 8)
        .padding(.vertical, 4)
        .glassEffect(.regular.tint(color.opacity(0.12)), in: .capsule)
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

// MARK: - Header Scroll State

@Observable
private final class HeaderScrollState {
    var offset: CGFloat = 0
}

// MARK: - Compact Header Bar

private struct CompactHeaderBar: View {
    let scroll: HeaderScrollState
    let date: Date
    let isSyncing: Bool
    var onTapDate: () -> Void

    /// Fades in as the expanded header scrolls away.
    private var visibility: Double {
        Double(min(max((scroll.offset - 34) / 40, 0), 1))
    }

    var body: some View {
        HStack(spacing: 12) {
            Button(action: onTapDate) {
                HStack(spacing: 5) {
                    Text(date.formatted(.dateTime.month(.abbreviated).day()))
                        .font(.title2.weight(.bold))
                    Image(systemName: "chevron.down")
                        .font(.system(size: 13, weight: .bold))
                        .foregroundStyle(.secondary)
                }
                .foregroundStyle(.primary)
                .contentShape(.rect)
            }
            .buttonStyle(.plain)
            .accessibilityLabel("View historical data")

            Spacer()

            if isSyncing {
                ProgressView()
                    .scaleEffect(0.8)
                    .frame(width: 34, height: 34)
            }
            ModeToolbarMenu(style: .headerChip)
        }
        .padding(.horizontal, 20)
        .padding(.top, 6)
        .padding(.bottom, 18)
        .background {
            Rectangle()
                .fill(.ultraThinMaterial)
                .mask {
                    LinearGradient(
                        stops: [
                            .init(color: .black, location: 0.0),
                            .init(color: .black, location: 0.55),
                            .init(color: .black.opacity(0.35), location: 0.82),
                            .init(color: .clear, location: 1.0)
                        ],
                        startPoint: .top,
                        endPoint: .bottom
                    )
                }
                .ignoresSafeArea(edges: .top)
        }
        .opacity(visibility)
        .allowsHitTesting(visibility > 0.5)
    }
}

// MARK: - Shimmer modifier

private struct ShimmerModifier: ViewModifier {
    @Environment(\.accessibilityReduceMotion) var reduceMotion
    @Environment(\.colorScheme) var colorScheme

    func body(content: Content) -> some View {
        if reduceMotion {
            return AnyView(content)
        } else {
            return AnyView(
                content
                    .overlay {
                        TimelineView(.animation) { timeline in
                            GeometryReader { geo in
                                let width = geo.size.width
                                let band = max(width * 0.35, 1)
                                let t = timeline.date.timeIntervalSinceReferenceDate
                                let phase = CGFloat((t.truncatingRemainder(dividingBy: 1.3)) / 1.3)

                                let shimmerColor: [Color] = colorScheme == .dark
                                    ? [.clear, .white.opacity(0.85), .clear]
                                    : [.clear, .black.opacity(0.35), .clear]

                                LinearGradient(
                                    colors: shimmerColor,
                                    startPoint: .leading,
                                    endPoint: .trailing
                                )
                                .frame(width: band)
                                .offset(x: -band + phase * (width + band))
                                .blendMode(colorScheme == .dark ? .plusLighter : .normal)
                            }
                        }
                        .mask(content)
                        .allowsHitTesting(false)
                    }
            )
        }
    }
}

private extension View {
    func shimmering() -> some View {
        modifier(ShimmerModifier())
    }
}

#if DEBUG
#Preview {
    HomeView()
        .environment(HealthKitService.preview)
}
#endif
