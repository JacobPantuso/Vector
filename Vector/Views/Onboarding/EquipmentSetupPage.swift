import SwiftUI

struct EquipmentSetupContent: View {
    @State private var store = EquipmentPreferencesStore.shared
    @FocusState private var focusedIncrementKind: EquipmentKind?

    var body: some View {
        GeometryReader { geo in
            ScrollView {
                VStack(spacing: 24) {
                    VStack(spacing: 8) {
                        Text("Gym & Equipment")
                            .font(.title.bold())

                        Text("Tell Vector where you train and what equipment is available.")
                            .font(.subheadline)
                            .foregroundStyle(.secondary)
                            .multilineTextAlignment(.center)
                            .padding(.horizontal, 24)
                    }
                    .padding(.top, 24)

                    // MARK: - Training Location
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Where do you train?")
                            .font(.headline)

                        VStack(spacing: 12) {
                            ForEach(TrainingLocation.allCases) { location in
                                locationButton(location)
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Available Equipment
                    VStack(alignment: .leading, spacing: 18) {
                        Text("Available Equipment")
                            .font(.headline)

                        VStack(spacing: 12) {
                            ForEach(EquipmentKind.allCases) { kind in
                                if kind == .bodyweight {
                                    equipmentChip(kind, isAvailable: true, isInteractive: false)
                                } else {
                                    equipmentChip(kind, isAvailable: store.preferences.isAvailable(kind), isInteractive: true)
                                }
                            }
                        }
                    }
                    .padding(.horizontal)

                    // MARK: - Load Increments
                    if !store.preferences.availableKinds.isEmpty {
                        VStack(alignment: .leading, spacing: 18) {
                            VStack(alignment: .leading, spacing: 4) {
                                Text("Load Increments")
                                    .font(.headline)
                                Text("Set the smallest weight jump you can make on each — Vector matches its progression to your equipment.")
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                            }

                            VStack(spacing: 14) {
                                ForEach(store.preferences.availableKinds) { kind in
                                    if kind.supportsLoadProgression {
                                        incrementRow(kind)
                                    }
                                }
                            }
                        }
                        .padding(.horizontal)
                    }
                }
                .padding(.bottom, 140)
                .frame(minHeight: geo.size.height)
            }
            .scrollEdgeEffectStyle(.soft, for: .top)
            .toolbar {
                ToolbarItemGroup(placement: .keyboard) {
                    Spacer()
                    Button("Done") { focusedIncrementKind = nil }
                }
            }
        }
    }

    private func locationButton(_ location: TrainingLocation) -> some View {
        let isSelected = store.preferences.location == location
        return Button {
            store.applyPreset(location)
        } label: {
            HStack(spacing: 12) {
                Image(systemName: location.symbol)
                    .font(.headline)
                    .foregroundStyle(isSelected ? .white : .primary)

                VStack(alignment: .leading, spacing: 2) {
                    Text(location.rawValue)
                        .font(.subheadline.bold())
                        .foregroundStyle(isSelected ? .white : .primary)

                    Text(location.subtitle)
                        .font(.caption)
                        .foregroundStyle(isSelected ? .white.opacity(0.8) : .secondary)
                }

                Spacer()

                Image(systemName: isSelected ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isSelected ? .white : .secondary)
            }
            .padding()
            .frame(maxWidth: .infinity, minHeight: 80, alignment: .leading)
            .glassEffect(.regular.tint(isSelected ? .indigo.opacity(0.62) : .white.opacity(0.08)), in: .rect(cornerRadius: 16))
        }
        .buttonStyle(.plain)
    }

    private func equipmentChip(_ kind: EquipmentKind, isAvailable: Bool, isInteractive: Bool) -> some View {
        Button {
            if isInteractive {
                store.preferences.toggle(kind)
            }
        } label: {
            HStack(spacing: 8) {
                Image(systemName: kind.symbol)
                    .font(.body.weight(.semibold))

                Text(kind.rawValue)
                    .font(.subheadline.weight(.semibold))

                Spacer()

                Image(systemName: isAvailable ? "checkmark.circle.fill" : "circle")
                    .foregroundStyle(isAvailable ? .green : .secondary)
            }
            .padding(.horizontal, 14)
            .padding(.vertical, 12)
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular.tint(isAvailable ? .green.opacity(0.28) : .white.opacity(0.08)), in: .rect(cornerRadius: 12))
            .opacity(isInteractive || isAvailable ? 1 : 0.6)
        }
        .buttonStyle(.plain)
        .disabled(!isInteractive)
    }

    private func incrementRow(_ kind: EquipmentKind) -> some View {
        let selected = store.preferences.increment(for: kind)
        return VStack(alignment: .leading, spacing: 12) {
            HStack {
                HStack(spacing: 6) {
                    Image(systemName: kind.symbol)
                        .font(.body.weight(.semibold))
                    Text(kind.rawValue)
                }
                .font(.subheadline.weight(.semibold))

                Spacer()

                Text("\(formatLb(selected)) lb")
                    .font(.subheadline.weight(.semibold))
                    .foregroundStyle(.indigo)
            }

            HStack(spacing: 8) {
                ForEach(kind.incrementOptions, id: \.self) { option in
                    let isPreset = abs(option - selected) < 0.001
                    Button {
                        store.preferences.setIncrement(option, for: kind)
                    } label: {
                        Text(formatLb(option))
                            .font(.caption.weight(.semibold))
                            .frame(maxWidth: .infinity, minHeight: 30)
                            .foregroundStyle(isPreset ? .white : .primary)
                            .glassEffect(.regular.tint(isPreset ? .indigo.opacity(0.62) : .white.opacity(0.06)), in: .capsule)
                    }
                    .buttonStyle(.plain)
                }
            }

            HStack {
                Text("Custom")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Spacer()
                TextField("", value: Binding(
                    get: { store.preferences.increment(for: kind) },
                    set: { store.preferences.setIncrement($0, for: kind) }
                ), format: .number)
                    .keyboardType(.decimalPad)
                    .multilineTextAlignment(.trailing)
                    .focused($focusedIncrementKind, equals: kind)
                    .frame(width: 56)
                Text("lb")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            .padding(.horizontal, 12)
            .padding(.vertical, 8)
            .glassEffect(.regular.tint(.white.opacity(0.06)), in: .capsule)

            Text(kind.incrementBlurb)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .padding()
        .glassEffect(in: .rect(cornerRadius: 12))
    }

    private func formatLb(_ value: Double) -> String {
        value.truncatingRemainder(dividingBy: 1) == 0
            ? String(format: "%.0f", value)
            : String(format: "%.1f", value)
    }
}

struct EquipmentSetupPage: View {
    var onContinue: () -> Void

    var body: some View {
        ZStack {
            EquipmentSetupContent()

            VStack {
                Spacer()
                VStack {
                    LinearGradient(colors: [.clear, Color(.systemBackground).opacity(0.8), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                        .frame(height: 120)
                        .ignoresSafeArea(edges: .bottom)
                }
            }
        }
    }
}
