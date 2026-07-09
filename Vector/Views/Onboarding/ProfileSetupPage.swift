import SwiftUI

struct ProfileSetupPage: View {
    var onContinue: () -> Void

    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.sleepTargetHours) private var sleepTargetHours = UserProfile.defaultSleepTargetHours
    @AppStorage(UserProfileStorage.firstName) private var firstName = ""
    @AppStorage(UserProfileStorage.biologicalSex) private var biologicalSexRaw = UserProfile.defaultBiologicalSex.rawValue
    @AppStorage(UserProfileStorage.fitnessLevel) private var fitnessLevelRaw = UserProfile.defaultFitnessLevel.rawValue

    private let goalColumns = [GridItem(.flexible()), GridItem(.flexible())]
    private let ageColumns = [GridItem(.flexible()), GridItem(.flexible())]
    private let sexColumns = [GridItem(.flexible()), GridItem(.flexible())]
    private let fitnessColumns = [GridItem(.flexible()), GridItem(.flexible())]

    private var profile: UserProfile {
        UserProfile(
            goal: FitnessGoal(rawValue: goalRaw) ?? UserProfile.defaultGoal,
            ageRange: AgeRange(rawValue: ageRangeRaw) ?? UserProfile.defaultAgeRange,
            trainingDaysPerWeek: trainingDays,
            sleepTargetHours: sleepTargetHours,
            biologicalSex: BiologicalSex(rawValue: biologicalSexRaw) ?? UserProfile.defaultBiologicalSex,
            fitnessLevel: FitnessLevel(rawValue: fitnessLevelRaw) ?? UserProfile.defaultFitnessLevel
        )
    }

    var body: some View {
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Text("About You")
                        .font(.title.bold())

                    Text("These choices help Vector estimate calorie needs, recovery, and training load.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .padding(.top, 24)

            VStack(alignment: .leading, spacing: 12) {
                Text("Your name")
                    .font(.headline)
                TextField("First name", text: $firstName)
                    .textFieldStyle(.plain)
                    .font(.subheadline)
                    .padding()
                    .glassEffect(in: .rect(cornerRadius: 14))
                    .textContentType(.givenName)
                    .autocorrectionDisabled()
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 18) {
                Text("Primary goal")
                    .font(.headline)

                LazyVGrid(columns: goalColumns, spacing: 12) {
                    ForEach(FitnessGoal.allCases, id: \.rawValue) { goal in
                        goalButton(goal)
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 18) {
                Text("Age range")
                    .font(.headline)

                LazyVGrid(columns: ageColumns, spacing: 12) {
                    ForEach(AgeRange.allCases, id: \.rawValue) { ageRange in
                        ageButton(ageRange)
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 18) {
                Text("Biological sex")
                    .font(.headline)

                LazyVGrid(columns: sexColumns, spacing: 12) {
                    ForEach(BiologicalSex.allCases, id: \.rawValue) { sex in
                        sexButton(sex)
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 18) {
                Text("Fitness level")
                    .font(.headline)

                LazyVGrid(columns: fitnessColumns, spacing: 12) {
                    ForEach(FitnessLevel.allCases, id: \.rawValue) { level in
                        fitnessButton(level)
                    }
                }
            }
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 12) {
                HStack {
                    Text("Training days")
                        .font(.headline)
                    Spacer()
                    Text("\(trainingDays)/week")
                        .font(.subheadline.bold())
                        .foregroundStyle(.secondary)
                }

                Stepper(value: $trainingDays, in: 1...7) {
                    Text("Weekly sessions")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16))
            .padding(.horizontal)

            VStack(alignment: .leading, spacing: 14) {
                Text("Your Estimate")
                    .font(.headline)

                Text(profile.detailLine)
                    .font(.subheadline)
                    .foregroundStyle(.secondary)

                Divider().opacity(0.3)

                Text("Daily Macro Targets")
                    .font(.subheadline.weight(.semibold))

                HStack(spacing: 12) {
                    macroTile(label: "Protein", value: "\(proteinGrams)g", color: .red)
                    macroTile(label: "Carbs", value: "\(carbGrams)g", color: .orange)
                    macroTile(label: "Fat", value: "\(fatGrams)g", color: .yellow)
                }

                HStack(spacing: 6) {
                    Image(systemName: "info.circle")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                    Text("Estimates based on your goal and age range. Adjust as needed.")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                }
            }
            .padding()
            .glassEffect(in: .rect(cornerRadius: 16))
            .padding(.horizontal)
            }
            .padding(.bottom, 140)
            .frame(minHeight: geo.size.height)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        }
    }

    private var proteinGrams: Int {
        let cals = Double(profile.calorieTargetEstimate)
        switch profile.goal {
        case .muscleGain: return Int(cals * 0.30 / 4)
        case .fatLoss: return Int(cals * 0.35 / 4)
        case .performance: return Int(cals * 0.25 / 4)
        case .maintenance: return Int(cals * 0.25 / 4)
        }
    }

    private var carbGrams: Int {
        let cals = Double(profile.calorieTargetEstimate)
        switch profile.goal {
        case .muscleGain: return Int(cals * 0.45 / 4)
        case .fatLoss: return Int(cals * 0.35 / 4)
        case .performance: return Int(cals * 0.50 / 4)
        case .maintenance: return Int(cals * 0.45 / 4)
        }
    }

    private var fatGrams: Int {
        let cals = Double(profile.calorieTargetEstimate)
        switch profile.goal {
        case .muscleGain: return Int(cals * 0.25 / 9)
        case .fatLoss: return Int(cals * 0.30 / 9)
        case .performance: return Int(cals * 0.25 / 9)
        case .maintenance: return Int(cals * 0.30 / 9)
        }
    }

    private func macroTile(label: String, value: String, color: Color) -> some View {
        VStack(spacing: 4) {
            Text(value)
                .font(.subheadline.bold().monospacedDigit())
            Text(label)
                .font(.caption2)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 10)
        .glassEffect(.regular.tint(color.opacity(0.2)), in: .rect(cornerRadius: 12))
    }

    private func goalButton(_ goal: FitnessGoal) -> some View {
        let isSelected = goalRaw == goal.rawValue
        return Button {
            goalRaw = goal.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(goal.rawValue)
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .secondary)
                }

                Text(goal.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .glassEffect(.regular.tint(isSelected ? .cyan.opacity(0.35) : .white.opacity(0.08)), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func ageButton(_ ageRange: AgeRange) -> some View {
        let isSelected = ageRangeRaw == ageRange.rawValue
        return Button {
            ageRangeRaw = ageRange.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(ageRange.rawValue)
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .secondary)
                }

                Text(ageRange.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .glassEffect(.regular.tint(isSelected ? .purple.opacity(0.35) : .white.opacity(0.08)), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func sexButton(_ sex: BiologicalSex) -> some View {
        let isSelected = biologicalSexRaw == sex.rawValue
        return Button {
            biologicalSexRaw = sex.rawValue
        } label: {
            VStack(alignment: .center, spacing: 8) {
                HStack {
                    Text(sex.rawValue)
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .secondary)
                }

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .glassEffect(.regular.tint(isSelected ? .cyan.opacity(0.35) : .white.opacity(0.08)), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func fitnessButton(_ level: FitnessLevel) -> some View {
        let isSelected = fitnessLevelRaw == level.rawValue
        return Button {
            fitnessLevelRaw = level.rawValue
        } label: {
            VStack(alignment: .leading, spacing: 8) {
                HStack {
                    Text(level.rawValue)
                        .font(.subheadline.bold())
                    Spacer()
                    Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                        .foregroundStyle(isSelected ? .green : .secondary)
                }

                Text(level.subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.leading)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 96, alignment: .leading)
            .glassEffect(.regular.tint(isSelected ? .indigo.opacity(0.35) : .white.opacity(0.08)), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }
}
