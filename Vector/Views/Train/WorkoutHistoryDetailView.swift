import SwiftUI
import HealthKit
import Charts
import MapKit
import CoreLocation

struct WorkoutHistoryDetailView: View {
    let workout: HKWorkout
    @Environment(HealthKitService.self) var healthService
    @Environment(\.dismiss) private var dismiss

    @State private var heartRateData: [(date: Date, value: Double)] = []
    @State private var routeData: [(latitude: Double, longitude: Double, altitude: Double, timestamp: Date)] = []
    @State private var splits: [(splitIndex: Int, duration: TimeInterval, avgHeartRate: Double?)] = []
    @State private var isLoading = true
    @State private var showAnimations = false
    @State private var mapReady = false
    @State private var showExpandedMap = false
    @State private var showingExerciseEditor = false
    @State private var localExercises: [ManualExerciseEntry]? = nil
    @State private var effortScore: Double? = nil

    var body: some View {
        ScrollView {
                VStack(spacing: 0) {
                    // MARK: - Hero Header
                    HeroHeader()
                        .frame(height: 280)
                        .opacity(showAnimations ? 1 : 0.8)
                        .scaleEffect(showAnimations ? 1 : 0.98, anchor: .top)
                        .background {
                            ZStack {
                                if hasRoute && mapReady {
                                    Map(interactionModes: []) {
                                        MapPolyline(coordinates: routeCoordinates)
                                            .stroke(workoutColor, lineWidth: 4)
                                    }
                                    .mapStyle(.standard(elevation: .realistic, pointsOfInterest: .excludingAll))
                                    .frame(height: 420)
                                    .overlay {
                                        LinearGradient(
                                            colors: [
                                                .black.opacity(0.55),
                                                .black.opacity(0.25),
                                                .black.opacity(0.45)
                                            ],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                    }
                                    .overlay(alignment: .bottom) {
                                        LinearGradient(
                                            colors: [.clear, Color(.systemBackground)],
                                            startPoint: .top,
                                            endPoint: .bottom
                                        )
                                        .frame(height: 130)
                                    }
                                    .ignoresSafeArea(edges: .top)
                                    .allowsHitTesting(false)
                                    .transition(.opacity)
                                } else {
                                    LinearGradient(
                                        colors: [workoutColor.opacity(0.45), workoutColor.opacity(0.2), .clear],
                                        startPoint: .top,
                                        endPoint: .bottom
                                    )
                                    .frame(height: 380)
                                    .ignoresSafeArea(edges: .top)
                                    .padding(.top, -40)
                                }
                            }
                            .padding(.top, -10)
                        }

                    VStack(spacing: 24) {
                        // MARK: - Stats Grid
                        StatsGrid()

                        if !isLoading {
                            // MARK: - Heart Rate Chart
                            if !heartRateData.isEmpty {
                                HeartRateSection()
                            }

                            // MARK: - Location-based sections
                            if isLocationWorkout && !routeData.isEmpty && !splits.isEmpty {
                                ElevationSection()
                                SplitsTableSection()
                                PaceChartSection()
                            }
                        }

                        // MARK: - Exercises Performed
                        if isStrengthWorkout {
                            if !displayedExercises.isEmpty {
                                VStack(alignment: .leading, spacing: 12) {
                                    PerformedExercisesSection(exercises: displayedExercises)
                                    Button {
                                        showingExerciseEditor = true
                                    } label: {
                                        HStack(spacing: 8) {
                                            Image(systemName: "pencil")
                                                .font(.subheadline)
                                            Text("Edit Exercises")
                                                .font(.subheadline.weight(.semibold))
                                            Spacer()
                                        }
                                        .foregroundStyle(.blue)
                                        .padding(14)
                                        .frame(maxWidth: .infinity)
                                        .glassEffect(.regular, in: .rect(cornerRadius: 16))
                                    }
                                    .buttonStyle(.plain)
                                }
                            } else {
                                Button {
                                    showingExerciseEditor = true
                                } label: {
                                    HStack(spacing: 16) {
                                        VStack {
                                            Image(systemName: "figure.strengthtraining.traditional")
                                                .font(.title)
                                                .foregroundStyle(VectorTheme.brandForeground)
                                        }
                                        .frame(width: 52, height: 52)

                                        VStack(alignment: .leading, spacing: 4) {
                                            Text("Personalize your Workout")
                                                .font(.headline)
                                                .foregroundStyle(.primary)

                                            Text("Add exercises or load a pre-saved template so Vector can track your progression.")
                                                .font(.caption)
                                                .foregroundStyle(.secondary)
                                                .fixedSize(horizontal: false, vertical: true)

                                            HStack {
                                                Text("Click here to personalize this workout")
                                                    .font(.caption)
                                                    .foregroundStyle(.gray)
                                            }
                                            .padding(.top, 6)
                                        }

                                        Spacer()
                                    }
                                    .padding(16)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                                    .glassEffect(.regular, in: .rect(cornerRadius: 16))
                                }
                                .buttonStyle(.plain)
                            }
                        }

                        // MARK: - Workout Summary Footer
                        WorkoutSummaryFooter()
                    }
                    .padding(.horizontal, 16)
                    .padding(.vertical, 24)
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
        .navigationBarBackButtonHidden(false)
        .toolbarBackground(.hidden, for: .navigationBar)
        .toolbarRole(.navigationStack)
        .toolbar {
            ToolbarItem(placement: .topBarLeading) {
                Button(action: {
                    dismiss()
                }) {
                    Image(systemName: "multiply")
                        .font(.body.weight(.medium))
                        .padding(8)
                }
            }
            if hasRoute {
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        showExpandedMap = true
                    } label: {
                        Image(systemName: "map.fill")
                            .font(.body.weight(.medium))
                            .padding(8)
                    }
                    .buttonStyle(.plain)
                }
            }
        }
        .fullScreenCover(isPresented: $showExpandedMap) {
            ExpandedRouteMapView(
                routeData: routeData,
                splits: splits,
                routeColor: workoutColor,
                workoutName: workoutTypeName,
                date: formatDate(workout.startDate),
                distance: formatDistance(workout.totalDistance),
                duration: formatDuration(workout.duration),
                totalDistance: workout.totalDistance?.doubleValue(for: .meter()) ?? 0
            )
        }
        .sheet(isPresented: $showingExerciseEditor) {
            StrengthExerciseEditorView(workout: workout, initial: displayedExercises) { edited in
                localExercises = edited
                WorkoutCompletionStore.shared.annotate(workout: workout, exercises: edited)
            }
        }
        .task {
            async let hr = healthService.fetchHeartRateDuringWorkout(workout)
            async let route = healthService.fetchWorkoutRoute(workout)
            let splitDist: Double = isLocationWorkout ? 1000 : 0
            async let sp = healthService.fetchWorkoutSplits(workout, distancePerSplit: max(splitDist, 1))
            let effort = await healthService.effortScore(for: workout)
            effortScore = effort

            heartRateData = await hr
            routeData = await route
            // Prefer GPS-route-based splits (matches Apple Fitness); fall back to
            // distance-sample splits only when no route is available.
            if routeData.count >= 2 {
                splits = computeRouteSplits(distancePerSplit: 1000)
            } else {
                splits = await sp
            }
            isLoading = false
        }
        .onAppear {
            if localExercises == nil {
                localExercises = matchedRecord?.performedExercises
            }
            withAnimation(.easeOut(duration: 0.6)) {
                showAnimations = true
            }
            Task {
                try? await Task.sleep(for: .milliseconds(550))
                withAnimation(.easeOut(duration: 0.4)) {
                    mapReady = true
                }
            }
        }
    }

    // MARK: - Hero Header
    @ViewBuilder
    private func HeroHeader() -> some View {
        VStack(alignment: .center, spacing: 12) {
            Image(systemName: workoutIcon)
                .font(.system(size: 48))
                .foregroundStyle(hasRoute ? .white : workoutColor)
                .shadow(color: .black.opacity(hasRoute ? 0.5 : 0), radius: 8)
                .scaleEffect(showAnimations ? 1 : 0.8)

            VStack(spacing: 4) {
                Text(workoutTypeName)
                    .font(.system(size: 28, weight: .bold, design: .rounded))
                    .foregroundStyle(hasRoute ? .white : .primary)

                Text(formatDate(workout.startDate))
                    .font(.system(size: 14, weight: .medium))
                    .foregroundStyle(hasRoute ? .white.opacity(0.7) : .secondary)
            }
            .shadow(color: .black.opacity(hasRoute ? 0.4 : 0), radius: 6)

            Text(formatDuration(workout.duration))
                .font(.system(size: 48, weight: .bold, design: .monospaced))
                .foregroundStyle(hasRoute ? .white : workoutColor)
                .shadow(color: .black.opacity(hasRoute ? 0.5 : 0), radius: 10)
                .padding(.top, 8)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 24)
    }

    // MARK: - Stats Grid
    @ViewBuilder
    private func StatsGrid() -> some View {
        VStack(spacing: 12) {
            if isStrengthWorkout {
                HStack(spacing: 12) {
                    StatCard(label: "Volume", value: WorkoutStatFormat.volume(totalVolume),
                             icon: "scalemass.fill", iconColor: .cyan)
                    StatCard(label: "Calories", value: formatCalories(workout.activeEnergyKcal),
                             icon: "flame.fill", iconColor: .orange)
                }
                HStack(spacing: 12) {
                    StatCard(label: "Avg Heart Rate", value: formatHeartRate(averageHeartRate),
                             icon: "heart.fill", iconColor: .red)
                    StatCard(label: totalSets > 0 ? "Total Sets" : "Duration",
                             value: totalSets > 0 ? "\(totalSets)" : formatDuration(workout.duration),
                             icon: totalSets > 0 ? "list.number" : "clock.fill", iconColor: .green)
                }
                if let effort = effortScore {
                    StatCard(label: "Effort", value: "\(Int(effort)) of 10", icon: "gauge.with.needle", iconColor: .cyan)
                }
            } else {
                HStack(spacing: 12) {
                    StatCard(label: "Distance", value: formatDistance(workout.totalDistance),
                             icon: "location.fill", iconColor: .blue)
                    StatCard(label: "Calories", value: formatCalories(workout.activeEnergyKcal),
                             icon: "flame.fill", iconColor: .orange)
                }
                HStack(spacing: 12) {
                    StatCard(label: "Avg Heart Rate", value: formatHeartRate(averageHeartRate),
                             icon: "heart.fill", iconColor: .red)
                    StatCard(label: "Avg Pace", value: formatPace(averagePacePerKm),
                             icon: "speedometer", iconColor: .green)
                }
                if let effort = effortScore {
                    StatCard(label: "Effort", value: "\(Int(effort)) of 10", icon: "gauge.with.needle", iconColor: .cyan)
                }
            }
        }
    }

    // MARK: - Heart Rate Section
    @ViewBuilder
    private func HeartRateSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Heart Rate")
                .font(.headline)

            GlassCard(cornerRadius: 20) {
                VStack(spacing: 16) {
                    Chart {
                        ForEach(heartRateData, id: \.date) { point in
                            AreaMark(
                                x: .value("Time", point.date),
                                y: .value("BPM", point.value)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    colors: [workoutColor.opacity(0.4), workoutColor.opacity(0.05)],
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Time", point.date),
                                y: .value("BPM", point.value)
                            )
                            .foregroundStyle(workoutColor)
                            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis {
                        AxisMarks(values: .automatic) { value in
                            AxisGridLine()
                            AxisTick()
                            AxisValueLabel {
                                if let date = value.as(Date.self) {
                                    Text(date.formatted(.dateTime.hour().minute()))
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                    }
                    .frame(height: 200)

                    HStack(spacing: 16) {
                        HRStat(label: "Min", value: Int(minHeartRate), color: .blue, icon: "arrow.down.heart.fill")
                        HRStat(label: "Avg", value: Int(averageHeartRate), color: .primary, icon: "heart.fill")
                        HRStat(label: "Max", value: Int(maxHeartRate), color: .red, icon: "arrow.up.heart.fill")
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Elevation Section
    @ViewBuilder
    private func ElevationSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Elevation")
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(.primary)

            GlassCard(cornerRadius: 16) {
                VStack(alignment: .leading, spacing: 16) {
                    Chart {
                        ForEach(Array(sampledRouteData.enumerated()), id: \.offset) { index, point in
                            AreaMark(
                                x: .value("Distance", index),
                                y: .value("Altitude", point.altitude)
                            )
                            .foregroundStyle(
                                LinearGradient(
                                    gradient: Gradient(colors: [
                                        Color.green.opacity(0.6),
                                        Color.green.opacity(0.1)
                                    ]),
                                    startPoint: .top,
                                    endPoint: .bottom
                                )
                            )
                            .interpolationMethod(.catmullRom)

                            LineMark(
                                x: .value("Distance", index),
                                y: .value("Altitude", point.altitude)
                            )
                            .foregroundStyle(Color.green)
                            .lineStyle(StrokeStyle(lineWidth: 2))
                            .interpolationMethod(.catmullRom)
                        }
                    }
                    .chartYAxis {
                        AxisMarks(position: .leading)
                    }
                    .chartXAxis(.hidden)
                    .frame(height: 160)

                    HStack(spacing: 16) {
                        if let minAlt = routeData.map(\.altitude).min(),
                           let maxAlt = routeData.map(\.altitude).max() {
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up.right")
                                        .font(.caption2)
                                    Text("Gain")
                                        .font(.caption)
                                }
                                .foregroundStyle(.green)
                                Text("\(Int(maxAlt - minAlt))m")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.green)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.down")
                                        .font(.caption2)
                                    Text("Min")
                                        .font(.caption)
                                }
                                .foregroundStyle(.blue)
                                Text("\(Int(minAlt))m")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.blue)
                            }
                            VStack(alignment: .leading, spacing: 2) {
                                HStack(spacing: 4) {
                                    Image(systemName: "arrow.up")
                                        .font(.caption2)
                                    Text("Max")
                                        .font(.caption)
                                }
                                .foregroundStyle(.red)
                                Text("\(Int(maxAlt))m")
                                    .font(.subheadline.weight(.semibold).monospacedDigit())
                                    .foregroundStyle(.red)
                            }
                        }
                        Spacer()
                    }
                }
            }
        }
    }

    // MARK: - Pace Chart Section
    @ViewBuilder
    private func PaceChartSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Pace per Split")
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(.primary)

            GlassCard(cornerRadius: 16) {
                Chart {
                    ForEach(splits, id: \.splitIndex) { split in
                        BarMark(
                            x: .value("Split", "km \(split.splitIndex + 1)"),
                            y: .value("Pace", secondsPerKmForSplit(split))
                        )
                        .foregroundStyle(colorForPace(secondsPerKmForSplit(split)))
                        .cornerRadius(4)
                    }
                }
                .chartYAxis {
                    AxisMarks(position: .leading)
                }
                .frame(height: 180)
            }
        }
    }

