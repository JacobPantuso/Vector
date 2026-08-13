import SwiftUI

/// Sheet for asking the user how they felt during flagged strain windows.
/// Advances through episodes, collecting feedback to help Vector learn personal patterns.
struct BodyCheckInSheet: View {
    let episodes: [StrainPatternDetector.StrainEpisode]
    var onFinish: () -> Void = {}

    @State private var index = 0
    @State private var feeling: BodyFeeling? = nil
    @State private var contexts: Set<BodyContext> = []
    @State private var note = ""

    @Environment(\.dismiss) private var dismiss

    private var currentEpisode: StrainPatternDetector.StrainEpisode? {
        guard index < episodes.count else { return nil }
        return episodes[index]
    }

    private var isLastEpisode: Bool {
        index == episodes.count - 1
    }

    var body: some View {
        ScrollView {
            if let episode = currentEpisode {
                VStack(alignment: .leading, spacing: 20) {
                    header(for: episode)
                    signalsCard(for: episode)
                    feelingSection
                    if feeling != nil {
                        contextSection
                        noteField
                    }
                }
                .padding(.horizontal, 20)
                .padding(.top, 24)
                .padding(.bottom, 12)
            }
        }
        .scrollIndicators(.hidden)
        .safeAreaInset(edge: .bottom) {
            actionButtons(for: currentEpisode)
        }
        .presentationDetents([.fraction(0.85), .large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(28)
    }

    // MARK: - Header

    private func header(for episode: StrainPatternDetector.StrainEpisode) -> some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [Color.indigo.opacity(0.28), Color.indigo.opacity(0.12)],
                        startPoint: .topLeading, endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                Image(systemName: "waveform.path.ecg")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(.indigo)
            }

            VStack(alignment: .leading, spacing: 6) {
                Text(episode.headline)
                    .font(.title3.bold())
                HStack(spacing: 4) {
                    Text(episode.dateRangeLabel)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text("·")
                        .font(.caption)
                        .foregroundStyle(.secondary)
                    Text(episode.severity.label)
                        .font(.caption)
                        .foregroundStyle(.secondary)
                }
                if episodes.count > 1 {
                    Text("\(index + 1) of \(episodes.count)")
                        .font(.caption2)
                        .foregroundStyle(.tertiary)
                        .padding(.top, 2)
                }
            }
            Spacer()
        }
    }

    // MARK: - Signals Card

    private func signalsCard(for episode: StrainPatternDetector.StrainEpisode) -> some View {
        let importantDeviations = episode.deviations.filter { $0.strainZ >= StrainPatternDetector.signalThreshold }

        return VStack(alignment: .leading, spacing: 12) {
            Text("Your signals")
                .font(.subheadline.weight(.semibold))

            VStack(alignment: .leading, spacing: 10) {
                ForEach(importantDeviations, id: \.id) { deviation in
                    HStack(spacing: 12) {
                        Image(systemName: deviation.signal.icon)
                            .font(.subheadline.weight(.semibold))
                            .foregroundStyle(.indigo)
                            .frame(width: 24)

                        Text(deviation.summary)
                            .font(.subheadline)
                            .foregroundStyle(.primary)
                            .lineLimit(2)

                        Spacer()
                    }
                }
            }
            .frame(maxWidth: .infinity, alignment: .leading)
            .padding(16)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }

    // MARK: - Feeling Section

    private var feelingSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            Text("How were you feeling?")
                .font(.subheadline.weight(.semibold))

            // Wrapping grid of feeling chips
            let columns: [GridItem] = [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ]

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(BodyFeeling.allCases) { f in
                    feelingChip(f)
                }
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func feelingChip(_ f: BodyFeeling) -> some View {
        let isSelected = feeling == f
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                feeling = f
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: f.icon)
                    .font(.title3)
                Text(f.label)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.indigo : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Context Section

    private var contextSection: some View {
        VStack(alignment: .leading, spacing: 12) {
            VStack(alignment: .leading, spacing: 4) {
                Text("What do you think caused it?")
                    .font(.subheadline.weight(.semibold))
                Text("Optional")
                    .font(.caption2)
                    .foregroundStyle(.tertiary)
            }

            let columns: [GridItem] = [
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10),
                GridItem(.flexible(), spacing: 10)
            ]

            LazyVGrid(columns: columns, spacing: 10) {
                ForEach(BodyContext.allCases) { context in
                    contextChip(context)
                }
            }

            // Sick mode offer
            if feeling == .sick && AppModeStore.shared.currentMode != .sick {
                HStack(spacing: 12) {
                    VStack(alignment: .leading, spacing: 4) {
                        Text("Switch Vector to Sick mode?")
                            .font(.subheadline.weight(.semibold))
                        Text("Coaching will prioritize rest.")
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }
                    Spacer()
                    Button {
                        AppModeStore.shared.setMode(.sick)
                    } label: {
                        Text("Yes")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                            .background(Color.orange.opacity(0.2), in: Capsule())
                            .foregroundStyle(.orange)
                    }
                    .buttonStyle(.plain)
                }
                .padding(12)
                .background(Color.orange.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .transition(.opacity.combined(with: .move(edge: .top)))
            }
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    private func contextChip(_ context: BodyContext) -> some View {
        let isSelected = contexts.contains(context)
        return Button {
            withAnimation(.spring(duration: 0.25)) {
                if isSelected {
                    contexts.remove(context)
                } else {
                    contexts.insert(context)
                }
            }
        } label: {
            VStack(spacing: 6) {
                Image(systemName: context.icon)
                    .font(.title3)
                Text(context.label)
                    .font(.caption2.weight(.semibold))
                    .lineLimit(1)
            }
            .frame(maxWidth: .infinity)
            .frame(height: 70)
            .foregroundStyle(isSelected ? .white : .primary)
            .background(isSelected ? Color.cyan : Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 14))
        }
        .buttonStyle(.plain)
    }

    // MARK: - Note Field

    private var noteField: some View {
        VStack(alignment: .leading, spacing: 8) {
            TextField("Anything else? (optional)", text: $note, axis: .vertical)
                .font(.subheadline)
                .padding(12)
                .background(Color.secondary.opacity(0.08), in: RoundedRectangle(cornerRadius: 12))
                .lineLimit(1...3)
        }
        .transition(.opacity.combined(with: .scale(scale: 0.95)))
    }

    // MARK: - Action Buttons

    @ViewBuilder
    private func actionButtons(for episode: StrainPatternDetector.StrainEpisode?) -> some View {
        HStack(spacing: 10) {
            Button(action: skipCurrent) {
                Text("Skip this one")
                    .font(.subheadline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
            }
            .buttonStyle(.plain)
            .foregroundStyle(.secondary)
            .padding(.horizontal, 16)
            .padding(.vertical, 8)
            .background(Color.secondary.opacity(0.1), in: RoundedRectangle(cornerRadius: 12))

            Button(action: saveCurrent) {
                Text("Save")
                    .font(.headline)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 10)
                    .foregroundStyle(.white)
                    .background(
                        LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing),
                        in: RoundedRectangle(cornerRadius: 12)
                    )
            }
            .buttonStyle(.plain)
            .disabled(feeling == nil)
            .opacity(feeling == nil ? 0.5 : 1)
        }
        .padding(.horizontal, 20)
        .padding(.vertical, 10)
        .background(.regularMaterial)
    }

    // MARK: - Actions

    private func saveCurrent() {
        guard let episode = currentEpisode, let f = feeling else { return }

        let trimmedNote = note.trimmingCharacters(in: .whitespacesAndNewlines)
        BodyCheckInStore.shared.record(
            episodeKey: episode.key,
            startDate: episode.startDate,
            endDate: episode.endDate,
            feeling: f,
            contexts: Array(contexts),
            note: trimmedNote.isEmpty ? nil : trimmedNote
        )

        advance()
    }

    private func skipCurrent() {
        guard let episode = currentEpisode else { return }
        BodyCheckInStore.shared.skip(episodeKey: episode.key)
        advance()
    }

    private func advance() {
        withAnimation(.easeInOut(duration: 0.3)) {
            index += 1
            feeling = nil
            contexts = []
            note = ""
        }

        if index >= episodes.count {
            onFinish()
            dismiss()
        }
    }
}

