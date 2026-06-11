import SwiftUI
import FoundationModels

struct TrainView: View {
    @Environment(HealthKitService.self) var service
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.sleepTargetHours) private var sleepTargetHours = UserProfile.defaultSleepTargetHours

    @State private var showingCreation = false
    @State private var activeSession: ActiveWorkoutSession?
    @State private var selectedWorkout: SavedWorkout?

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
                    readinessCard
                    savedWorkoutsSection
                    quickActionsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle("Train")
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreation = true } label: {
                        Image(systemName: "plus.circle.fill")
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.secondary)
                }
            }
            .sheet(isPresented: $showingCreation) {
                WorkoutCreationView { savedWorkout in
                    WorkoutStorageService.shared.save(savedWorkout)
                    showingCreation = false
                }
            }
            .sheet(item: $selectedWorkout) { workout in
                WorkoutDetailView(workout: workout) { session in
                    activeSession = session
                    selectedWorkout = nil
                }
            }
            .fullScreenCover(item: $activeSession) { session in
                ActiveWorkoutView(session: session) {
                    activeSession = nil
                }
            }
            .task { await service.refreshToday() }
        }
    }

    // MARK: - Readiness Card
    private var readinessCard: some View {
        GlassCard(tint: .purple.opacity(0.2), cornerRadius: 24) {
            HStack(spacing: 16) {
                MetricRing(
                    progress: Double(service.exertionScore?.score ?? 0) / 100,
                    gradient: LinearGradient(colors: [.purple, .pink], startPoint: .topLeading, endPoint: .bottomTrailing),
                    size: 88
                ) {
                    VStack(spacing: 2) {
                        Text("\(service.exertionScore?.score ?? 0)")
                            .font(.title2.bold())
                            .monospacedDigit()
                        Text("Load")
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                VStack(alignment: .leading, spacing: 8) {
                    Text("Training Focus")
                        .font(.headline)
                    Text(profile.summaryLine)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(focusText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                Spacer()
            }
        }
    }

    private var focusText: String {
        if WorkoutStorageService.shared.savedWorkouts.isEmpty {
            return "Create your first workout to get started."
        } else if service.exertionScore?.todayStrain == 0 {
            return "No strain today — a good moment to train."
        } else {
            return "Today is loaded. Align the next session with recovery."
        }
    }

    // MARK: - Saved Workouts
    private var savedWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            HStack {
                Text("My Workouts")
                    .font(.title3.bold())
                Spacer()
                Text("\(WorkoutStorageService.shared.savedWorkouts.count) saved")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            if WorkoutStorageService.shared.savedWorkouts.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 40))
                        .foregroundStyle(.tertiary)
                    Text("No workouts yet")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Tap + to create your first workout")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button { showingCreation = true } label: {
                        Label("Create Workout", systemImage: "plus")
                    }
                    .buttonStyle(.glassProminent)
                    .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 32)
                .glassEffect(in: .rect(cornerRadius: 24))
            } else {
                ScrollView(.horizontal, showsIndicators: false) {
                    HStack(spacing: 14) {
                        Button { showingCreation = true } label: {
                            VStack(spacing: 12) {
                                Image(systemName: "plus.circle.fill")
                                    .font(.system(size: 32))
                                    .foregroundStyle(.cyan)
                                Text("New")
                                    .font(.headline)
                                Text("Workout")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                            .frame(width: 120, height: 160)
                            .glassEffect(.regular.tint(.cyan.opacity(0.18)), in: .rect(cornerRadius: 20))
                        }
                        .buttonStyle(.plain)

                        ForEach(WorkoutStorageService.shared.savedWorkouts) { workout in
                            SavedWorkoutCard(workout: workout) {
                                selectedWorkout = workout
                            }
                        }
                    }
                    .padding(.horizontal, 2)
                    .padding(.vertical, 4)
                }
            }
        }
    }

    // MARK: - Quick Actions
    private var quickActionsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Start Training")
                .font(.title3.bold())

            HStack(spacing: 14) {
                QuickActionTile(
                    icon: "sparkles",
                    label: "AI Generate",
                    description: "Describe your workout",
                    tint: .purple
                ) { showingCreation = true }

                QuickActionTile(
                    icon: "list.bullet.clipboard",
                    label: "Build Manually",
                    description: "Pick exercises yourself",
                    tint: .orange
                ) { showingCreation = true }
            }
        }
    }
}

// MARK: - SavedWorkoutCard
private struct SavedWorkoutCard: View {
    let workout: SavedWorkout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 10) {
                HStack {
                    Label(workout.source == .ai ? "AI" : "Manual",
                          systemImage: workout.source == .ai ? "sparkles" : "list.bullet.clipboard.fill")
                        .font(.caption.weight(.semibold))
                        .padding(.horizontal, 8)
                        .padding(.vertical, 4)
                        .glassEffect(.regular.tint(workout.source == .ai ? .purple.opacity(0.3) : .orange.opacity(0.3)), in: .capsule)
                    Spacer()
                }

                Text(workout.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)

                Text(workout.focus)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()

                HStack(spacing: 10) {
                    Label("\(workout.exercises.count)", systemImage: "dumbbell")
                        .font(.caption2)
                    Label("\(workout.durationMinutes)m", systemImage: "clock")
                        .font(.caption2)
                }
                .foregroundStyle(.secondary)

                HStack(spacing: 3) {
                    ForEach(0..<min(workout.effort, 10), id: \.self) { _ in
                        Circle()
                            .fill(.orange)
                            .frame(width: 4, height: 4)
                    }
                    ForEach(0..<max(10 - workout.effort, 0), id: \.self) { _ in
                        Circle()
                            .fill(.white.opacity(0.15))
                            .frame(width: 4, height: 4)
                    }
                }
            }
            .frame(width: 160, height: 180)
            .padding(14)
            .glassEffect(in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - QuickActionTile
private struct QuickActionTile: View {
    let icon: String
    let label: String
    let description: String
    let tint: Color
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            VStack(alignment: .leading, spacing: 8) {
                Image(systemName: icon)
                    .font(.title3)
                    .foregroundStyle(tint)

                Text(label)
                    .font(.headline)

                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .lineLimit(1)

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
            .frame(height: 110)
            .glassEffect(.regular.tint(tint.opacity(0.15)), in: .rect(cornerRadius: 20))
        }
        .buttonStyle(.plain)
    }
}

#Preview {
    TrainView()
        .environment(HealthKitService())
}