    // MARK: - Splits Table Section
    @ViewBuilder
    private func SplitsTableSection() -> some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("Splits")
                .font(.system(size: 16, weight: .semibold, design: .default))
                .foregroundStyle(.primary)

            GlassCard(cornerRadius: 16) {
                VStack(spacing: 0) {
                    ForEach(Array(splits.enumerated()), id: \.element.splitIndex) { index, split in
                        SplitRow(
                            splitIndex: split.splitIndex,
                            pace: formatPace(secondsPerKmForSplit(split)),
                            heartRate: split.avgHeartRate,
                            paceValue: secondsPerKmForSplit(split),
                            averagePace: averagePacePerKm
                        )
                        if index < splits.count - 1 {
                            Divider()
                                .opacity(0.25)
                                .padding(.horizontal, 12)
                        }
                    }
                }
                .padding(.vertical, 4)
            }
        }
    }

    // MARK: - Workout Summary Footer
    @ViewBuilder
    private func WorkoutSummaryFooter() -> some View {
        VStack(spacing: 16) {
            Divider()
                .opacity(0.3)

            VStack(alignment: .leading, spacing: 12) {
                SummaryRow(label: "Start Time", value: formatTime(workout.startDate))
                SummaryRow(label: "End Time", value: formatTime(workout.endDate))
                SummaryRow(label: "Source", value: workout.sourceRevision.source.name)
            }
            .font(.system(size: 14, design: .default))
        }
    }

    // MARK: - Helper Components
    @ViewBuilder
    private func SplitRow(
        splitIndex: Int,
        pace: String,
        heartRate: Double?,
        paceValue: Double,
        averagePace: Double
    ) -> some View {
        HStack(spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("Split \(splitIndex + 1)")
                    .font(.system(size: 14, weight: .semibold, design: .default))
                    .foregroundStyle(.primary)
                Text(pace)
                    .font(.system(size: 16, weight: .bold, design: .monospaced))
                    .foregroundStyle(colorForPace(paceValue))
            }

            Spacer()

            if let hr = heartRate {
                VStack(alignment: .trailing, spacing: 4) {
                    Text("HR")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("\(Int(hr))")
                        .font(.system(size: 14, weight: .semibold, design: .monospaced))
                        .foregroundStyle(.primary)
                }
            }

            Circle()
                .fill(colorForPace(paceValue))
                .frame(width: 12, height: 12)
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 10)
    }

    @ViewBuilder
    private func SummaryRow(label: String, value: String) -> some View {
        HStack {
            Text(label)
                .foregroundStyle(.secondary)
            Spacer()
            Text(value)
                .foregroundStyle(.primary)
                .fontWeight(.semibold)
        }
    }

    // MARK: - Computed Properties
    private var isLocationWorkout: Bool {
        [.running, .walking, .cycling, .hiking].contains(workout.workoutActivityType)
    }

    private var hasRoute: Bool {
        isLocationWorkout && routeCoordinates.count >= 2
    }

    // Build per-kilometer splits from the GPS route — the same source Apple
    // Fitness uses. Two corrections make it match Fitness:
    //  1. GPS jitter overcounts distance, so scale boundaries to the workout's
    //     authoritative totalDistance (prevents a spurious extra split).
    //  2. Auto-pauses leave large time gaps between points; gaps over the pause
    //     threshold are excluded so split times reflect active (moving) time.
    private func computeRouteSplits(distancePerSplit: Double) -> [(splitIndex: Int, duration: TimeInterval, avgHeartRate: Double?)] {
        // Route batches can arrive out of order — sort by timestamp first.
        let points = routeData.sorted { $0.timestamp < $1.timestamp }
        guard points.count >= 2 else { return [] }

        func avgHR(from start: Date, to end: Date) -> Double? {
            let s = heartRateData.filter { $0.date >= start && $0.date < end }
            return s.isEmpty ? nil : s.map(\.value).reduce(0, +) / Double(s.count)
        }

        // Raw GPS cumulative distance, then a scale factor so split boundaries
        // align with the workout's authoritative total distance.
        var rawTotal: Double = 0
        for i in 1..<points.count {
            rawTotal += CLLocation(latitude: points[i].latitude, longitude: points[i].longitude)
                .distance(from: CLLocation(latitude: points[i - 1].latitude, longitude: points[i - 1].longitude))
        }
        let authoritative = workout.totalDistance?.doubleValue(for: .meter()) ?? rawTotal
        let distanceScale = (rawTotal > 0 && authoritative > 0) ? authoritative / rawTotal : 1

        // Inter-point gaps longer than this are treated as paused time and
        // excluded, so durations reflect active (moving) time like Apple Fitness.
        let pauseGapThreshold: TimeInterval = 20

        var splits: [(splitIndex: Int, duration: TimeInterval, avgHeartRate: Double?)] = []
        var cumulative: Double = 0           // scaled meters covered
        var activeElapsed: TimeInterval = 0  // active (moving) seconds covered
        var nextBoundary = distancePerSplit
        var splitIndex = 0
        var splitStartElapsed: TimeInterval = 0
        var splitStartDate = points[0].timestamp

        for i in 1..<points.count {
            let a = points[i - 1]
            let b = points[i]
            let segDistance = CLLocation(latitude: b.latitude, longitude: b.longitude)
                .distance(from: CLLocation(latitude: a.latitude, longitude: a.longitude)) * distanceScale
            guard segDistance > 0 else { continue }
            let rawDur = b.timestamp.timeIntervalSince(a.timestamp)
            // A large gap is a pause: it contributes no active time.
            let segActive: TimeInterval = (rawDur > 0 && rawDur <= pauseGapThreshold) ? rawDur : 0
            let c0 = cumulative
            let c1 = cumulative + segDistance

            while nextBoundary <= c1 {
                let frac = (nextBoundary - c0) / segDistance
                let boundaryElapsed = activeElapsed + frac * segActive
                let boundaryDate = a.timestamp.addingTimeInterval(frac * max(rawDur, 0))
                splits.append((splitIndex, boundaryElapsed - splitStartElapsed, avgHR(from: splitStartDate, to: boundaryDate)))
                splitStartElapsed = boundaryElapsed
                splitStartDate = boundaryDate
                splitIndex += 1
                nextBoundary += distancePerSplit
            }
            cumulative = c1
            activeElapsed += segActive
        }

        // Trailing partial split only if a meaningful remainder exists (>50 m).
        let coveredByFullSplits = nextBoundary - distancePerSplit
        if cumulative - coveredByFullSplits > 50, activeElapsed > splitStartElapsed {
            let lastDate = points.last?.timestamp ?? splitStartDate
            splits.append((splitIndex, activeElapsed - splitStartElapsed, avgHR(from: splitStartDate, to: lastDate)))
        }

        return splits
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

    private var routeCoordinates: [CLLocationCoordinate2D] {
        routeData.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }
    }

    private var sampledRouteData: [(latitude: Double, longitude: Double, altitude: Double, timestamp: Date)] {
        guard routeData.count > 200 else { return routeData }
        let step = routeData.count / 200
        return stride(from: 0, to: routeData.count, by: step).map { routeData[$0] }
    }

    private var minHeartRate: Double {
        heartRateData.map(\.value).min() ?? 0
    }

    private var maxHeartRate: Double {
        heartRateData.map(\.value).max() ?? 0
    }

    private var averageHeartRate: Double {
        guard !heartRateData.isEmpty else { return 0 }
        return heartRateData.map(\.value).reduce(0, +) / Double(heartRateData.count)
    }

    private var averagePacePerKm: Double {
        guard !splits.isEmpty else { return 0 }
        let totalSeconds = splits.map(\.duration).reduce(0, +)
        let totalSplits = Double(splits.count)
        return totalSeconds / totalSplits
    }

    private var matchedRecord: WorkoutCompletionRecord? {
        WorkoutCompletionStore.shared.record(matching: workout)
    }

    private var displayedExercises: [ManualExerciseEntry] {
        localExercises ?? matchedRecord?.performedExercises ?? []
    }

    private var isStrengthWorkout: Bool {
        [.traditionalStrengthTraining, .functionalStrengthTraining].contains(workout.workoutActivityType)
    }

    private var totalVolume: Double {
        if let v = matchedRecord?.totalVolume, v > 0 { return v }
        return (workout.metadata?["VectorTotalVolume"] as? Double) ?? 0
    }

    private var totalSets: Int {
        matchedRecord?.performedExercises?.reduce(0) { $0 + $1.sets } ?? 0
    }

    // MARK: - Formatting Helpers
    private func formatDuration(_ seconds: TimeInterval) -> String {
        let h = Int(seconds) / 3600
        let m = (Int(seconds) % 3600) / 60
        let s = Int(seconds) % 60
        if h > 0 { return String(format: "%d:%02d:%02d", h, m, s) }
        return String(format: "%d:%02d", m, s)
    }

    private func formatPace(_ secondsPerKm: Double) -> String {
        guard secondsPerKm.isFinite && secondsPerKm > 0 else { return "--:--" }
        let mins = Int(secondsPerKm) / 60
        let secs = Int(secondsPerKm) % 60
        return String(format: "%d:%02d", mins, secs)
    }

    private func formatDistance(_ distance: HKQuantity?) -> String {
        guard let distance = distance else { return "--" }
        let km = distance.doubleValue(for: .meterUnit(with: .kilo))
        return String(format: "%.2f km", km)
    }

    private func formatCalories(_ kcal: Double) -> String {
        guard kcal > 0 else { return "--" }
        return String(format: "%.0f kcal", kcal)
    }

    private func formatHeartRate(_ bpm: Double) -> String {
        guard bpm > 0 else { return "--" }
        return String(format: "%.0f bpm", bpm)
    }

    private func formatDate(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.dateFormat = "EEEE, MMMM d"
        return formatter.string(from: date)
    }

    private func formatTime(_ date: Date) -> String {
        let formatter = DateFormatter()
        formatter.timeStyle = .short
        return formatter.string(from: date)
    }

    private func secondsPerKmForSplit(_ split: (splitIndex: Int, duration: TimeInterval, avgHeartRate: Double?)) -> Double {
        split.duration
    }

    private func colorForPace(_ secondsPerKm: Double) -> Color {
        let avgPace = averagePacePerKm
        guard avgPace > 0 else { return .gray }

        let ratio = secondsPerKm / avgPace
        if ratio < 0.95 { return .green }
        if ratio > 1.05 { return .red }
        return .yellow
    }
}

