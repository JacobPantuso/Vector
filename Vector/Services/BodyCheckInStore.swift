import Foundation

/// How the user says they felt during a flagged window.
enum BodyFeeling: String, Codable, Sendable, CaseIterable, Identifiable {
    case great, fine, rundown, sick, sore, stressed

    var id: String { rawValue }

    var label: String {
        switch self {
        case .great: "Felt great"
        case .fine: "Felt fine"
        case .rundown: "Run down"
        case .sick: "Getting sick"
        case .sore: "Sore"
        case .stressed: "Stressed"
        }
    }

    var icon: String {
        switch self {
        case .great: "face.smiling.fill"
        case .fine: "face.smiling"
        case .rundown: "person.crop.circle.badge.exclamationmark"
        case .sick: "thermometer"
        case .sore: "figure.step.trail"
        case .stressed: "bolt.fill"
        }
    }

    /// True when the answer indicates the body really was under load — used to tell
    /// a true positive from a false alarm when summarizing what Vector has learned.
    var indicatesStrain: Bool {
        switch self {
        case .great, .fine: false
        case .rundown, .sick, .sore, .stressed: true
        }
    }
}

/// Optional cause the user can attach. Multi-select.
enum BodyContext: String, Codable, Sendable, CaseIterable, Identifiable {
    case hardTraining, poorSleep, illness, alcohol, travel, workStress, other

    var id: String { rawValue }

    var label: String {
        switch self {
        case .hardTraining: "Hard training"
        case .poorSleep: "Poor sleep"
        case .illness: "Illness"
        case .alcohol: "Alcohol"
        case .travel: "Travel"
        case .workStress: "Work stress"
        case .other: "Something else"
        }
    }

    var icon: String {
        switch self {
        case .hardTraining: "bolt.circle.fill"
        case .poorSleep: "moon.zzz.fill"
        case .illness: "virus"
        case .alcohol: "wineglass.fill"
        case .travel: "airplane"
        case .workStress: "laptopcomputer"
        case .other: "ellipsis"
        }
    }
}

/// One answered check-in about a flagged window.
struct BodyCheckIn: Identifiable, Codable, Sendable, Hashable {
    let id: UUID
    /// `StrainEpisode.key` — stable across recomputation.
    let episodeKey: String
    let startDate: Date
    let endDate: Date
    let feeling: BodyFeeling
    var contexts: [BodyContext]
    var note: String?
    let answeredAt: Date

    init(id: UUID = UUID(), episodeKey: String, startDate: Date, endDate: Date, feeling: BodyFeeling, contexts: [BodyContext] = [], note: String? = nil, answeredAt: Date = Date()) {
        self.id = id
        self.episodeKey = episodeKey
        self.startDate = startDate
        self.endDate = endDate
        self.feeling = feeling
        self.contexts = contexts
        self.note = note
        self.answeredAt = answeredAt
    }
}

@MainActor
@Observable
final class BodyCheckInStore {
    static let shared = BodyCheckInStore()

    private(set) var checkIns: [BodyCheckIn] = []
    /// Episode keys the user skipped. Kept so Vector never re-asks about the same window.
    private(set) var skippedKeys: Set<String> = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var checkInsFileURL: URL {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("body-checkins.json")
    }

    private var skipsFileURL: URL {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("body-checkin-skips.json")
    }

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    /// Record or update a check-in for an episode. Replaces any existing check-in
    /// with the same episodeKey, clears it from skippedKeys, inserts newest-first, and saves.
    func record(
        episodeKey: String,
        startDate: Date,
        endDate: Date,
        feeling: BodyFeeling,
        contexts: [BodyContext] = [],
        note: String? = nil
    ) {
        // Remove any existing check-in with the same episode key
        checkIns.removeAll { $0.episodeKey == episodeKey }

        // Remove from skipped keys if it was there
        skippedKeys.remove(episodeKey)

        // Insert new check-in at front (newest first)
        let checkIn = BodyCheckIn(
            episodeKey: episodeKey,
            startDate: startDate,
            endDate: endDate,
            feeling: feeling,
            contexts: contexts,
            note: note,
            answeredAt: Date()
        )
        checkIns.insert(checkIn, at: 0)

        // Cap at 100 entries (drop oldest)
        if checkIns.count > 100 {
            checkIns = Array(checkIns.prefix(100))
        }

        save()
    }

