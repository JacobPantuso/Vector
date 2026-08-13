import SwiftUI
import Charts
import TipKit

struct WorkoutDetailView: View {
    @State var workout: SavedWorkout
    let onStartWorkout: (ActiveWorkoutSession) -> Void
    let onWorkoutUpdated: ((SavedWorkout) -> Void)?

    init(workout: SavedWorkout, onStartWorkout: @escaping (ActiveWorkoutSession) -> Void, onWorkoutUpdated: ((SavedWorkout) -> Void)? = nil) {
        self._workout = State(initialValue: workout)
        self.onStartWorkout = onStartWorkout
        self.onWorkoutUpdated = onWorkoutUpdated
    }

    @Environment(\.dismiss) private var dismiss
    @State private var showingDeleteConfirm = false
    @State private var isEditing = false
    @State private var stepsExercise: ManualExerciseEntry?
    @State private var pickerRole: ExerciseRole?
    @State private var pendingSupersetID: UUID?
    @State private var showingProgressionApplied = false
    @State private var showingProgressionReview = false
    @State private var appliedChanges: [ProgressionChange] = []
    @FocusState private var titleFocused: Bool
    @FocusState private var focusFocused: Bool

    private let supersetDragTip = SupersetDragTip()

    private let titleCharLimit = 40

    private var totalVolume: Double {
        workout.exercises.reduce(0) { $0 + $1.totalVolumeKg }
    }

    private var formattedLastUpdated: String {
        workout.createdAt.formatted(date: .abbreviated, time: .omitted)
    }

    private var formattedVolume: String {
        if totalVolume >= 1000 {
            let formatter = NumberFormatter()
            formatter.numberStyle = .decimal
            formatter.maximumFractionDigits = 0
            let formatted = formatter.string(from: NSNumber(value: totalVolume)) ?? "\(Int(totalVolume))"
            return "\(formatted) lbs"
        } else if totalVolume > 0 {
            return String(format: "%.0f lbs", totalVolume)
        }
        return "-- lbs"
    }

    private var focusTags: [String] {
        let parts = workout.focus.split(separator: ",").map { $0.trimmingCharacters(in: .whitespaces) }
        guard parts.count > 1 else { return [] }
        return parts
    }

    private var intensityColor: Color {
        switch workout.effort {
        case 0...3: return .green
        case 4...6: return .orange
        case 7...9: return .red
        default: return .red
        }
    }

