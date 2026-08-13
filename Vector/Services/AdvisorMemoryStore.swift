import Foundation

/// One durable fact the user told the advisor — an injury, an equipment
/// constraint, a schedule, a preference. Survives across chats and launches.
struct AdvisorMemory: Identifiable, Codable, Hashable {
    let id: UUID
    var text: String
    let date: Date

    init(id: UUID = UUID(), text: String, date: Date = Date()) {
        self.id = id
        self.text = text
        self.date = date
    }
}

/// Persistent store of what the advisor remembers about the user, separate
/// from any one conversation. Injected into the session instructions so it
/// applies from the first turn of every new chat.
@MainActor
@Observable
final class AdvisorMemoryStore {
    static let shared = AdvisorMemoryStore()

    private(set) var memories: [AdvisorMemory] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("advisor-memory.json")
    }

    init() {
        encoder.dateEncodingStrategy = .iso8601
        decoder.dateDecodingStrategy = .iso8601
        load()
    }

    /// Save a durable fact about the user. Dedupes case-insensitively (if an existing memory
    /// contains the new text or vice versa, replace it with the longer text and move to front).
    /// Caps at 30 entries. Returns true if anything changed.
    func remember(_ text: String) -> Bool {
        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard trimmed.count >= 4 else { return false }

        let lowerNew = trimmed.lowercased()

        // Check for existing matching memory (case-insensitive substring match)
        if let existingIdx = memories.firstIndex(where: { memory in
            let lowerExisting = memory.text.lowercased()
            return lowerExisting.contains(lowerNew) || lowerNew.contains(lowerExisting)
        }) {
            let existing = memories[existingIdx]
            // Replace with the longer text
            let newText = trimmed.count > existing.text.count ? trimmed : existing.text
            if newText == existing.text {
                // Already have it; just move to front if not there
                if existingIdx != 0 {
                    let memory = memories.remove(at: existingIdx)
                    memories.insert(memory, at: 0)
                    save()
                    return true
                }
                return false
            } else {
                // Update with longer text and move to front
                memories.remove(at: existingIdx)
                memories.insert(AdvisorMemory(text: newText, date: Date()), at: 0)
                save()
                return true
            }
        }

        // No match; add new memory at front
        memories.insert(AdvisorMemory(text: trimmed, date: Date()), at: 0)

        // Cap at 30 entries (drop oldest)
        if memories.count > 30 {
            memories = Array(memories.prefix(30))
        }

        save()
        return true
    }

    /// Remove a memory matching the query (case-insensitive bidirectional substring match).
    /// Returns the removed text or nil if nothing matched.
    func forget(matching query: String) -> String? {
        let lowerQuery = query.lowercased()
        if let idx = memories.firstIndex(where: { memory in
            let stored = memory.text.lowercased()
            return stored.contains(lowerQuery) || lowerQuery.contains(stored)
        }) {
            let removed = memories.remove(at: idx)
            save()
            return removed.text
        }
        return nil
    }

    /// Delete a specific memory by ID.
    func delete(_ id: UUID) {
        memories.removeAll { $0.id == id }
        save()
    }

    /// Clear all memories.
    func clearAll() {
        memories.removeAll()
        save()
    }

    /// Return memories as a prompt block, newest first, capped at 20 lines.
    /// Nil if empty.
    var promptBlock: String? {
        guard !memories.isEmpty else { return nil }
        let lines = memories.prefix(20).map { "- \($0.text)" }
        return lines.joined(separator: "\n")
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([AdvisorMemory].self, from: data) else {
            return
        }
        memories = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(memories) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
