import Foundation

/// One archived advisor conversation, restorable later from Chat History.
struct ArchivedConversation: Identifiable, Codable {
    let id: UUID
    var title: String
    var messages: [AdvisorMessage]
    let date: Date

    init(id: UUID = UUID(), title: String, messages: [AdvisorMessage], date: Date = Date()) {
        self.id = id
        self.title = title
        self.messages = messages
        self.date = date
    }
}

/// Stores past advisor conversations (newest first), JSON-persisted to Application Support.
@MainActor
@Observable
final class ConversationHistoryStore {
    static let shared = ConversationHistoryStore()

    private(set) var conversations: [ArchivedConversation] = []

    private let encoder = JSONEncoder()
    private let decoder = JSONDecoder()

    private var fileURL: URL {
        let docs = FileManager.default.urls(for: .applicationSupportDirectory, in: .userDomainMask)[0]
        return docs.appendingPathComponent("advisor-history.json")
    }

    init() {
        load()
    }

    /// Archive a conversation. Ignores empty conversations. Title is derived from the first user message.
    func archive(_ messages: [AdvisorMessage]) {
        let meaningful = messages.filter { !$0.content.trimmingCharacters(in: .whitespacesAndNewlines).isEmpty }
        guard !meaningful.isEmpty else { return }
        let source = meaningful.first(where: { $0.role == .user })?.content ?? meaningful.first?.content ?? "Conversation"
        let title = String(source.trimmingCharacters(in: .whitespacesAndNewlines).prefix(50))
        conversations.insert(ArchivedConversation(title: title.isEmpty ? "Conversation" : title, messages: messages, date: Date()), at: 0)
        save()
    }

    func delete(_ id: UUID) {
        conversations.removeAll { $0.id == id }
        save()
    }

    func clearAll() {
        conversations.removeAll()
        save()
    }

    func conversation(_ id: UUID) -> ArchivedConversation? {
        conversations.first { $0.id == id }
    }

    private func load() {
        guard let data = try? Data(contentsOf: fileURL),
              let decoded = try? decoder.decode([ArchivedConversation].self, from: data) else { return }
        conversations = decoded
    }

    private func save() {
        guard let data = try? encoder.encode(conversations) else { return }
        try? data.write(to: fileURL, options: .atomic)
    }
}
