import SwiftUI

struct OnboardingView: View {
    @Binding var hasCompletedOnboarding: Bool
    @State private var currentPage = 0
    @State private var navigatingForward = true
    @State private var walkthroughCardIndex = 0
    @State private var animateBlobs = false

    private var pageTransition: AnyTransition {
        .asymmetric(
            insertion: .move(edge: navigatingForward ? .trailing : .leading).combined(with: .opacity),
            removal: .move(edge: navigatingForward ? .leading : .trailing).combined(with: .opacity)
        )
    }

    var body: some View {
        ZStack {
            ZStack {
                Color(.systemBackground)

                Circle()
                    .fill(Color.purple.opacity(0.18))
                    .frame(width: 280, height: 280)
                    .blur(radius: 100)
                    .offset(
                        x: animateBlobs ? -100 : -60,
                        y: animateBlobs ? -180 : -220
                    )

                Circle()
                    .fill(Color.blue.opacity(0.12))
                    .frame(width: 220, height: 220)
                    .blur(radius: 90)
                    .offset(
                        x: animateBlobs ? 120 : 60,
                        y: animateBlobs ? 60 : 140
                    )

                Circle()
                    .fill(Color.indigo.opacity(0.14))
                    .frame(width: 200, height: 200)
                    .blur(radius: 80)
                    .offset(
                        x: animateBlobs ? 40 : -80,
                        y: animateBlobs ? -40 : 40
                    )

                Circle()
                    .fill(Color.purple.opacity(0.2))
                    .frame(width: 340, height: 340)
                    .blur(radius: 130)
                    .offset(
                        x: animateBlobs ? -60 : 20,
                        y: animateBlobs ? 260 : 340
                    )

                Circle()
                    .fill(Color.blue.opacity(0.15))
                    .frame(width: 300, height: 300)
                    .blur(radius: 110)
                    .offset(
                        x: animateBlobs ? 100 : 50,
                        y: animateBlobs ? 350 : 420
                    )

                Circle()
                    .fill(Color.cyan.opacity(0.08))
                    .frame(width: 180, height: 180)
                    .blur(radius: 70)
                    .offset(
                        x: animateBlobs ? -120 : -40,
                        y: animateBlobs ? 180 : 240
                    )
            }
            .animation(.easeInOut(duration: 8).repeatForever(autoreverses: true), value: animateBlobs)
            .onAppear { animateBlobs = true }
            .ignoresSafeArea()

            Group {
                switch currentPage {
                case 0:
                    WelcomePage(onContinue: { })
                case 1:
                    ProfileSetupPage(onContinue: { })
                case 2:
                    HealthPermissionPage(onContinue: { })
                case 3:
                    CardWalkthroughPage(selectedIndex: $walkthroughCardIndex, onContinue: { })
                case 4:
                    AISetupPage(onComplete: { })
                case 5:
                    SetupCompletePage()
                default:
                    WelcomePage(onContinue: { })
                }
            }
            .transition(pageTransition)
            .safeAreaBar(edge: .top) {
                if currentPage > 0 && currentPage < 5 {
                    HStack {
                        HStack(spacing: 8) {
                            Image("VectorIcon")
                                .resizable()
                                .frame(width: 32, height: 32)
                                .clipShape(.rect(cornerRadius: 7))
                            HStack(alignment: .center, spacing: 4) {
                                Text("Vector")
                                    .font(.headline.weight(.semibold))
                                Text("Onboarding")
                                    .font(.subheadline)
                                    .foregroundStyle(.secondary)
                            }
                        }
                        Spacer()
                    }
                    .padding(.horizontal, 20)
                    .padding(.vertical, 8)
                }
            }

            VStack {
                Spacer()
                navigationBar
            }
        }
    }

    private func goForward() {
        if currentPage == 3 && walkthroughCardIndex < DashboardCardInfo.allCards.count - 1 {
            withAnimation(.easeInOut(duration: 0.3)) {
                walkthroughCardIndex += 1
            }
        } else {
            navigatingForward = true
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                currentPage += 1
            }
        }
    }

    private func goBack() {
        if currentPage == 3 && walkthroughCardIndex > 0 {
            withAnimation(.easeInOut(duration: 0.3)) {
                walkthroughCardIndex -= 1
            }
        } else {
            navigatingForward = false
            withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                currentPage -= 1
            }
        }
    }

    private var navigationBar: some View {
        VStack {
            Spacer()
            ZStack {
                LinearGradient(colors: [.clear, Color(.systemBackground).opacity(0.8), Color(.systemBackground)], startPoint: .top, endPoint: .bottom)
                    .frame(height: 120)
                    .ignoresSafeArea(edges: .bottom)

                VStack(spacing: 12) {
                    if currentPage == 3 {
                        HStack(spacing: 8) {
                            ForEach(0..<DashboardCardInfo.allCards.count, id: \.self) { index in
                                Capsule()
                                    .fill(walkthroughCardIndex == index ? Color.primary : Color.primary.opacity(0.3))
                                    .frame(width: walkthroughCardIndex == index ? 24 : 8, height: 8)
                                    .animation(.easeInOut(duration: 0.3), value: walkthroughCardIndex)
                            }
                        }
                        .frame(maxWidth: .infinity)
                        .transition(.opacity)
                    }

                    HStack {
                        if currentPage > 0 {
                            Button(action: goBack) {
                                Image(systemName: "arrow.left")
                                    .font(.body.weight(.semibold))
                                    .frame(width: 48, height: 48)
                            }
                            .buttonStyle(.glass)
                            .clipShape(Capsule())
                            .transition(.opacity.combined(with: .scale))
                        }

                        Spacer()

                        Button {
                            if currentPage == 0 {
                                navigatingForward = true
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    currentPage = 1
                                }
                            } else if currentPage < 5 {
                                goForward()
                            } else {
                                withAnimation(.spring(response: 0.5, dampingFraction: 0.85)) {
                                    hasCompletedOnboarding = true
                                }
                            }
                        } label: {
                            Group {
                                if currentPage == 0 || currentPage == 5 {
                                    Text(currentPage == 0 ? "Get Started" : "Let's Go")
                                        .font(.body.weight(.semibold))
                                        .padding(.horizontal, 12)
                                        .padding(.vertical, 12)
                                } else {
                                    Image(systemName: "arrow.right")
                                        .font(.body.weight(.semibold))
                                        .frame(width: 48, height: 48)
                                }
                            }
                            .animation(.smooth, value: currentPage)
                        }
                        .buttonStyle(.glass)
                        .clipShape(Capsule())
                    }
                }
                .padding(.horizontal, 24)
                .padding(.bottom, 4)
            }
        }
    }
}
