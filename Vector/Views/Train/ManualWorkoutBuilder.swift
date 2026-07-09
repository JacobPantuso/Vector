import SwiftUI

struct ManualWorkoutBuilder: View {
    let onSave: (SavedWorkout) -> Void

    @State private var title = ""
    @State private var focus = ""
    @State private var effort: Double = 6
    @State private var exercises: [ManualExerciseEntry] = []
    @State private var showingPicker = false
    @State private var editingExercise: ManualExerciseEntry?
    @State private var pendingSupersetID: UUID?

    private var estimatedDuration: Int {
        let total = exercises.reduce(0) { acc, ex in
            let setTime = ex.inputType == .duration ? ex.durationSeconds : ex.reps * 3
            let restTime = ex.restSeconds * max(ex.sets - 1, 0)
            return acc + (setTime * ex.sets) + restTime
        }
        return total / 60 + 5
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                metadataSection
                exerciseListSection
                if !exercises.isEmpty {
                    statsRow
                }
                if !title.isEmpty && !exercises.isEmpty {
                    saveButton
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 8)
            .padding(.bottom, 40)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .sheet(isPresented: $showingPicker) {
            ExercisePickerView { selected in
                exercises.append(contentsOf: selected)
            }
        }
        .sheet(item: $editingExercise) { exercise in
            ExerciseEntryEditor(entry: exercise) { updated in
                if let idx = exercises.firstIndex(where: { $0.id == updated.id }) {
                    exercises[idx] = updated
                }
                editingExercise = nil
            }
        }
    }

    // MARK: - Metadata
    private var metadataSection: some View {
        GlassCard(cornerRadius: 20) {
            VStack(spacing: 14) {
                HStack {
                    TextField("Workout Title", text: $title)
                        .font(.title3.bold())
                        .onChange(of: title) { _, newValue in
                            if newValue.count > 40 {
                                title = String(newValue.prefix(40))
                            }
                        }
                    Text("\(title.count)/40")
                        .font(.caption)
                        .foregroundStyle(title.count >= 35 ? .orange : .secondary)
                }

                Divider()

                TextField("Focus or goal (optional)", text: $focus)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider()

                HStack {
                    Label("Effort", systemImage: "flame")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Spacer()
                    Text("\(Int(effort))/10")
                        .font(.subheadline.monospacedDigit())
                }

                Slider(value: $effort, in: 1...10, step: 1)
                    .tint(.orange)
            }
        }
    }

