import SwiftUI

struct WorkoutCreationView: View {
    let onSave: (SavedWorkout) -> Void

    @State private var selectedMode: CreationMode = .ai
    @Environment(\.dismiss) private var dismiss

    enum CreationMode: String, CaseIterable {
        case ai = "AI Generate"
        case manual = "Manual Build"

        var icon: String {
            switch self {
            case .ai: return "sparkles"
            case .manual: return "list.bullet.clipboard.fill"
            }
        }
    }

    var body: some View {
        NavigationStack {
            VStack(spacing: 0) {
                HStack(spacing: 0) {
                    ForEach(CreationMode.allCases, id: \.self) { mode in
                        Button {
                            withAnimation(.spring(duration: 0.3)) { selectedMode = mode }
                        } label: {
                            HStack(spacing: 6) {
                                Image(systemName: mode.icon)
                                Text(mode.rawValue)
                                    .font(.subheadline.weight(.semibold))
                            }
                            .frame(maxWidth: .infinity)
                            .padding(.vertical, 12)
                            .background {
                                if selectedMode == mode {
                                    RoundedRectangle(cornerRadius: 14)
                                        .fill(.regularMaterial)
                                        .shadow(color: .black.opacity(0.08), radius: 4, y: 2)
                                }
                            }
                            .foregroundStyle(selectedMode == mode ? .primary : .secondary)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(4)
                .glassEffect(in: .rect(cornerRadius: 18))
                .padding(.horizontal, 20)
                .padding(.top, 16)
                .padding(.bottom, 8)

                if selectedMode == .ai {
                    AIGenerateView(onSave: onSave)
                } else {
                    ManualWorkoutBuilder(onSave: onSave)
                }
            }
            .navigationTitle("New Workout")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarLeading) {
                    Button(action: {
                        dismiss()
                    }, label: {
                        Image(systemName: "multiply")
                    })
                }
            }
        }
    }
}

#Preview {
    WorkoutCreationView { _ in }
        .environment(HealthKitService())
}
