import SwiftUI

struct CardWalkthroughPage: View {
    @Binding var selectedIndex: Int
    var onContinue: () -> Void
    @State private var isFloating: Bool = false

    var body: some View {
        VStack(spacing: 0) {
            VStack(alignment: .center, spacing: 8) {
                Text("Your Dashboard")
                    .font(.title.bold())

                Text("Swipe to explore your metrics")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
            }
            .padding(.top, 16)
            .padding(.bottom, 12)

            TabView(selection: $selectedIndex) {
                ForEach(Array(DashboardCardInfo.allCards.enumerated()), id: \.element.id) { index, cardInfo in
                    GeometryReader { geo in
                        ScrollView {
                            VStack(spacing: 20) {
                                cardPreview(for: cardInfo)
                                    .scaleEffect(0.8)
                                    .frame(height: 240)
                                    .padding(.horizontal, 32)
                                    .padding(.top, 8)

                                VStack(spacing: 8) {
                                    Text(cardInfo.headline)
                                        .font(.title3.bold())

                                    Text(cardInfo.description)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                        .multilineTextAlignment(.center)
                                }
                                .padding(.horizontal, 32)

                                VStack(alignment: .leading, spacing: 8) {
                                    Text("What goes into it")
                                        .font(.caption.weight(.semibold))
                                        .foregroundStyle(.secondary)
                                        .padding(.horizontal, 4)

                                    ForEach(cardInfo.factors, id: \.self) { factor in
                                        HStack(spacing: 10) {
                                            Image(systemName: "checkmark.circle.fill")
                                                .font(.caption)
                                                .foregroundStyle(cardInfo.color)
                                            Text(factor)
                                                .font(.subheadline)
                                        }
                                    }
                                }
                                .padding()
                                .frame(maxWidth: .infinity, alignment: .leading)
                                .glassEffect(in: .rect(cornerRadius: 14))
                                .padding(.horizontal, 32)

                                Spacer().frame(height: 120)
                            }
                            .frame(minHeight: geo.size.height)
                        }
                        .scrollIndicators(.hidden)
                        .scrollEdgeEffectStyle(.soft, for: .top)
                    }
                    .tag(index)
                }
            }
            .tabViewStyle(.page(indexDisplayMode: .never))
        }
        .onAppear {
            withAnimation(.easeInOut(duration: 2.5).repeatForever(autoreverses: true)) {
                isFloating = true
            }
        }
    }

    @ViewBuilder
    private func cardPreview(for cardInfo: DashboardCardInfo) -> some View {
        Group {
            if cardInfo.id == "recovery" {
                RecoveryCard(
                    score: RecoveryScore(
                        score: 82,
                        hrvValue: 48,
                        restingHeartRate: 58,
                        sleepQuality: 0.85,
                        hrvBaseline: 45,
                        rhrBaseline: 60,
                        hrr: nil,
                        hrrBaseline: nil
                    ),
                    progress: 0.82
                )
            } else if cardInfo.id == "exertion" {
                ExertionCard(
                    score: ExertionScore(
                        score: 65,
                        acuteLoad: 2400,
                        chronicLoad: 2100,
                        todayStrain: 320,
                        zoneSplits: (1...5).map { ZoneTime(zone: $0, duration: 600, percentage: 0.2) }
                    ),
                    progress: 0.65
                )
            } else if cardInfo.id == "sleep" {
                SleepCard(
                    analysis: SleepAnalysis(
                        totalDuration: 27000,
                        remDuration: 5400,
                        deepDuration: 7200,
                        coreDuration: 12600,
                        awakeDuration: 1800
                    ),
                    progress: 0.94
                )
            } else if cardInfo.id == "stress" {
                StressCard(
                    score: StressScore(
                        score: 35,
                        hrvValue: 52,
                        restingHeartRate: 56,
                        hrvBaseline: 48,
                        rhrBaseline: 58
                    ),
                    progress: 0.35
                )
            }
        }
        .offset(y: isFloating ? -6 : 6)
        .allowsHitTesting(false)
    }
}

#Preview {
    CardWalkthroughPage(selectedIndex: .constant(0)) { }
}