    // MARK: - Exercise List
    private var exerciseListSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Exercises")
                    .font(.title3.bold())
                Spacer()
                if !exercises.isEmpty {
                    Button {
                        showingPicker = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.subheadline.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.cyan)
                }
            }

            if exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No exercises yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button { showingPicker = true } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassEffect(in: .rect(cornerRadius: 20))
            } else {
                ForEach(Array(exercises.enumerated()), id: \.element.id) { idx, exercise in
                    exerciseRow(exercise, index: idx)
                        .draggable(exercise.id.uuidString)
                        .dropDestination(for: String.self) { items, _ in
                            handleDrop(draggedID: items.first, onto: exercise.id)
                            return true
                        }
                }
            }
        }
    }

    private func exerciseRow(_ exercise: ManualExerciseEntry, index: Int) -> some View {
        HStack(spacing: 12) {
            // Drag handle
            Image(systemName: "line.3.horizontal")
                .foregroundStyle(.secondary)
                .font(.caption)

            // Left accent for supersets
            if exercise.supersetID != nil {
                RoundedRectangle(cornerRadius: 2)
                    .fill(.purple)
                    .frame(width: 3)
            }

            // Number circle
            ZStack {
                Circle()
                    .fill(.ultraThinMaterial)
                    .frame(width: 32, height: 32)
                Text("\(index + 1)")
                    .font(.caption.bold())
                    .foregroundStyle(.secondary)
            }

            VStack(alignment: .leading, spacing: 2) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                    if exercise.supersetID != nil {
                        Text("SUPERSET")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.purple)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.purple.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }
                HStack(spacing: 6) {
                    Text(exercise.displaySetsReps)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    if exercise.weightKg ?? 0 > 0 {
                        Text("·").foregroundStyle(.tertiary)
                        Text(exercise.displayWeight)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                if exercise.inputType == .reps {
                    PerSetBreakdownView(exercise: exercise)
                        .padding(.top, 2)
                }

                if exercise.supersetID != nil, exercise.supersetID == pendingSupersetID {
                    HStack(spacing: 6) {
                        Image(systemName: "arrow.down.to.line")
                        Text("Drag an exercise on top to combine")
                    }
                    .font(.caption2)
                    .foregroundStyle(.purple)
                }
            }

            Spacer()

            Menu {
                Button(action: { editingExercise = exercise }) {
                    Label("Edit Exercise", systemImage: "slider.horizontal.3")
                }
                if exercise.supersetID == nil {
                    Button(action: { makeSuperset(id: exercise.id) }) {
                        Label("Make Superset", systemImage: "link")
                    }
                } else {
                    Button(role: .destructive, action: { removeFromSuperset(id: exercise.id) }) {
                        Label("Remove from Superset", systemImage: "xmark.circle")
                    }
                }
                Divider()
                Button(role: .destructive, action: { deleteExercise(id: exercise.id) }) {
                    Label("Remove Exercise", systemImage: "trash")
                }
            } label: {
                Image(systemName: "ellipsis.circle")
                    .font(.title3)
                    .foregroundStyle(.secondary)
            }
            .buttonStyle(.plain)
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 10)
        .glassEffect(in: .rect(cornerRadius: 14))
        .overlay {
            if pendingSupersetID != nil, exercise.supersetID == pendingSupersetID {
                RoundedRectangle(cornerRadius: 14)
                    .strokeBorder(style: StrokeStyle(lineWidth: 1.5, dash: [6]))
                    .foregroundStyle(.purple.opacity(0.6))
            }
        }
    }

    // MARK: - Stats Row
    private var statsRow: some View {
        HStack(spacing: 0) {
            statCell(label: "Exercises", value: "\(exercises.count)", icon: "dumbbell")
            Divider().frame(height: 40)
            statCell(label: "Est. Time", value: "\(estimatedDuration)m", icon: "clock")
            Divider().frame(height: 40)
            statCell(label: "Effort", value: "\(Int(effort))/10", icon: "flame")
        }
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 18))
    }

    private func statCell(label: String, value: String, icon: String) -> some View {
        VStack(spacing: 4) {
            Image(systemName: icon)
                .font(.caption)
                .foregroundStyle(.secondary)
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.tertiary)
        }
        .frame(maxWidth: .infinity)
    }

    // MARK: - Save Button
    private var saveButton: some View {
        Button {
            pendingSupersetID = nil
            normalizeSupersets()
            let workout = SavedWorkout(
                title: title,
                focus: focus.isEmpty ? "Custom Workout" : focus,
                source: .manual,
                aiPlan: nil,
                exercises: exercises,
                durationMinutes: estimatedDuration,
                effort: Int(effort)
            )
            onSave(workout)
        } label: {
            Label("Save Workout", systemImage: "checkmark.circle.fill")
                .frame(maxWidth: .infinity)
        }
        .buttonStyle(.glassProminent)
    }

    // MARK: - Drag & Reorder Helpers
    private func handleDrop(draggedID: String?, onto targetID: UUID) {
        guard let draggedID, let draggedUUID = UUID(uuidString: draggedID),
              draggedUUID != targetID,
              let from = exercises.firstIndex(where: { $0.id == draggedUUID }),
              let toIdx = exercises.firstIndex(where: { $0.id == targetID }) else { return }
        let target = exercises[toIdx]
        withAnimation(.spring(duration: 0.3)) {
            if let sid = target.supersetID {
                // Drop onto a superset → join it
                var item = exercises.remove(at: from)
                item.supersetID = sid
                let insertIdx = (exercises.firstIndex(where: { $0.id == targetID }) ?? 0) + 1
                exercises.insert(item, at: insertIdx)
                if sid == pendingSupersetID { pendingSupersetID = nil }
            } else {
                // Drop onto a normal exercise → reorder before it
                let item = exercises.remove(at: from)
                let insertAt = toIdx > from ? toIdx - 1 : toIdx
                exercises.insert(item, at: insertAt)
            }
            normalizeSupersets()
        }
    }

    // MARK: - Superset Helpers
    private func makeSuperset(id: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == id }) else { return }
        let newID = UUID()
        withAnimation(.spring(duration: 0.3)) {
            exercises[i].supersetID = newID
            pendingSupersetID = newID
        }
    }

    private func deleteExercise(id: UUID) {
        withAnimation(.spring(duration: 0.3)) {
            exercises.removeAll { $0.id == id }
            normalizeSupersets()
        }
    }

    private func removeFromSuperset(id: UUID) {
        guard let i = exercises.firstIndex(where: { $0.id == id }) else { return }
        withAnimation(.spring(duration: 0.3)) {
            exercises[i].supersetID = nil
            normalizeSupersets()
        }
    }

    /// Any supersetID that no longer covers 2+ consecutive entries is cleared (the pending one is preserved).
    private func normalizeSupersets() {
        let groups = exercises.groupedBySuperset()
        for group in groups where !group.isSuperset {
            if let only = group.entries.first,
               only.supersetID != pendingSupersetID,
               let i = exercises.firstIndex(where: { $0.id == only.id }) {
                exercises[i].supersetID = nil
            }
        }
    }
}

