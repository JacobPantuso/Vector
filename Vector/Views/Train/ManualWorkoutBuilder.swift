import SwiftUI

struct ManualWorkoutBuilder: View {
    let onSave: (SavedWorkout) -> Void

    @State private var title = ""
    @State private var focus = ""
    @State private var effort: Double = 6
    @State private var exercises: [ManualExerciseEntry] = []
    @State private var showingPicker = false
    @State private var pickerRole: ExerciseRole = .main
    @State private var pendingSupersetID: UUID?

    private var estimatedDuration: Int {
        let total = exercises.reduce(0) { acc, ex in
            let setTime = ex.inputType == .duration ? ex.durationSeconds : ex.reps * 3
            let restTime = ex.totalRestSeconds
            return acc + (setTime * ex.sets) + restTime
        }
        return total / 60 + 5
    }

    private var warmups: [ManualExerciseEntry] {
        exercises.filter { $0.resolvedRole == .warmup }
    }

    private var mains: [ManualExerciseEntry] {
        exercises.filter { $0.resolvedRole == .main }
    }

    private var cooldowns: [ManualExerciseEntry] {
        exercises.filter { $0.resolvedRole == .cooldown }
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
        .vectorSheet(isPresented: $showingPicker) {
            ExercisePickerView(onAdd: { selected in
                let updated = selected.map { var e = $0; e.role = pickerRole; return e }

                // Insert warmups BEFORE mains, mains in order, cooldowns AT END
                if pickerRole == .warmup {
                    let insertIdx = exercises.firstIndex { $0.resolvedRole == .main } ?? exercises.count
                    exercises.insert(contentsOf: updated, at: insertIdx)
                } else if pickerRole == .cooldown {
                    exercises.append(contentsOf: updated)
                } else {
                    exercises.append(contentsOf: updated)
                }
            }, role: pickerRole)
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
        VStack(alignment: .leading, spacing: 14) {
            Text("Exercises")
                .font(.title3.bold())

            if exercises.isEmpty {
                VStack(spacing: 12) {
                    Image(systemName: "dumbbell")
                        .font(.system(size: 36))
                        .foregroundStyle(.tertiary)
                    Text("No exercises yet")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                    Button { pickerRole = .main; showingPicker = true } label: {
                        Label("Add Exercise", systemImage: "plus")
                    }
                    .buttonStyle(.glass)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 28)
                .glassEffect(in: .rect(cornerRadius: 20))
            } else {
                // Warm-Up section
                if !warmups.isEmpty {
                    exerciseSection(warmups, title: "Warm-Up")
                } else {
                    addButton(label: "Add Warm-Up", role: .warmup)
                }

                // Main exercises section
                exerciseSection(mains, title: "Main")

                // Cool-Down section
                if !cooldowns.isEmpty {
                    exerciseSection(cooldowns, title: "Cool-Down")
                } else {
                    addButton(label: "Add Cool-Down", role: .cooldown)
                }
            }
        }
    }

    private func exerciseSection(_ exs: [ManualExerciseEntry], title: String) -> some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Text(title)
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                Spacer()
                if title == "Main" {
                    Button {
                        pickerRole = .main
                        showingPicker = true
                    } label: {
                        Label("Add", systemImage: "plus.circle.fill")
                            .font(.caption.weight(.semibold))
                    }
                    .buttonStyle(.plain)
                    .foregroundStyle(.cyan)
                }
            }

            ForEach(exs, id: \.id) { exercise in
                exerciseRow(exercise)
                    .draggable(exercise.id.uuidString)
                    .dropDestination(for: String.self) { items, _ in
                        handleDrop(draggedID: items.first, onto: exercise.id)
                        return true
                    }
            }
        }
    }

    private func addButton(label: String, role: ExerciseRole) -> some View {
        Button {
            pickerRole = role
            showingPicker = true
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

    private func exerciseRow(_ exercise: ManualExerciseEntry) -> some View {
        VStack(spacing: 0) {
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

                // Link button (superset)
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

                // Trash button (delete)
                Button(role: .destructive) {
                    deleteExercise(id: exercise.id)
                } label: {
                    Image(systemName: "trash")
                        .font(.subheadline)
                        .foregroundStyle(.red)
                }
                .buttonStyle(.plain)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 10)

            // Inline set editor
            InlineSetEditor(entry: Binding(
                get: { exercise },
                set: { updated in
                    if let idx = exercises.firstIndex(where: { $0.id == exercise.id }) {
                        exercises[idx] = updated
                    }
                }
            ))
        }
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
