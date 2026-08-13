import SwiftUI
import Combine

// MARK: - Readiness Strip (3 compact pills)

struct ReadinessPill: View {
    let label: String
    let value: String
    let icon: String
    let tintColor: Color

    var body: some View {
        VStack(spacing: 2) {
            HStack(spacing: 4) {
                Image(systemName: icon)
                    .font(.caption2)
                Text(label)
                    .font(.caption2)
            }
            Text(value)
                .font(.subheadline.bold())
        }
        .frame(maxWidth: .infinity)
        .padding(.horizontal, 10)
        .padding(.vertical, 8)
        .glassEffect(.regular.tint(tintColor.opacity(0.12)), in: .rect(cornerRadius: 12))
    }
}

// MARK: - Context Chip Card (above user message if topic != nil)

struct ContextChipCard: View {
    let topic: AdvisorTopic

    var tintColor: Color {
        colorFromTintName(topic.tintName)
    }

    var body: some View {
        HStack(spacing: 12) {
            ZStack {
                Circle()
                    .fill(tintColor.opacity(0.15))
                    .frame(width: 32, height: 32)
                Image(systemName: topic.icon)
                    .font(.caption)
                    .foregroundStyle(tintColor)
            }
            VStack(alignment: .leading, spacing: 2) {
                Text(topic.title)
                    .font(.caption.bold())
                    .foregroundStyle(.primary)
                VStack(alignment: .leading, spacing: 1) {
                    ForEach(topic.contextLines.prefix(2), id: \.self) { line in
                        Text(line)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
            }
            Spacer()
        }
        .padding(10)
        .glassEffect(.regular.tint(tintColor.opacity(0.08)), in: .rect(cornerRadius: 12))
    }

    private func colorFromTintName(_ name: String) -> Color {
        switch name.lowercased() {
        case "green": return .green
        case "red": return .red
        case "cyan": return .cyan
        case "orange": return .orange
        case "indigo": return .indigo
        case "blue": return .blue
        case "purple": return .purple
        case "pink": return .pink
        case "mint": return .mint
        case "yellow": return .yellow
        default: return .indigo
        }
    }
}

// MARK: - Skill Row (advisor capabilities)

struct AdvisorSkill: Identifiable {
    var id: String { title }
    let icon: String
    let title: String
    let tint: Color
    let prompt: String
    /// When true, tapping prefills the input field instead of sending immediately.
    var prefillsOnly: Bool = false

    static var all: [AdvisorSkill] {
        var skills: [AdvisorSkill] = [
            AdvisorSkill(icon: "dumbbell.fill", title: "Workout", tint: .orange,
                         prompt: "Build me a workout for today based on my recovery."),
            AdvisorSkill(icon: "heart.fill", title: "Recovery", tint: .green,
                         prompt: "How recovered am I today, and what's driving it?"),
            AdvisorSkill(icon: "moon.stars.fill", title: "Sleep", tint: .blue,
                         prompt: "Analyze my sleep and tell me how to improve it."),
            AdvisorSkill(icon: "chart.line.uptrend.xyaxis", title: "Progression", tint: .cyan,
                         prompt: "Where am I progressing, and where am I plateauing?"),
            AdvisorSkill(icon: "clock.arrow.circlepath", title: "History", tint: .indigo,
                         prompt: "Summarize my recent workout history.")
        ]
        if FeatureFlags.nutritionEnabled {
            skills.append(AdvisorSkill(icon: "fork.knife", title: "Log meal", tint: .mint,
                                       prompt: "Log a meal: ", prefillsOnly: true))
        }
        return skills
    }
}

struct SkillRow: View {
    let onSelect: (AdvisorSkill) -> Void

    var body: some View {
        ScrollView(.horizontal, showsIndicators: false) {
            HStack(spacing: 8) {
                ForEach(AdvisorSkill.all) { skill in
                    Button {
                        onSelect(skill)
                    } label: {
                        HStack(spacing: 5) {
                            Image(systemName: skill.icon)
                                .font(.caption2)
                                .foregroundStyle(skill.tint)
                            Text(skill.title)
                                .font(.caption.weight(.medium))
                        }
                        .padding(.horizontal, 12)
                        .padding(.vertical, 7)
                        .glassEffect(.regular.tint(skill.tint.opacity(0.10)), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }
            .padding(.horizontal, 16)
        }
    }
}

// MARK: - Suggestion

/// A prebuilt opener shown in the empty state. `title` is the short label the
/// user reads; `prompt` is what actually gets sent to the advisor.
struct AdvisorSuggestion: Identifiable {
    var id: String { prompt }
    let icon: String
    let tint: Color
    let title: String
    var subtitle: String? = nil
    let prompt: String
}

struct SuggestionCard: View {
    let suggestion: AdvisorSuggestion
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack(spacing: 12) {
                Image(systemName: suggestion.icon)
                    .font(.system(size: 13, weight: .semibold))
                    .foregroundStyle(suggestion.tint)
                    .frame(width: 30, height: 30)
                    .background(
                        RoundedRectangle(cornerRadius: 9, style: .continuous)
                            .fill(suggestion.tint.opacity(0.16))
                    )

                VStack(alignment: .leading, spacing: 1) {
                    Text(suggestion.title)
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.primary)
                    if let subtitle = suggestion.subtitle {
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                            .lineLimit(1)
                    }
                }
                .multilineTextAlignment(.leading)

                Spacer(minLength: 8)

                Image(systemName: "chevron.right")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.tertiary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 10)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 16))
        }
        .buttonStyle(PressableCardStyle())
    }
}