    private let tagColors: [Color] = [.cyan, .purple, .orange, .green, .pink, .yellow, .mint, .indigo]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 20) {
                    statsRow
                    progressionSection
                    exercisesSection
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 140)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle(isEditing ? "Edit Workout" : workout.title)
            .navigationSubtitle(isEditing ? "" : "Last updated on \(formattedLastUpdated)")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItemGroup(placement: .topBarTrailing) {
                    if !isEditing {
                        Menu {
                            Button {
                                withAnimation(.spring(duration: 0.35)) { isEditing = true }
                            } label: {
                                Label("Edit Workout", systemImage: "pencil")
                            }
                            Button(role: .destructive) { showingDeleteConfirm = true } label: {
                                Label("Delete Workout", systemImage: "trash")
                            }
                        } label: {
                            Image(systemName: "gear")
                                .font(.title3)
                                .foregroundStyle(.secondary)
                        }
                    }
                }
            }
            .safeAreaInset(edge: .bottom) {
                bottomBar
            }
            .confirmationDialog("Delete Workout?", isPresented: $showingDeleteConfirm, titleVisibility: .visible) {
                Button("Delete", role: .destructive) {
                    WorkoutStorageService.shared.delete(workout)
                    dismiss()
                }
                Button("Cancel", role: .cancel) {}
            } message: {
                Text("This cannot be undone.")
            }
            .vectorSheet(item: $stepsExercise, style: .half) { exercise in
                ExerciseStepsSheet(exercise: exercise)
            }
            .vectorSheet(item: $pickerRole) { role in
                ExercisePickerView(onAdd: { selected in
                    let updated = selected.map { var e = $0; e.role = role; return e }

                    if role == .warmup {
                        let insertIdx = workout.exercises.firstIndex { $0.resolvedRole == .main } ?? workout.exercises.count
                        workout.exercises.insert(contentsOf: updated, at: insertIdx)
                    } else if role == .cooldown {
                        workout.exercises.append(contentsOf: updated)
                    } else {
                        workout.exercises.append(contentsOf: updated)
                    }
                }, role: role)
            }
            .vectorSheet(isPresented: $showingProgressionApplied, style: .half) {
                ProgressionAppliedSheet(changes: appliedChanges)
                    .presentationDetents([.medium])
                    .presentationDragIndicator(.visible)
            }
            .vectorSheet(isPresented: $showingProgressionReview, style: .half) {
                ProgressionReviewSheet(
                    changes: pendingProgressionChanges,
                    headlines: progressionHeadlines
                ) { selected in
                    showingProgressionReview = false
                    // Wait for the review sheet to finish dismissing before
                    // presenting the applied confirmation sheet.
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.45) {
                        applyProgression(selected)
                    }
                }
                .presentationDetents([.medium])
                .presentationDragIndicator(.visible)
            }
        }
    }

    // MARK: - Focus Tags

    private var focusTagsView: some View {
        WorkoutFlowLayout(spacing: 8) {
            ForEach(Array(focusTags.enumerated()), id: \.offset) { idx, tag in
                let color = tagColors[idx % tagColors.count]
                Text(tag)
                    .font(.caption.weight(.semibold))
                    .padding(.horizontal, 10)
                    .padding(.vertical, 5)
                    .background(color.opacity(0.15))
                    .foregroundStyle(color)
                    .clipShape(Capsule())
            }
        }
    }

    // MARK: - Effort Bar (display)

    private var effortBar: some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack {
                Text("Intensity")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(workout.effort)/10")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(intensityColor)
            }
            GeometryReader { geo in
                RoundedRectangle(cornerRadius: 3)
                    .fill(.white.opacity(0.1))
                    .overlay(alignment: .leading) {
                        RoundedRectangle(cornerRadius: 3)
                            .fill(intensityColor.gradient)
                            .frame(width: geo.size.width * CGFloat(workout.effort) / 10)
                    }
            }
            .frame(height: 4)
        }
    }

    // MARK: - Effort Editor (edit mode)

    private var effortEditor: some View {
        VStack(spacing: 8) {
            HStack {
                Label("Effort", systemImage: "flame")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                Text("\(workout.effort)/10")
                    .font(.subheadline.bold().monospacedDigit())
                    .foregroundStyle(intensityColor)
            }
            Slider(value: Binding(
                get: { Double(workout.effort) },
                set: { workout.effort = Int($0) }
            ), in: 1...10, step: 1)
            .tint(.orange)
        }
    }

    // MARK: - Progression

    private var completions: [WorkoutCompletionRecord] {
        WorkoutCompletionStore.shared.completions(for: workout.id)
    }

    private var pendingProgressionChanges: [ProgressionChange] {
        workout.exercises.compactMap { ex in
            guard let insight = ProgressionAdvisor.insight(for: ex),
                  insight.hasSuggestion,
                  let newWeight = insight.suggestedWeightKg else { return nil }
            let old = ex.topSetWeightKg ?? (ex.weightKg ?? 0)
            guard abs(newWeight - old) > 0.01 else { return nil }
            return ProgressionChange(id: ex.id, name: ex.name, oldWeightKg: old, newWeightKg: newWeight)
        }
    }

    /// Advisor headlines keyed by exercise ID, for the review sheet.
    private var progressionHeadlines: [UUID: String] {
        var result: [UUID: String] = [:]
        for ex in workout.exercises {
            if let insight = ProgressionAdvisor.insight(for: ex) {
                result[ex.id] = insight.headline
            }
        }
        return result
    }

    private func applyProgression(_ changes: [ProgressionChange]) {
        guard !changes.isEmpty else { return }
        for change in changes {
            guard let idx = workout.exercises.firstIndex(where: { $0.id == change.id }) else { continue }
            let delta = change.newWeightKg - change.oldWeightKg
            if let details = workout.exercises[idx].setDetails, !details.isEmpty {
                // Shift every set by the same delta to preserve the per-set spread.
                let bumped = details.map { SetDetail(weightKg: ($0.weightKg ?? 0) + delta, reps: $0.reps) }
                workout.exercises[idx].setDetails = bumped
                workout.exercises[idx].weightKg = bumped.compactMap { $0.weightKg }.max()
            } else {
                workout.exercises[idx].weightKg = change.newWeightKg
            }
        }
        WorkoutStorageService.shared.save(workout)
        onWorkoutUpdated?(workout)
        appliedChanges = changes
        showingProgressionApplied = true
    }

    private var volumeYDomain: ClosedRange<Double> {
        let values = completions.map(\.totalVolume)
        guard let minV = values.min(), let maxV = values.max(), maxV > 0 else { return 0...1 }
        let spread = maxV - minV
        let padBelow = spread > 0 ? spread * 0.25 : maxV * 0.05
        let padAbove = spread > 0 ? spread * 0.20 : maxV * 0.05
        let lower = max(0, ((minV - padBelow) / 250).rounded(.down) * 250)
        let upper = max(lower + 250, ((maxV + padAbove) / 250).rounded(.up) * 250)
        return lower...upper
    }

    /// Y-axis labels sized to the visible range rather than the raw magnitude.
    /// A template creeping from 12,180 to 12,550 lbs sits entirely inside one
    /// thousand, so a flat `Int(v / 1000)` renders every tick as "12k".
    private func volumeAxisLabel(_ v: Double) -> String {
        guard v >= 1000 else { return "\(Int(v))" }
        let span = volumeYDomain.upperBound - volumeYDomain.lowerBound
        if span >= 20000 { return "\(Int(v / 1000))k" }
        if span >= 2000 { return String(format: "%.1fk", v / 1000) }
        return v.formatted(.number.precision(.fractionLength(0)))
    }

    private var volumeTrend: (text: String, icon: String, color: Color)? {
        guard let first = completions.first?.totalVolume,
              let last = completions.last?.totalVolume,
              first > 0 else { return nil }
        let pct = (last - first) / first * 100
        if pct > 1 {
            return (String(format: "+%.0f%%", pct), "arrow.up.right", .green)
        } else if pct < -1 {
            return (String(format: "%.0f%%", pct), "arrow.down.right", .orange)
        } else {
            return ("Stable", "arrow.right", .secondary)
        }
    }

    private var progressionSection: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Progression")
                .font(.title3.bold())

            if completions.count >= 2 {
                GlassCard(tint: .green.opacity(0.15), cornerRadius: 20) {
                    VStack(alignment: .leading, spacing: 10) {
                        HStack {
                            Text("Total Volume")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Spacer()
                            if let trend = volumeTrend {
                                Label(trend.text, systemImage: trend.icon)
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(trend.color)
                            }
                        }
                        progressionChart
                            .frame(height: 180)
                    }
                }
            } else {
                ZStack {
                    progressionPlaceholderChart
                        .opacity(0.35)
                        .blur(radius: 6)
                    VStack(spacing: 10) {
                        Image(systemName: "chart.line.uptrend.xyaxis")
                            .font(.system(size: 32))
                            .foregroundStyle(.secondary)
                        Text("Not Enough Data")
                            .font(.headline)
                            .foregroundStyle(.primary)
                        Text("Complete this workout at least twice to track your progressive overload")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding()
                }
                .frame(maxWidth: .infinity)
                .frame(height: 200)
                .glassEffect(in: .rect(cornerRadius: 20))
            }

            if !pendingProgressionChanges.isEmpty {
                applyProgressionCard
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
    }

    private var applyProgressionCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "sparkles")
                .font(.title2)
                .foregroundStyle(
                    LinearGradient(colors: [.indigo, .indigo.opacity(0.8)], startPoint: .topLeading, endPoint: .bottomTrailing)
                )

            VStack(alignment: .leading, spacing: 3) {
                Text("Progressive Overload")
                    .font(.subheadline.weight(.semibold))
                Text(pendingProgressionChanges.count == 1
                     ? "Apply progression to 1 exercise?"
                     : "Apply progression to \(pendingProgressionChanges.count) exercises?")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()

            Button {
                showingProgressionReview = true
            } label: {
                Image(systemName: "magnifyingglass")
                    .font(.headline)
            }
            .buttonStyle(.glassProminent)
            .tint(.indigo)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
        .overlay {
            RoundedRectangle(cornerRadius: 20)
                .strokeBorder(Color.indigo.opacity(0.18), lineWidth: 1)
        }
        .shadow(color: .indigo.opacity(0.15), radius: 10)
        .padding(.top, 20)
    }

    private var volumeXDomain: ClosedRange<Date> {
        guard let minDate = completions.map(\.date).min(),
              let maxDate = completions.map(\.date).max() else {
            let now = Date()
            return now...now
        }
        let timespan = maxDate.timeIntervalSince(minDate)
        let leadingPad = timespan == 0 ? (12 * 3600) : (timespan * 0.08)
        let trailingPad = timespan == 0 ? (12 * 3600) : (timespan * 0.16)
        return Date(timeInterval: -leadingPad, since: minDate)...Date(timeInterval: trailingPad, since: maxDate)
    }

    private var progressionChart: some View {
        Chart(completions, id: \.id) { record in
            AreaMark(
                x: .value("Date", record.date),
                yStart: .value("Base", volumeYDomain.lowerBound),
                yEnd: .value("Volume", record.totalVolume)
            )
            .foregroundStyle(
                LinearGradient(
                    stops: [
                        .init(color: .green.opacity(0.32), location: 0.0),
                        .init(color: .green.opacity(0.18), location: 0.45),
                        .init(color: .green.opacity(0.0), location: 0.90)
                    ],
                    startPoint: .top,
                    endPoint: .bottom
                )
            )
            .interpolationMethod(.monotone)

            LineMark(
                x: .value("Date", record.date),
                y: .value("Volume", record.totalVolume)
            )
            .foregroundStyle(Color.green.gradient)
            .interpolationMethod(.monotone)
            .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            PointMark(
                x: .value("Date", record.date),
                y: .value("Volume", record.totalVolume)
            )
            .symbolSize(60)
            .symbol {
                Circle()
                    .fill(Color.green)
                    .frame(width: 8, height: 8)
                    .overlay(Circle().strokeBorder(.background, lineWidth: 1.5))
            }
        }
        .chartXScale(domain: volumeXDomain)
        .chartYScale(domain: volumeYDomain)
        .chartXAxis(.hidden)
        .chartOverlay { proxy in
            GeometryReader { geo in
                if let plotFrame = proxy.plotFrame {
                    let rect = geo[plotFrame]
                    ForEach(completions, id: \.id) { record in
                        if let x = proxy.position(forX: record.date) {
                            Text(record.date.formatted(.dateTime.month(.abbreviated).day()))
                                .font(.caption2)
                                .foregroundStyle(.secondary)
                                .fixedSize()
                                .position(x: rect.minX + x, y: rect.maxY - 6)
                        }
                    }
                }
            }
        }
        .chartYAxis {
            AxisMarks(position: .trailing, values: .automatic(desiredCount: 4)) { value in
                AxisGridLine(stroke: StrokeStyle(lineWidth: 0.5, dash: [3, 3]))
                AxisValueLabel {
                    if let v = value.as(Double.self) {
                        Text(volumeAxisLabel(v))
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .chartPlotStyle { $0.padding(.horizontal, 4).padding(.vertical, 8).clipped() }
    }

    private var progressionPlaceholderChart: some View {
        Chart {
            ForEach(Array([0.3, 0.45, 0.4, 0.6, 0.7, 0.85].enumerated()), id: \.offset) { i, v in
                AreaMark(x: .value("Session", i + 1), y: .value("Volume", v))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(
                        LinearGradient(
                            colors: [.green.opacity(0.3), .green.opacity(0.02)],
                            startPoint: .top,
                            endPoint: .bottom
                        )
                    )
                LineMark(x: .value("Session", i + 1), y: .value("Volume", v))
                    .interpolationMethod(.catmullRom)
                    .foregroundStyle(Color.green.gradient)
            }
        }
        .chartXAxis(.hidden)
        .chartYAxis(.hidden)
        .padding()
    }

    // MARK: - Stats Row

    private var statsRow: some View {
        VStack(alignment: .leading) {
            Text("Workout Summary")
                .font(.title3.bold())
                .padding(.bottom, 14)
            HStack(spacing: 12) {
                statCard(icon: "clock", value: "\(workout.durationMinutes)m", label: "Duration", tint: .cyan)
                statCard(icon: "dumbbell", value: "\(workout.exercises.count)", label: "Exercises", tint: .purple)
                statCard(icon: "scalemass", value: formattedVolume, label: "Volume", tint: .green)
            }
        }
        .padding(.top, 12)
    }

    private func statCard(icon: String, value: String, label: String, tint: Color) -> some View {
        GlassCard(tint: tint.opacity(0.12), cornerRadius: 18) {
            VStack(spacing: 6) {
                Image(systemName: icon)
                    .font(.caption)
                    .foregroundStyle(tint)
                Text(value)
                    .font(.headline.monospacedDigit())
                    .lineLimit(1)
                    .minimumScaleFactor(0.7)
                Text(label)
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }
            .frame(maxWidth: .infinity, minHeight: 80)
        }
    }

    // MARK: - Exercises Section

    private var exercisesSection: some View {
        let warmups = workout.exercises.filter { $0.resolvedRole == .warmup }
        let mains = workout.exercises.filter { $0.resolvedRole == .main }
        let cooldowns = workout.exercises.filter { $0.resolvedRole == .cooldown }

        return VStack(alignment: .leading, spacing: 14) {
            Text("Exercises")
                .font(.title3.bold())

            // Warm-Up section
            if !warmups.isEmpty {
                exerciseSection(warmups, title: "Warm-Up")
            } else if isEditing {
                addButton(label: "Add Warm-Up", role: .warmup)
            }

            // Main exercises section
            if !mains.isEmpty  {
                exerciseSection(mains, title: "Main", showsTitle: !(warmups.isEmpty && cooldowns.isEmpty))
            } else if isEditing {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No exercises yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button { pickerRole = .main } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassEffect(in: .rect(cornerRadius: 20))
            }

            // Cool-Down section
            if !cooldowns.isEmpty {
                exerciseSection(cooldowns, title: "Cool-Down")
            } else if isEditing {
                addButton(label: "Add Cool-Down", role: .cooldown)
            }
        }
    }

    private func exerciseSection(_ exs: [ManualExerciseEntry], title: String, showsTitle: Bool = true) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            if showsTitle {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            ForEach(exs, id: \.id) { exercise in
                exerciseCardWithConnector(exercise)
            }
        }
    }

    private func addButton(label: String, role: ExerciseRole) -> some View {
        Button {
            pickerRole = role
        } label: {
            HStack(spacing: 8) {
                Image(systemName: "plus")
                    .font(.caption)
                Text(label)
                    .font(.caption.weight(.semibold))
            }
            .foregroundStyle(.cyan)
            .frame(maxWidth: .infinity, alignment: .center)
            .padding(.vertical, 12)
        }
        .buttonStyle(.plain)
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    private func exerciseCardWithConnector(_ exercise: ManualExerciseEntry) -> some View {
        VStack(spacing: 0) {
            exerciseCard(exercise)

            // Superset connector after exercise
            let exs = workout.exercises
            if let idx = exs.firstIndex(where: { $0.id == exercise.id }), idx < exs.count - 1 {
                let nextExercise = exs[idx + 1]
                let sameSuperset = exercise.supersetID != nil && exercise.supersetID == nextExercise.supersetID

            }
        }
    }

    private func exerciseCard(_ exercise: ManualExerciseEntry) -> some View {
        let card = VStack(spacing: 0) {
            HStack(spacing: 10) {
                if isEditing {
                    Image(systemName: "line.3.horizontal")
                        .foregroundStyle(.secondary)
                        .frame(width: 20)
                }

                VStack(alignment: .leading, spacing: 3) {
                    HStack(spacing: 6) {
                        Text(exercise.name)
                            .font(.subheadline.weight(.semibold))
                            .lineLimit(1)

                        if exercise.supersetID != nil {
                            Text("SUPERSET")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.purple)
                                .padding(.horizontal, 6)
                                .padding(.vertical, 2)
                                .background(.purple.opacity(0.15))
                                .clipShape(Capsule())
                        }
                    }
                }

                Spacer()

                if isEditing {
                    Button {
                        if exercise.supersetID == nil {
                            makeSuperset(id: exercise.id)
                        } else {
                            removeFromSuperset(id: exercise.id)
                        }
                    } label: {
                        Image(systemName: exercise.supersetID == nil ? "link" : "link.slash")
                            .font(.subheadline)
                            .foregroundStyle(exercise.supersetID == nil ? AnyShapeStyle(.secondary) : AnyShapeStyle(Color.purple))
                    }
                    .buttonStyle(.plain)

                    Button(role: .destructive) {
                        deleteExercise(id: exercise.id)
                    } label: {
                        Image(systemName: "trash")
                            .font(.subheadline)
                            .foregroundStyle(.red)
                    }
                    .buttonStyle(.plain)
                } else {
                    Button {
                        stepsExercise = exercise
                    } label: {
                        Image(systemName: "info.circle")
                            .font(.callout)
                            .foregroundStyle(.cyan)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.vertical, 12)
            .padding(.horizontal, 14)

            if isEditing {
                Divider()
                InlineSetEditor(entry: Binding(
                    get: { exercise },
                    set: { updated in
                        if let idx = workout.exercises.firstIndex(where: { $0.id == exercise.id }) {
                            workout.exercises[idx] = updated
                        }
                    }
                ))
            } else {
                if exercise.inputType == .reps {
                    PerSetBreakdownView(exercise: exercise)
                        .padding(.horizontal, 14)
                        .padding(.vertical, 10)
                }

                if exercise.supersetID != nil, exercise.supersetID == pendingSupersetID {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.to.line")
                        Text("Drag an exercise on top to combine")
                    }
                    .font(.caption2)
                    .foregroundStyle(.purple)
                    .padding(.horizontal, 14)
                    .padding(.vertical, 10)
                }
            }
        }
        .glassEffect(.regular, in: RoundedRectangle(cornerRadius: 16))
        .overlay(alignment: .leading) {
            if exercise.supersetID != nil {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.purple)
                    .frame(width: 3)
                    .padding(.vertical, 8)
            }
        }
        .overlay {
            if isEditing, pendingSupersetID != nil, exercise.supersetID == pendingSupersetID {
                RoundedRectangle(cornerRadius: 16)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(.purple.opacity(0.6))
            }
        }

        if isEditing {
            if pendingSupersetID != nil, exercise.supersetID == pendingSupersetID {
                return AnyView(
                    card
                        .draggable(exercise.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            handleDrop(draggedID: items.first, onto: exercise.id)
                            return true
                        }
                        .popoverTip(supersetDragTip)
                        .askVector(topicForExercise(exercise))
                )
            } else {
                return AnyView(
                    card
                        .draggable(exercise.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            handleDrop(draggedID: items.first, onto: exercise.id)
                            return true
                        }
                        .askVector(topicForExercise(exercise))
                )
            }
        } else {
            return AnyView(card.askVector(topicForExercise(exercise)))
        }
    }


    // MARK: - Advisor Topics

    private func topicForExercise(_ exercise: ManualExerciseEntry) -> AdvisorTopic {
        var context = ["Exercise: \(exercise.name)"]
        context.append("Sets: \(exercise.sets), Reps: \(exercise.reps)")
        if let weight = exercise.weightKg, weight > 0 {
            context.append("Weight: \(Int(weight)) kg")
        }
        if let insight = ProgressionAdvisor.insight(for: exercise), insight.hasSuggestion {
            context.append("Progression: \(insight.headline)")
        }
        return AdvisorTopic(
            title: exercise.name,
            icon: "figure.strengthtraining.traditional",
            tintName: "orange",
            contextLines: context,
            suggestedPrompt: "Should I increase the weight on \(exercise.name)? What does my progression look like?"
        )
    }

    // MARK: - Superset Management

    private func handleDrop(draggedID: String?, onto targetID: UUID) {
        guard let draggedID, let draggedUUID = UUID(uuidString: draggedID),
              draggedUUID != targetID,
              let from = workout.exercises.firstIndex(where: { $0.id == draggedUUID }),
              let toIdx = workout.exercises.firstIndex(where: { $0.id == targetID }) else { return }
        let target = workout.exercises[toIdx]
        withAnimation(.spring(duration: 0.3)) {
            if let sid = target.supersetID {
                // Drop onto a superset → join it
                var item = workout.exercises.remove(at: from)
                item.supersetID = sid
                let insertIdx = (workout.exercises.firstIndex(where: { $0.id == targetID }) ?? 0) + 1
                workout.exercises.insert(item, at: insertIdx)
                if sid == pendingSupersetID { pendingSupersetID = nil }
                supersetDragTip.invalidate(reason: .actionPerformed)
            } else {
                // Drop onto a normal exercise → reorder before it
                let item = workout.exercises.remove(at: from)
                let insertAt = toIdx > from ? toIdx - 1 : toIdx
                workout.exercises.insert(item, at: insertAt)
            }
            normalizeSupersets()
        }
    }

    private func makeSuperset(id: UUID) {
        guard let i = workout.exercises.firstIndex(where: { $0.id == id }) else { return }
        let newID = UUID()
        withAnimation(.spring(duration: 0.3)) {
            workout.exercises[i].supersetID = newID
            pendingSupersetID = newID
        }
    }

    private func deleteExercise(id: UUID) {
        withAnimation(.spring(duration: 0.3)) {
            workout.exercises.removeAll { $0.id == id }
            normalizeSupersets()
        }
    }

    private func removeFromSuperset(id: UUID) {
        guard let i = workout.exercises.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(duration: 0.3)) {
            workout.exercises[i].supersetID = nil
            normalizeSupersets()
        }
    }

    private func normalizeSupersets() {
        for group in workout.exercises.groupedBySuperset() where !group.isSuperset {
            if let only = group.entries.first,
               only.supersetID != pendingSupersetID,
               let i = workout.exercises.firstIndex(where: { $0.id == only.id }) {
                workout.exercises[i].supersetID = nil
            }
        }
    }

    // MARK: - Bottom Bar

    private var bottomBar: some View {
        VStack(spacing: 0) {
            if isEditing {
                HStack(spacing: 12) {
                    Button {
                        pickerRole = .main
                    } label: {
                        Label("Add Exercise", systemImage: "plus")
                            .font(.headline)
                            .padding(.vertical, 14)
                            .padding(.horizontal, 18)
                    }
                    .buttonStyle(.glass)

                    Button {
                        pendingSupersetID = nil
                        normalizeSupersets()
                        WorkoutStorageService.shared.save(workout)
                        onWorkoutUpdated?(workout)
                        withAnimation(.spring(duration: 0.35)) {
                            isEditing = false
                        }
                    } label: {
                        Label("Save Changes", systemImage: "checkmark.circle.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glassProminent)
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            } else {
                Button {
                    let session = ActiveWorkoutSession(workout: workout)
                    dismiss()
                    onStartWorkout(session)
                } label: {
                    Label("Start Workout", systemImage: "play.fill")
                        .font(.headline)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 14)
                }
                .buttonStyle(.glassProminent)
                .padding(.horizontal, 20)
                .padding(.bottom, 8)
            }
        }
        .background(
            LinearGradient(
                colors: [.clear, .black.opacity(0.3), .black.opacity(0.5)],
                startPoint: .top,
                endPoint: .bottom
            )
            .ignoresSafeArea()
        )
        // Slide the bar out of the way while the progression review sheet is up.
        .opacity(showingProgressionReview ? 0 : 1)
        .offset(y: showingProgressionReview ? 80 : 0)
        .animation(.spring(duration: 0.25), value: showingProgressionReview)
        .sensoryFeedback(.success, trigger: showingProgressionApplied)
    }
}

// MARK: - Flow Layout

private struct WorkoutFlowLayout: Layout {
    var spacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalSize: CGSize = .zero

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + spacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + spacing
            totalSize.width = max(totalSize.width, currentX - spacing)
        }

        totalSize.height = currentY + lineHeight
        return LayoutResult(size: totalSize, positions: positions)
    }
}

// MARK: - Exercise Steps Sheet

private struct ExerciseStepsSheet: View {
    let exercise: ManualExerciseEntry
    @Environment(\.dismiss) private var dismiss

    private var steps: [String] {
        ExerciseLibrary.shared.allExercises
            .first { $0.id == exercise.libraryExerciseId }?.steps ?? []
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(alignment: .leading, spacing: 16) {
                    if steps.isEmpty {
                        Text(exercise.notes.isEmpty ? "No steps available for this exercise." : exercise.notes)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .frame(maxWidth: .infinity, alignment: .leading)
                    } else {
                        ForEach(Array(steps.enumerated()), id: \.offset) { idx, step in
                            HStack(alignment: .top, spacing: 12) {
                                ZStack {
                                    Circle()
                                        .fill(Color.cyan.opacity(0.2))
                                        .frame(width: 26, height: 26)
                                    Text("\(idx + 1)")
                                        .font(.caption.bold())
                                        .foregroundStyle(.cyan)
                                }
                                Text(step)
                                    .font(.subheadline)
                                    .frame(maxWidth: .infinity, alignment: .leading)
                            }
                        }
                    }
                }
                .padding(20)
            }
            .navigationTitle(exercise.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .presentationDetents([.medium, .large])
            .presentationDragIndicator(.visible)
        }
    }
}

