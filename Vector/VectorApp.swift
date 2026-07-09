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
    @State private var activeSession: ActiveWorkoutSession?
    @State private var showingWorkout = false
    @State private var selectedTab = 0
    @State private var advisorPresenter = AdvisorPresenter()
    @State private var advisorDetent: PresentationDetent = .medium
    @State private var appModeStore = AppModeStore.shared

    var body: some Scene {
        WindowGroup {
            Group {
                if !hasCompletedOnboarding {
                    OnboardingView(hasCompletedOnboarding: $hasCompletedOnboarding)
                } else {
                    TabView(selection: $selectedTab) {
                        Tab("Home", systemImage: "house.fill", value: 0) {
                            HomeView()
                                .tint(nil)
                        }

                        Tab("Train", systemImage: "dumbbell.fill", value: 1) {
                            TrainView(activeSession: $activeSession, showingWorkout: $showingWorkout)
                                .tint(nil)
                        }

                        if FeatureFlags.nutritionEnabled {
                            Tab("Nutrition", systemImage: "fork.knife", value: 2) {
                                NutritionView()
                                    .tint(nil)
                            }
                        }

                        Tab("Profile", systemImage: "person.crop.circle", value: 3) {
                            SettingsView()
                                .tint(nil)
                        }
                    }
                    .tint(.purple)
                    .miniWorkoutBar(session: activeSession) {
                        showingWorkout = true
                    } onEnd: {
                        endActiveWorkoutTeardown()
                        activeSession = nil
                    }
                    .sheet(isPresented: $showingWorkout) {
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
                    .sheet(isPresented: Binding(get: { advisorPresenter.isPresented }, set: { advisorPresenter.isPresented = $0 })) {
                        AdvisorView(isMinimized: advisorDetent == .medium)
                            .presentationDetents([.medium, .large], selection: $advisorDetent)
                            .presentationDragIndicator(.visible)
                            .environment(healthKitService)
                            .environment(advisorPresenter)
                    }
                }
            }
            .environment(healthKitService)
            .environment(watchSync)
            .environment(FoodLogService.shared)
            .environment(advisorPresenter)
            .environment(appModeStore)
            .task {
                #if DEBUG && targetEnvironment(simulator)
                if activeSession == nil {
                    hasCompletedOnboarding = true
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
            .onChange(of: healthKitService.recoveryScore) { syncToWatch() }
            .onChange(of: healthKitService.exertionScore) { syncToWatch() }
            .onChange(of: healthKitService.sleepAnalysis) { syncToWatch() }
            .onChange(of: healthKitService.stressScore) { syncToWatch() }
        }
    }

    private func syncToWatch() {
        WatchSyncService.shared.syncScores(
            recovery: healthKitService.recoveryScore,
            exertion: healthKitService.exertionScore,
            sleep: healthKitService.sleepAnalysis,
            stress: healthKitService.stressScore
        )
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
