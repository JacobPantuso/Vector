import SwiftUI

/// Settings sheet for Vector Intelligence: coach tone, chat history, model/data info, and clear-all.
struct AdvisorSettingsView: View {
    @Environment(\.dismiss) private var dismiss
    @State private var advisor = VectorAdvisor.shared
    @State private var history = ConversationHistoryStore.shared
    @State private var memory = AdvisorMemoryStore.shared
    @State private var persona: AdvisorPersona = AdvisorPersona.current
    @State private var showClearConfirm = false

    var body: some View {
        NavigationStack {
            Form {
                Section("Coach Tone") {
                    Picker("Tone", selection: $persona) {
                        ForEach(AdvisorPersona.allCases, id: \.self) { p in
                            Text(p.rawValue).tag(p)
                        }
                    }
                    .onChange(of: persona) { _, newValue in
                        UserDefaults.standard.set(newValue.rawValue, forKey: AdvisorPersona.storageKey)
                    }
                }

                Section("Memory") {
                    NavigationLink {
                        AdvisorMemoryView()
                    } label: {
                        HStack {
                            Label("What Vector Remembers", systemImage: "brain")
                            Spacer()
                            Text("\(memory.memories.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("History") {
                    NavigationLink {
                        ConversationHistoryView { conversation in
                            advisor.restore(conversation)
                            dismiss()
                        }
                    } label: {
                        HStack {
                            Label("Chat History", systemImage: "clock.arrow.circlepath")
                            Spacer()
                            Text("\(history.conversations.count)")
                                .foregroundStyle(.secondary)
                        }
                    }
                }

                Section("About Vector Intelligence") {
                    Label("On-device & private", systemImage: "lock.fill")
                    Text("Vector Intelligence runs entirely on your iPhone. It sees your recovery, sleep, training, and profile to tailor advice — nothing leaves your device.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }

                Section {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Label("Clear All Chats", systemImage: "trash")
                    }
                }
            }
            .navigationTitle("Vector Settings")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
            .confirmationDialog(
                "Clear all conversations? This can't be undone.",
                isPresented: $showClearConfirm,
                titleVisibility: .visible
            ) {
                Button("Clear All", role: .destructive) {
                    history.clearAll()
                    advisor.resetConversation()
                    dismiss()
                }
            }
        }
    }
}

/// Browsable list of archived conversations; tap to restore, swipe to delete.
struct ConversationHistoryView: View {
    let onSelect: (ArchivedConversation) -> Void
    @State private var history = ConversationHistoryStore.shared

    var body: some View {
        Group {
            if history.conversations.isEmpty {
                ContentUnavailableView(
                    "No past chats",
                    systemImage: "bubble.left.and.bubble.right",
                    description: Text("Start a new chat and it'll be saved here.")
                )
            } else {
                List {
                    ForEach(history.conversations) { conversation in
                        Button {
                            onSelect(conversation)
                        } label: {
                            VStack(alignment: .leading, spacing: 2) {
                                Text(conversation.title)
                                    .font(.body)
                                    .foregroundStyle(.primary)
                                    .lineLimit(1)
                                Text(conversation.date.formatted(date: .abbreviated, time: .shortened))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }
                        }
                    }
                    .onDelete { offsets in
                        let ids = offsets.map { history.conversations[$0].id }
                        for id in ids { history.delete(id) }
                    }
                }
            }
        }
        .navigationTitle("Chat History")
        .navigationBarTitleDisplayMode(.inline)
    }
}

/// Browse and manage persisted advisor memories (durable facts about the user).
struct AdvisorMemoryView: View {
    @State private var memory = AdvisorMemoryStore.shared
    @State private var showClearConfirm = false

    var body: some View {
        Group {
            if memory.memories.isEmpty {
                ContentUnavailableView(
                    "Nothing Remembered Yet",
                    systemImage: "brain",
                    description: Text("As you chat, Vector saves lasting details like your equipment, injuries, and schedule.")
                )
            } else {
                List {
                    ForEach(memory.memories) { item in
                        VStack(alignment: .leading, spacing: 4) {
                            Text(item.text)
                                .font(.body)
                                .foregroundStyle(.primary)
                            Text(item.date.formatted(.relative(presentation: .named)))
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        .swipeActions(edge: .trailing) {
                            Button(role: .destructive) {
                                memory.delete(item.id)
                            } label: {
                                Label("Delete", systemImage: "trash")
                            }
                        }
                    }
                }
            }
        }
        .navigationTitle("Memory")
        .navigationBarTitleDisplayMode(.inline)
        .toolbar {
            ToolbarItem(placement: .topBarTrailing) {
                if !memory.memories.isEmpty {
                    Button(role: .destructive) {
                        showClearConfirm = true
                    } label: {
                        Text("Forget All")
                    }
                }
            }
        }
        .confirmationDialog(
            "Forget everything? This can't be undone.",
            isPresented: $showClearConfirm,
            titleVisibility: .visible
        ) {
            Button("Forget All", role: .destructive) {
                memory.clearAll()
            }
        }
    }
}

/// Chat-history sheet presented from the Advisor toolbar. Points at Profile for settings.
struct AdvisorHistorySheet: View {
    let onSelect: (ArchivedConversation) -> Void
    let onConfigure: () -> Void

    @Environment(\.dismiss) private var dismiss
    @State private var history = ConversationHistoryStore.shared

    var body: some View {
        NavigationStack {
            List {
                Section {
                    Button {
                        dismiss()
                        onConfigure()
                    } label: {
                        HStack {
                            VStack(alignment: .leading, spacing: 2) {
                                Text("To configure Vector Intelligence, go to your Profile")
                                    .font(.subheadline)
                                    .foregroundStyle(.primary)
                                    .multilineTextAlignment(.leading)
                                Text("Open Profile")
                                    .font(.caption)
                                    .foregroundStyle(.tint)
                            }
                            Spacer()
                            Image(systemName: "chevron.right")
                                .font(.caption.weight(.semibold))
                                .foregroundStyle(.secondary)
                        }
                    }
                    .buttonStyle(.plain)
                }

                if history.conversations.isEmpty {
                    Section {
                        ContentUnavailableView(
                            "No past chats",
                            systemImage: "bubble.left.and.bubble.right",
                            description: Text("Start a new chat and it'll be saved here.")
                        )
                    }
                } else {
                    Section("Chat History") {
                        ForEach(history.conversations) { conversation in
                            Button {
                                onSelect(conversation)
                                dismiss()
                            } label: {
                                VStack(alignment: .leading, spacing: 2) {
                                    Text(conversation.title)
                                        .font(.body)
                                        .foregroundStyle(.primary)
                                        .lineLimit(1)
                                    Text(conversation.date.formatted(date: .abbreviated, time: .shortened))
                                        .font(.caption)
                                        .foregroundStyle(.secondary)
                                }
                            }
                        }
                        .onDelete { offsets in
                            let ids = offsets.map { history.conversations[$0].id }
                            for id in ids { history.delete(id) }
                        }
                    }
                }
            }
            .navigationTitle("Chats")
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                }
            }
        }
    }
}