// MARK: - HR Stat
private struct HRStat: View {
    let label: String
    let value: Int
    let color: Color
    let icon: String

    var body: some View {
        VStack(alignment: .leading, spacing: 3) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption)
            }
            .foregroundStyle(color)
            Text("\(value)")
                .font(.subheadline.weight(.semibold).monospacedDigit())
                .foregroundStyle(color)
        }
    }
}

// MARK: - Stat Card Component
private struct StatCard: View {
    let label: String
    let value: String
    let icon: String
    let iconColor: Color

    var body: some View {
        VStack(alignment: .leading, spacing: 6) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(iconColor.opacity(0.8))
            Text(value)
                .font(.system(size: 20, weight: .bold, design: .rounded))
                .monospacedDigit()
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 16))
    }
}

// MARK: - Colored Polyline
private class ColoredPolyline: MKPolyline {
    var color: UIColor = .systemBlue
}

// MARK: - Gradient Route Map (UIKit-backed for per-segment coloring)
private struct GradientRouteMap: UIViewRepresentable {
    let routeData: [(latitude: Double, longitude: Double, altitude: Double, timestamp: Date)]
    let splits: [(splitIndex: Int, duration: TimeInterval, avgHeartRate: Double?)]
    let overlayMode: ExpandedRouteMapView.RouteOverlay
    let routeColor: UIColor
    let isSatellite: Bool

