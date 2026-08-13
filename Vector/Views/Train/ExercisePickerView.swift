import SwiftUI

struct ExercisePickerView: View {
    let onAdd: ([ManualExerciseEntry]) -> Void
    var role: ExerciseRole = .main

    @State private var searchText = ""
    @State private var selectedEquipment: String? = nil
    @State private var showingCreate = false
    @State private var selectedIDs: [String] = []
    @Environment(\.dismiss) private var dismiss

    private var filteredExercises: [LibraryExercise] {
        if role == .main {
            return ExerciseLibrary.shared.searchAndFilter(
                query: searchText,
                equipment: selectedEquipment,
                muscleGroup: nil
            )
        } else {
            return ExerciseLibrary.shared.search(searchText, in: role)
        }
    }

    private var equipmentFilters: [String] {
        ["All"] + ExerciseLibrary.shared.allEquipmentTypes
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                if role == .main {
                    filterChips
                        .padding(.horizontal, 16)
                }

                List {
                    if role == .main {
                        Button {
                            showingCreate = true
                        } label: {
                            createCustomCard
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    if role != .main {
                        Button {
                            addTimedBlock()
                        } label: {
                            timedBlockCard
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }

                    ForEach(filteredExercises) { exercise in
                        Button {
                            toggle(exercise)
                        } label: {
                            ExerciseRowView(exercise: exercise, isSelected: selectedIDs.contains(exercise.id))
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                        .swipeActions {
                            if exercise.isCustom {
                                Button(role: .destructive) {
                                    CustomExerciseStore.shared.delete(exercise)
                                } label: {
                                    Label("Delete", systemImage: "trash")
                                }
                            }
                        }
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle(navTitle)
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: role == .warmup ? "Search warm-ups" : role == .cooldown ? "Search cool-downs" : "Search exercises, muscles...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button {
                        confirmAdd()
                    } label: {
                        Text(selectedIDs.isEmpty ? "Add" : "Add \(selectedIDs.count) Exercises")
                            .fontWeight(.semibold)
                            .foregroundStyle(.blue)
                    }
                    .disabled(selectedIDs.isEmpty)
                }
            }
            .vectorSheet(isPresented: $showingCreate) {
                CustomExerciseCreationView { newExercise in
                    CustomExerciseStore.shared.add(newExercise)
                    showingCreate = false
                    if !selectedIDs.contains(newExercise.id) {
                        selectedIDs.append(newExercise.id)
                    }
                }
            }
        }
    }

    private var navTitle: String {
        switch role {
        case .warmup:
            return "Add Warm-Up"
        case .cooldown:
            return "Add Cool-Down"
        case .main:
            return "Choose Exercise"
        }
    }

    private var createCustomCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "plus.circle.fill")
                .font(.title2)
                .foregroundStyle(.cyan)
            VStack(alignment: .leading, spacing: 2) {
                Text("Create Custom Exercise")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text("Add your own movement")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    private var timedBlockCard: some View {
        HStack(spacing: 14) {
            Image(systemName: "timer")
                .font(.title2)
                .foregroundStyle(.orange)
            VStack(alignment: .leading, spacing: 2) {
                Text("Add Timed Block")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)
                Text(role == .warmup ? "A timed warm-up — no exercise needed" : "A timed cool-down — no exercise needed")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.horizontal, 14)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    private func addTimedBlock() {
        let entry = ManualExerciseEntry(
            role: role,
            name: role == .warmup ? "Timed Warm-Up" : "Timed Cool-Down",
            sets: 1,
            reps: 0,
            durationSeconds: 300,
            inputType: .duration,
            weightKg: nil,
            restSeconds: 0,
            notes: ""
        )
        onAdd([entry])
        dismiss()
    }

    private var filterChips: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(equipmentFilters, id: \.self) { filter in
                    let isSelected = filter == "All" ? selectedEquipment == nil : selectedEquipment == filter
                    Button {
                        withAnimation(.spring(duration: 0.25)) {
                            selectedEquipment = filter == "All" ? nil : (isSelected ? nil : filter)
                        }
                    } label: {
                        Text(filter)
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 14)
                            .padding(.vertical, 7)
                            .glassEffect(
                                isSelected
                                    ? .regular.tint(equipmentColor(filter).opacity(0.35))
                                    : .regular,
                                in: .capsule
                            )
                            .foregroundStyle(isSelected ? .primary : .secondary)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 2)
            .padding(.vertical, 10)
        }
    }

    private func equipmentColor(_ equipment: String) -> Color {
        switch equipment {
        case "Bodyweight": return .green
        case "Freeweight": return .orange
        case "Cable": return .blue
        case "Machine": return .purple
        default: return .cyan
        }
    }

    private func toggle(_ exercise: LibraryExercise) {
        if let idx = selectedIDs.firstIndex(of: exercise.id) {
            selectedIDs.remove(at: idx)
        } else {
            selectedIDs.append(exercise.id)
        }
    }

    private func buildEntry(for exercise: LibraryExercise) -> ManualExerciseEntry {
        switch role {
        case .warmup:
            return ManualExerciseEntry(
                libraryExerciseId: exercise.id,
                role: .warmup,
                name: exercise.name,
                sets: 1,
                reps: 10,
                durationSeconds: 45,
                inputType: .duration,
                weightKg: nil,
                restSeconds: 15,
                notes: ""
            )
        case .cooldown:
            return ManualExerciseEntry(
                libraryExerciseId: exercise.id,
                role: .cooldown,
                name: exercise.name,
                sets: 1,
                reps: 10,
                durationSeconds: 30,
                inputType: .duration,
                weightKg: nil,
                restSeconds: 0,
                notes: ""
            )
        case .main:
            return ManualExerciseEntry(
                libraryExerciseId: exercise.id,
                role: .main,
                name: exercise.name,
                sets: 3,
                reps: 10,
                durationSeconds: 30,
                inputType: .reps,
                weightKg: nil,
                restSeconds: 90,
                notes: ""
            )
        }
    }

    private func confirmAdd() {
        let entries = selectedIDs.compactMap { id in
            if role == .main {
                ExerciseLibrary.shared.allExercises.first { $0.id == id }
            } else {
                ExerciseLibrary.shared.exercises(for: role).first { $0.id == id }
            }
        }.map { buildEntry(for: $0) }
        guard !entries.isEmpty else { return }
        onAdd(entries)
        dismiss()
    }
}

// MARK: - Exercise Row
private struct ExerciseRowView: View {
    let exercise: LibraryExercise
    var isSelected: Bool = false

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(equipmentColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                HStack(spacing: 6) {
                    Text(exercise.name)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if exercise.isCustom {
                        Text("CUSTOM")
                            .font(.caption2.weight(.bold))
                            .foregroundStyle(.cyan)
                            .padding(.horizontal, 6)
                            .padding(.vertical, 2)
                            .background(Color.cyan.opacity(0.15))
                            .clipShape(Capsule())
                    }
                }

                HStack(spacing: 6) {
                    Text(exercise.primaryMuscle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(exercise.equipment)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .foregroundStyle(.tertiary)
                    Text(exercise.difficulty)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(difficultyColor)
                }
            }

            Spacer()

            Image(systemName: isSelected ? "checkmark.circle.fill" : "plus.circle")
                .foregroundStyle(isSelected ? AnyShapeStyle(.cyan) : AnyShapeStyle(.secondary))
                .font(isSelected ? .title3 : .subheadline)
        }
        .padding(.horizontal, 4)
        .padding(.vertical, 6)
    }

    private var equipmentColor: Color {
        switch exercise.equipment {
        case "Bodyweight": return .green
        case "Freeweight": return .orange
        case "Cable": return .blue
        case "Machine": return .purple
        default: return .gray
        }
    }

    private var difficultyColor: Color {
        switch exercise.difficulty {
        case "Beginner": return .green
        case "Intermediate": return .orange
        case "Advanced": return .red
        default: return .secondary
        }
    }
}
