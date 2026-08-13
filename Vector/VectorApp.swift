import SwiftUI
import HealthKit
import AppIntents
import Combine
import TipKit

@main
struct VectorApp: App {
    @State private var healthKitService = HealthKitService()
    @State private var profileSync = ProfileCloudSync()
    @State private var watchSync = WatchSyncService.shared
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("hasCompletedEquipmentSetup") private var hasCompletedEquipmentSetup = false
    @State private var activeSession: ActiveWorkoutSession?
    @State private var showingWorkout = false
    @State private var selectedTab = 0
    @State private var advisorPresenter = AdvisorPresenter()
    @State private var appModeStore = AppModeStore.shared
    @State private var isAdvisorSupported = VectorAdvisor.isSupported
    @Environment(\.scenePhase) private var scenePhase

    var body: some Scene {
        WindowGroup {
            rootContent
                .sheetBackdropScaling()
                .environment(healthKitService)
                .environment(watchSync)
                .environment(FoodLogService.shared)
                .environment(advisorPresenter)
                .environment(appModeStore)
                .task {
                    #if DEBUG && targetEnvironment(simulator)
                    if activeSession == nil {
                        hasCompletedOnboarding = true
                        hasCompletedEquipmentSetup = true
                        healthKitService.applyMockData()
                        activeSession = VectorApp.makeMockSession()
                    }
                    #endif
                    healthKitService.refreshAuthorizationStatus()
                    VectorAdvisor.shared.prewarm(healthService: healthKitService)
                    try? Tips.configure([.displayFrequency(.immediate), .datastoreLocation(.applicationDefault)])
                    profileSync.pullFromCloud()
                    profileSync.pushAllLocalToCloud()
                    VectorShortcuts.updateAppShortcutParameters()
                }
                .onReceive(NotificationCenter.default.publisher(for: .watchRequestedSync)) { _ in
                    syncToWatch()
                }
                .onChange(of: advisorPresenter.isPresented) {
                    if advisorPresenter.isPresented {
                        if isAdvisorSupported {
                            selectedTab = 4
                        }
                        advisorPresenter.isPresented = false
                    }
                }
                .onChange(of: advisorPresenter.wantsProfileTab) {
                    if advisorPresenter.wantsProfileTab {
                        selectedTab = 3
                        advisorPresenter.wantsProfileTab = false
                    }
                }
                .onChange(of: healthKitService.recoveryScore) { syncToWatch() }
                .onChange(of: healthKitService.exertionScore) { syncToWatch() }
                .onChange(of: healthKitService.sleepAnalysis) { syncToWatch() }
                .onChange(of: healthKitService.stressScore) { syncToWatch() }
                .onChange(of: scenePhase) { _, newPhase in
                    guard newPhase == .active else { return }
                    Task { await healthKitService.refreshIfStale() }
                }
        }
    }

