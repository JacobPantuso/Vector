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

// MARK: - Suggestion Chip

struct SuggestionChip: View {
    let text: String
    let action: () -> Void

    var body: some View {
        Button(action: action) {
            HStack {
                Text(text)
                Spacer()
                Image(systemName: "arrow.up.right")
                    .foregroundStyle(.secondary)
            }
            .font(.subheadline)
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(12)
            .glassEffect(.regular.tint(.cyan.opacity(0.08)), in: .rect(cornerRadius: 12))
        }
        .buttonStyle(.plain)
    }
}

// MARK: - Empty State Hero

struct EmptyStateHero: View {
    var body: some View {
        VStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(colors: [.indigo.opacity(0.2), .cyan.opacity(0.2)], startPoint: .topLeading, endPoint: .bottomTrailing))
                    .frame(width: 60, height: 60)
                Image(systemName: "sparkles")
                    .font(.title2)
                    .foregroundStyle(LinearGradient(colors: [.indigo, .cyan], startPoint: .topLeading, endPoint: .bottomTrailing))
            }
            VStack(spacing: 6) {
                Text("Ask Vector anything")
                    .font(.title3.bold())
                Text("Vector sees your recovery, sleep, training, and nutrition — and can take action.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
        }
        .frame(maxWidth: .infinity)
        .padding(24)
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
                                Image(systemName: "sparkles")
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
            Label("How Vector did this", systemImage: "sparkles")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
        }
        .tint(.secondary)
        .padding(12)
        .glassEffect(.regular, in: .rect(cornerRadius: 14))
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
            .presentationDetents([.medium, .large])
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
