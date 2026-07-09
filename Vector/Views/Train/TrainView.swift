import SwiftUI
import FoundationModels
import HealthKit
import MuscleMap
import Charts

struct TrainView: View {
    @Environment(HealthKitService.self) var service
    @Binding var activeSession: ActiveWorkoutSession?
    @Binding var showingWorkout: Bool
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.sleepTargetHours) private var sleepTargetHours = UserProfile.defaultSleepTargetHours

    @State private var showingCreation = false
    @State private var selectedWorkout: SavedWorkout?
    @State private var selectedHistoryWorkout: HKWorkout?
    @State private var selectedProcessingRecord: WorkoutCompletionRecord?
    @State private var showingAllHistory = false
    @State private var showingTrainingLoadDetail = false
    @State private var showingCardioLoadDetail = false
    @State private var muscleWindowDays: Int = 30

    private var profile: UserProfile {
        UserProfile(
            goal: FitnessGoal(rawValue: goalRaw) ?? UserProfile.defaultGoal,
            ageRange: AgeRange(rawValue: ageRangeRaw) ?? UserProfile.defaultAgeRange,
            trainingDaysPerWeek: trainingDays,
            sleepTargetHours: sleepTargetHours
        )
    }

    private static let cardioTypes: Set<HKWorkoutActivityType> = [
        .running, .walking, .cycling, .swimming, .hiking,
        .rowing, .elliptical, .stairClimbing, .highIntensityIntervalTraining,
        .dance, .jumpRope, .crossTraining
    ]

    private var sevenDaysAgo: Date {
        Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
    }

    private var muscleGridColumns: [GridItem] {
        [GridItem(.flexible(), spacing: 12), GridItem(.flexible(), spacing: 12)]
    }

    private var cardioLoad: Double {
        service.recentWorkouts
            .filter { Self.cardioTypes.contains($0.workoutActivityType) && $0.startDate >= sevenDaysAgo }
            .reduce(0) { sum, w in sum + w.activeEnergyKcal }
    }

    /// Daily total energy (kcal) over the last `days` days for workouts matching `include`.
    private func dailyEnergySeries(days: Int, include: (HKWorkout) -> Bool) -> [Double] {
        let cal = Calendar.current
        let today = cal.startOfDay(for: Date())
        var buckets = Array(repeating: 0.0, count: days)
        for w in service.recentWorkouts where include(w) {
            let day = cal.startOfDay(for: w.startDate)
            let diff = cal.dateComponents([.day], from: day, to: today).day ?? 0
            if diff >= 0 && diff < days {
                buckets[days - 1 - diff] += w.activeEnergyKcal
            }
        }
        return buckets
    }

    private var trainingLoadSeries: [Double] { dailyEnergySeries(days: 14) { _ in true } }
    private var cardioLoadSeries: [Double] { dailyEnergySeries(days: 14) { Self.cardioTypes.contains($0.workoutActivityType) } }

    private var historyItems: [WorkoutHistoryItem] {
        WorkoutHistoryItem.merged(workouts: service.recentWorkouts)
    }

    private var todayItems: [WorkoutHistoryItem] {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        return historyItems.filter { $0.date >= startOfDay }
    }

    private var muscleGroupData: [(group: String, volume: Double)] {
        let cutoff = Calendar.current.date(byAdding: .day, value: -muscleWindowDays, to: Date()) ?? Date()
        let workoutsByID = Dictionary(
            uniqueKeysWithValues: WorkoutStorageService.shared.savedWorkouts.map { ($0.id, $0) }
        )
        let library = ExerciseLibrary.shared
        var volumes: [String: Double] = [:]

        for record in WorkoutCompletionStore.shared.records where record.date >= cutoff {
            if let snapshot = record.muscleVolumes {
                // Use the snapshot captured at completion time (survives template deletion).
                for (group, vol) in snapshot {
                    volumes[group, default: 0] += vol
                }
            } else if let template = workoutsByID[record.templateID] {
                // Legacy records without a snapshot: fall back to the template if it still exists.
                for exercise in template.exercises where exercise.inputType == .reps {
                    let exVolume = exercise.totalVolumeKg
                    guard exVolume > 0 else { continue }
                    if let lib = library.exercises.first(where: { $0.name.lowercased() == exercise.name.lowercased() }) {
                        volumes[lib.muscleCategory, default: 0] += exVolume
                    }
                }
            }
        }

        return volumes
            .sorted { $0.value > $1.value }
            .map { (group: $0.key, volume: $0.value) }
    }

    private var cardioACWR: Double? {
        let sevenDaysAgo = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let twentyEightDaysAgo = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        let cardioWorkouts = service.recentWorkouts.filter { Self.cardioTypes.contains($0.workoutActivityType) }
        let acute = cardioWorkouts
            .filter { $0.startDate >= sevenDaysAgo }
            .reduce(0.0) { $0 + $1.activeEnergyKcal }
        let chronicTotal = cardioWorkouts
            .filter { $0.startDate >= twentyEightDaysAgo }
            .reduce(0.0) { $0 + $1.activeEnergyKcal }
        let chronic = chronicTotal / 4
        guard chronic > 10 else { return nil }
        return acute / chronic
    }

    private var cardioLoadLabel: String {
        guard let acwr = cardioACWR else { return "No Data" }
        if acwr < 0.8 { return "Detraining" }
        else if acwr <= 1.3 { return "Steady" }
        else { return "Overtraining" }
    }

    private var cardioLoadColor: Color {
        guard let acwr = cardioACWR else { return .secondary }
        if acwr < 0.8 { return .blue }
        else if acwr <= 1.3 { return .green }
        else { return .red }
    }

    private var trainingLoadLabel: String {
        guard let score = service.exertionScore else { return "No Data" }
        switch score.loadStatus {
        case .detraining: return "Detraining"
        case .optimal: return "Steady"
        case .overreaching, .overtraining: return "Overtraining"
        }
    }

    private var trainingLoadColor: Color {
        guard let score = service.exertionScore else { return .secondary }
        switch score.loadStatus {
        case .detraining: return .blue
        case .optimal: return .green
        case .overreaching, .overtraining: return .red
        }
    }

    private var exertionFill: Double {
        let total = Double(service.exertionScore?.score ?? 0)
        return total > 100 ? 1 : total / 100
    }

    private var exertionOverflow: Double {
        let total = Double(service.exertionScore?.score ?? 0)
        return total > 100 ? (total - 100) / total : 0
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    exertionHero
                    loadMetricsSection
                    muscleMapSection
                    savedWorkoutsSection
                    previousWorkoutsSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .gradientHeader()
            .navigationTitle("Train")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    ModeToolbarMenu()
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button { showingCreation = true } label: {
                        Image(systemName: "plus")
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
                WorkoutDetailView(workout: workout, onStartWorkout: { session in
                    activeSession = session
                    selectedWorkout = nil
                    showingWorkout = true
                }, onWorkoutUpdated: { updated in
                    selectedWorkout = updated
                })
            }
            .sheet(item: $selectedHistoryWorkout) { workout in
                NavigationStack {
                    WorkoutHistoryDetailView(workout: workout)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(item: $selectedProcessingRecord) { record in
                NavigationStack {
                    ProcessingWorkoutDetailView(record: record)
                        .navigationBarTitleDisplayMode(.inline)
                }
            }
            .sheet(isPresented: $showingAllHistory) {
                WorkoutFullHistoryView(workouts: service.recentWorkouts)
            }
            .sheet(isPresented: $showingTrainingLoadDetail) {
                LoadDetailView(
                    type: .training,
                    workouts: service.recentWorkouts,
                    vo2Max: service.latestVO2Max
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
            .sheet(isPresented: $showingCardioLoadDetail) {
                LoadDetailView(
                    type: .cardio,
                    workouts: service.recentWorkouts,
                    vo2Max: service.latestVO2Max
                )
                .presentationDetents([.medium, .large])
                .presentationDragIndicator(.visible)
                .presentationCornerRadius(28)
            }
            .task { await service.refreshIfStale() }
            .onChange(of: showingWorkout) { _, isShowing in
                guard !isShowing else { return }
                Task {
                    await service.refreshToday()
                    try? await Task.sleep(for: .seconds(3))
                    await service.refreshToday()
                }
            }
        }
    }

    // MARK: - Exertion Hero

    private var exertionHero: some View {
        let mode = AppModeStore.shared.currentMode
        let heroContent = VStack(spacing: 18) {
            ExertionTickRing(progress: exertionFill, overflow: exertionOverflow, size: 210) {
                VStack(spacing: 2) {
                    Text("\(service.exertionScore?.score ?? 0)")
                        .font(.system(size: 56, weight: .bold, design: .rounded))
                        .monospacedDigit()
                        .contentTransition(.numericText())
                        .lineLimit(1)
                        .minimumScaleFactor(0.5)
                    Text("EXERTION")
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .tracking(1.5)
                }
            }
            .frame(maxWidth: .infinity)
            .animation(.snappy, value: exertionFill)

            if let score = service.exertionScore {
                HStack(spacing: 0) {
                    ExertionStat(label: "7-Day Load", value: String(format: "%.0f kcal", score.acuteLoad))
                    Divider().frame(height: 28).opacity(0.3)
                    ExertionStat(label: "28-Day Load", value: String(format: "%.0f kcal", score.chronicLoad))
                    Divider().frame(height: 28).opacity(0.3)
                    ExertionStat(label: "Today's Exertion", value: score.exertionLevel.label)
                }
            }
        }
        .padding(.vertical, 8)

        if let statusMessage = mode.statusMessage {
            return AnyView(
                ZStack {
                    heroContent
                        .blur(radius: 8)

                    VStack(spacing: 8) {
                        Image(systemName: mode.icon)
                            .font(.title2)
                            .foregroundStyle(mode.color)
                        Text(statusMessage)
                            .font(.caption)
                            .foregroundStyle(.primary)
                            .multilineTextAlignment(.center)
                            .fixedSize(horizontal: false, vertical: true)
                    }
                    .padding(20)
                    .frame(maxWidth: 280)
                }
                .frame(maxWidth: .infinity)
            )
        } else {
            return AnyView(heroContent)
        }
    }

    // MARK: - Load Metrics

    private var loadMetricsSection: some View {
        HStack(spacing: 14) {
            Button { showingTrainingLoadDetail = true } label: {
                LoadStatusCard(
                    title: "Training Load",
                    status: trainingLoadLabel,
                    statusColor: trainingLoadColor,
                    icon: "flame.fill",
                    color: .orange,
                    series: trainingLoadSeries
                )
            }
            .buttonStyle(.plain)

            Button { showingCardioLoadDetail = true } label: {
                LoadStatusCard(
                    title: "Cardio Load",
                    status: cardioLoadLabel,
                    statusColor: cardioLoadColor,
                    icon: "heart.fill",
                    color: .pink,
                    series: cardioLoadSeries
                )
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Muscle Map

    private var muscleMapSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Muscle Focus")
                    .font(.title3.bold())
                Spacer()
            }

            if muscleGroupData.isEmpty {
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 14) {
                        HStack(spacing: 12) {
                            BodyView(gender: .male, side: .front)
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                            BodyView(gender: .male, side: .back)
                                .frame(maxWidth: .infinity)
                                .frame(height: 220)
                        }
                        .opacity(0.35)

                        VStack(spacing: 6) {
                            Image(systemName: "figure.strengthtraining.traditional")
                                .font(.system(size: 30))
                                .foregroundStyle(.secondary)
                            Text("No Vector Strength Data")
                                .font(.headline)
                            Text("Complete a Vector workout to track muscle focus")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                                .multilineTextAlignment(.center)
                        }
                    }
                }
            } else {
                GlassCard(cornerRadius: 20) {
                    VStack(spacing: 16) {
                        HStack(spacing: 12) {
                            BodyView(gender: .male, side: .front)
                                .intensities(muscleIntensityMap, colorScale: .thermal)
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                            BodyView(gender: .male, side: .back)
                                .intensities(muscleIntensityMap, colorScale: .thermal)
                                .frame(maxWidth: .infinity)
                                .frame(height: 300)
                        }
                        HeatScaleLegend()
                        Picker("Time Window", selection: $muscleWindowDays) {
                            Text("Week").tag(7)
                            Text("Month").tag(30)
                            Text("3 Months").tag(90)
                        }
                        .pickerStyle(.segmented)
                    }
                }
            }
        }
    }

    /// Maps a coarse muscle-group label (from `muscleGroupData`) to the MuscleMap
    /// muscles it represents.
    private func musclesForGroup(_ group: String) -> [Muscle] {
        switch group.lowercased() {
        case "arms": return [.biceps, .triceps, .forearm]
        case "shoulders": return [.deltoids]
        case "chest": return [.chest]
        case "back": return [.upperBack, .lowerBack, .trapezius, .rhomboids]
        case "hips & glutes": return [.gluteal, .hipFlexors, .adductors]
        case "legs": return [.quadriceps, .hamstring, .calves]
        case "core": return [.abs, .obliques]
        default: return []
        }
    }

    /// Per-muscle heat levels (1...4) derived from the selected time-window's training volume,
    /// scaled to the highest-volume group.
    private var muscleIntensityMap: [Muscle: Int] {
        let maxVolume = muscleGroupData.map(\.volume).max() ?? 0
        guard maxVolume > 0 else { return [:] }
        var map: [Muscle: Int] = [:]
        for item in muscleGroupData where item.volume > 0 {
            let level = max(1, Int((item.volume / maxVolume * 4).rounded()))
            for muscle in musclesForGroup(item.group) {
                map[muscle] = max(map[muscle] ?? 0, level)
            }
        }
        return map
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
                .glassEffect(in: .rect(cornerRadius: 20))
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
                .scrollClipDisabled()
            }
        }
    }

    // MARK: - Previous Workouts

    private var previousWorkoutsSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Recent Activity")
                .font(.title3.bold())

            if historyItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "heart.circle")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No workouts recorded")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Workouts from Apple Health will appear here")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button("See All History") { showingAllHistory = true }
                        .buttonStyle(.glassProminent)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassEffect(in: .rect(cornerRadius: 24))
            } else if todayItems.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "moon.zzz")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No activity today")
                        .font(.headline)
                        .foregroundStyle(.secondary)
                    Text("Your training history is below")
                        .font(.caption)
                        .foregroundStyle(.tertiary)
                    Button("See All History") { showingAllHistory = true }
                        .buttonStyle(.glassProminent)
                        .padding(.top, 4)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassEffect(in: .rect(cornerRadius: 20))
            } else {
                LazyVStack(spacing: 10) {
                    ForEach(todayItems.prefix(5)) { item in
                        Button {
                            if let wk = item.hkWorkout {
                                selectedHistoryWorkout = wk
                            } else if let record = item.record {
                                selectedProcessingRecord = record
                            }
                        } label: {
                            WorkoutHistoryRow(item: item)
                        }
                        .buttonStyle(.plain)
                    }
                }
                if service.recentWorkouts.count > todayItems.count {
                    Button {
                        showingAllHistory = true
                    } label: {
                        Text("See All History (\(service.recentWorkouts.count) workouts)")
                            .font(.subheadline)
                            .foregroundStyle(.cyan)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .glassEffect(in: .rect(cornerRadius: 14))
                    }
                    .buttonStyle(.plain)
                }
            }
        }
    }
}