    func makeUIView(context: Context) -> MKMapView {
        let map = MKMapView()
        map.delegate = context.coordinator
        map.showsCompass = true
        map.showsScale = true
        return map
    }

    func updateUIView(_ map: MKMapView, context: Context) {
        context.coordinator.parent = self
        map.removeOverlays(map.overlays)

        guard routeData.count >= 2 else { return }

        let coords = routeData.map { CLLocationCoordinate2D(latitude: $0.latitude, longitude: $0.longitude) }

        if overlayMode == .route {
            let polyline = MKPolyline(coordinates: coords, count: coords.count)
            map.addOverlay(polyline, level: .aboveRoads)
        } else {
            let segmentCount = min(splits.isEmpty ? 10 : splits.count, 20)
            let pointsPerSegment = max(coords.count / segmentCount, 2)
            for i in 0..<segmentCount {
                let start = i * pointsPerSegment
                let end = min(start + pointsPerSegment + 1, coords.count)
                guard end > start else { continue }
                let segCoords = Array(coords[start..<end])
                let polyline = ColoredPolyline(coordinates: segCoords, count: segCoords.count)
                if overlayMode == .pace {
                    polyline.color = paceColor(forSegment: i, of: segmentCount)
                } else {
                    polyline.color = elevationColor(forSegment: i, of: segmentCount)
                }
                map.addOverlay(polyline, level: .aboveRoads)
            }
        }

        if let first = coords.first, let last = coords.last {
            let startAnnotation = MKPointAnnotation()
            startAnnotation.coordinate = first
            startAnnotation.title = "Start"
            let endAnnotation = MKPointAnnotation()
            endAnnotation.coordinate = last
            endAnnotation.title = "Finish"
            map.removeAnnotations(map.annotations)
            map.addAnnotations([startAnnotation, endAnnotation])
        }

        map.preferredConfiguration = isSatellite
            ? MKImageryMapConfiguration(elevationStyle: .realistic)
            : MKStandardMapConfiguration(elevationStyle: .realistic, emphasisStyle: .default)
        (map.preferredConfiguration as? MKStandardMapConfiguration)?.pointOfInterestFilter = .excludingAll

        let rect = map.overlays.reduce(MKMapRect.null) { $0.union($1.boundingMapRect) }
        if !rect.isNull {
            map.setVisibleMapRect(rect, edgePadding: UIEdgeInsets(top: 80, left: 40, bottom: 160, right: 40), animated: false)
        }
    }