/// Subtle press feedback shared by the advisor's tappable cards.
struct PressableCardStyle: ButtonStyle {
    func makeBody(configuration: Configuration) -> some View {
        configuration.label
            .scaleEffect(configuration.isPressed ? 0.975 : 1)
            .opacity(configuration.isPressed ? 0.85 : 1)
            .animation(.spring(response: 0.28, dampingFraction: 0.7), value: configuration.isPressed)
    }
}

// MARK: - Empty State Hero

struct EmptyStateHero: View {
    var body: some View {
        VStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(
                        RadialGradient(
                            colors: [.indigo.opacity(0.55), .cyan.opacity(0.10), .clear],
                            center: .center,
                            startRadius: 2,
                            endRadius: 60
                        )
                    )
                    .frame(width: 120, height: 120)
                    .blur(radius: 14)

                Circle()
                    .fill(
                        LinearGradient(
                            colors: [.indigo.opacity(0.28), .cyan.opacity(0.20)],
                            startPoint: .topLeading,
                            endPoint: .bottomTrailing
                        )
                    )
                    .frame(width: 58, height: 58)
                    .overlay(
                        Circle().strokeBorder(.white.opacity(0.12), lineWidth: 0.5)
                    )

                Image(systemName: "sparkles")
                    .font(.system(size: 22, weight: .medium))
                    .foregroundStyle(VectorTheme.brandForeground)
                    .symbolEffect(.breathe.plain, options: .repeat(.continuous))
            }

            VStack(spacing: 5) {
                Text("Ask Vector anything")
                    .font(.title2.weight(.semibold))
                Text("Recovery, sleep, training and progression — with the context to act on it.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 12)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(.top, 18)
        .padding(.bottom, 22)
    }
}

// MARK: - Thinking Dots

struct ThinkingDots: View {
    @State private var phase = 0
    private let timer = Timer.publish(every: 0.35, on: .main, in: .common).autoconnect()

    var body: some View {
        HStack(spacing: 4) {
            ForEach(0..<3, id: \.self) { i in
                Circle()
                    .frame(width: 5, height: 5)
                    .opacity(phase == i ? 1 : 0.3)
            }
        }
        .foregroundStyle(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))
        .onReceive(timer) { _ in
            withAnimation(.easeInOut(duration: 0.25)) {
                phase = (phase + 1) % 3
            }
        }
    }
}

// MARK: - Live Activity (streaming)

struct LiveActivityView: View {
    let steps: [AdvisorStep]
    let liveReasoning: String

    var body: some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack(spacing: 8) {
                Image(systemName: "sparkles")
                    .font(.caption)
                    .foregroundStyle(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))
                Text("Thinking")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                ThinkingDots()
                Spacer()
            }

            ForEach(steps.filter { $0.kind == .tool }) { step in
                HStack(alignment: .top, spacing: 8) {
                    if step.done {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                    } else {
                        ProgressView().scaleEffect(0.6)
                    }
                    Text(step.text)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Spacer(minLength: 0)
                }
                .font(.caption)
            }
        }
        .padding(12)
        .frame(maxWidth: .infinity, alignment: .leading)
        .glassEffect(.regular.tint(.indigo.opacity(0.10)), in: .rect(cornerRadius: 14))
    }
}

// MARK: - Thought Process (collapsed after completion)