// MARK: - Exertion Tick Ring

/// A ring built from radial tick marks. Ticks fill clockwise up to `progress`,
/// colored along a green→red gradient (green at the start, red toward max).
private struct ExertionTickRing<Center: View>: View {
    let progress: Double      // 0...1 portion of ticks that are active
    let overflow: Double      // >0 when the score exceeds max; pushes active ticks deep red
    let tickCount: Int
    let size: CGFloat
    @ViewBuilder let center: () -> Center

    init(progress: Double, overflow: Double = 0, tickCount: Int = 56, size: CGFloat = 210, @ViewBuilder center: @escaping () -> Center) {
        self.progress = progress
        self.overflow = overflow
        self.tickCount = tickCount
        self.size = size
        self.center = center
    }

    var body: some View {
        ZStack {
            ForEach(0..<tickCount, id: \.self) { i in
                let fraction = Double(i) / Double(tickCount)
                let active = fraction < max(progress, 0.0001) && progress > 0
                tick(active: active, fraction: fraction, index: i)
            }
            center()
        }
        .frame(width: size, height: size)
    }

    private func tick(active: Bool, fraction: Double, index: Int) -> some View {
        // Green (hue 0.33) at the start → red (hue 0.0) at the max.
        let baseHue = 0.33 * (1 - fraction)
        let hue = overflow > 0 ? 0.0 : baseHue
        let color = active
            ? Color(hue: hue, saturation: 0.9, brightness: 0.95)
            : Color.gray.opacity(0.16)
        return RoundedRectangle(cornerRadius: 2)
            .fill(color)
            .frame(width: 3.5, height: 15)
            .offset(y: -size / 2 + 10)
            .rotationEffect(.degrees(Double(index) / Double(tickCount) * 360))
    }
}

