import SwiftUI

extension ActiveWorkoutView {

    // MARK: - Paused Overlay

    @ViewBuilder
    var pausedOverlay: some View {
        if isPaused {
            ZStack {
                Rectangle()
                    .fill(.ultraThinMaterial)
                    .ignoresSafeArea()

                VStack(spacing: 28) {
                    Image(systemName: "pause.circle.fill")
                        .font(.system(size: 72))
                        .foregroundStyle(.secondary)
                        .symbolEffect(.pulse)

                    VStack(spacing: 8) {
                        Text("Workout Paused")
                            .font(.system(size: 28, weight: .bold))
                        Text(elapsedFormatted)
                            .font(.title3.weight(.semibold).monospacedDigit())
                            .foregroundStyle(.secondary)
                    }

                    Button {
                        withAnimation(.spring(duration: 0.3)) { isPaused = false }
                    } label: {
                        Label("Resume", systemImage: "play.fill")
                            .font(.headline)
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 14)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(.green)
                    .padding(.horizontal, 50)
                }
            }
            .transition(.opacity)
        }
    }

    // MARK: - Hero Section (Heart Rate)

    var heroSection: some View {
        ZStack {
            // Pulsing glow ring
            Circle()
                .stroke(phaseColor.opacity(0.3), lineWidth: 2)
                .frame(width: 220, height: 220)
                .scaleEffect(pulse ? 1.05 : 0.97)
                .animation(.easeInOut(duration: 0.95).repeatForever(autoreverses: true), value: pulse)

            // Rest progress ring (if resting)
            if session.isResting {
                ZStack {
                    Circle()
                        .stroke(.blue.opacity(0.2), lineWidth: 6)
                    Circle()
                        .trim(from: 0, to: restProgress)
                        .stroke(.blue.gradient, style: StrokeStyle(lineWidth: 6, lineCap: .round))
                        .rotationEffect(.degrees(-90))
                        .animation(.linear(duration: 1), value: restProgress)
                }
                .frame(width: 200, height: 200)
            } else {
                // Set phase ring
                Circle()
                    .stroke(.red.opacity(0.2), lineWidth: 4)
                    .frame(width: 200, height: 200)
            }

            // Center content
            VStack(spacing: 8) {
                Image(systemName: "heart.fill")
                    .font(.system(size: 18))
                    .foregroundStyle(phaseColor)

                Text(watchSync.liveWatchHeartRate > 0 ? "\(Int(watchSync.liveWatchHeartRate))" : "--")
                    .font(.system(size: 48, weight: .bold, design: .default).monospacedDigit())
                    .foregroundStyle(phaseColor)

                Text("BPM")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)

                if session.isResting {
                    Text("\(session.restSecondsRemaining)s")
                        .font(.system(size: 20, weight: .semibold).monospacedDigit())
                        .foregroundStyle(.blue)
                        .padding(.top, 4)
                }
            }
        }
        .frame(height: 240)
        .padding(.vertical, 12)
    }

    // MARK: - Current Exercise Block

    var currentExerciseBlock: some View {
        VStack(spacing: 12) {
            if let exercise = session.currentExercise {
                // Superset header (if applicable)
                if session.isInSuperset {
                    HStack() {
                        Image(systemName: "link.circle.fill")
                            .font(.title)
                            .foregroundStyle(.purple)
                        VStack(alignment: .leading) {
                            Text("Superset")
                                .font(.headline.weight(.bold))
                                .foregroundStyle(.purple)
                            Text("Up Next - \(session.upNextExercise?.name ?? "Rest")")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Spacer()
                    }
                    Divider()
                }

                // Name + set info on the left, complete button on the right
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 8) {
                        // Exercise name
                        Text(exercise.name)
                            .font(.title2.weight(.bold))
                            .multilineTextAlignment(.leading)

                        // Set dots
                        HStack(spacing: 5) {
                            let count = session.isInSuperset ? session.currentGroupRounds : exercise.sets
                            ForEach(0..<count, id: \.self) { idx in
                                let isDone = session.isSetDone(exercise.id, idx)
                                RoundedRectangle(cornerRadius: 13)
                                    .fill(isDone
                                          ? Color.green
                                          : (idx == session.currentSetIndex ? Color.cyan : Color.gray.opacity(0.2)))
                                    .frame(width: 20, height: 8)
                                    .animation(.spring(duration: 0.3), value: session.currentSetIndex)
                                    .animation(.spring(duration: 0.3), value: session.completedSetIndices)
                            }
                        }
                    }
                    .frame(maxWidth: .infinity, alignment: .leading)

                    // Context-aware action button (complete / skip rest / start duration)
                    exerciseActionButton
                }
            }
            loggedWeightSection
                .padding(.vertical, 10)
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 16)
        .padding(.vertical, 16)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    @ViewBuilder
    var exerciseActionButton: some View {
        if session.isResting {
            // Skip the current rest period
            actionCircle(systemImage: "forward.fill", tint: .blue) {
                withAnimation(.spring(duration: 0.2)) { skipRest() }
            }
        } else if session.currentExercise?.inputType == .duration {
            if session.isExerciseTimerRunning {
                // Timer running — checkmark completes the set
                actionCircle(systemImage: "checkmark", tint: phaseColor) {
                    withAnimation(.spring(duration: 0.4)) { completeSet() }
                }
            } else {
                // Start the duration countdown
                actionCircle(systemImage: "play.fill", tint: phaseColor) {
                    withAnimation(.spring(duration: 0.3)) { startExerciseTimer() }
                }
            }
        } else {
            // Complete the current set
            actionCircle(systemImage: "checkmark", tint: phaseColor) {
                withAnimation(.spring(duration: 0.4)) { completeSet() }
            }
        }
    }

    func actionCircle(systemImage: String, tint: Color, action: @escaping () -> Void) -> some View {
        Button(action: action) {
            Image(systemName: systemImage)
                .font(.title2.weight(.bold))
                .foregroundStyle(.white)
                .frame(width: 46, height: 46)
                .background(Circle().fill(tint.gradient))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Logged Weight Section

    var loggedWeightSection: some View {
        HStack(spacing: 8) {
            if let exercise = session.currentExercise {
                if exercise.inputType == .duration {
                    durationTimerDisplay(exercise)
                } else {
                // Weight adjustment
                HStack(spacing: 12) {
                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            session.adjustWeight(-5)
                        }
                    } label: {
                        Text("−")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.glass)

                    VStack(spacing: 2) {
                        if (session.currentLoggedWeight == 0) {
                            Text("Bodyweight")
                                .font(.caption2.monospacedDigit()).bold()
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                                .minimumScaleFactor(0.8)
                        } else {
                            Text(String(format: "%.1f lbs", session.currentLoggedWeight))
                                .font(.caption.monospacedDigit()).bold()
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                    }
                    .frame(maxWidth: .infinity)

                    Button {
                        withAnimation(.spring(duration: 0.2)) {
                            session.adjustWeight(5)
                        }
                    } label: {
                        Text("+")
                            .font(.system(size: 18, weight: .semibold))
                            .frame(width: 12, height: 12)
                    }
                    .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity)

                // Reps adjustment (only for reps exercises)
                if exercise.inputType == .reps {
                    HStack(spacing: 12) {
                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                session.adjustReps(-1)
                            }
                        } label: {
                            Text("−")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(.glass)

                        VStack(spacing: 2) {
                            Text("\(session.currentLoggedReps) reps")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.primary)
                                .multilineTextAlignment(.center)
                        }
                        .frame(maxWidth: .infinity)

                        Button {
                            withAnimation(.spring(duration: 0.2)) {
                                session.adjustReps(1)
                            }
                        } label: {
                            Text("+")
                                .font(.system(size: 16, weight: .semibold))
                                .frame(width: 12, height: 12)
                        }
                        .buttonStyle(.glass)
                    }
                    .frame(maxWidth: .infinity)
                }
                }
            }
        }
    }

    func durationTimerDisplay(_ exercise: ManualExerciseEntry) -> some View {
        let running = session.isExerciseTimerRunning
        let remaining = running ? session.exerciseSecondsRemaining : exercise.durationSeconds
        let isOvertime = remaining < 0
        let shown = abs(remaining)
        return VStack(spacing: 4) {
            Text((isOvertime ? "+" : "") + String(format: "%d:%02d", shown / 60, shown % 60))
                .font(.system(size: 56, weight: .bold, design: .rounded).monospacedDigit())
                .foregroundStyle(isOvertime ? .green : .primary)
                .contentTransition(.numericText())
                .animation(.spring(duration: 0.3), value: remaining)
            Text(running ? (isOvertime ? "Overtime" : "Remaining") : "Ready · \(exercise.durationSeconds)s")
                .font(.caption.weight(.semibold))
                .foregroundStyle(isOvertime ? .green : .secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 8)
    }

    // MARK: - Paging Content

    var page0Content: some View {
        VStack(spacing: 20) {
            Spacer()
            // Hero section: heart rate display
            heroSection

            // Current exercise info
            currentExerciseBlock

            // Progressive-overload advisor callout (tap to auto-apply)
            if let ex = session.currentExercise,
               ex.inputType == .reps,
               !session.appliedOverloadIDs.contains(ex.id),
               let insight = ProgressionAdvisor.insight(for: ex),
               insight.hasSuggestion {
                WorkoutAdvisorCallout(insight: insight) {
                    if let w = insight.suggestedWeightKg {
                        session.applySuggestedTopWeight(w, for: ex)
                    }
                } onDismiss: {
                    withAnimation(.spring(duration: 0.3)) {
                        _ = session.appliedOverloadIDs.insert(ex.id)
                    }
                }
                .id(ex.id)
                .padding(.top, 2)
                .transition(.opacity.combined(with: .move(edge: .bottom)))
            }

            Spacer()

            // Swipe-up affordance
            VStack(spacing: 4) {
                Image(systemName: "chevron.up")
                    .font(.caption2.weight(.semibold))
                    .foregroundStyle(.secondary)
                Text("Plan")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
            }
            .padding(.vertical, 12)
        }
        .padding(.horizontal, 20)
        .frame(maxWidth: .infinity, maxHeight: .infinity)
    }


    var planList: some View {
        ScrollView {
            VStack(spacing: 8) {
                ForEach(session.workout.exercises.groupedBySuperset()) { group in
                    if group.isSuperset {
                        supersetGroupView(group)
                    } else if let ex = group.entries.first {
                        planRow(ex)
                    }
                }
            }
            .padding(.vertical, 8)
        }
        .scrollEdgeEffectStyle(.soft, for: .bottom)
    }

    func supersetGroupView(_ group: ExerciseGroup) -> some View {
        VStack(alignment: .leading, spacing: 6) {
            HStack(spacing: 5) {
                Image(systemName: "link")
                    .font(.caption2.weight(.bold))
                Text("Superset")
                    .font(.caption2.weight(.bold))
                    .tracking(0.5)
            }
            .foregroundStyle(.purple)
            .padding(.horizontal, 12)
            .padding(.top, 8)

            VStack(spacing: 2) {
                ForEach(group.entries) { ex in
                    planRow(ex)
                }
            }
            .padding(.bottom, 6)
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .background(Color.purple.opacity(0.08))
        .overlay(alignment: .leading) {
            RoundedRectangle(cornerRadius: 1.5)
                .fill(Color.purple)
                .frame(width: 3)
                .padding(.vertical, 8)
        }
        .clipShape(RoundedRectangle(cornerRadius: 12))
    }

    func planRow(_ exercise: ManualExerciseEntry) -> some View {
        let idx = session.workout.exercises.firstIndex(where: { $0.id == exercise.id }) ?? 0
        return VStack(alignment: .leading, spacing: 6) {
            // Tappable header — selects the exercise and jumps to the workout page
            Button {
                withAnimation(.spring(duration: 0.3)) {
                    session.select(index: idx)
                    withAnimation {
                        currentPage = 0
                    }
                }
            } label: {
                HStack(spacing: 12) {
                    // Status circle
                    ZStack {
                        Circle()
                            .fill(
                                session.isExerciseComplete(exercise)
                                ? Color.green.opacity(0.3)
                                : (idx == session.currentExerciseIndex ? Color.cyan.opacity(0.3) : Color.white.opacity(0.08))
                            )
                            .frame(width: 32, height: 32)

                        if session.isExerciseComplete(exercise) {
                            Image(systemName: "checkmark")
                                .font(.caption2.weight(.bold))
                                .foregroundStyle(.green)
                        } else if idx == session.currentExerciseIndex {
                            Text("●")
                                .font(.caption.weight(.bold))
                                .foregroundStyle(.cyan)
                        } else {
                            Text("\(idx + 1)")
                                .font(.caption2.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }

                    Text(exercise.name)
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(idx == session.currentExerciseIndex ? .primary : .secondary)
                        .lineLimit(1)

                    Spacer()

                    if idx == session.currentExerciseIndex {
                        Text("NOW")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 3)
                            .background(Color.cyan.opacity(0.2))
                            .cornerRadius(4)
                    }
                }
            }
            .buttonStyle(.plain)

            // Editable set table sits OUTSIDE the navigation button so its
            // text fields and swipe-to-delete gestures work independently.
            if exercise.inputType == .reps {
                EditableSetTable(session: session, exercise: exercise)
                    .padding(.leading, 44)
            }
        }
        .padding(.horizontal, 12)
        .padding(.vertical, 8)
        .opacity(session.isExerciseComplete(exercise) ? 0.6 : 1)
        .contextMenu {
            Button(role: .destructive) {
                withAnimation {
                    session.deleteExercise(id: exercise.id)
                }
            } label: {
                Label("Delete", systemImage: "trash")
            }
        }
    }

    /// Per-set details for the overview list, reflecting live-logged weights/reps
    /// and falling back to the planned targets for sets not yet logged.
    func loggedSetDetails(for exercise: ManualExerciseEntry) -> [SetDetail] {
        let planned = exercise.resolvedSetDetails
        let weights = session.loggedSetWeights[exercise.id] ?? planned.map { $0.weightKg ?? 0 }
        let reps = session.loggedSetReps[exercise.id] ?? planned.map { $0.reps }
        let count = max(weights.count, reps.count)
        return (0..<count).map { i in
            let w = i < weights.count ? weights[i] : 0
            let r = i < reps.count ? reps[i] : exercise.reps
            return SetDetail(weightKg: w > 0 ? w : nil, reps: r)
        }
    }

    // MARK: - Editable Set Table

    var page1Content: some View {
        ScrollView {
            VStack(spacing: 16) {

                // Exercise plan list
                planList
                    .padding(.horizontal, 20)

            }
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .scrollBounceBehavior(.basedOnSize)
        .onScrollGeometryChange(for: CGFloat.self) { $0.contentOffset.y + $0.contentInsets.top } action: { _, new in
            planScrollOffset = new
        }
        .safeAreaBar(edge: .top) {
            HStack {
                VStack(alignment: .leading) {
                    Text(session.workout.title)
                        .font(.headline)
                    let remaining = session.workout.exercises.count - session.workout.exercises.filter { session.isExerciseComplete($0) }.count
                    Text("\(remaining) sets remaining")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                Spacer()
                Button {
                    withAnimation { currentPage = 0 }
                } label: {
                    Image(systemName: "chevron.up")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .padding(10)
                        .glassEffect(in: .circle)
                }
            }
            .padding(.top, 20)
            .padding(.bottom, 5)
            .padding(.horizontal, 20)
        }
        .safeAreaBar(edge: .bottom) {
            Button {
                showingExercisePicker = true
            } label: {
                Label("Add Exercise", systemImage: "plus.circle.fill")
                    .font(.subheadline.weight(.semibold))
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 12)
            }
            .buttonStyle(.glass)
            .padding(.horizontal, 20)
            .padding(.bottom, 25)
        }
        .sheet(isPresented: $showingExercisePicker) {
            ExercisePickerView { entries in
                session.addExercises(entries)
                showingExercisePicker = false
            }
        }
        .simultaneousGesture(
            DragGesture()
                .onChanged { g in
                    // Fire during the drag: the system hand-off can strand the pager between
                    // pages, so we commit the page change ourselves as soon as intent is clear.
                    if currentPage == 1, !didTriggerPageBack, planScrollOffset <= 8, g.translation.height > 50 {
                        didTriggerPageBack = true
                        Task { @MainActor in
                            withAnimation(.spring(duration: 0.35)) { currentPage = 0 }
                        }
                    }
                }
                .onEnded { _ in didTriggerPageBack = false }
        )
    }

    var restProgress: Double {
        guard let exercise = session.currentExercise, exercise.restSeconds > 0 else { return 0 }
        return Double(exercise.restSeconds - session.restSecondsRemaining) / Double(exercise.restSeconds)
    }

    // MARK: - Completion View

    var completionView: some View {
        VStack(spacing: 28) {
            Spacer()

            ZStack {
                Circle()
                    .fill(.green.opacity(0.15))
                    .frame(width: 130, height: 130)

                Image(systemName: "checkmark.seal.fill")
                    .font(.system(size: 72))
                    .foregroundStyle(.green.gradient)
            }
            .scaleEffect(1.05)
            .animation(.spring(response: 0.6, dampingFraction: 0.6), value: session.isFinished)

            VStack(spacing: 8) {
                Text("Workout Complete")
                    .font(.system(size: 30, weight: .bold, design: .default))
                Text(session.workout.title)
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.secondary)
            }

            VStack(spacing: 12) {
                completionStatRow(label: "Duration", value: elapsedFormatted, icon: "clock.fill", color: .cyan)
                completionStatRow(label: "Exercises", value: "\(session.workout.exercises.count)", icon: "dumbbell.fill", color: .orange)
                completionStatRow(label: "Total Sets", value: totalSetsCompleted, icon: "square.stack.fill", color: .purple)
            }
            .padding()
            .glassEffect(.regular.tint(.green.opacity(0.1)), in: .rect(cornerRadius: 20))

            // Perceived effort adjuster (visible only when watch is installed, not in dev mode;
            // always shown on simulator builds so the card can be design-reviewed).
            if showsEffortCard {
                VStack(alignment: .leading, spacing: 14) {
                    HStack {
                        Text("Perceived Effort").font(.subheadline.weight(.semibold))
                        Spacer()
                        Text(effortLabel)
                            .font(.caption.weight(.bold))
                            .foregroundStyle(effortColor)
                            .contentTransition(.numericText())
                    }
                    GeometryReader { proxy in
                        HStack(spacing: 5) {
                            ForEach(1...10, id: \.self) { i in
                                Capsule()
                                    .fill(Double(i) <= session.perceivedEffort ? effortColor(for: Double(i)) : Color.primary.opacity(0.08))
                                    .frame(height: Double(i) <= session.perceivedEffort ? 26 : 20)
                                    .onTapGesture {
                                        withAnimation(.spring(response: 0.3, dampingFraction: 0.7)) {
                                            session.perceivedEffort = Double(i)
                                        }
                                    }
                            }
                        }
                        .frame(height: 30)
                        .gesture(
                            DragGesture(minimumDistance: 0)
                                .onChanged { g in
                                    let fraction = g.location.x / proxy.size.width
                                    let raw = Double(Int(fraction * 10) + 1)
                                    let newValue = min(10, max(1, raw))
                                    withAnimation(.spring(response: 0.2, dampingFraction: 0.7)) {
                                        session.perceivedEffort = newValue
                                    }
                                }
                        )
                    }
                    .frame(height: 30)
                    HStack {
                        Text("1").font(.caption2).foregroundStyle(.tertiary)
                        Spacer()
                        Text("Effort \(Int(session.perceivedEffort)) of 10").font(.caption).foregroundStyle(.secondary).monospacedDigit()
                        Spacer()
                        Text("10").font(.caption2).foregroundStyle(.tertiary)
                    }
                    Text(effortDescription)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .contentTransition(.opacity)
                        .animation(.easeInOut(duration: 0.2), value: effortLabel)
                }
                .padding(16)
                .glassEffect(.regular.tint(effortColor.opacity(0.08)), in: .rect(cornerRadius: 20))
                .sensoryFeedback(.selection, trigger: session.perceivedEffort)
            }

            // Saved to Health indicator
            if devModeEnabled {
                HStack(spacing: 6) {
                    Image(systemName: "hammer.fill")
                        .font(.subheadline)
                        .foregroundStyle(.orange)
                    Text("Dev Mode — Not Saved to Health")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.orange)
                }
                .transition(.opacity.combined(with: .scale))
            } else if session.hasSavedToHealth {
                HStack(spacing: 6) {
                    Image(systemName: "checkmark.circle.fill")
                        .font(.subheadline)
                        .foregroundStyle(.green)
                    Text("Saved to Health")
                        .font(.subheadline.weight(.medium))
                        .foregroundStyle(.secondary)
                }
                .transition(.opacity.combined(with: .scale))
            }

            HStack(spacing: 12) {
                Button {
                    withAnimation(.spring(duration: 0.3)) { updateTemplate() }
                } label: {
                    Label(
                        session.hasUpdatedTemplate ? "Template Updated" : "Update Template",
                        systemImage: session.hasUpdatedTemplate ? "checkmark.circle.fill" : "arrow.triangle.2.circlepath"
                    )
                    .font(.footnote.weight(.semibold))
                    .lineLimit(1)
                    .fixedSize(horizontal: true, vertical: false)
                    .padding(.horizontal, 4)
                    .padding(.vertical, 12)
                }
                .buttonStyle(.glass)
                .tint(session.hasUpdatedTemplate ? .green : .cyan)
                .disabled(session.hasUpdatedTemplate)

                Button {
                    commitEffortScore()
                    saveToHealth()
                    onFinish()
                } label: {
                    Label("Done", systemImage: "checkmark.circle.fill")
                        .font(.footnote.weight(.semibold))
                        .lineLimit(1)
                        .frame(maxWidth: .infinity)
                        .padding(.vertical, 12)
                }
                .buttonStyle(.glassProminent)
            }
            .padding(.horizontal, 30)

            Spacer()
        }
        .padding(.horizontal, 20)
    }

    var totalSetsCompleted: String {
        session.workout.exercises.reduce(0) { $0 + $1.sets }.description
    }

    func completionStatRow(label: String, value: String, icon: String, color: Color) -> some View {
        HStack(spacing: 12) {
            Image(systemName: icon)
                .font(.title3)
                .foregroundStyle(color)
                .frame(width: 24)

            Text(label)
                .font(.subheadline)
                .foregroundStyle(.secondary)

            Spacer()

            Text(value)
                .font(.headline.monospacedDigit())
                .foregroundStyle(.primary)
        }
    }

    /// Whether the perceived-effort card is shown. On device it requires a paired watch
    /// (no Health save happens without one); the simulator never pairs a watch, so show
    /// it there regardless to allow design review.
    private var showsEffortCard: Bool {
        #if targetEnvironment(simulator)
        return !devModeEnabled
        #else
        return !devModeEnabled && watchSync.isWatchAppInstalled
        #endif
    }

    private func effortColor(for value: Double) -> Color {
        switch value {
        case 1...3:
            return .green
        case 4...6:
            return .yellow
        case 7...8:
            return .orange
        default:
            return .red
        }
    }

    private var effortColor: Color {
        effortColor(for: session.perceivedEffort)
    }

    private var effortLabel: String {
        switch session.perceivedEffort {
        case 1...3:
            return "Easy"
        case 4...6:
            return "Moderate"
        case 7...8:
            return "Hard"
        default:
            return "All Out"
        }
    }

    private var effortDescription: String {
        switch session.perceivedEffort {
        case 1...3:
            return "Light work — you could hold a conversation"
        case 4...6:
            return "Breathing harder, but still in control"
        case 7...8:
            return "Out of breath — talking is tough"
        default:
            return "Maximal effort — nothing left in the tank"
        }
    }
}