struct ThoughtProcessView: View {
    let steps: [AdvisorStepRecord]
    @State private var expanded = false

    var body: some View {
        DisclosureGroup(isExpanded: $expanded) {
            VStack(alignment: .leading, spacing: 6) {
                ForEach(steps) { step in
                    HStack(alignment: .top, spacing: 8) {
                        Group {
                            switch step.kind {
                            case "reasoning":
                                Image(systemName: "brain")
                                    .foregroundStyle(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))
                            case "tool":
                                Image(systemName: "checkmark.circle.fill")
                                    .foregroundStyle(.green)
                            default:
                                Image(systemName: "circle")
                                    .foregroundStyle(.secondary)
                            }
                        }
                        .font(.caption)
                        .frame(width: 16, alignment: .center)
                        Text(step.text)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                        Spacer(minLength: 0)
                    }
                }
            }
            .padding(.top, 6)
        } label: {
            Label("Thought Process", systemImage: "brain")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .tint(.secondary)
        .padding(.vertical, 6)
        .padding(.horizontal, 4)
    }
}

// MARK: - Action Row (undoable)

struct ActionRowView: View {
    let action: AdvisorAction
    let onEdit: (UUID) -> Void
    @State private var undone = false

    var body: some View {
        HStack(spacing: 10) {
            Image(systemName: undone ? "arrow.uturn.backward.circle" : "checkmark.seal.fill")
                .foregroundStyle(undone ? Color.secondary : .green)
            Text(action.summary)
                .font(.caption)
                .strikethrough(undone)
                .foregroundStyle(undone ? .secondary : .primary)
            Spacer(minLength: 0)
            if !undone {
                if let mealID = action.editTargetMealID {
                    Button {
                        onEdit(mealID)
                    } label: {
                        Image(systemName: "pencil")
                    }
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .buttonStyle(.plain)
                }
                Button("Undo") {
                    withAnimation(.spring(duration: 0.3)) {
                        action.undo()
                        undone = true
                    }
                }
                .font(.caption.weight(.semibold))
                .foregroundStyle(.orange)
                .buttonStyle(.plain)
            }
        }
        .padding(10)
        .glassEffect(.regular.tint((undone ? Color.secondary : Color.green).opacity(0.10)), in: .rect(cornerRadius: 12))
    }
}

// MARK: - Day Separator

struct DaySeparator: View {
    let date: Date

    var dateLabel: String {
        let calendar = Calendar.current
        let today = calendar.startOfDay(for: Date())
        let messageDate = calendar.startOfDay(for: date)
        let daysDiff = calendar.dateComponents([.day], from: messageDate, to: today).day ?? 0

        switch daysDiff {
        case 0: return "Today"
        case 1: return "Yesterday"
        default:
            return date.formatted(date: .abbreviated, time: .omitted)
        }
    }

    var body: some View {
        HStack {
            Spacer()
            Text(dateLabel)
                .font(.caption2)
                .foregroundStyle(.secondary)
            Spacer()
        }
        .padding(.vertical, 12)
    }
}

// MARK: - Markdown Text Helper

struct MarkdownText: View {
    let content: String

    var body: some View {
        if let attributedString = try? AttributedString(markdown: content, options: .init(interpretedSyntax: .inlineOnlyPreservingWhitespace)) {
            Text(attributedString)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        } else {
            Text(content)
                .font(.body)
                .frame(maxWidth: .infinity, alignment: .leading)
        }
    }
}

// MARK: - Meal Edit Sheet

struct MealEditSheet: View {
    let mealID: UUID
    @Environment(\.dismiss) private var dismiss

    @State private var name = ""
    @State private var calories = ""
    @State private var protein = ""
    @State private var carbs = ""
    @State private var fat = ""

