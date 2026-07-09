import SwiftUI
import HealthKit
import PhotosUI
import UIKit
import StoreKit

struct SettingsView: View {
    @State private var profileSync = ProfileCloudSync()
    @AppStorage(UserProfileStorage.firstName) private var firstName = ""
    @AppStorage(UserProfileStorage.lastName) private var lastName = ""
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.fitnessLevel) private var fitnessLevelRaw = UserProfile.defaultFitnessLevel.rawValue
    @AppStorage("firstLaunchDate") private var firstLaunchEpoch: Double = 0
    @State private var photoData: Data?
    @Environment(\.requestReview) var requestReview

    private var displayName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Your Profile" : name
    }

    private var memberText: String {
        guard firstLaunchEpoch > 0 else { return "New member" }
        let days = Int(Date().timeIntervalSince1970 - firstLaunchEpoch) / 86400
        return days < 1 ? "Joined today" : "Member for \(days) day\(days == 1 ? "" : "s")"
    }

    var body: some View {
        NavigationStack {
            List {
                // MARK: - Profile Header
                Section {
                    NavigationLink {
                        ProfilePageView(profileSync: profileSync, photoData: $photoData)
                    } label: {
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 16) {
                                ZStack {
                                    if let photoData, let ui = UIImage(data: photoData) {
                                        Image(uiImage: ui).resizable().scaledToFill()
                                    } else {
                                        Circle().fill(.secondary.opacity(0.2))
                                        Image(systemName: "person.fill").font(.title).foregroundStyle(.secondary)
                                    }
                                }
                                .frame(width: 64, height: 64)
                                .clipShape(Circle())
                                .overlay(Circle().stroke(VectorTheme.brandForeground, lineWidth: 1))

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(displayName).font(.headline)
                                    Text(memberText).font(.caption).foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                        }
                        .padding(.vertical, 4)
                    }
                }

                // MARK: - Profile Section
                Section("Profile") {
                    NavigationLink {
                        PersonalDetailsView()
                    } label: {
                        iconTile(icon: "person.text.rectangle", color: .blue) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Personal Details")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Name & body metrics")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        TrainingGoalsView()
                    } label: {
                        iconTile(icon: "figure.run", color: .orange) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Training & Goals")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Fitness targets & sleep")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }

                    NavigationLink {
                        FitnessProfileView()
                    } label: {
                        iconTile(icon: "heart.text.square", color: .pink) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Fitness Profile")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Level & activity type")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // MARK: - Health Section
                Section("Health") {
                    NavigationLink {
                        HealthDevicesSettingsView()
                    } label: {
                        iconTile(icon: "heart.fill", color: .red) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Health & Devices")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("HealthKit & Apple Watch")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // MARK: - Intelligence Section
                Section("Intelligence") {
                    NavigationLink {
                        AISettingsView()
                    } label: {
                        iconTile(icon: "sparkles", color: .indigo) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Vector Intelligence")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Apple Intelligence settings")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // MARK: - App Section
                Section("App") {
                    NavigationLink {
                        AppSettingsView()
                    } label: {
                        iconTile(icon: "gearshape.fill", color: .gray) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("App Settings")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Notifications & developer")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }

                // MARK: - Support Section
                Section("Support") {
                    Button {
                        requestReview()
                    } label: {
                        iconTile(icon: "star.fill", color: .yellow) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Rate Vector")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Share your feedback")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .buttonStyle(.plain)

                    ShareLink(item: "Check out Vector — turn your health data into daily recovery, sleep, and training scores.", label: {
                        iconTile(icon: "square.and.arrow.up", color: .teal) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Share Vector")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Tell a friend")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    })
                    .buttonStyle(.plain)

                    NavigationLink {
                        SupportSettingsView()
                    } label: {
                        iconTile(icon: "ladybug.fill", color: .green) {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("Report a Bug")
                                    .font(.subheadline)
                                    .fontWeight(.semibold)
                                Text("Send feedback")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                }
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .gradientHeader(base: Color(.systemGray6))
            .listStyle(.insetGrouped)
            .navigationTitle("Profile & Settings")
            .onAppear {
                profileSync.pullFromCloud()
                photoData = ProfilePhotoStore.load()
                if firstLaunchEpoch == 0 { firstLaunchEpoch = Date().timeIntervalSince1970 }
            }
        }
    }

    private func iconTile<Content: View>(icon: String, color: Color, @ViewBuilder content: () -> Content) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(color)
                .frame(width: 29, height: 29)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

            content()
            Spacer()
        }
    }
}

// MARK: - ChipFlowLayout for wrapping chips
private struct ChipFlowLayout: Layout {
    var vSpacing: CGFloat = 8
    var hSpacing: CGFloat = 8

    func sizeThatFits(proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) -> CGSize {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        return result.size
    }

    func placeSubviews(in bounds: CGRect, proposal: ProposedViewSize, subviews: Subviews, cache: inout ()) {
        let result = computeLayout(proposal: proposal, subviews: subviews)
        for (index, position) in result.positions.enumerated() {
            subviews[index].place(
                at: CGPoint(x: bounds.minX + position.x, y: bounds.minY + position.y),
                proposal: .unspecified
            )
        }
    }

    private struct LayoutResult {
        var size: CGSize
        var positions: [CGPoint]
    }

    private func computeLayout(proposal: ProposedViewSize, subviews: Subviews) -> LayoutResult {
        let maxWidth = proposal.width ?? .infinity
        var positions: [CGPoint] = []
        var currentX: CGFloat = 0
        var currentY: CGFloat = 0
        var lineHeight: CGFloat = 0
        var totalSize: CGSize = .zero

        for subview in subviews {
            let size = subview.sizeThatFits(.unspecified)

            if currentX + size.width > maxWidth, currentX > 0 {
                currentX = 0
                currentY += lineHeight + vSpacing
                lineHeight = 0
            }

            positions.append(CGPoint(x: currentX, y: currentY))
            lineHeight = max(lineHeight, size.height)
            currentX += size.width + hSpacing
            totalSize.width = max(totalSize.width, currentX - hSpacing)
        }

        totalSize.height = currentY + lineHeight
        return LayoutResult(size: totalSize, positions: positions)
    }
}

// MARK: - FlowLayout wrapper for backward compatibility
private struct FlowLayout<Content: View>: View {
    let spacing: CGFloat
    let hSpacing: CGFloat
    let content: Content

    init(spacing: CGFloat = 8, hSpacing: CGFloat = 8, @ViewBuilder content: () -> Content) {
        self.spacing = spacing
        self.hSpacing = hSpacing
        self.content = content()
    }

    var body: some View {
        ChipFlowLayout(vSpacing: spacing, hSpacing: hSpacing) {
            content
        }
    }
}

// MARK: - Personal Details View

private struct PersonalDetailsView: View {
    @AppStorage(UserProfileStorage.firstName) private var firstName = ""
    @AppStorage(UserProfileStorage.lastName) private var lastName = ""
    @AppStorage(UserProfileStorage.weightKg) private var weightKg = 0.0
    @AppStorage(UserProfileStorage.heightCm) private var heightCm = 0.0
    @State private var profileSync = ProfileCloudSync()

    var body: some View {
        List {
            Section("Identity") {
                HStack(spacing: 12) {
                    TextField("First name", text: $firstName)
                        .onChange(of: firstName) { profileSync.push(key: UserProfileStorage.firstName, value: firstName) }
                    TextField("Last name", text: $lastName)
                        .onChange(of: lastName) { profileSync.push(key: UserProfileStorage.lastName, value: lastName) }
                }
            }

            Section("Body") {
                HStack {
                    Text("Weight")
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("0", value: $weightKg, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .onChange(of: weightKg) { profileSync.push(key: UserProfileStorage.weightKg, value: weightKg) }
                        Text("kg")
                            .foregroundStyle(.secondary)
                    }
                }

                HStack {
                    Text("Height")
                    Spacer()
                    HStack(spacing: 4) {
                        TextField("0", value: $heightCm, format: .number)
                            .multilineTextAlignment(.trailing)
                            .keyboardType(.decimalPad)
                            .frame(width: 60)
                            .onChange(of: heightCm) { profileSync.push(key: UserProfileStorage.heightCm, value: heightCm) }
                        Text("cm")
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .navigationTitle("Personal Details")
    }
}

// MARK: - Training & Goals View

private struct TrainingGoalsView: View {
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.sleepTargetHours) private var sleepTargetHours = UserProfile.defaultSleepTargetHours
    @State private var profileSync = ProfileCloudSync()

    private var profile: UserProfile {
        UserProfile(
            goal: FitnessGoal(rawValue: goalRaw) ?? UserProfile.defaultGoal,
            ageRange: AgeRange(rawValue: ageRangeRaw) ?? UserProfile.defaultAgeRange,
            trainingDaysPerWeek: trainingDays,
            sleepTargetHours: sleepTargetHours,
            biologicalSex: UserProfile.defaultBiologicalSex,
            fitnessLevel: UserProfile.defaultFitnessLevel,
            primaryActivity: UserProfile.defaultPrimaryActivity
        )
    }

    var body: some View {
        List {
            Section("Fitness Goals") {
                Picker("Goal", selection: $goalRaw) {
                    ForEach(FitnessGoal.allCases, id: \.rawValue) { goal in
                        Text(goal.rawValue).tag(goal.rawValue)
                    }
                }
                .onChange(of: goalRaw) { profileSync.push(key: UserProfileStorage.goal, value: goalRaw) }

                if let goal = FitnessGoal(rawValue: goalRaw) {
                    Text(goal.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Age Range") {
                Picker("Age Range", selection: $ageRangeRaw) {
                    ForEach(AgeRange.allCases, id: \.rawValue) { ageRange in
                        Text(ageRange.rawValue).tag(ageRange.rawValue)
                    }
                }
                .onChange(of: ageRangeRaw) { profileSync.push(key: UserProfileStorage.ageRange, value: ageRangeRaw) }

                if let ageRange = AgeRange(rawValue: ageRangeRaw) {
                    Text(ageRange.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Training") {
                Stepper("Training Days: \(trainingDays)/week", value: $trainingDays, in: 1...7)
                    .onChange(of: trainingDays) { profileSync.push(key: UserProfileStorage.trainingDays, value: trainingDays) }

                Stepper(String(format: "Sleep Target: %.1f h", sleepTargetHours), value: $sleepTargetHours, in: 4...12, step: 0.5)
                    .onChange(of: sleepTargetHours) { profileSync.push(key: UserProfileStorage.sleepTargetHours, value: sleepTargetHours) }

                HStack {
                    Text("Estimated Calories")
                    Spacer()
                    Text("\(profile.calorieTargetEstimate) kcal")
                        .foregroundStyle(.secondary)
                }
            }
        }
        .navigationTitle("Training & Goals")
    }
}

// MARK: - Fitness Profile View

private struct FitnessProfileView: View {
    @AppStorage(UserProfileStorage.biologicalSex) private var biologicalSexRaw = UserProfile.defaultBiologicalSex.rawValue
    @AppStorage(UserProfileStorage.fitnessLevel) private var fitnessLevelRaw = UserProfile.defaultFitnessLevel.rawValue
    @AppStorage(UserProfileStorage.primaryActivity) private var primaryActivityRaw = UserProfile.defaultPrimaryActivity.rawValue
    @State private var profileSync = ProfileCloudSync()

    var body: some View {
        List {
            Section("Biological Sex") {
                Picker("Biological Sex", selection: $biologicalSexRaw) {
                    ForEach(BiologicalSex.allCases, id: \.rawValue) { item in
                        Text(item.rawValue).tag(item.rawValue)
                    }
                }
                .onChange(of: biologicalSexRaw) { profileSync.push(key: UserProfileStorage.biologicalSex, value: biologicalSexRaw) }
            }

            Section("Fitness Level") {
                Picker("Fitness Level", selection: $fitnessLevelRaw) {
                    ForEach(FitnessLevel.allCases, id: \.rawValue) { item in
                        Text(item.rawValue).tag(item.rawValue)
                    }
                }
                .onChange(of: fitnessLevelRaw) { profileSync.push(key: UserProfileStorage.fitnessLevel, value: fitnessLevelRaw) }

                if let level = FitnessLevel(rawValue: fitnessLevelRaw) {
                    Text(level.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Primary Activity") {
                Picker("Primary Activity", selection: $primaryActivityRaw) {
                    ForEach(PrimaryActivity.allCases, id: \.rawValue) { item in
                        Text(item.rawValue).tag(item.rawValue)
                    }
                }
                .onChange(of: primaryActivityRaw) { profileSync.push(key: UserProfileStorage.primaryActivity, value: primaryActivityRaw) }
            }
        }
        .navigationTitle("Fitness Profile")
    }
}

// MARK: - Health & Devices Settings Detail View

private struct HealthDevicesSettingsView: View {
    @Environment(HealthKitService.self) var healthService
    @Environment(WatchSyncService.self) var watchSync
    @State private var isRefreshingHealth = false

    var body: some View {
        List {
            Section {
                VStack(spacing: 12) {
                    Image(systemName: "applewatch")
                        .font(.system(size: 80, weight: .thin))
                        .foregroundStyle(watchSync.isPaired
                            ? AnyShapeStyle(LinearGradient(colors: [.cyan, .indigo], startPoint: .top, endPoint: .bottom))
                            : AnyShapeStyle(Color.secondary))
                        .padding(.vertical, 8)
                    Text(watchSync.isPaired ? "Apple Watch Connected" : "No Apple Watch Paired")
                        .font(.headline)
                    Text(watchSync.isPaired
                        ? (watchSync.isReachable ? "Active connection" : "Connected in background")
                        : "Pair an Apple Watch to track workouts and recovery on your wrist.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                }
                .frame(maxWidth: .infinity)
                .padding(.vertical, 8)
                .listRowBackground(Color.clear)
            }

            Section("Health Data") {
                Button {
                    isRefreshingHealth = true
                    Task {
                        await healthService.requestAuthorization()
                        await healthService.refreshToday()
                        isRefreshingHealth = false
                    }
                } label: {
                    HStack {
                        Label("Refresh Health Access", systemImage: "heart.fill")
                            .foregroundStyle(.red)
                        Spacer()
                        if isRefreshingHealth {
                            ProgressView()
                        } else {
                            Text(healthService.isAuthorized ? "Connected" : "Reconnect")
                                .foregroundStyle(.secondary)
                        }
                    }
                }
                .buttonStyle(.plain)

                Text("Vector uses HealthKit to tailor recovery, sleep, and calorie guidance.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Section("Apple Watch") {
                HStack {
                    Label("Watch Paired", systemImage: "applewatch")
                    Spacer()
                    Text(watchSync.isPaired ? "Yes" : "No")
                        .foregroundStyle(watchSync.isPaired ? .primary : .secondary)
                }

                if watchSync.isPaired {
                    HStack {
                        Label("App Installed", systemImage: "app.badge.checkmark")
                        Spacer()
                        Text(watchSync.isWatchAppInstalled ? "Yes" : "No")
                            .foregroundStyle(watchSync.isWatchAppInstalled ? .green : .secondary)
                    }

                    HStack {
                        Label("Connection", systemImage: "wifi")
                        Spacer()
                        HStack(spacing: 6) {
                            Circle()
                                .fill(watchSync.isReachable ? Color.green : Color.orange)
                                .frame(width: 8, height: 8)
                            Text(watchSync.isReachable ? "Active" : "Background")
                                .foregroundStyle(.secondary)
                        }
                    }

                    Button {
                        NotificationCenter.default.post(name: .watchRequestedSync, object: nil)
                    } label: {
                        Label("Sync Now", systemImage: "arrow.triangle.2.circlepath")
                    }
                }
            }
        }
        .navigationTitle("Health & Devices")
        .task {
            healthService.refreshAuthorizationStatus()
        }
    }
}

// MARK: - AI Settings Detail View

private struct AISettingsView: View {
    @State private var insightEngine = InsightEngine()
    @AppStorage(AdvisorPersona.storageKey) private var advisorPersonaRaw = AdvisorPersona.trainer.rawValue

    var body: some View {
        List {
            Section("Apple Intelligence") {
                HStack {
                    Text("Status")
                    Spacer()
                    Text(insightEngine.isOnDeviceAvailable ? "Ready" : "Unavailable")
                        .foregroundStyle(insightEngine.isOnDeviceAvailable ? .green : .secondary)
                }
                Text("When Apple Intelligence is unavailable, Vector falls back to guided coaching.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Section("Vector Intelligence") {
                Picker("Tone", selection: $advisorPersonaRaw) {
                    ForEach(AdvisorPersona.allCases, id: \.rawValue) { persona in
                        Text(persona.rawValue).tag(persona.rawValue)
                    }
                }
                Text("Shapes how Vector communicates: like a coach, a friend, encouraging, or direct.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .navigationTitle("Vector Intelligence")
    }
}

// MARK: - App Settings Detail View

private struct AppSettingsView: View {
    @AppStorage("hasCompletedOnboarding") private var hasCompletedOnboarding = false
    @AppStorage("devModeEnabled") private var devModeEnabled = false
    @AppStorage(NotificationSettings.enabledKey) private var notificationsEnabled = false
    @State private var notifyTime = Date()
    @State private var insightEngine = InsightEngine()
    @Environment(WatchSyncService.self) private var watchSync
    @State private var notifAuthorized = false

    var body: some View {
        List {
            Section("Notifications") {
                Toggle(isOn: $notificationsEnabled) {
                    Label("Morning Briefing", systemImage: "bell.fill")
                }
                .onChange(of: notificationsEnabled) { _, on in
                    if on {
                        Task {
                            _ = await NotificationService.shared.requestAuthorization()
                        }
                    }
                }

                if notificationsEnabled {
                    DatePicker("Briefing time", selection: $notifyTime, displayedComponents: .hourAndMinute)
                        .onChange(of: notifyTime) {
                            let comps = Calendar.current.dateComponents([.hour, .minute], from: notifyTime)
                            if let h = comps.hour {
                                UserDefaults.standard.set(h, forKey: NotificationSettings.hourKey)
                            }
                            if let m = comps.minute {
                                UserDefaults.standard.set(m, forKey: NotificationSettings.minuteKey)
                            }
                        }

                    Text("Fires near your wake time and is skipped on days when nothing meaningful changed.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            Section("Onboarding") {
                Button {
                    hasCompletedOnboarding = false
                } label: {
                    Label("Replay Onboarding", systemImage: "arrow.counterclockwise")
                }
            }

            Section("Developer") {
                Toggle(isOn: $devModeEnabled) {
                    Label("Dev Mode", systemImage: "hammer.fill")
                }
                if devModeEnabled {
                    Text("When Dev Mode is on, workouts won't be saved to Health, workout history, or progression.")
                        .font(.caption)
                        .foregroundStyle(.orange)
                }
            }

            Section("Device Capabilities") {
                capabilityRow("Apple Intelligence", insightEngine.isOnDeviceAvailable)
                capabilityRow("Apple Health", HKHealthStore.isHealthDataAvailable())
                capabilityRow("Notifications", notifAuthorized)
                capabilityRow("Apple Watch", watchSync.isPaired)
            }

            Section("About") {
                HStack {
                    Text("Version")
                    Spacer()
                    Text("1.0")
                        .foregroundStyle(.secondary)
                }

                Label("Open Source", systemImage: "book.fill")
                    .foregroundStyle(.cyan)
            }
        }
        .navigationTitle("App Settings")
        .onAppear {
            let h = UserDefaults.standard.object(forKey: NotificationSettings.hourKey) as? Int ?? NotificationSettings.defaultHour
            let m = UserDefaults.standard.object(forKey: NotificationSettings.minuteKey) as? Int ?? NotificationSettings.defaultMinute
            var comps = DateComponents()
            comps.hour = h
            comps.minute = m
            notifyTime = Calendar.current.date(from: comps) ?? Date()
        }
        .task {
            notifAuthorized = await NotificationService.shared.authorizationStatus() == .authorized
        }
    }

    private func capabilityRow(_ label: String, _ available: Bool) -> some View {
        HStack {
            Text(label)
            Spacer()
            Image(systemName: available ? "checkmark.circle.fill" : "xmark.circle")
                .foregroundStyle(available ? .green : .secondary)
        }
    }
}

// MARK: - Support Settings Detail View

private struct SupportSettingsView: View {
    var body: some View {
        List {
            Section {
                Label("Vector is a TestFlight beta. Bug reports and feedback go straight to the developer through TestFlight — no email needed.", systemImage: "ladybug.fill")
                    .foregroundStyle(.green)
                    .font(.subheadline)
            }

            Section("Option 1: Screenshot") {
                supportStep(number: 1, icon: "camera.fill", color: .blue, title: "Take a screenshot", subtitle: "Press the side button and volume-up button together anywhere in Vector.")
                supportStep(number: 2, icon: "square.and.pencil", color: .indigo, title: "Open the screenshot editor", subtitle: "Tap the thumbnail that appears in the corner of the screen.")
                supportStep(number: 3, icon: "arrowshape.turn.up.right.fill", color: .teal, title: "Share Beta Feedback", subtitle: "Scroll the share sheet options and tap \"Share Beta Feedback,\" then describe the issue.")
            }

            Section("Option 2: TestFlight App") {
                supportStep(number: 1, icon: "testtube.2", color: .purple, title: "Open TestFlight", subtitle: "Find Vector in your list of installed beta apps.")
                supportStep(number: 2, icon: "bubble.left.and.exclamationmark.bubble.right.fill", color: .orange, title: "Send Beta Feedback", subtitle: "Tap Vector, then \"Send Beta Feedback\" to write up what happened.")
            }
        }
        .navigationTitle("Report a Bug")
    }

    private func supportStep(number: Int, icon: String, color: Color, title: String, subtitle: String) -> some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 7)
                .fill(color)
                .frame(width: 29, height: 29)
                .overlay {
                    Image(systemName: icon)
                        .font(.system(size: 14, weight: .semibold))
                        .foregroundStyle(.white)
                }

            VStack(alignment: .leading, spacing: 2) {
                Text("\(number). \(title)")
                    .font(.subheadline)
                    .fontWeight(.semibold)
                Text(subtitle)
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Spacer()
        }
        .padding(.vertical, 2)
    }
}

// MARK: - Profile Page View

private struct ProfilePageView: View {
    let profileSync: ProfileCloudSync
    @Binding var photoData: Data?
    @State private var photoItem: PhotosPickerItem?
    @Environment(\.openURL) private var openURL

    @AppStorage(UserProfileStorage.firstName) private var firstName = ""
    @AppStorage(UserProfileStorage.lastName) private var lastName = ""
    @AppStorage(UserProfileStorage.weightKg) private var weightKg = 0.0
    @AppStorage(UserProfileStorage.heightCm) private var heightCm = 0.0
    @AppStorage(UserProfileStorage.goal) private var goalRaw = UserProfile.defaultGoal.rawValue
    @AppStorage(UserProfileStorage.ageRange) private var ageRangeRaw = UserProfile.defaultAgeRange.rawValue
    @AppStorage(UserProfileStorage.trainingDays) private var trainingDays = UserProfile.defaultTrainingDays
    @AppStorage(UserProfileStorage.sleepTargetHours) private var sleepTargetHours = UserProfile.defaultSleepTargetHours
    @AppStorage(UserProfileStorage.biologicalSex) private var biologicalSexRaw = UserProfile.defaultBiologicalSex.rawValue
    @AppStorage(UserProfileStorage.fitnessLevel) private var fitnessLevelRaw = UserProfile.defaultFitnessLevel.rawValue
    @AppStorage(UserProfileStorage.primaryActivity) private var primaryActivityRaw = UserProfile.defaultPrimaryActivity.rawValue
    @AppStorage("firstLaunchDate") private var firstLaunchEpoch: Double = 0

    var body: some View {
        ScrollView {
            VStack(spacing: 20) {
                // MARK: Hero Section
                VStack(spacing: 12) {
                    PhotosPicker(selection: $photoItem, matching: .images) {
                        ZStack {
                            if let photoData, let ui = UIImage(data: photoData) {
                                Image(uiImage: ui).resizable().scaledToFill()
                            } else {
                                Circle().fill(.secondary.opacity(0.2))
                                Image(systemName: "person.fill").font(.system(size: 44)).foregroundStyle(.secondary)
                            }
                        }
                        .frame(width: 110, height: 110)
                        .clipShape(Circle())
                        .overlay(Circle().stroke(VectorTheme.brandForeground, lineWidth: 2))
                        .overlay(alignment: .bottomTrailing) {
                            ZStack {
                                Circle().fill(Color(.systemBackground))
                                Image(systemName: "camera.fill")
                                    .font(.system(size: 12, weight: .semibold))
                                    .foregroundStyle(VectorTheme.brandForeground)
                            }
                            .frame(width: 32, height: 32)
                        }
                    }
                    .buttonStyle(.plain)

                    Text(displayName)
                        .font(.largeTitle.bold())

                    Text(memberText)
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding(.top, 20)
                .padding(.horizontal, 20)

                // MARK: iCloud Status Pill
                Group {
                    if profileSync.isSignedIntoiCloud {
                        HStack(spacing: 8) {
                            Image(systemName: "checkmark.icloud.fill")
                                .foregroundStyle(.cyan)
                            Text("iCloud Sync Enabled")
                                .font(.subheadline.weight(.semibold))
                                .foregroundStyle(.primary)
                        }
                        .padding(.horizontal, 16)
                        .padding(.vertical, 10)
                        .background(.cyan.opacity(0.15), in: Capsule())
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 20)
                    } else {
                        Button {
                            if let url = URL(string: UIApplication.openSettingsURLString) {
                                openURL(url)
                            }
                        } label: {
                            HStack(spacing: 12) {
                                Image(systemName: "icloud.slash.fill")
                                    .font(.system(size: 16, weight: .semibold))
                                    .foregroundStyle(.secondary)
                                    .frame(width: 36, height: 36)
                                    .background(.secondary.opacity(0.15), in: Circle())

                                VStack(alignment: .leading, spacing: 2) {
                                    Text("iCloud Sync is Off")
                                        .font(.subheadline.weight(.semibold))
                                        .foregroundStyle(.primary)
                                    Text("Your profile won't back up across devices")
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }

                                Spacer(minLength: 8)

                                Text("Enable")
                                    .font(.caption.weight(.semibold))
                                    .foregroundStyle(.white)
                                    .padding(.horizontal, 12)
                                    .padding(.vertical, 6)
                                    .background(VectorTheme.brandForeground, in: Capsule())
                            }
                            .padding(12)
                            .background {
                                RoundedRectangle(cornerRadius: 18, style: .continuous)
                                    .fill(.secondary.opacity(0.08))
                                    .overlay {
                                        RoundedRectangle(cornerRadius: 18, style: .continuous)
                                            .stroke(.secondary.opacity(0.15), lineWidth: 1)
                                    }
                            }
                        }
                        .buttonStyle(.plain)
                        .frame(maxWidth: .infinity, alignment: .center)
                        .padding(.horizontal, 20)
                    }
                }

                // MARK: Baselines Header
                VStack(alignment: .leading, spacing: 4) {
                    Text("Configured Baselines")
                        .font(.title3.bold())
                    Text("Baselines computed based on your historical and entered data.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                .frame(maxWidth: .infinity, alignment: .leading)
                .padding(.horizontal, 20)

                // MARK: Stats Grid
                LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
                    statTile(icon: "target", label: "Goal", value: goal.rawValue, tint: .orange)
                    statTile(icon: "figure.strengthtraining.traditional", label: "Fitness Level", value: level.rawValue, tint: .pink)
                    statTile(icon: "calendar", label: "Training Days", value: "\(trainingDays)/wk", tint: .blue)
                    statTile(icon: "bed.double.fill", label: "Sleep Target", value: String(format: "%.1f h", sleepTargetHours), tint: .purple)
                    statTile(icon: "figure.run", label: "Primary Activity", value: activity.rawValue, tint: .indigo)
                    statTile(icon: "flame.fill", label: "Est. Calories", value: "\(profile.calorieTargetEstimate) kcal", tint: .red)
                    statTile(icon: "scalemass.fill", label: "Weight", value: weightKg > 0 ? "\(Int(weightKg)) kg" : "—", tint: .cyan)
                    statTile(icon: "ruler.fill", label: "Height", value: heightCm > 0 ? "\(Int(heightCm)) cm" : "—", tint: .teal)
                }
                .padding(.horizontal, 20)

                Spacer(minLength: 20)
            }
        }
        .gradientHeader()
        .navigationTitle("Profile")
        .navigationBarTitleDisplayMode(.inline)
        .onChange(of: photoItem) {
            Task {
                if let data = try? await photoItem?.loadTransferable(type: Data.self) {
                    photoData = data
                    ProfilePhotoStore.save(data)
                }
            }
        }
    }

    private var displayName: String {
        let name = "\(firstName) \(lastName)".trimmingCharacters(in: .whitespaces)
        return name.isEmpty ? "Your Profile" : name
    }

    private var memberText: String {
        guard firstLaunchEpoch > 0 else { return "New member" }
        let days = Int(Date().timeIntervalSince1970 - firstLaunchEpoch) / 86400
        return days < 1 ? "Joined today" : "Member for \(days) day\(days == 1 ? "" : "s")"
    }

    private var profile: UserProfile {
        UserProfile(
            goal: goal,
            ageRange: ageRange,
            trainingDaysPerWeek: trainingDays,
            sleepTargetHours: sleepTargetHours,
            biologicalSex: biologicalSex,
            fitnessLevel: level,
            primaryActivity: activity
        )
    }

    private var goal: FitnessGoal {
        FitnessGoal(rawValue: goalRaw) ?? UserProfile.defaultGoal
    }

    private var ageRange: AgeRange {
        AgeRange(rawValue: ageRangeRaw) ?? UserProfile.defaultAgeRange
    }

    private var biologicalSex: BiologicalSex {
        BiologicalSex(rawValue: biologicalSexRaw) ?? UserProfile.defaultBiologicalSex
    }

    private var level: FitnessLevel {
        FitnessLevel(rawValue: fitnessLevelRaw) ?? UserProfile.defaultFitnessLevel
    }

    private var activity: PrimaryActivity {
        PrimaryActivity(rawValue: primaryActivityRaw) ?? UserProfile.defaultPrimaryActivity
    }

    private func statTile(icon: String, label: String, value: String, tint: Color) -> some View {
        GlassCard {
            VStack(alignment: .leading, spacing: 8) {
                HStack(spacing: 8) {
                    Image(systemName: icon)
                        .font(.title3)
                        .foregroundStyle(tint)
                    Spacer()
                }

                VStack(alignment: .leading, spacing: 2) {
                    Text(value)
                        .font(.headline)
                    Text(label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }
        }
    }
}

#Preview {
    SettingsView()
}