    private func paceColor(forSegment index: Int, of total: Int) -> UIColor {
        guard !splits.isEmpty else { return routeColor }
        let splitIndex = min(index * splits.count / max(total, 1), splits.count - 1)
        let avgPace = splits.map(\.duration).reduce(0, +) / Double(splits.count)
        guard avgPace > 0 else { return .systemYellow }
        let ratio = splits[splitIndex].duration / avgPace
        if ratio < 0.95 { return .systemGreen }
        if ratio > 1.05 { return .systemRed }
        return .systemYellow
    }

    private func elevationColor(forSegment index: Int, of total: Int) -> UIColor {
        guard !routeData.isEmpty, total > 0 else { return .systemGreen }
        let midPoint = min(index * routeData.count / total + routeData.count / (total * 2), routeData.count - 1)
        let alts = routeData.map(\.altitude)
        guard let minA = alts.min(), let maxA = alts.max(), maxA - minA > 0 else { return .systemGreen }
        let normalized = (routeData[midPoint].altitude - minA) / (maxA - minA)
        if normalized < 0.33 { return .systemGreen }
        if normalized < 0.66 { return .systemYellow }
        return .systemRed
    }

    func makeCoordinator() -> Coordinator { Coordinator(parent: self) }

    class Coordinator: NSObject, MKMapViewDelegate {
        var parent: GradientRouteMap