// MARK: - Exercise Entry Editor
struct ExerciseEntryEditor: View {
    @State var entry: ManualExerciseEntry
    let onDone: (ManualExerciseEntry) -> Void

    @Environment(\.dismiss) private var dismiss

    private let restPresets = [0, 30, 45, 60, 90, 120, 180]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Sets & Reps
                    GlassCard(cornerRadius: 20) {
                        VStack(spacing: 16) {
                            Picker("Type", selection: $entry.inputType) {
                                ForEach(ExerciseInputType.allCases, id: \.self) { type in
                                    Text(type.rawValue).tag(type)
                                }
                            }
                            .pickerStyle(.segmented)

                            Divider()

                            counterRow(
                                label: "Sets",
                                value: $entry.sets,
                                range: 1...20,
                                step: 1,
                                color: .cyan
                            )

                            if entry.inputType == .reps {
                                Divider()

                                perSetRows
                            } else {
                                Divider()

                                durationCounter
                            }
                        }
                    }

                    // Rest Time
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Rest Between Sets", systemImage: "timer")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)

                            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 10), count: 4), spacing: 10) {
                                ForEach(restPresets, id: \.self) { seconds in
                                    let isSelected = entry.restSeconds == seconds
                                    Button {
                                        entry.restSeconds = seconds
                                    } label: {
                                        Text(restLabel(seconds))
                                            .font(.subheadline.weight(.semibold))
                                            .frame(maxWidth: .infinity)
                                            .padding(.vertical, 10)
                                            .glassEffect(.regular.tint(isSelected ? .orange.opacity(0.35) : .white.opacity(0.06)), in: .rect(cornerRadius: 12))
                                            .foregroundStyle(isSelected ? .orange : .primary)
                                    }
                                    .buttonStyle(.plain)
                                }
                            }
                        }
                    }

                    // Weight (uniform — reps mode has per-set weights)
                    if entry.inputType == .duration {
                        GlassCard(cornerRadius: 20) {
                            HStack {
                                Label("Weight", systemImage: "scalemass")
                                    .font(.subheadline.weight(.semibold))
                                    .foregroundStyle(.secondary)
                                Spacer()
                                TextField("0", value: $entry.weightKg, format: .number)
                                    .keyboardType(.decimalPad)
                                    .multilineTextAlignment(.trailing)
                                    .font(.title3.bold().monospacedDigit())
                                    .frame(width: 72)
                                Text("lbs")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    // Notes
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Notes", systemImage: "text.bubble")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Optional cue or note…", text: $entry.notes, axis: .vertical)
                                .font(.subheadline)
                                .lineLimit(2...4)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .onAppear {
                if entry.inputType == .reps, entry.setDetails == nil {
                    entry.setDetails = entry.resolvedSetDetails
                }
            }
            .onChange(of: entry.sets) { resizeSetDetails() }
            .onChange(of: entry.inputType) { _, type in
                if type == .reps {
                    if entry.setDetails == nil { entry.setDetails = entry.resolvedSetDetails }
                } else {
                    entry.setDetails = nil
                }
            }
            .navigationTitle(entry.name)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") {
                        onDone(entry)
                        dismiss()
                    }
                    .fontWeight(.semibold)
                }
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
    }

    private func counterRow(label: String, value: Binding<Int>, range: ClosedRange<Int>, step: Int, color: Color) -> some View {
        HStack {
            Text(label)
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 48, alignment: .leading)

            Spacer()

            HStack(spacing: 24) {
                Button {
                    if value.wrappedValue - step >= range.lowerBound {
                        value.wrappedValue -= step
                    }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(value.wrappedValue <= range.lowerBound ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue <= range.lowerBound)

                Text("\(value.wrappedValue)")
                    .font(.title2.bold().monospacedDigit())
                    .frame(minWidth: 44)
                    .multilineTextAlignment(.center)

                Button {
                    if value.wrappedValue + step <= range.upperBound {
                        value.wrappedValue += step
                    }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(value.wrappedValue >= range.upperBound ? AnyShapeStyle(.tertiary) : AnyShapeStyle(color))
                }
                .buttonStyle(.plain)
                .disabled(value.wrappedValue >= range.upperBound)
            }
        }
    }

    private var durationCounter: some View {
        HStack {
            Text("Duration")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)
                .frame(width: 72, alignment: .leading)

            Spacer()

            HStack(spacing: 24) {
                Button {
                    if entry.durationSeconds - 5 >= 5 { entry.durationSeconds -= 5 }
                } label: {
                    Image(systemName: "minus.circle.fill")
                        .font(.title)
                        .foregroundStyle(entry.durationSeconds <= 5 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.purple))
                }
                .buttonStyle(.plain)
                .disabled(entry.durationSeconds <= 5)

                Text("\(entry.durationSeconds)s")
                    .font(.title2.bold().monospacedDigit())
                    .frame(minWidth: 56)
                    .multilineTextAlignment(.center)

                Button {
                    if entry.durationSeconds + 5 <= 600 { entry.durationSeconds += 5 }
                } label: {
                    Image(systemName: "plus.circle.fill")
                        .font(.title)
                        .foregroundStyle(entry.durationSeconds >= 600 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.purple))
                }
                .buttonStyle(.plain)
                .disabled(entry.durationSeconds >= 600)
            }
        }
    }

    private func restLabel(_ seconds: Int) -> String {
        if seconds == 0 { return "None" }
        if seconds < 60 { return "\(seconds)s" }
        let m = seconds / 60
        let s = seconds % 60
        return s == 0 ? "\(m)m" : "\(m)m \(s)s"
    }

    // MARK: - Per-Set Editing

    private var perSetRows: some View {
        VStack(alignment: .leading, spacing: 14) {
            Label("Set Targets", systemImage: "slider.horizontal.3")
                .font(.subheadline.weight(.semibold))
                .foregroundStyle(.secondary)

            ForEach(0..<entry.sets, id: \.self) { i in
                HStack(spacing: 12) {
                    Text("Set \(i + 1)")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.secondary)
                        .frame(width: 52, alignment: .leading)
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("0", value: setBinding(i).weightKg, format: .number)
                            .keyboardType(.decimalPad)
                            .multilineTextAlignment(.trailing)
                            .font(.subheadline.bold().monospacedDigit())
                            .frame(width: 35)
                        Text("lb")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    .padding(.horizontal, 10)
                    .padding(.vertical, 6)
                    .overlay {
                        RoundedRectangle(cornerRadius: 8)
                            .strokeBorder(Color.black.opacity(0.5), lineWidth: 1)
                    }
                    Spacer()

                    HStack(spacing: 16) {
                        Button { adjustSetReps(i, -1) } label: {
                            Image(systemName: "minus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(setReps(i) <= 1 ? AnyShapeStyle(.tertiary) : AnyShapeStyle(Color.gray))
                        }
                        .buttonStyle(.plain)
                        .disabled(setReps(i) <= 1)

                        Text("\(setReps(i)) reps")
                            .font(.subheadline.bold().monospacedDigit())
                            .frame(minWidth: 54)
                            .multilineTextAlignment(.center)

                        Button { adjustSetReps(i, 1) } label: {
                            Image(systemName: "plus.circle.fill")
                                .font(.title3)
                                .foregroundStyle(Color.gray)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
        }
    }

    private func setReps(_ i: Int) -> Int {
        if let details = entry.setDetails, details.indices.contains(i) { return details[i].reps }
        return entry.reps
    }

    private func setBinding(_ i: Int) -> Binding<SetDetail> {
        Binding(
            get: {
                if let details = entry.setDetails, details.indices.contains(i) { return details[i] }
                return SetDetail(weightKg: entry.weightKg, reps: entry.reps)
            },
            set: { newValue in
                if entry.setDetails == nil { entry.setDetails = entry.resolvedSetDetails }
                if entry.setDetails!.indices.contains(i) { entry.setDetails![i] = newValue }
            }
        )
    }

    private func adjustSetReps(_ i: Int, _ delta: Int) {
        if entry.setDetails == nil { entry.setDetails = entry.resolvedSetDetails }
        guard entry.setDetails!.indices.contains(i) else { return }
        entry.setDetails![i].reps = max(1, entry.setDetails![i].reps + delta)
    }

    private func resizeSetDetails() {
        guard entry.inputType == .reps else { return }
        var details = entry.setDetails ?? entry.resolvedSetDetails
        if details.count < entry.sets {
            let pad = details.last ?? SetDetail(weightKg: entry.weightKg, reps: entry.reps)
            details.append(contentsOf: Array(repeating: pad, count: entry.sets - details.count))
        } else if details.count > entry.sets {
            details = Array(details.prefix(entry.sets))
        }
        entry.setDetails = details
    }
}
