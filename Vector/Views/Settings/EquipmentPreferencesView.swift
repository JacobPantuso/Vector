import SwiftUI

struct EquipmentPreferencesView: View {
    @State private var store = EquipmentPreferencesStore.shared

    var body: some View {
        List {
            // MARK: - Training Location
            Section {
                Picker("Location", selection: Binding(
                    get: { store.preferences.location },
                    set: { store.applyPreset($0) }
                )) {
                    ForEach(TrainingLocation.allCases) { location in
                        Text(location.rawValue).tag(location)
                    }
                }

                if let location = TrainingLocation.allCases.first(where: { $0 == store.preferences.location }) {
                    Text(location.subtitle)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            } header: {
                Text("Training Location")
            }

            // MARK: - Available Equipment
            Section {
                ForEach(EquipmentKind.allCases) { kind in
                    HStack {
                        HStack(spacing: 8) {
                            Image(systemName: kind.symbol)
                                .font(.body.weight(.semibold))
                                .frame(width: 24)

                            Text(kind.rawValue)
                        }

                        Spacer()

                        if kind == .bodyweight {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundStyle(.green)
                                .font(.body)
                        } else {
                            Toggle("", isOn: Binding(
                                get: { store.preferences.isAvailable(kind) },
                                set: { _ in store.preferences.toggle(kind) }
                            ))
                            .labelsHidden()
                        }
                    }
                }
            } header: {
                Text("Available Equipment")
            } footer: {
                Text("Bodyweight is always available. Select which other equipment you have access to.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            // MARK: - Load Increments
            if !store.preferences.availableKinds.isEmpty {
                Section {
                    ForEach(store.preferences.availableKinds) { kind in
                        if kind.supportsLoadProgression {
                            incrementRow(kind)
                        }
                    }
                } header: {
                    Text("Load Increments")
                } footer: {
                    Text("Vector only suggests weight jumps you can actually load.")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
            }

            // MARK: - Reset
            Section {
                Button(role: .destructive) {
                    store.reset()
                } label: {
                    Label("Reset to Defaults", systemImage: "arrow.counterclockwise")
                        .frame(maxWidth: .infinity, alignment: .center)
                }
            }
        }
        .navigationTitle("Gym & Equipment")
    }

    private func incrementRow(_ kind: EquipmentKind) -> some View {
        VStack(alignment: .leading, spacing: 8) {
            HStack {
                HStack(spacing: 8) {
                    Image(systemName: kind.symbol)
                        .font(.body.weight(.semibold))
                        .frame(width: 24)

                    Text(kind.rawValue)
                        .font(.subheadline.weight(.semibold))
                }

                Spacer()

                Text("\(Int(store.preferences.increment(for: kind))) lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }

            Picker(selection: Binding(
                get: {
                    store.preferences.increment(for: kind)
                },
                set: { value in
                    store.preferences.setIncrement(value, for: kind)
                }
            )) {
                ForEach(kind.incrementOptions, id: \.self) { increment in
                    Text("\(Int(increment)) lb")
                        .tag(increment)
                }
            } label: {
                EmptyView()
            }
            .pickerStyle(.segmented)

            Text(kind.incrementBlurb)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding(.vertical, 4)
    }
}