        init(parent: GradientRouteMap) { self.parent = parent }

        func mapView(_ mapView: MKMapView, rendererFor overlay: any MKOverlay) -> MKOverlayRenderer {
            if let colored = overlay as? ColoredPolyline {
                let renderer = MKPolylineRenderer(polyline: colored)
                renderer.strokeColor = colored.color
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            if let polyline = overlay as? MKPolyline {
                let renderer = MKPolylineRenderer(polyline: polyline)
                renderer.strokeColor = parent.routeColor
                renderer.lineWidth = 5
                renderer.lineCap = .round
                renderer.lineJoin = .round
                return renderer
            }
            return MKOverlayRenderer(overlay: overlay)
        }

        func mapView(_ mapView: MKMapView, viewFor annotation: any MKAnnotation) -> MKAnnotationView? {
            let id = "marker"
            let view = mapView.dequeueReusableAnnotationView(withIdentifier: id) ?? MKAnnotationView(annotation: annotation, reuseIdentifier: id)
            view.annotation = annotation

            let size: CGFloat = 14
            let circle = UIView(frame: CGRect(x: 0, y: 0, width: size, height: size))
            circle.layer.cornerRadius = size / 2
            circle.backgroundColor = annotation.title == "Start" ? .systemGreen : .systemRed
            circle.layer.borderColor = UIColor.white.cgColor
            circle.layer.borderWidth = 2

            view.subviews.forEach { $0.removeFromSuperview() }
            view.addSubview(circle)
            view.frame = circle.frame
            view.canShowCallout = false
            return view
        }
    }
}

// MARK: - Expanded Route Map
private struct ExpandedRouteMapView: View {
    let routeData: [(latitude: Double, longitude: Double, altitude: Double, timestamp: Date)]
    let splits: [(splitIndex: Int, duration: TimeInterval, avgHeartRate: Double?)]
    let routeColor: Color
    let workoutName: String
    let date: String
    let distance: String
    let duration: String
    let totalDistance: Double

