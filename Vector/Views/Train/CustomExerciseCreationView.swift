import SwiftUI

struct CustomExerciseCreationView: View {
    let onCreate: (LibraryExercise) -> Void
    @Environment(\.dismiss) private var dismiss
    @State private var name = ""
    @State private var equipment = "Freeweight"
    @State private var muscleGroup = "Upper Body"
    @State private var primaryMuscle = ""

    private let equipmentOptions = ["Bodyweight", "Freeweight", "Cable", "Machine", "Kettlebell", "Band", "Cardio"]
    private let muscleGroupOptions = ["Upper Body", "Lower Body", "Core", "Full Body", "Cardio"]

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    // Name
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Exercise Name", systemImage: "pencil")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("Required", text: $name)
                                .font(.subheadline)
                        }
                    }

                    // Equipment
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Equipment", systemImage: "dumbbell")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Equipment", selection: $equipment) {
                                ForEach(equipmentOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // Target Muscle Group
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 12) {
                            Label("Target Muscle Group", systemImage: "figure.strengthtraining")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            Picker("Muscle Group", selection: $muscleGroup) {
                                ForEach(muscleGroupOptions, id: \.self) { option in
                                    Text(option).tag(option)
                                }
                            }
                            .pickerStyle(.menu)
                        }
                    }

                    // Primary Muscle
                    GlassCard(cornerRadius: 20) {
                        VStack(alignment: .leading, spacing: 8) {
                            Label("Primary Muscle", systemImage: "sparkles")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.secondary)
                            TextField("e.g. Chest (optional)", text: $primaryMuscle)
                                .font(.subheadline)
                        }
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle("Custom Exercise")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button("Cancel") { dismiss() }
                        .foregroundStyle(.secondary)
                }
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Save") {
                        let ex = CustomExerciseStore.makeExercise(
                            name: name.trimmingCharacters(in: .whitespaces),
                            equipment: equipment,
                            targetMuscleGroup: muscleGroup,
                            primaryMuscle: primaryMuscle.trimmingCharacters(in: .whitespaces).isEmpty ? muscleGroup : primaryMuscle.trimmingCharacters(in: .whitespaces)
                        )
                        onCreate(ex)
                        dismiss()
                    }
                    .fontWeight(.bold)
                    .disabled(name.trimmingCharacters(in: .whitespaces).isEmpty)
                }
            }
        }
    }
}