// MARK: - Progression Applied

struct ProgressionChange: Identifiable {
    let id: UUID
    let name: String
    let oldWeightKg: Double
    let newWeightKg: Double
    var deltaKg: Double { newWeightKg - oldWeightKg }
}

private struct ProgressionAppliedSheet: View {
    let changes: [ProgressionChange]
    @Environment(\.dismiss) private var dismiss

    private func fmt(_ kg: Double) -> String {
        kg.rounded() == kg ? String(format: "%.0f", kg) : String(format: "%.1f", kg)
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    VStack(spacing: 10) {
                        Image(systemName: "sparkles")
                            .font(.system(size: 40))
                            .foregroundStyle(
                                LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                            )
                        Text("Progression Applied")
                            .font(.title3.bold())
                        Text(changes.count == 1
                             ? "Updated 1 exercise based on your recent performance."
                             : "Updated \(changes.count) exercises based on your recent performance.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                    }
                    .padding(.top, 12)

                    VStack(spacing: 10) {
                        ForEach(changes) { change in
                            HStack(spacing: 12) {
                                Image(systemName: "arrow.up.forward.circle.fill")
                                    .font(.title3)
                                    .foregroundStyle(.green)
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(change.name)
                                        .font(.subheadline.weight(.semibold))
                                        .lineLimit(1)
                                    HStack(spacing: 6) {
                                        Text("\(fmt(change.oldWeightKg)) lb")
                                            .foregroundStyle(.secondary)
                                        Image(systemName: "arrow.right")
                                            .font(.caption2)
                                            .foregroundStyle(.tertiary)
                                        Text("\(fmt(change.newWeightKg)) lb")
                                            .foregroundStyle(.primary)
                                            .fontWeight(.semibold)
                                    }
                                    .font(.caption)
                                }
                                Spacer()
                                Text("+\(fmt(change.deltaKg))")
                                    .font(.caption.weight(.bold))
                                    .foregroundStyle(.green)
                                    .padding(.horizontal, 8)
                                    .padding(.vertical, 3)
                                    .background(Color.green.opacity(0.15))
                                    .clipShape(Capsule())
                            }
                            .padding(.horizontal, 14)
                            .padding(.vertical, 12)
                            .glassEffect(in: .rect(cornerRadius: 14))
                        }
                    }
                }
                .padding(20)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle("Progression")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
        }
    }
}

