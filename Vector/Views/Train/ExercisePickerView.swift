import SwiftUI

struct ExercisePickerView: View {
    let onSelect: (ManualExerciseEntry) -> Void

    @State private var searchText = ""
    @State private var selectedEquipment: String? = nil
    @Environment(\.dismiss) private var dismiss

    private var filteredExercises: [LibraryExercise] {
        ExerciseLibrary.shared.searchAndFilter(
            query: searchText,
            equipment: selectedEquipment,
            muscleGroup: nil
        )
    }

    private let equipmentFilters = ["All", "Bodyweight", "Freeweight", "Cable", "Machine"]

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                filterChips
                    .padding(.horizontal, 16)
                    .padding(.vertical, 10)

                List {
                    ForEach(filteredExercises) { exercise in
                        Button {
                            let entry = ManualExerciseEntry(
                                libraryExerciseId: exercise.id,
                                name: exercise.name,
                                sets: 3,
                                reps: 10,
                                durationSeconds: 30,
                                inputType: .reps,
                                weightKg: nil,
                                restSeconds: 90,
                                notes: ""
                            )
                            onSelect(entry)
                        } label: {
                            ExerciseRowView(exercise: exercise)
                        }
                        .buttonStyle(.plain)
                        .listRowBackground(Color.clear)
                        .listRowSeparator(.hidden)
                    }
                }
                .listStyle(.plain)
                .scrollContentBackground(.hidden)
            }
            .navigationTitle("Choose Exercise")
            .navigationBarTitleDisplayMode(.large)
            .searchable(text: $searchText, prompt: "Search exercises, muscles...")
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
            }
        }
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
}

// MARK: - Exercise Row
private struct ExerciseRowView: View {
    let exercise: LibraryExercise

    var body: some View {
        HStack(spacing: 14) {
            RoundedRectangle(cornerRadius: 4)
                .fill(equipmentColor)
                .frame(width: 4, height: 44)

            VStack(alignment: .leading, spacing: 3) {
                Text(exercise.name)
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.primary)

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

            Image(systemName: "plus.circle")
                .foregroundStyle(.secondary)
                .font(.subheadline)
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