// MARK: - ExertionStat

private struct ExertionStat: View {
    let label: String
    let value: String

    var body: some View {
        VStack(spacing: 3) {
            Text(value)
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .lineLimit(1)
                .minimumScaleFactor(0.7)
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
                .lineLimit(1)
                .minimumScaleFactor(0.7)
        }
        .frame(maxWidth: .infinity)
    }
}

// MARK: - Mini Sparkline

private struct MiniSparkline: View {
    let values: [Double]
    let color: Color

    var body: some View {
        let maxV = values.max() ?? 0
        let minV = values.min() ?? 0
        let span = max(maxV - minV, 1)
        return Chart(Array(values.enumerated()), id: \.offset) { idx, v in
            AreaMark(x: .value("i", idx), y: .value("v", v))
                .foregroundStyle(LinearGradient(colors: [color.opacity(0.35), color.opacity(0)], startPoint: .top, endPoint: .bottom))
                .interpolationMethod(.catmullRom)
            LineMark(x: .value("i", idx), y: .value("v", v))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2, lineCap: .round))
                .interpolationMethod(.catmullRom)
        }
        .chartYScale(domain: (minV - span * 0.18)...(maxV + span * 0.1))
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .chartLegend(.hidden)
        .chartPlotStyle { plot in
            plot.frame(maxWidth: .infinity).padding(0)
        }
        .frame(height: 40)
    }
}

