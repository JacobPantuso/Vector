import Foundation
import SwiftUI

enum TrainingLocation: String, CaseIterable, Codable, Sendable, Identifiable {
    case gym = "Gym"
    case home = "Home"
    case both = "Gym + Home"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .gym: return "dumbbell.fill"
        case .home: return "house.fill"
        case .both: return "arrow.left.arrow.right"
        }
    }

    var subtitle: String {
        switch self {
        case .gym: return "Full rack, machines, and a dumbbell ladder."
        case .home: return "Dumbbells, kettlebells, and bands."
        case .both: return "Mix between gym and home equipment."
        }
    }
}

enum EquipmentKind: String, CaseIterable, Codable, Sendable, Identifiable {
    case barbell = "Barbell"
    case dumbbell = "Dumbbell"
    case machine = "Machine"
    case cable = "Cable"
    case kettlebell = "Kettlebell"
    case band = "Band"
    case bodyweight = "Bodyweight"

    var id: String { rawValue }

    var symbol: String {
        switch self {
        case .barbell: return "figure.strengthtraining.traditional"
        case .dumbbell: return "dumbbell"
        case .machine: return "gear"
        case .cable: return "link"
        case .kettlebell: return "circle.fill"
        case .band: return "waveform"
        case .bodyweight: return "figure.walk"
        }
    }

    var supportsLoadProgression: Bool {
        switch self {
        case .band, .bodyweight: return false
        default: return true
        }
    }

    var defaultIncrementLb: Double {
        switch self {
        case .barbell: return 5
        case .dumbbell: return 5
        case .machine: return 10
        case .cable: return 5
        case .kettlebell: return 8
        case .band: return 0
        case .bodyweight: return 0
        }
    }

    var incrementOptions: [Double] {
        switch self {
        case .barbell: return [2.5, 5, 10]
        case .dumbbell: return [2.5, 5, 10]
        case .machine: return [5, 10, 15, 20]
        case .cable: return [2.5, 5, 10]
        case .kettlebell: return [4, 8, 10]
        case .band: return []
        case .bodyweight: return []
        }
    }

    var incrementBlurb: String {
        switch self {
        case .barbell: return "Plate pairs: most racks jump 5 lb per side."
        case .dumbbell: return "Most racks jump 5 lb per bell."
        case .machine: return "Stack increments vary; common steps are 5–20 lb."
        case .cable: return "Pin steps are usually 5–10 lb."
        case .kettlebell: return "Kettlebells come in 4–10 lb increments."
        case .band: return "Add reps or move up a band."
        case .bodyweight: return "Progress by adding reps or improving form."
        }
    }

    /// Maps a library exercise's equipment string + name onto a kind.
    static func classify(equipment: String, name: String) -> EquipmentKind {
        let eqLower = equipment.lowercased()
        let nameLower = name.lowercased()

        // Exact matches
        if eqLower.contains("machine") { return .machine }
        if eqLower.contains("cable") { return .cable }
        if eqLower.contains("band") { return .band }
        if eqLower.contains("kettlebell") { return .kettlebell }
        if eqLower.contains("bodyweight") || eqLower.contains("cardio") { return .bodyweight }

        // Freeweight requires inspection of name
        if eqLower.contains("freeweight") {
            if nameLower.contains("kettlebell") { return .kettlebell }
            if nameLower.contains("dumbbell") || nameLower.contains("db ") || nameLower.contains("goblet") || nameLower.contains("single-arm") {
                return .dumbbell
            }
            return .barbell
        }

        // Default to barbell for anything unrecognized
        return .barbell
    }
}

struct EquipmentPreferences: Codable, Sendable, Equatable {
    var location: TrainingLocation
    /// Increment in lb keyed by EquipmentKind.rawValue (String keys so JSON stays simple).
    var incrementsLb: [String: Double]
    /// Available EquipmentKind.rawValue values.
    var availableEquipment: Set<String>

    func increment(for kind: EquipmentKind) -> Double {
        let val = incrementsLb[kind.rawValue] ?? kind.defaultIncrementLb
        return val > 0 ? val : kind.defaultIncrementLb
    }

    func isAvailable(_ kind: EquipmentKind) -> Bool {
        // Bodyweight is always available
        if kind == .bodyweight { return true }
        return availableEquipment.contains(kind.rawValue)
    }

    mutating func setIncrement(_ value: Double, for kind: EquipmentKind) {
        incrementsLb[kind.rawValue] = value > 0 ? value : kind.defaultIncrementLb
    }

