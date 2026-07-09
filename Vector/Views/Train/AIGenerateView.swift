import SwiftUI

struct AIGenerateView: View {
    let onSave: (SavedWorkout) -> Void

    @Environment(HealthKitService.self) var healthService
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.sleepTargetHours) private var sleepTargetHours = UserProfile.defaultSleepTargetHours

    @State private var promptText = ""
    @State private var isGenerating = false
    @State private var generatedPlan: WorkoutPlan?
    @State private var glowPhase: Double = 0
    @State private var shimmerPhase: Double = 0
    @FocusState private var isFocused: Bool

    private let presets: [(name: String, prompt: String, icon: String)] = [
        ("Push Day", "push day with chest, shoulders, and triceps", "figure.strengthtraining.traditional"),
        ("Pull Day", "pull workout with back thickness and biceps", "arrow.down.to.line"),
        ("Leg Day", "leg session with squat pattern, hinge, and calves", "figure.walk"),
        ("Full Body", "full body strength session with moderate load", "sparkles"),
        ("Core Blast", "core-focused workout with planks, rotation, and stability", "circle.circle"),
        ("HIIT", "high intensity interval cardio and bodyweight circuit", "bolt.fill"),
    ]

    private var profile: UserProfile {
        UserProfile(
            goal: FitnessGoal(rawValue: goalRaw) ?? UserProfile.defaultGoal,
            ageRange: AgeRange(rawValue: ageRangeRaw) ?? UserProfile.defaultAgeRange,
            trainingDaysPerWeek: trainingDays,
            sleepTargetHours: sleepTargetHours
        )
    }

    var body: some View {
        ScrollView {
            VStack(spacing: 28) {
                glassBubble
                presetChips
                if let plan = generatedPlan {
                    generatedPlanCard(plan)
                        .transition(.move(edge: .bottom).combined(with: .opacity))
                }
            }
            .padding(.horizontal, 20)
            .padding(.top, 16)
            .padding(.bottom, 40)
        }
        .scrollEdgeEffectStyle(.soft, for: .all)
        .onAppear {
            withAnimation(.linear(duration: 3).repeatForever(autoreverses: false)) {
                shimmerPhase = 1
            }
        }
    }

    // MARK: - Liquid Glass Bubble
    private var glassBubble: some View {
        ZStack {
            // Expanding glow rings when generating
            if isGenerating {
                ForEach(0..<3, id: \.self) { i in
                    Ellipse()
                        .stroke(
                            LinearGradient(
                                colors: [.purple, .cyan, .pink],
                                startPoint: .topLeading,
                                endPoint: .bottomTrailing
                            ).opacity(0.4 - Double(i) * 0.12),
                            lineWidth: 2
                        )
                        .scaleEffect(1 + glowPhase * (0.12 + Double(i) * 0.08))
                        .opacity(1 - glowPhase)
                        .animation(
                            .easeOut(duration: 1.4).repeatForever(autoreverses: false).delay(Double(i) * 0.35),
                            value: glowPhase
                        )
                }
            }

            ZStack(alignment: .center) {
                // Subtle shimmer sweep
                LinearGradient(
                    stops: [
                        .init(color: .clear, location: shimmerPhase - 0.3),
                        .init(color: .white.opacity(0.08), location: shimmerPhase),
                        .init(color: .clear, location: shimmerPhase + 0.3),
                    ],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                )
                .allowsHitTesting(false)

                VStack(spacing: 12) {
                    if isGenerating {
                        ProgressView()
                            .tint(.purple)
                            .scaleEffect(1.3)
                        Text("Generating your workout...")
                            .font(.subheadline.weight(.medium))
                            .foregroundStyle(.secondary)
                    } else {
                        if promptText.isEmpty {
                            Image(systemName: "sparkles")
                                .font(.system(size: 28))
                                .foregroundStyle(
                                    LinearGradient(colors: [.purple, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
                                )
                            Text("Describe your workout")
                                .font(.subheadline)
                                .foregroundStyle(.tertiary)
                        }

                        TextField("e.g. push day with heavy chest and triceps...", text: $promptText, axis: .vertical)
                            .font(.body)
                            .multilineTextAlignment(.center)
                            .focused($isFocused)
                            .lineLimit(3...6)
                            .padding(.horizontal, 24)

                        if !promptText.isEmpty {
                            Button {
                                Task { await generateWorkout() }
                            } label: {
                                Label("Generate", systemImage: "sparkles")
                                    .font(.subheadline.weight(.semibold))
                            }
                            .buttonStyle(.glassProminent)
                            .padding(.top, 4)
                        }
                    }
                }
            }
            .frame(maxWidth: .infinity)
            .frame(minHeight: 210)
            .glassEffect(
                isGenerating
                    ? .regular.tint(.purple.opacity(0.25))
                    : (isFocused ? .regular.tint(.cyan.opacity(0.15)) : .regular),
                in: .rect(cornerRadius: 32)
            )
        }
        .onChange(of: isGenerating) { _, generating in
            if generating {
                withAnimation(.easeInOut(duration: 1.2).repeatForever(autoreverses: true)) {
                    glowPhase = 1
                }
            } else {
                withAnimation(.spring(duration: 0.4)) { glowPhase = 0 }
            }
        }
        .onTapGesture { isFocused = true }
    }

    // MARK: - Preset Chips
    private var presetChips: some View {
        VStack(alignment: .leading, spacing: 10) {
            Text("Quick Presets")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
                .padding(.horizontal, 4)

            ScrollView(.horizontal, showsIndicators: false) {
                HStack(spacing: 10) {
                    ForEach(presets, id: \.name) { preset in
                        Button {
                            promptText = preset.prompt
                            Task { await generateWorkout() }
                        } label: {
                            Label(preset.name, systemImage: preset.icon)
                                .font(.caption.weight(.semibold))
                                .padding(.horizontal, 14)
                                .padding(.vertical, 8)
                                .glassEffect(.regular.tint(.purple.opacity(0.15)), in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
                .padding(.horizontal, 2)
                .padding(.vertical, 5)
            }
        }
    }

    // MARK: - Generated Plan Card
    private func generatedPlanCard(_ plan: WorkoutPlan) -> some View {
        GlassCard(tint: .green.opacity(0.18), cornerRadius: 24) {
            VStack(alignment: .leading, spacing: 16) {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        Text(plan.title)
                            .font(.title3.bold())
                        Text(plan.focus)
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    VStack(alignment: .trailing, spacing: 4) {
                        Text("\(plan.durationMinutes)m")
                            .font(.headline.monospacedDigit())
                        Text("Effort \(plan.effort)/10")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                }

                Divider()

                VStack(alignment: .leading, spacing: 8) {
                    Text("Working Sets")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(.secondary)
                    ForEach(plan.exercises.prefix(5), id: \.name) { ex in
                        HStack {
                            Text("·")
                                .foregroundStyle(.tertiary)
                            Text(ex.name)
                                .font(.subheadline)
                            Spacer()
                            Text("\(ex.sets)×\(ex.reps)")
                                .font(.caption.monospacedDigit())
                                .foregroundStyle(.secondary)
                        }
                    }
                    if plan.exercises.count > 5 {
                        Text("+ \(plan.exercises.count - 5) more")
                            .font(.caption)
                            .foregroundStyle(.tertiary)
                    }
                }

                Button {
                    saveWorkout(from: plan)
                } label: {
                    Label("Save This Workout", systemImage: "checkmark.circle.fill")
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glassProminent)

                Button {
                    withAnimation(.spring(duration: 0.3)) { generatedPlan = nil }
                } label: {
                    Text("Regenerate")
                        .font(.subheadline)
                        .frame(maxWidth: .infinity)
                }
                .buttonStyle(.glass)
            }
        }
    }

    // MARK: - Actions
    private func generateWorkout() async {
        guard !promptText.trimmingCharacters(in: .whitespaces).isEmpty else { return }
        isFocused = false
        withAnimation(.spring(duration: 0.4)) { isGenerating = true }
        defer { withAnimation(.spring(duration: 0.4)) { isGenerating = false } }

        let plan = await WorkoutPlanningEngine.generatePlan(
            from: promptText,
            profile: profile,
            recoveryScore: healthService.recoveryScore,
            exertionScore: healthService.exertionScore
        )

        withAnimation(.spring(duration: 0.5)) {
            generatedPlan = plan
        }
    }

    private func saveWorkout(from plan: WorkoutPlan) {
        let entries: [ManualExerciseEntry] = plan.exercises.map { step in
            ManualExerciseEntry(
                libraryExerciseId: nil,
                name: step.name,
                sets: step.sets,
                reps: step.reps,
                durationSeconds: 0,
                inputType: .reps,
                weightKg: nil,
                restSeconds: step.restSeconds,
                notes: step.cue
            )
        }

        let workout = SavedWorkout(
            title: plan.title,
            focus: plan.focus,
            source: .ai,
            aiPlan: plan,
            exercises: entries,
            durationMinutes: plan.durationMinutes,
            effort: plan.effort
        )
        onSave(workout)
    }
}