// MARK: - LoadStatusCard

private struct LoadStatusCard: View {
    let title: String
    let status: String
    let statusColor: Color
    let icon: String
    let color: Color
    let series: [Double]

    var body: some View {
        VStack(alignment: .leading, spacing: 0) {
            VStack(alignment: .leading, spacing: 10) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(color)
                    Text(title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                        .lineLimit(1)
                        .minimumScaleFactor(0.7)
                    Spacer(minLength: 4)
                    Image(systemName: "chevron.right")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
                Text(status)
                    .font(.title3.bold())
                    .foregroundStyle(.primary)
                    .lineLimit(1)
                    .minimumScaleFactor(0.6)
            }
            .padding(16)
            .frame(maxWidth: .infinity, alignment: .leading)

            Spacer(minLength: 8)

            if series.contains(where: { $0 > 0 }) {
                MiniSparkline(values: series, color: color)
                    .padding(.bottom, 14)
            }
        }
        .frame(maxWidth: .infinity, minHeight: 132, alignment: .topLeading)
        .glassEffect(.regular.tint(color.opacity(0.12)), in: .rect(cornerRadius: 20))
        .clipShape(.rect(cornerRadius: 20))
    }
}

// MARK: - Heat Scale Legend

private struct HeatScaleLegend: View {
    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            LinearGradient(
                colors: [.blue, .green, .yellow, .red],
                startPoint: .leading,
                endPoint: .trailing
            )
            .frame(height: 8)
            .clipShape(Capsule())