    var body: some View {
        NavigationStack {
            Form {
                Section("Meal") {
                    TextField("Name", text: $name)
                }
                Section("Nutrition") {
                    field("Calories", text: $calories, unit: "kcal")
                    field("Protein", text: $protein, unit: "g")
                    field("Carbs", text: $carbs, unit: "g")
                    field("Fat", text: $fat, unit: "g")
                }
            }
            .navigationTitle("Edit Meal")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .cancellationAction) {
                    Button("Cancel") { dismiss() }
                }
                ToolbarItem(placement: .confirmationAction) {
                    Button("Save") { save(); dismiss() }
                }
            }
            .onAppear(perform: load)
            .presentationDetents([ .large])
        }
    }

    private func field(_ label: String, text: Binding<String>, unit: String) -> some View {
        HStack {
            Text(label)
            Spacer()
            TextField("0", text: text)
                .keyboardType(.decimalPad)
                .multilineTextAlignment(.trailing)
                .frame(maxWidth: 90)
            Text(unit)
                .foregroundStyle(.secondary)
        }
    }

    private func load() {
        guard let entry = FoodLogService.shared.entries.first(where: { $0.id == mealID }) else { return }
        name = entry.name
        calories = String(format: "%.0f", entry.calories)
        protein = String(format: "%.0f", entry.protein)
        carbs = String(format: "%.0f", entry.carbs)
        fat = String(format: "%.0f", entry.fat)
    }

    private func save() {
        guard var entry = FoodLogService.shared.entries.first(where: { $0.id == mealID }) else { return }
        entry.name = name.isEmpty ? entry.name : name
        entry.calories = Double(calories) ?? entry.calories
        entry.protein = Double(protein) ?? entry.protein
        entry.carbs = Double(carbs) ?? entry.carbs
        entry.fat = Double(fat) ?? entry.fat
        FoodLogService.shared.update(entry)
    }
}

// MARK: - Shimmer Text (animated gradient sheen)

/// Text with a light sheen sweeping left-to-right, used for in-progress thought labels.
struct ShimmerText: View {
    let text: String
    var font: Font = .caption.weight(.semibold)
    @State private var phase: CGFloat = -1
    @Environment(\.accessibilityReduceMotion) private var reduceMotion

    var body: some View {
        Text(text)
            .font(font)
            .lineLimit(1)
            .foregroundStyle(.secondary)
            .overlay {
                if !reduceMotion {
                    GeometryReader { geo in
                        LinearGradient(
                            colors: [.clear, .white.opacity(0.95), .clear],
                            startPoint: .leading,
                            endPoint: .trailing
                        )
                        .frame(width: geo.size.width * 0.55)
                        .offset(x: phase * geo.size.width * 1.7)
                        .blendMode(.plusLighter)
                    }
                    .mask(Text(text).font(font).lineLimit(1))
                    .allowsHitTesting(false)
                }
            }
            .onAppear {
                guard !reduceMotion else { return }
                withAnimation(.linear(duration: 1.4).repeatForever(autoreverses: false)) {
                    phase = 1
                }
            }
    }
}

// MARK: - Thinking Trail (live, no glass card)

/// The Advisor's live thought process: one row per tool step with a contextual icon,
/// shimmering while in progress and checked off when done. No container/glass.
struct ThinkingTrailView: View {
    let steps: [AdvisorStep]
    let liveReasoning: String

    private var accent: LinearGradient {
        LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing)
    }

    private var toolSteps: [AdvisorStep] {
        steps.filter { $0.kind == .tool }
    }

    private func icon(for text: String) -> String {
        let t = text.lowercased()
        if t.contains("exertion") || t.contains("load") { return "bolt.fill" }
        if t.contains("recovery") { return "heart.fill" }
        if t.contains("sleep") { return "moon.stars.fill" }
        if t.contains("stress") { return "waveform.path.ecg" }
        if t.contains("workout") || t.contains("generat") || t.contains("exercise") || t.contains("plan") || t.contains("prepar") { return "dumbbell.fill" }
        if t.contains("meal") || t.contains("nutrition") || t.contains("food") || t.contains("calor") { return "fork.knife" }
        if t.contains("analyz") || t.contains("fetch") || t.contains("read") || t.contains("check") || t.contains("look") { return "magnifyingglass" }
        return "sparkles"
    }

    var body: some View {
        VStack(alignment: .leading, spacing: 10) {
            if toolSteps.isEmpty {
                row(icon: "sparkles", text: "Thinking…", done: false)
            } else {
                ForEach(toolSteps) { step in
                    row(icon: icon(for: step.text), text: step.text, done: step.done)
                }
            }
        }
        .frame(maxWidth: .infinity, alignment: .leading)
        .padding(.vertical, 4)
        .animation(.spring(duration: 0.35), value: toolSteps.count)
    }

    @ViewBuilder
    private func row(icon: String, text: String, done: Bool) -> some View {
        HStack(alignment: .center, spacing: 10) {
            Image(systemName: icon)
                .font(.caption)
                .frame(width: 18)
                .foregroundStyle(done ? AnyShapeStyle(.secondary) : AnyShapeStyle(accent))
                .symbolEffect(.pulse, options: .repeating, isActive: !done)
            if done {
                Text(text)
                    .font(.caption.weight(.medium))
                    .lineLimit(1)
                    .foregroundStyle(.secondary)
            } else {
                ShimmerText(text: text)
            }
            Spacer(minLength: 0)
            if done {
                Image(systemName: "checkmark")
                    .font(.caption2.weight(.bold))
                    .foregroundStyle(.green.opacity(0.7))
            }
        }
        .transition(.opacity.combined(with: .move(edge: .leading)))
    }
}

