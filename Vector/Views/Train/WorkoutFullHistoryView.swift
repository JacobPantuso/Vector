import SwiftUI
import HealthKit

struct WorkoutFullHistoryView: View {
    let workouts: [HKWorkout]
    @Environment(HealthKitService.self) var service
    @Environment(\.dismiss) private var dismiss
    @State private var selectedWorkout: HKWorkout?
    @State private var searchText = ""
    @State private var selectedFilter: WorkoutFilter = .all

    enum WorkoutFilter: String, CaseIterable {
        case all = "All"
        case strength = "Strength"
        case cardio = "Cardio"
        case other = "Other"
    }

    private var filteredWorkouts: [HKWorkout] {
        var result = workouts
        if !searchText.isEmpty {
            result = result.filter { workout in
                workoutTypeName(workout).localizedCaseInsensitiveContains(searchText)
            }
        }
        switch selectedFilter {
        case .all:
            break
        case .strength:
            result = result.filter {
                $0.workoutActivityType == .traditionalStrengthTraining ||
                $0.workoutActivityType == .functionalStrengthTraining
            }
        case .cardio:
            let cardioTypes: Set<HKWorkoutActivityType> = [
                .running, .walking, .cycling, .swimming, .hiking,
                .rowing, .elliptical, .stairClimbing, .highIntensityIntervalTraining,
                .dance, .crossTraining
            ]
            result = result.filter { cardioTypes.contains($0.workoutActivityType) }
        case .other:
            let knownTypes: Set<HKWorkoutActivityType> = [
                .running, .walking, .cycling, .swimming, .hiking,
                .rowing, .elliptical, .stairClimbing, .highIntensityIntervalTraining,
                .dance, .crossTraining, .traditionalStrengthTraining, .functionalStrengthTraining
            ]
            result = result.filter { !knownTypes.contains($0.workoutActivityType) }
        }
        return result
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    filterPicker
                    if filteredWorkouts.isEmpty {
                        emptyState
                    } else {
                        workoutList
                    }
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .searchable(text: $searchText, prompt: "Search workouts")
            .navigationTitle("Workout History")
            .navigationBarTitleDisplayMode(.large)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .sheet(item: $selectedWorkout) { workout in
                NavigationStack {
                    WorkoutHistoryDetailView(workout: workout)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
        }
    }

    private var filterPicker: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(WorkoutFilter.allCases, id: \.self) { filter in
                    Button(filter.rawValue) {
                        selectedFilter = filter
                    }
                    .font(.subheadline.weight(.medium))
                    .padding(.horizontal, 16)
                    .padding(.vertical, 8)
                    .background(
                        selectedFilter == filter
                            ? Color.cyan.opacity(0.25)
                            : Color.white.opacity(0.08),
                        in: Capsule()
                    )
                    .foregroundStyle(selectedFilter == filter ? .cyan : .secondary)
                }
            }
            .padding(.horizontal, 2)
        }
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "magnifyingglass")
                .font(.system(size: 36))
                .foregroundStyle(.tertiary)
            Text("No workouts found")
                .font(.headline)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 60)
    }

    private var workoutList: some View {
        LazyVStack(spacing: 10) {
            ForEach(filteredWorkouts) { workout in
                Button {
                    selectedWorkout = workout
                } label: {
                    HistoryRow(workout: workout)
                }
                .buttonStyle(.plain)
            }
        }
    }

    private func workoutTypeName(_ workout: HKWorkout) -> String {
        switch workout.workoutActivityType {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        case .hiking: return "Hike"
        case .swimming: return "Swim"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        default: return "Workout"
        }
    }
}

// MARK: - HistoryRow

private struct HistoryRow: View {
    let workout: HKWorkout

    var body: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(workoutColor.opacity(0.18))
                    .frame(width: 48, height: 48)
                Image(systemName: workoutIcon)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(workoutColor)
            }

            VStack(alignment: .leading, spacing: 4) {
                Text(workoutTypeName)
                    .font(.headline)
                Text(workout.startDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day().hour().minute()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 4) {
                Text(formatDuration(workout.duration))
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                if workout.activeEnergyKcal > 0 {
                    Text("\(Int(workout.activeEnergyKcal)) kcal")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .glassEffect(.regular.tint(workoutColor.opacity(0.08)), in: .rect(cornerRadius: 18))
    }

    private var workoutIcon: String {
        switch workout.workoutActivityType {
        case .running: return "figure.run"
        case .walking: return "figure.walk"
        case .cycling: return "figure.outdoor.cycle"
        case .hiking: return "figure.hiking"
        case .swimming: return "figure.pool.swim"
        case .yoga: return "figure.yoga"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "dumbbell.fill"
        case .highIntensityIntervalTraining: return "flame.fill"
        case .dance: return "figure.dance"
        case .cooldown: return "figure.cooldown"
        case .elliptical: return "figure.elliptical"
        case .rowing: return "figure.rowing"
        case .stairClimbing: return "figure.stair.stepper"
        default: return "figure.mixed.cardio"
        }
    }

    private var workoutColor: Color {
        switch workout.workoutActivityType {
        case .running: return .green
        case .walking: return .blue
        case .cycling: return .orange
        case .hiking: return .brown
        case .swimming: return .cyan
        case .yoga: return .purple
        case .functionalStrengthTraining, .traditionalStrengthTraining: return .red
        case .highIntensityIntervalTraining: return .orange
        default: return .pink
        }
    }

    private var workoutTypeName: String {
        switch workout.workoutActivityType {
        case .running: return "Run"
        case .walking: return "Walk"
        case .cycling: return "Cycle"
        case .hiking: return "Hike"
        case .swimming: return "Swim"
        case .yoga: return "Yoga"
        case .functionalStrengthTraining: return "Strength"
        case .traditionalStrengthTraining: return "Strength"
        case .highIntensityIntervalTraining: return "HIIT"
        case .dance: return "Dance"
        case .cooldown: return "Cooldown"
        case .elliptical: return "Elliptical"
        case .rowing: return "Rowing"
        case .stairClimbing: return "Stair Climbing"
        default: return "Workout"
        }
    }

    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }
}
