import SwiftUI
import AVKit

struct ActiveWorkoutView: View {
    let session: ActiveWorkoutSession
    let onFinish: () -> Void

    @Environment(HealthKitService.self) var healthService
    @Environment(WatchSyncService.self) var watchSync

    @State var elapsedSeconds: Int = 0
    @State var showingFinishConfirm = false
    @State var currentPage: Int? = 0
    @State var planScrollOffset: CGFloat = 0
    @State var didTriggerPageBack = false
    @State var pulse = false
    @State var isPaused = false
    @State var showingExercisePicker = false
    @AppStorage("devModeEnabled") var devModeEnabled = false

    var phaseColor: Color {
        if session.isFinished || session.allExercisesComplete { return .green }
        return session.isResting ? .blue : .red
    }

    var pagingScrollView: some View {
        GeometryReader { geo in
            ScrollView(.vertical) {
                VStack(spacing: 0) {
                    // Page 0: Workout content (scrolls internally when it overflows)
                    ScrollView(.vertical) {
                        page0Content
                            .frame(width: geo.size.width)
                            .frame(minHeight: geo.size.height)
                    }
                    .scrollBounceBehavior(.basedOnSize)
                    .frame(width: geo.size.width, height: geo.size.height)
                    .id(0)

                    // Page 1: Exercise plan
                    page1Content
                        .frame(width: geo.size.width, height: geo.size.height)
                        .id(1)
                }
                .scrollTargetLayout()
            }
            .scrollTargetBehavior(.viewAligned(limitBehavior: .always))
            .scrollPosition(id: $currentPage)
            .scrollDisabled(currentPage == 1)
            .scrollEdgeEffectStyle(.soft, for: .all)
            .frame(width: geo.size.width, height: geo.size.height)
            .clipped()
        }
    }

    var body: some View {
        ZStack {
            // Opaque base so no system-white shows through the lower half
            Color(.systemBackground)
                .ignoresSafeArea()

            // Background with phase-aware gradient
            LinearGradient(
                colors: [
                    phaseColor.opacity(0.12),
                    phaseColor.opacity(0.04),
                    Color.clear
                ],
                startPoint: .top,
                endPoint: .center
            )
            .ignoresSafeArea()
            .animation(.easeInOut, value: session.isResting)
            .animation(.easeInOut, value: session.isFinished)
            .animation(.easeInOut, value: session.allExercisesComplete)

            VStack(spacing: 0) {
                if session.isFinished || session.allExercisesComplete {
                    completionView
                } else {
                    topBar
                        .padding(.horizontal, 20)
                        .padding(.top, 16)
                    pagingScrollView
                }
            }
        }
        .ignoresSafeArea(edges: .bottom)
        .overlay { pausedOverlay }
        .task { await runTimer() }
        .onAppear {
            let alreadyActive = WatchSyncService.shared.hasActiveWorkout
            WatchSyncService.shared.hasActiveWorkout = true
            pulse = true
            syncToWatch()
            if !alreadyActive {
                WorkoutLiveActivityController.shared.start(title: session.workout.title, state: liveActivityState())
                if watchSync.isWatchAppInstalled {
                    healthService.launchWatchWorkout()
                }
            }
        }
        .onChange(of: session.currentExerciseIndex) { syncToWatch() }
        .onChange(of: session.currentSetIndex) { syncToWatch() }
        .onChange(of: session.isResting) { syncToWatch() }
        .onChange(of: session.completedSetIndices) { syncToWatch() }
        .onChange(of: isPaused) { syncToWatch() }
        .onChange(of: session.isFinished) {
            if session.isFinished {
                handleWorkoutFinished()
            }
        }
        .onChange(of: session.allExercisesComplete) {
            if session.allExercisesComplete {
                handleWorkoutFinished()
            }
        }
        .onDisappear {
            pulse = false
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchCommandCompleteSet)) { note in
            let weight = note.userInfo?["weight"] as? Double
            let reps = note.userInfo?["reps"] as? Int
            session.logCurrentSet(weight: weight, reps: reps)
            withAnimation(.spring(duration: 0.4)) { completeSet() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchCommandStartTimer)) { _ in
            withAnimation(.spring(duration: 0.3)) { startExerciseTimer() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchCommandSkipRest)) { _ in
            withAnimation(.spring(duration: 0.2)) { skipRest() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchCommandPause)) { _ in
            withAnimation(.spring(duration: 0.3)) { isPaused.toggle() }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchCommandEndWorkout)) { _ in
            showingFinishConfirm = true
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchCommandSelectExercise)) { note in
            if let idx = note.userInfo?["index"] as? Int {
                withAnimation(.spring(duration: 0.3)) { session.select(index: idx) }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .watchRequestedSync)) { _ in
            syncToWatch()
        }
        .confirmationDialog("End Workout?", isPresented: $showingFinishConfirm) {
            Button("End Workout", role: .destructive) { onFinish() }
            Button("Cancel", role: .cancel) {}
        }
    }

    // MARK: - Top Bar

    var topBar: some View {
        HStack(spacing: 16) {
            VStack(alignment: .leading, spacing: 3) {
                Text("Elapsed")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text(elapsedFormatted)
                    .font(.system(size: 22, weight: .bold, design: .default).monospacedDigit())
                    .foregroundStyle(.primary)
            }

            Spacer()

            watchStatusIndicator

            Menu {
                Button {
                    withAnimation(.spring(duration: 0.3)) { isPaused.toggle() }
                } label: {
                    Label(isPaused ? "Resume" : "Pause", systemImage: isPaused ? "play.fill" : "pause.fill")
                }
                Divider()
                Button {
                    finishWorkout()
                } label: {
                    Label("Finish Workout", systemImage: "checkmark")
                }
                Button(role: .destructive) {
                    onFinish()
                } label: {
                    Label("Discard Workout", systemImage: "trash")
                }
            } label: {
                Image(systemName: "gearshape.fill")
                    .font(.title3)
                    .foregroundStyle(.primary)
                    .padding(.horizontal, 12)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
            }
            .buttonStyle(.plain)
        }
        .padding(.top, 20)
    }

    // MARK: - Watch Connection Status

    /// Tappable Apple Watch status chip: the glass capsule is tinted by connection
    /// state, and tapping opens a menu showing the watch name + connection status.
    var watchStatusIndicator: some View {
        Menu {
            Section("Apple Watch") {
                Label(watchSync.watchName ?? "Apple Watch", systemImage: "applewatch")
                Label(connectionStatusText, systemImage: connectionStatusIcon)
            }
        } label: {
            Image(systemName: "applewatch")
                .font(.title3)
                .foregroundStyle(.primary)
                .padding(.horizontal, 12)
                .padding(.vertical, 8)
                .glassEffect(.regular.tint(watchStatusColor.opacity(0.6)), in: .capsule)
                .animation(.easeInOut, value: watchSync.watchReachable)
        }
        .buttonStyle(.plain)
    }

    var watchStatusColor: Color {
        if !watchSync.isWatchAppInstalled { return .gray }
        return watchSync.watchReachable ? .green : .orange
    }

    var connectionStatusText: String {
        if !watchSync.isWatchAppInstalled { return "Not Connected" }
        return watchSync.watchReachable ? "Connected" : "Not Reachable"
    }

    var connectionStatusIcon: String {
        if !watchSync.isWatchAppInstalled { return "applewatch.slash" }
        return watchSync.watchReachable ? "checkmark.circle.fill" : "exclamationmark.circle.fill"
    }
}