// MARK: - BodyPatternsCard

/// Compact card to invite review of pending strain patterns.
struct BodyPatternsCard: View {
    let pendingCount: Int
    var onReview: () -> Void

    var body: some View {
        if pendingCount == 0 {
            EmptyView()
        } else {
            VStack(alignment: .leading, spacing: 12) {
                HStack(spacing: 12) {
                    Image(systemName: "waveform.path.ecg")
                        .font(.title3.weight(.semibold))
                        .foregroundStyle(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))

                    VStack(alignment: .leading, spacing: 4) {
                        Text("Help Vector learn your patterns")
                            .font(.subheadline.weight(.semibold))

                        let subtitle = pendingCount == 1
                            ? "1 window in the last 2 weeks where your signals drifted — tell Vector how you felt"
                            : "\(pendingCount) windows in the last 2 weeks where your signals drifted — tell Vector how you felt"
                        Text(subtitle)
                            .font(.caption)
                            .foregroundStyle(.secondary)
                    }

                    Spacer()

                    Button(action: onReview) {
                        Text("Review")
                            .font(.caption.weight(.semibold))
                            .padding(.horizontal, 12)
                            .padding(.vertical, 6)
                    }
                    .buttonStyle(.glassProminent)
                    .tint(LinearGradient(colors: [.indigo, .cyan], startPoint: .leading, endPoint: .trailing))
                }
                .padding(16)
                .glassEffect(.regular, in: .rect(cornerRadius: 20))
            }
        }
    }
}