    mutating func toggle(_ kind: EquipmentKind) {
        // Never allow removing bodyweight
        if kind == .bodyweight { return }
        if availableEquipment.contains(kind.rawValue) {
            availableEquipment.remove(kind.rawValue)
        } else {
            availableEquipment.insert(kind.rawValue)
        }
    }

    var availableKinds: [EquipmentKind] {
        EquipmentKind.allCases.filter { isAvailable($0) }
    }

    var summaryLine: String {
        // Location + two most relevant loaded kinds
        let loaded = availableKinds.filter { $0.supportsLoadProgression }
        let topTwo = Array(loaded.prefix(2))

        var parts: [String] = [location.rawValue]
        for kind in topTwo {
            let inc = increment(for: kind)
            let fmt = inc.truncatingRemainder(dividingBy: 1) == 0 ? String(format: "%.0f", inc) : String(format: "%.1f", inc)
            parts.append("\(kind.rawValue) \(fmt) lb")
        }
        return parts.joined(separator: " • ")
    }

    static let `default`: EquipmentPreferences = {
        var prefs = EquipmentPreferences(
            location: .gym,
            incrementsLb: [:],
            availableEquipment: Set(EquipmentKind.allCases.map { $0.rawValue })
        )
        for kind in EquipmentKind.allCases {
            prefs.incrementsLb[kind.rawValue] = kind.defaultIncrementLb
        }
        return prefs
    }()

    static func preset(for location: TrainingLocation) -> EquipmentPreferences {
        let availableKinds: [EquipmentKind]
        switch location {
        case .gym:
            availableKinds = EquipmentKind.allCases // all kinds
        case .home:
            availableKinds = [.dumbbell, .kettlebell, .band, .bodyweight]
        case .both:
            availableKinds = EquipmentKind.allCases // all kinds
        }

        var prefs = EquipmentPreferences(
            location: location,
            incrementsLb: [:],
            availableEquipment: Set(availableKinds.map { $0.rawValue })
        )
        for kind in EquipmentKind.allCases {
            prefs.incrementsLb[kind.rawValue] = kind.defaultIncrementLb
        }
        return prefs
    }
}

@Observable
final class EquipmentPreferencesStore {
    static let shared = EquipmentPreferencesStore()

    var preferences: EquipmentPreferences {
        didSet { save() }
    }

    private let kvStore = NSUbiquitousKeyValueStore.default
    private let kvKey = "equipmentPreferences"
    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .documentDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("equipmentPreferences.json")
    }

    init() {
        preferences = .default
        load()
        NotificationCenter.default.addObserver(
            self,
            selector: #selector(kvStoreChanged),
            name: NSUbiquitousKeyValueStore.didChangeExternallyNotification,
            object: kvStore
        )
        kvStore.synchronize()
    }

    func increment(for kind: EquipmentKind) -> Double {
        preferences.increment(for: kind)
    }

    /// Convenience used by the advisor.
    func increment(forEquipment equipment: String, name: String) -> Double {
        let kind = EquipmentKind.classify(equipment: equipment, name: name)
        return increment(for: kind)
    }

    func kind(forEquipment equipment: String, name: String) -> EquipmentKind {
        EquipmentKind.classify(equipment: equipment, name: name)
    }

    func applyPreset(_ location: TrainingLocation) {
        preferences = EquipmentPreferences.preset(for: location)
    }

    func reset() {
        preferences = EquipmentPreferences.default
    }

    private func load() {
        if let data = try? Data(contentsOf: fileURL),
           let prefs = try? decoder.decode(EquipmentPreferences.self, from: data) {
            preferences = prefs
            return
        }
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let prefs = try? decoder.decode(EquipmentPreferences.self, from: data) {
            preferences = prefs
            save()
        }
    }

    private func save() {
        guard let data = try? encoder.encode(preferences) else { return }
        try? data.write(to: fileURL, options: .atomic)
        if data.count < 900_000, let jsonString = String(data: data, encoding: .utf8) {
            kvStore.set(jsonString, forKey: kvKey)
            kvStore.synchronize()
        }
    }

    @objc private func kvStoreChanged(_ notification: Notification) {
        if let jsonString = kvStore.string(forKey: kvKey),
           let data = jsonString.data(using: .utf8),
           let prefs = try? decoder.decode(EquipmentPreferences.self, from: data) {
            preferences = prefs
            save()
        }
    }
}