    /// Mark an episode as skipped. The user won't be prompted about it again.
    func skip(episodeKey: String) {
        skippedKeys.insert(episodeKey)
        save()
    }

    /// Retrieve a check-in by episode key.
    func checkIn(forKey key: String) -> BodyCheckIn? {
        checkIns.first { $0.episodeKey == key }
    }

    /// True if the user has answered OR skipped this episode, so it shouldn't be
    /// re-prompted.
    func hasResponded(toKey key: String) -> Bool {
        checkIns.contains { $0.episodeKey == key } || skippedKeys.contains(key)
    }

    /// Delete a specific check-in by ID.
    func delete(_ id: UUID) {
        checkIns.removeAll { $0.id == id }
        save()
    }

    /// Clear all check-ins and skipped keys.
    func clearAll() {
        checkIns.removeAll()
        skippedKeys.removeAll()
        save()
    }

    /// Count of answered check-ins.
    var answeredCount: Int {
        checkIns.count
    }

    /// A plain-language digest of what Vector has learned from user feedback,
    /// suitable for injecting into advisor context. Nil if fewer than 2 answered check-ins.
    var patternSummary: String? {
        guard checkIns.count >= 2 else { return nil }

        let strainCount = checkIns.filter { $0.feeling.indicatesStrain }.count
        let allContexts = checkIns.flatMap { $0.contexts }
        let frequentContexts = mostCommonContexts.prefix(2)
        let contextNames = frequentContexts.map { $0.label }.joined(separator: " and ")

        if contextNames.isEmpty {
            return "Of \(checkIns.count) flagged windows the user confirmed, \(strainCount) involved real strain."
        } else {
            return "Of \(checkIns.count) flagged windows the user confirmed, \(strainCount) involved real strain; most often attributed to \(contextNames)."
        }
    }

    /// Contexts sorted by frequency across all check-ins, most frequent first.
    /// Ties broken by CaseIterable order for determinism. Empty when there are no check-ins.
    var mostCommonContexts: [BodyContext] {
        let allContexts = checkIns.flatMap { $0.contexts }
        guard !allContexts.isEmpty else { return [] }

        var counts: [BodyContext: Int] = [:]
        for context in allContexts {
            counts[context, default: 0] += 1
        }

        return counts.sorted { a, b in
            if a.value != b.value {
                return a.value > b.value
            }
            // Tie-breaker: CaseIterable order
            let allCases = BodyContext.allCases
            let aIndex = allCases.firstIndex(of: a.key) ?? Int.max
            let bIndex = allCases.firstIndex(of: b.key) ?? Int.max
            return aIndex < bIndex
        }
        .map { $0.key }
    }

    private func load() {
        // Load check-ins
        if let data = try? Data(contentsOf: checkInsFileURL),
           let decoded = try? decoder.decode([BodyCheckIn].self, from: data) {
            checkIns = decoded
        }

        // Load skipped keys
        if let data = try? Data(contentsOf: skipsFileURL),
           let decodedArray = try? decoder.decode([String].self, from: data) {
            skippedKeys = Set(decodedArray)
        }
    }

    private func save() {
        // Save check-ins
        if let data = try? encoder.encode(checkIns) {
            try? data.write(to: checkInsFileURL, options: .atomic)
        }

        // Save skipped keys as sorted array for stability and diffability
        let sortedSkips = skippedKeys.sorted()
        if let data = try? encoder.encode(sortedSkips) {
            try? data.write(to: skipsFileURL, options: .atomic)
        }
    }
}