// MARK: - Recommendation Card (Add / Dismiss)

/// A "Recommended by Vector" workout card the user can Add to their library or Dismiss.
struct RecommendationCardView: View {
    let recommendation: AdvisorRecommendation

    private enum CardState { case idle, added, dismissed }
    @State private var state: CardState = .idle

    private var accent: LinearGradient {
        LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    var body: some View {
        if state == .dismissed {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(accent)
                    Text("Recommended by Vector")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text(recommendation.title)
                        .font(.headline)
                    Text("\(recommendation.focus) · ~\(recommendation.durationMinutes) min · \(recommendation.exerciseCount) exercises")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                if !recommendation.exerciseNames.isEmpty {
                    Text(recommendation.exerciseNames.prefix(4).joined(separator: " · "))
                        .font(.caption2)
                        .foregroundStyle(.secondary)
                        .lineLimit(2)
                }

                if state == .added {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Added to your library")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                } else {
                    HStack(spacing: 10) {
                        Button {
                            recommendation.add()
                            withAnimation(.spring(duration: 0.35)) { state = .added }
                        } label: {
                            Text("Add")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.purple.opacity(0.15), in: .capsule)
                                .foregroundStyle(.purple)
                        }
                        .buttonStyle(.plain)

                        Button {
                            withAnimation(.spring(duration: 0.35)) { state = .dismissed }
                        } label: {
                            Text("Dismiss")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(.secondary)
                                .glassEffect(.regular, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
        }
    }
}

// MARK: - Exercise Update Card (progressive overload on existing workouts)

/// A "Recommended by Vector" card listing the user's saved workouts that contain a given exercise.
/// The user multi-selects which to bump to the next weight step, then taps Update to apply.
struct ExerciseUpdateCardView: View {
    let update: AdvisorExerciseUpdate

    @State private var selected: Set<UUID> = []
    @State private var applied = false
    @State private var dismissed = false
    @State private var didPreselect = false

    private var accent: LinearGradient {
        LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing)
    }

    private func lb(_ kg: Double) -> String { String(format: "%.0f", kg) }

    var body: some View {
        if dismissed {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 6) {
                    Image(systemName: "sparkles")
                        .font(.caption)
                        .foregroundStyle(accent)
                    Text("Recommended by Vector")
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(accent)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 4) {
                    Text("Apply Progressive Overload")
                        .font(.headline)
                    Text(applied ? "Updated your workouts" : "Bump \(update.exerciseName) to the next step in these workouts")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                VStack(spacing: 8) {
                    ForEach(update.matches) { match in
                        let isOn = selected.contains(match.id)
                        Button {
                            guard !applied else { return }
                            if isOn { selected.remove(match.id) } else { selected.insert(match.id) }
                        } label: {
                            HStack(spacing: 10) {
                                Image(systemName: (applied || isOn) ? "checkmark.circle.fill" : "circle")
                                    .foregroundStyle((applied || isOn) ? AnyShapeStyle(accent) : AnyShapeStyle(.secondary))
                                VStack(alignment: .leading, spacing: 1) {
                                    Text(match.title)
                                        .font(.subheadline.weight(.medium))
                                        .foregroundStyle(.primary)
                                    Text("\(lb(match.currentWeightKg)) → \(lb(match.newWeightKg)) lb")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }
                            .padding(10)
                            .background(RoundedRectangle(cornerRadius: 12).fill(.regularMaterial))
                        }
                        .buttonStyle(.plain)
                        .disabled(applied)
                    }
                }

                if applied {
                    HStack(spacing: 8) {
                        Image(systemName: "checkmark.circle.fill")
                            .foregroundStyle(.green)
                        Text("Updated \(selected.count) workout\(selected.count == 1 ? "" : "s")")
                            .font(.subheadline.weight(.semibold))
                        Spacer()
                    }
                } else {
                    HStack(spacing: 10) {
                        Button {
                            for match in update.matches where selected.contains(match.id) {
                                match.apply()
                            }
                            withAnimation(.spring(duration: 0.35)) { applied = true }
                        } label: {
                            Text(selected.isEmpty ? "Select workouts" : (selected.count == 1 ? "Update Workout" : "Update Workouts"))
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .background(Color.purple.opacity(0.15), in: .capsule)
                                .foregroundStyle(.purple)
                                .opacity(selected.isEmpty ? 0.5 : 1)
                        }
                        .buttonStyle(.plain)
                        .disabled(selected.isEmpty)

                        Button {
                            withAnimation(.spring(duration: 0.35)) { dismissed = true }
                        } label: {
                            Text("Dismiss")
                                .font(.subheadline.weight(.semibold))
                                .frame(maxWidth: .infinity)
                                .padding(.vertical, 10)
                                .foregroundStyle(.secondary)
                                .glassEffect(.regular, in: .capsule)
                        }
                        .buttonStyle(.plain)
                    }
                }
            }
            .padding(16)
            .background(
                RoundedRectangle(cornerRadius: 18)
                    .fill(.regularMaterial)
                    .shadow(color: .black.opacity(0.12), radius: 10, x: 0, y: 4)
            )
            .transition(.opacity.combined(with: .scale(scale: 0.96)))
            .onAppear {
                if !didPreselect {
                    didPreselect = true
                    selected = Set(update.matches.map { $0.id })
                }
            }
        }
    }
}

// MARK: - Chat Bubble Shape (rounded rect with a small tail)

/// A rounded-rectangle speech bubble with a small tail at the bottom corner on the given side.
/// The tail is contained within the shape's rect (the rounded body occupies rect minus the tail height).
struct ChatBubble: Shape {
    enum Side { case leading, trailing }
    var side: Side
    var radius: CGFloat = 16
    var tailHeight: CGFloat = 7
    var tailWidth: CGFloat = 9

    func path(in rect: CGRect) -> Path {
        let minX = rect.minX, minY = rect.minY, maxX = rect.maxX, maxY = rect.maxY
        let t = tailHeight
        let bottom = maxY - t                     // flat body bottom; the tail pokes below on one side
        let r = min(radius, min(rect.width, max(1, rect.height - t)) / 2)
        var p = Path()
        if side == .trailing {
            // Bottom-RIGHT corner becomes the tail; all other corners rounded.
            p.move(to: CGPoint(x: minX + r, y: minY))
            p.addLine(to: CGPoint(x: maxX - r, y: minY))
            p.addQuadCurve(to: CGPoint(x: maxX, y: minY + r), control: CGPoint(x: maxX, y: minY))
            p.addLine(to: CGPoint(x: maxX, y: maxY))                                   // straight down to tail tip (flush at corner)
            p.addQuadCurve(to: CGPoint(x: maxX - r, y: bottom),
                           control: CGPoint(x: maxX - r * 0.5, y: bottom + t * 0.4))   // hook back onto the bottom edge
            p.addLine(to: CGPoint(x: minX + r, y: bottom))
            p.addQuadCurve(to: CGPoint(x: minX, y: bottom - r), control: CGPoint(x: minX, y: bottom))
            p.addLine(to: CGPoint(x: minX, y: minY + r))
            p.addQuadCurve(to: CGPoint(x: minX + r, y: minY), control: CGPoint(x: minX, y: minY))
            p.closeSubpath()
        } else {
            // Bottom-LEFT corner becomes the tail; all other corners rounded.
            p.move(to: CGPoint(x: minX + r, y: minY))
            p.addLine(to: CGPoint(x: maxX - r, y: minY))
            p.addQuadCurve(to: CGPoint(x: maxX, y: minY + r), control: CGPoint(x: maxX, y: minY))
            p.addLine(to: CGPoint(x: maxX, y: bottom - r))
            p.addQuadCurve(to: CGPoint(x: maxX - r, y: bottom), control: CGPoint(x: maxX, y: bottom))
            p.addLine(to: CGPoint(x: minX + r, y: bottom))
            p.addQuadCurve(to: CGPoint(x: minX, y: maxY),
                           control: CGPoint(x: minX + r * 0.5, y: bottom + t * 0.4))   // tail tip (flush at bottom-left corner)
            p.addLine(to: CGPoint(x: minX, y: minY + r))                               // straight up the left edge from the tip
            p.addQuadCurve(to: CGPoint(x: minX + r, y: minY), control: CGPoint(x: minX, y: minY))
            p.closeSubpath()
        }
        return p
    }
}