    @ViewBuilder
    private var rootContent: some View {
        if !hasCompletedOnboarding {
            OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding, hasCompletedEquipmentSetup: $hasCompletedEquipmentSetup)
        } else {
            mainTabView
        }
    }

    @ViewBuilder
    private var mainTabView: some View {
        TabView(selection: $selectedTab) {
            Tab("Home", systemImage: "house.fill", value: 0) {
                HomeView()
                    .tint(nil)
                    .tabCrossFade(gradientHeight: 460)
            }

            Tab("Train", systemImage: "dumbbell.fill", value: 1) {
                TrainView(activeSession: $activeSession, showingWorkout: $showingWorkout)
                    .tint(nil)
                    .tabCrossFade()
            }

            if FeatureFlags.nutritionEnabled {
                Tab("Nutrition", systemImage: "fork.knife", value: 2) {
                    NutritionView()
                        .tint(nil)
                        .tabCrossFade()
                }
            }

            Tab("Profile", systemImage: "person.crop.circle", value: 3) {
                SettingsView()
                    .tint(nil)
                    .tabCrossFade(base: Color(.systemGroupedBackground))
            }

            if isAdvisorSupported {
                Tab("Vector", image: "VectorMark", value: 4, role: .prominent) {
                    AdvisorView()
                        .tint(nil)
                        .tabCrossFade(gradientHeight: 0)
                }
            }
        }
        .tint(.purple)
        .miniWorkoutBar(session: activeSession) {
            showingWorkout = true
        } onEnd: {
            endActiveWorkoutTeardown()
            activeSession = nil
        }
        .vectorSheet(isPresented: $showingWorkout) {
            if let session = activeSession {
                ActiveWorkoutView(session: session) {
                    endActiveWorkoutTeardown()
                    activeSession = nil
                    showingWorkout = false
                }
                .presentationDetents([.large])
                .presentationDragIndicator(.hidden)
                .presentationCornerRadius(32)
            }
        }
        .vectorSheet(isPresented: showingEquipmentSetup) {
            EquipmentSetupSheet(hasCompletedEquipmentSetup: $hasCompletedEquipmentSetup)
        }
    }

    private var showingEquipmentSetup: Binding<Bool> {
        Binding(
            get: { hasCompletedOnboarding && !hasCompletedEquipmentSetup },
            set: { _ in }
        )
    }

    private func syncToWatch() {
        WatchSyncService.shared.syncScores(
            recovery: healthKitService.recoveryScore,
            exertion: healthKitService.exertionScore,
            sleep: healthKitService.sleepAnalysis,
            stress: healthKitService.stressScore
        )
        publishWidgetSnapshot()
    }

    private func publishWidgetSnapshot() {
        let exertionTargetLow: Int?
        let exertionTargetHigh: Int?
        if let targetRange = healthKitService.exertionScore?.optimalTargetRange {
            exertionTargetLow = Int(targetRange.lowerBound.rounded())
            exertionTargetHigh = Int(targetRange.upperBound.rounded())
        } else {
            exertionTargetLow = nil
            exertionTargetHigh = nil
        }

        let sleepQuality: Int?
        let sleepAsleepSeconds: Double?
        let sleepDeepSeconds: Double?
        let sleepRemSeconds: Double?
        let sleepCoreSeconds: Double?
        let sleepAwakeSeconds: Double?
        if let sleep = healthKitService.sleepAnalysis {
            sleepQuality = Int((sleep.quality * 100).rounded())
            sleepAsleepSeconds = sleep.asleepDuration
            sleepDeepSeconds = sleep.deepDuration
            sleepRemSeconds = sleep.remDuration
            sleepCoreSeconds = sleep.coreDuration
            sleepAwakeSeconds = sleep.awakeDuration
        } else {
            sleepQuality = nil
            sleepAsleepSeconds = nil
            sleepDeepSeconds = nil
            sleepRemSeconds = nil
            sleepCoreSeconds = nil
            sleepAwakeSeconds = nil
        }

        let recoveryHistorySeries = ScoreHistoryStore.series(for: .recovery)
        let recoveryHistory = recoveryHistorySeries.suffix(7).map { $0.score }

        let firstName: String? = {
            let rawName = UserDefaults.standard.string(forKey: UserProfileStorage.firstName)
            let trimmed = rawName?.trimmingCharacters(in: .whitespaces) ?? ""
            return trimmed.isEmpty ? nil : trimmed
        }()

        let snapshot = VectorWidgetSnapshot(
            updated: .now,
            recovery: healthKitService.recoveryScore?.score,
            exertion: healthKitService.exertionScore?.score,
            exertionTargetLow: exertionTargetLow,
            exertionTargetHigh: exertionTargetHigh,
            sleep: sleepQuality,
            sleepAsleepSeconds: sleepAsleepSeconds,
            stress: healthKitService.stressScore?.score,
            hrv: healthKitService.latestHRV,
            restingHR: healthKitService.latestRestingHR,
            steps: Int(healthKitService.todaySteps),
            recoveryHistory: Array(recoveryHistory),
            name: firstName,
            sleepDeepSeconds: sleepDeepSeconds,
            sleepRemSeconds: sleepRemSeconds,
            sleepCoreSeconds: sleepCoreSeconds,
            sleepAwakeSeconds: sleepAwakeSeconds
        )
        VectorWidgetStore.save(snapshot)
    }

    private func endActiveWorkoutTeardown() {
        WatchSyncService.shared.hasActiveWorkout = false
        // A finished workout records a completion (and the phone authors the HKWorkout);
        // a discard records nothing. Tell the watch which happened so it discards its live
        // session on a discard instead of leaving a phantom workout in Apple Health.
        if activeSession?.hasRecordedCompletion == true {
            WatchSyncService.shared.sendWorkoutEnded()
        } else {
            WatchSyncService.shared.sendWorkoutDiscarded()
        }
        WorkoutLiveActivityController.shared.end()
    }
}

private extension View {
    @ViewBuilder
    func miniWorkoutBar(session: ActiveWorkoutSession?, onResume: @escaping () -> Void, onEnd: @escaping () -> Void) -> some View {
        if let session {
            self.tabViewBottomAccessory {
                WorkoutMiniBar(session: session, onResume: onResume, onEnd: onEnd)
            }
        } else {
            self
        }
    }
}

