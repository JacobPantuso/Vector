import Foundation

enum FitnessGoal: String, CaseIterable, Codable, Sendable, Equatable {
    case fatLoss = "Fat Loss"
    case maintenance = "Maintenance"
    case muscleGain = "Muscle Gain"
    case performance = "Performance"

    var calorieAdjustment: Int {
        switch self {
        case .fatLoss:
            return -300
        case .maintenance:
            return 0
        case .muscleGain:
            return 250
        case .performance:
            return 150
        }
    }

    var subtitle: String {
        switch self {
        case .fatLoss:
            return "Lean out while protecting recovery."
        case .maintenance:
            return "Hold steady and keep energy balanced."
        case .muscleGain:
            return "Fuel growth and progressive overload."
        case .performance:
            return "Prioritize readiness and output."
        }
    }
}

enum AgeRange: String, CaseIterable, Codable, Sendable, Equatable {
    case under18 = "Under 18"
    case age18to24 = "18-24"
    case age25to34 = "25-34"
    case age35to44 = "35-44"
    case age45Plus = "45+"

    var calorieAdjustment: Int {
        switch self {
        case .under18:
            return -150
        case .age18to24:
            return 0
        case .age25to34:
            return -50
        case .age35to44:
            return -100
        case .age45Plus:
            return -150
        }
    }

    var subtitle: String {
        switch self {
        case .under18:
            return "Lower-volume guidance with extra caution."
        case .age18to24:
            return "Baseline adult profile."
        case .age25to34:
            return "Balanced targets with slightly tighter recovery."
        case .age35to44:
            return "Slightly lower calorie estimates and more recovery."
        case .age45Plus:
            return "Recovery-first defaults and conservative load."
        }
    }
}

enum BiologicalSex: String, CaseIterable, Codable, Sendable, Equatable {
    case male = "Male"
    case female = "Female"
    case unspecified = "Unspecified"
}

enum FitnessLevel: String, CaseIterable, Codable, Sendable, Equatable {
    case sedentary = "Sedentary"
    case recreational = "Recreational"
    case trained = "Trained"
    case athlete = "Athlete"

    var subtitle: String {
        switch self {
        case .sedentary: return "Little structured exercise."
        case .recreational: return "Regular activity a few days a week."
        case .trained: return "Consistent structured training."
        case .athlete: return "High-volume, performance-focused training."
        }
    }
}

enum PrimaryActivity: String, CaseIterable, Codable, Sendable, Equatable {
    case strength = "Strength"
    case endurance = "Endurance"
    case mixed = "Mixed"
}

struct UserProfile: Codable, Sendable {
    let goal: FitnessGoal
    let ageRange: AgeRange
    let trainingDaysPerWeek: Int
    let sleepTargetHours: Double
    var biologicalSex: BiologicalSex = .unspecified
    var fitnessLevel: FitnessLevel = .recreational
    var primaryActivity: PrimaryActivity = .mixed

    var calorieTargetEstimate: Int {
        max(1500, 2200 + goal.calorieAdjustment + ageRange.calorieAdjustment)
    }

    var recommendedDeficit: Int {
        switch goal {
        case .fatLoss:
            return 350
        case .maintenance:
            return 0
        case .muscleGain:
            return -200
        case .performance:
            return -100
        }
    }

    var summaryLine: String {
        "\(goal.rawValue) • \(ageRange.rawValue) • \(trainingDaysPerWeek)d/wk"
    }

    var detailLine: String {
        let balance = recommendedDeficit >= 0 ? "\(recommendedDeficit) kcal deficit" : "\(abs(recommendedDeficit)) kcal surplus"
        return "Target \(calorieTargetEstimate) kcal/day with a \(balance) focus."
    }

    static let defaultGoal = FitnessGoal.performance
    static let defaultAgeRange = AgeRange.age25to34
    static let defaultTrainingDays = 4
    static let defaultSleepTargetHours = 8.0
    static let defaultBiologicalSex = BiologicalSex.unspecified
    static let defaultFitnessLevel = FitnessLevel.recreational
    static let defaultPrimaryActivity = PrimaryActivity.mixed
}

enum UserProfileStorage {
    static let goal = "fitnessGoal"
    static let ageRange = "ageRange"
    static let trainingDays = "trainingDaysPerWeek"
    static let sleepTargetHours = "sleepTargetHours"
    static let firstName = "profileFirstName"
    static let lastName = "profileLastName"
    static let weightKg = "profileWeightKg"
    static let heightCm = "profileHeightCm"
    static let biologicalSex = "profileBiologicalSex"
    static let fitnessLevel = "profileFitnessLevel"
    static let primaryActivity = "profilePrimaryActivity"

    static let allKeys: [String] = [goal, ageRange, trainingDays, sleepTargetHours, firstName, lastName, weightKg, heightCm, biologicalSex, fitnessLevel, primaryActivity]
}

@Observable
final class ProfileCloudSync {
    private let kvStore = NSUbiquitousKeyValueStore.default
    var isSignedIntoiCloud: Bool = false

    init() {
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(storeChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(iCloudStatusChanged),
            name: NSNotification.Name(rawValue: "NSUbiquityIdentityDidChange"),
            object: nil
        )
        pullFromCloud()
        refreshiCloudStatus()
        kvStore.synchronize()
    }

    func push(key: String, value: Any?) {
        if let value {
            kvStore.set(value, forKey: key)
        } else {
            kvStore.removeObject(forKey: key)
        }
        kvStore.synchronize()
    }

    func pullFromCloud() {
        for key in UserProfileStorage.allKeys {
            if let cloudValue = kvStore.object(forKey: key) {
                UserDefaults.standard.set(cloudValue, forKey: key)
            }
        }
    }

    func pushAllLocalToCloud() {
        for key in UserProfileStorage.allKeys {
            if let value = UserDefaults.standard.object(forKey: key) {
                kvStore.set(value, forKey: key)
            }
        }
        kvStore.synchronize()
    }

    private func refreshiCloudStatus() {
        isSignedIntoiCloud = FileManager.default.ubiquityIdentityToken != nil
    }

    @objc private func iCloudStatusChanged() {
        refreshiCloudStatus()
    }

    @objc private func storeChanged(_ notification: Notification) {
        pullFromCloud()
        refreshiCloudStatus()
    }
}