// MARK: - Previews

#if DEBUG
#Preview("BodyCheckInSheet - Single Episode") {
    let episode1 = StrainPatternDetector.StrainEpisode(
        id: UUID(),
        startDate: Date().addingTimeInterval(-86400 * 3),
        endDate: Date().addingTimeInterval(-86400),
        deviations: [
            StrainPatternDetector.SignalDeviation(
                signal: .hrv,
                strainZ: 2.1,
                value: 35,
                baseline: 50
            ),
            StrainPatternDetector.SignalDeviation(
                signal: .wristTemperature,
                strainZ: 1.8,
                value: 37.5,
                baseline: 36.8
            ),
            StrainPatternDetector.SignalDeviation(
                signal: .restingHR,
                strainZ: 2.3,
                value: 72,
                baseline: 62
            )
        ],
        severity: .notable
    )

    return Color.black.vectorSheet(isPresented: .constant(true), style: .half) {
        BodyCheckInSheet(episodes: [episode1]) { }
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
    }
    .preferredColorScheme(.dark)
}

#Preview("BodyCheckInSheet - Multiple Episodes") {
    let episode1 = StrainPatternDetector.StrainEpisode(
        id: UUID(),
        startDate: Date().addingTimeInterval(-86400 * 5),
        endDate: Date().addingTimeInterval(-86400 * 3),
        deviations: [
            StrainPatternDetector.SignalDeviation(
                signal: .hrv,
                strainZ: 1.9,
                value: 38,
                baseline: 50
            ),
            StrainPatternDetector.SignalDeviation(
                signal: .wristTemperature,
                strainZ: 1.6,
                value: 37.3,
                baseline: 36.8
            )
        ],
        severity: .mild
    )

    let episode2 = StrainPatternDetector.StrainEpisode(
        id: UUID(),
        startDate: Date().addingTimeInterval(-86400 * 2),
        endDate: Date().addingTimeInterval(-86400),
        deviations: [
            StrainPatternDetector.SignalDeviation(
                signal: .hrv,
                strainZ: 2.8,
                value: 28,
                baseline: 50
            ),
            StrainPatternDetector.SignalDeviation(
                signal: .wristTemperature,
                strainZ: 2.2,
                value: 37.8,
                baseline: 36.8
            ),
            StrainPatternDetector.SignalDeviation(
                signal: .respiratoryRate,
                strainZ: 2.0,
                value: 18,
                baseline: 16
            ),
            StrainPatternDetector.SignalDeviation(
                signal: .bloodOxygen,
                strainZ: 1.7,
                value: 96.5,
                baseline: 97.8
            )
        ],
        severity: .strong
    )

    return Color.black.vectorSheet(isPresented: .constant(true), style: .half) {
        BodyCheckInSheet(episodes: [episode1, episode2]) { }
            .presentationDetents([.fraction(0.85), .large])
            .presentationDragIndicator(.visible)
    }
    .preferredColorScheme(.dark)
}

#Preview("BodyPatternsCard - With Patterns") {
    VStack(spacing: 16) {
        BodyPatternsCard(pendingCount: 1) { }
        BodyPatternsCard(pendingCount: 3) { }
    }
    .padding()
}

#Preview("BodyPatternsCard - No Patterns") {
    VStack(spacing: 16) {
        BodyPatternsCard(pendingCount: 0) { }
        Text("Card above is empty")
            .foregroundStyle(.secondary)
    }
    .padding()
}
#endif