struct WorkoutMiniBar: View {
    let session: ActiveWorkoutSession
    let onResume: () -> Void
    let onEnd: () -> Void

    @State private var now = Date()
    private let timer = Timer.publish(every: 1, on: .main, in: .common).autoconnect()

    private var elapsed: String {
        let secs = Int(now.timeIntervalSince(session.startedAt))
        let m = secs / 60
        let s = secs % 60
        return String(format: "%d:%02d", m, s)
    }

    var body: some View {
        Button(action: onResume) {
            HStack(spacing: 14) {
                Circle()
                    .fill(.orange)
                    .frame(width: 8, height: 8)

                VStack(alignment: .leading, spacing: 1) {
                    Text(session.workout.title)
                        .font(.subheadline.weight(.semibold))
                        .lineLimit(1)
                    Text(session.currentExercise?.name ?? "Workout active")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(1)
                }

                Spacer()

                Text(elapsed)
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(.orange)

                Button(action: onEnd) {
                    Image(systemName: "xmark.circle.fill")
                        .font(.title3)
                        .foregroundStyle(.secondary)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 16)
            .padding(.vertical, 10)
        }
        .buttonStyle(.plain)
        .onReceive(timer) { now = $0 }
    }
}

#if DEBUG
extension VectorApp {
    /// Builds a mock in-progress workout session for DEBUG simulator launches.
    static func makeMockSession() -> ActiveWorkoutSession {
        let supersetID = UUID()
        let curl = ManualExerciseEntry(
            supersetID: supersetID,
            name: "Dumbbell Curl",
            sets: 3, reps: 12, durationSeconds: 0,
            inputType: .reps, weightKg: 30, restSeconds: 75, notes: ""
        )
        let pushdown = ManualExerciseEntry(
            supersetID: supersetID,
            name: "Tricep Pushdown",
            sets: 3, reps: 12, durationSeconds: 0,
            inputType: .reps, weightKg: 50, restSeconds: 75, notes: ""
        )
        let bench = ManualExerciseEntry(
            name: "Barbell Bench Press",
            sets: 4, reps: 8, durationSeconds: 0,
            inputType: .reps, weightKg: 135, restSeconds: 90, notes: ""
        )
        let plank = ManualExerciseEntry(
            name: "Plank",
            sets: 3, reps: 0, durationSeconds: 45,
            inputType: .duration, weightKg: nil, restSeconds: 60, notes: ""
        )
        let pec = ManualExerciseEntry(
            name: "Pec Deck Fly",
            sets: 3, reps: 12, durationSeconds: 0,
            inputType: .reps, weightKg: 40, restSeconds: 60, notes: ""
        )
        let workout = SavedWorkout(
            title: "Upper Body Strength",
            focus: "Chest & Arms",
            source: .manual,
            aiPlan: nil,
            exercises: [curl, pushdown, bench, plank, pec],
            durationMinutes: 45,
            effort: 7
        )
        let session = ActiveWorkoutSession(workout: workout)
        // Mark the first set done so the workout looks mid-progress.
        session.toggleSetDone(for: curl.id, setIndex: 0)
        return session
    }
}
#endif

/// Fades tab content in when it becomes selected. `TabView` swaps its children
/// instantly, so this is what makes switching tabs a cross-fade instead of a cut.
/// The backdrop mirrors the tab's own `gradientHeader` so only foreground content
/// fades — without it the page background dissolves to white mid-transition.
private struct TabCrossFade: ViewModifier {
    var base: Color
    var gradientHeight: CGFloat
    @State private var opacity: Double = 0

    func body(content: Content) -> some View {
        ZStack {
            base
                .ignoresSafeArea()
                .allowsHitTesting(false)

            if gradientHeight > 0 {
                VStack(spacing: 0) {
                    VectorTheme.brandGradient
                        .frame(maxWidth: .infinity)
                        .frame(height: gradientHeight)
                    Spacer(minLength: 0)
                }
                .ignoresSafeArea()
                .allowsHitTesting(false)
            }

            content
                .opacity(opacity)
        }
        .onAppear {
            opacity = 0
            withAnimation(.easeOut(duration: 0.22)) { opacity = 1 }
        }
        .onDisappear { opacity = 0 }
    }
}

private extension View {
    /// - Parameters must match the tab root's own `gradientHeader(base:height:)`
    ///   call, otherwise the backdrop shows a seam while the content fades in.
    func tabCrossFade(base: Color = Color(.systemBackground), gradientHeight: CGFloat = 360) -> some View {
        modifier(TabCrossFade(base: base, gradientHeight: gradientHeight))
    }
}