#if DEBUG
#Preview {
    let bench = ManualExerciseEntry(name: "Barbell Bench Press", sets: 4, reps: 8, durationSeconds: 0, inputType: .reps, weightKg: 135, restSeconds: 90, notes: "")
    let curl = ManualExerciseEntry(name: "Dumbbell Curl", sets: 3, reps: 12, durationSeconds: 0, inputType: .reps, weightKg: 30, restSeconds: 75, notes: "")
    let pushdown = ManualExerciseEntry(name: "Tricep Pushdown", sets: 3, reps: 12, durationSeconds: 0, inputType: .reps, weightKg: 50, restSeconds: 75, notes: "")
    let plank = ManualExerciseEntry(name: "Plank", sets: 3, reps: 0, durationSeconds: 45, inputType: .duration, weightKg: nil, restSeconds: 60, notes: "")

    let workout = SavedWorkout(
        title: "Upper Body Strength",
        focus: "Chest, Shoulders, Arms",
        source: .manual,
        aiPlan: nil,
        exercises: [bench, curl, pushdown, plank],
        durationMinutes: 50,
        effort: 7
    )

    ExerciseProgressionStore.shared.seedPreview([
        "barbell bench press": [
            ExercisePerformance(weightKg: 125, reps: 8, targetReps: 8, date: Date().addingTimeInterval(-86400 * 14)),
            ExercisePerformance(weightKg: 130, reps: 8, targetReps: 8, date: Date().addingTimeInterval(-86400 * 7)),
            ExercisePerformance(weightKg: 135, reps: 8, targetReps: 8, date: Date().addingTimeInterval(-86400 * 2))
        ],
        "dumbbell curl": [
            ExercisePerformance(weightKg: 30, reps: 10, targetReps: 12, date: Date().addingTimeInterval(-86400 * 3))
        ],
        "tricep pushdown": [
            ExercisePerformance(weightKg: 50, reps: 12, targetReps: 12, date: Date().addingTimeInterval(-86400 * 9)),
            ExercisePerformance(weightKg: 50, reps: 12, targetReps: 12, date: Date().addingTimeInterval(-86400 * 5)),
            ExercisePerformance(weightKg: 50, reps: 12, targetReps: 12, date: Date().addingTimeInterval(-86400 * 2))
        ]
    ])

    WorkoutCompletionStore.shared.seedPreview([
        WorkoutCompletionRecord(templateID: workout.id, date: Date().addingTimeInterval(-86400 * 21), totalVolume: 8200, durationMinutes: 48),
        WorkoutCompletionRecord(templateID: workout.id, date: Date().addingTimeInterval(-86400 * 14), totalVolume: 8650, durationMinutes: 49),
        WorkoutCompletionRecord(templateID: workout.id, date: Date().addingTimeInterval(-86400 * 7), totalVolume: 9100, durationMinutes: 51),
        WorkoutCompletionRecord(templateID: workout.id, date: Date().addingTimeInterval(-86400 * 2), totalVolume: 9600, durationMinutes: 50)
    ])

    

    return Color.black.opacity(0.001)
        .ignoresSafeArea()
        .vectorSheet(isPresented: .constant(true)) {
            WorkoutDetailView(workout: workout, onStartWorkout: { _ in })
        }
}
#endif

// MARK: - Edit Mode Tips

struct WorkoutEditMenuTip: Tip {
    var title: Text { Text("Customize an Exercise") }
    var message: Text? { Text("Tap the menu to edit sets and weight, build a superset, or remove it.") }
    var image: Image? { Image(systemName: "ellipsis.circle") }
}

struct SupersetDragTip: Tip {
    var title: Text { Text("Build a Superset") }
    var message: Text? { Text("Now drag another exercise on top of this one to group them with no rest between sets.") }
    var image: Image? { Image(systemName: "link") }
}