            HStack {
                Text("Less volume")
                Spacer()
                Text("More volume")
            }
            .font(.caption2)
            .foregroundStyle(.secondary)
        }
    }
}

// MARK: - SavedWorkoutCard

private struct SavedWorkoutCard: View {
    let workout: SavedWorkout
    let onTap: () -> Void

    var body: some View {
        Button(action: onTap) {
            VStack(alignment: .leading, spacing: 0) {
                HStack {
                    Text(workout.focus)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .minimumScaleFactor(0.8)
                    Spacer()
                }
                .padding(.bottom, 10)

                Text(workout.title)
                    .font(.headline)
                    .lineLimit(2)
                    .foregroundStyle(.primary)
                    .minimumScaleFactor(0.7)
                Spacer()

                HStack(spacing: 10) {
                    Label("\(workout.exercises.count)", systemImage: "dumbbell.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                    Label("\(workout.durationMinutes)m", systemImage: "clock.fill")
                        .font(.caption2.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .padding(.bottom, 8)

                HStack(spacing: 3) {
                    ForEach(0..<min(workout.effort, 10), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.orange)
                            .frame(width: 10, height: 4)
                    }
                    ForEach(0..<max(10 - workout.effort, 0), id: \.self) { _ in
                        RoundedRectangle(cornerRadius: 2)
                            .fill(.white.opacity(0.12))
                            .frame(width: 10, height: 4)
                    }
                }
            }
            .padding(14)
            .glassEffect(.regular, in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
        .frame(width: 165, height: 160)
        .askVector(topicForSavedWorkout(workout))
    }

    private func topicForSavedWorkout(_ workout: SavedWorkout) -> AdvisorTopic {
        var context = ["Workout: \(workout.title)"]
        context.append("Focus: \(workout.focus)")
        context.append("Exercises: \(workout.exercises.count)")
        context.append("Duration: \(workout.durationMinutes) min")
        context.append("Intensity: \(workout.effort)/10")
        return AdvisorTopic(
            title: workout.title,
            icon: "dumbbell.fill",
            tintName: "orange",
            contextLines: context,
            suggestedPrompt: "Is this workout a good choice for me today given my recovery?"
        )
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
            VStack(alignment: .leading, spacing: 10) {
                ZStack {
                    Circle()
                        .fill(tint.opacity(0.18))
                        .frame(width: 44, height: 44)
                    Image(systemName: icon)
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(tint)
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(label)
                        .font(.headline)
                    Text(description)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                        .fixedSize(horizontal: false, vertical: true)
                }

                Spacer()
            }
            .frame(maxWidth: .infinity, alignment: .topLeading)
            .padding(16)
            .frame(height: 130)
            .glassEffect(.regular.tint(tint.opacity(0.18)), in: .rect(cornerRadius: 22))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - WorkoutHistoryRow

private struct WorkoutHistoryRow: View {
    let item: WorkoutHistoryItem

    private var activityType: HKWorkoutActivityType {
        item.hkWorkout?.workoutActivityType ?? .traditionalStrengthTraining
    }

    private var isStrength: Bool {
        activityType == .traditionalStrengthTraining || activityType == .functionalStrengthTraining
    }

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
                Text(item.record?.title ?? workoutTypeName)
                    .font(.headline)
                    .lineLimit(1)
                Text(item.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            if item.isProcessing {
                processingBadge
            } else {
                VStack(alignment: .trailing, spacing: 4) {
                    Text(formatDuration(item.hkWorkout?.duration ?? 0))
                        .font(.subheadline.weight(.semibold).monospacedDigit())

                    HStack(spacing: 8) {
                        if isStrength {
                            if let vol = item.record?.totalVolume, vol > 0 {
                                Text(WorkoutStatFormat.volume(vol))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        } else {
                            if let distance = item.hkWorkout?.totalDistance?.doubleValue(for: .meter()), distance > 0 {
                                Text(String(format: "%.2f km", distance / 1000))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        if let cal = item.hkWorkout, cal.activeEnergyKcal > 0 {
                            Text("\(Int(cal.activeEnergyKcal)) kcal")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }

            Image(systemName: "chevron.right")
                .font(.caption)
                .foregroundStyle(.tertiary)
        }
        .padding(14)
        .glassEffect(.regular.tint(workoutColor.opacity(0.08)), in: .rect(cornerRadius: 18))
        .askVector(topicForWorkoutHistory(item))
    }

    private func topicForWorkoutHistory(_ item: WorkoutHistoryItem) -> AdvisorTopic {
        var context = [
            "Workout: \(item.record?.title ?? workoutTypeName)",
            "Date: \(item.date.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))",
            "Duration: \(formatDuration(item.hkWorkout?.duration ?? 0))"
        ]
        if let vol = item.record?.totalVolume, vol > 0, isStrength {
            context.append("Volume: \(WorkoutStatFormat.volume(vol))")
        }
        if let cal = item.hkWorkout, cal.activeEnergyKcal > 0 {
            context.append("Energy: \(Int(cal.activeEnergyKcal)) kcal")
        }
        return AdvisorTopic(
            title: item.record?.title ?? workoutTypeName,
            icon: workoutIcon,
            tintName: workoutColorName(),
            contextLines: context,
            suggestedPrompt: "How was this workout session? Any trends in my performance?"
        )
    }

    private func workoutColorName() -> String {
        switch activityType {
        case .running: return "green"
        case .walking: return "blue"
        case .cycling: return "orange"
        case .hiking: return "orange"
        case .swimming: return "cyan"
        case .yoga: return "purple"
        case .functionalStrengthTraining, .traditionalStrengthTraining: return "red"
        case .highIntensityIntervalTraining: return "orange"
        default: return "pink"
        }
    }

    private var processingBadge: some View {
        HStack(spacing: 6) {
            ProgressView()
                .controlSize(.mini)
            Text("Processing")
                .font(.caption.weight(.medium))
                .foregroundStyle(.orange)
        }
        .padding(.horizontal, 10)
        .padding(.vertical, 6)
        .glassEffect(.regular.tint(.orange.opacity(0.15)), in: Capsule())
    }

    private var workoutIcon: String {
        switch activityType {
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
        switch activityType {
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
        switch activityType {
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

extension HKWorkout: @retroactive Identifiable {}

#Preview {
    @Previewable @State var activeSession: ActiveWorkoutSession? = nil
    @Previewable @State var showingWorkout = false

    TrainView(activeSession: $activeSession, showingWorkout: $showingWorkout)
        .environment(HealthKitService())
}