    @Environment(\.dismiss) private var dismiss
    @State private var isSatellite = false
    @State private var overlayMode: RouteOverlay = .route

    enum RouteOverlay: String, CaseIterable {
        case route = "Route"
        case pace = "Pace"
        case elevation = "Elevation"
    }

    var body: some View {
        ZStack {
            GradientRouteMap(
                routeData: routeData,
                splits: splits,
                overlayMode: overlayMode,
                routeColor: UIColor(routeColor),
                isSatellite: isSatellite
            )
            .ignoresSafeArea()

            VStack(spacing: 0) {
                HStack {
                    Button { dismiss() } label: {
                        Image(systemName: "xmark")
                            .font(.body.weight(.semibold))
                            .foregroundStyle(.primary)
                            .frame(width: 40, height: 40)
                            .glassEffect(.regular, in: .circle)
                    }

                    Spacer()

                    VStack(alignment: .trailing, spacing: 2) {
                        Text(workoutName)
                            .font(.subheadline.weight(.semibold))
                        Text(date)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 14)
                    .padding(.vertical, 8)
                    .glassEffect(.regular, in: .capsule)
                }
                .padding(.horizontal, 16)
                .padding(.top, 60)

                Spacer()

                VStack(spacing: 10) {
                    if overlayMode != .route {
                        legendView
                            .transition(.move(edge: .bottom).combined(with: .opacity))
                    }

                    HStack(spacing: 16) {
                        VStack(spacing: 2) {
                            Text(distance)
                                .font(.subheadline.weight(.bold).monospacedDigit())
                            Text("Distance")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                        Divider().frame(height: 24)
                        VStack(spacing: 2) {
                            Text(duration)
                                .font(.subheadline.weight(.bold).monospacedDigit())
                            Text("Duration")
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                        }
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 10)
                    .glassEffect(.regular, in: .capsule)

                    HStack(spacing: 8) {
                        Picker("Overlay", selection: $overlayMode.animation(.easeInOut(duration: 0.25))) {
                            ForEach(RouteOverlay.allCases, id: \.self) { mode in
                                Text(mode.rawValue).tag(mode)
                            }
                        }
                        .pickerStyle(.segmented)

                        Button {
                            isSatellite.toggle()
                        } label: {
                            Image(systemName: isSatellite ? "globe.americas.fill" : "map")
                                .font(.body.weight(.medium))
                                .frame(width: 40, height: 32)
                                .glassEffect(.regular, in: .rect(cornerRadius: 8))
                        }
                    }
                    .padding(.horizontal, 16)
                }
                .padding(.bottom, 36)
            }
        }
    }

    private var legendView: some View {
        HStack(spacing: 12) {
            if overlayMode == .pace {
                LegendItem(color: .green, label: "Fast")
                LegendItem(color: .yellow, label: "Average")
                LegendItem(color: .red, label: "Slow")
            } else {
                LegendItem(color: .green, label: "Low")
                LegendItem(color: .yellow, label: "Mid")
                LegendItem(color: .red, label: "High")
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 8)
        .glassEffect(.regular, in: .capsule)
    }
}

private struct LegendItem: View {
    let color: Color
    let label: String

    var body: some View {
        HStack(spacing: 5) {
            RoundedRectangle(cornerRadius: 2)
                .fill(color)
                .frame(width: 14, height: 4)
            Text(label)
                .font(.caption2.weight(.medium))
                .foregroundStyle(.secondary)
        }
    }
}

#Preview {
    NavigationStack {
        let mockWorkout = HKWorkout(
            activityType: .traditionalStrengthTraining,
            start: Date().addingTimeInterval(-3600),
            end: Date(),
            duration: 3600,
            totalEnergyBurned: HKQuantity(unit: .kilocalorie(), doubleValue: 500),
            totalDistance: HKQuantity(unit: .meterUnit(with: .kilo), doubleValue: 10),
            device: nil,
            metadata: nil
        )
        WorkoutHistoryDetailView(workout: mockWorkout)
            .environment(HealthKitService())
    }
}
