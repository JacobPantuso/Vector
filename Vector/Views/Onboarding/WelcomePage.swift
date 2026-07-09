import SwiftUI

struct WelcomePage: View {
    var onContinue: () -> Void
    @State private var appeared = false
    @State private var pulsing = false

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("VectorIcon")
                .resizable()
                .frame(width: 160, height: 160)
                .clipShape(.rect(cornerRadius: 36))
                .scaleEffect(appeared ? 1 : 0.5)
                .opacity(appeared ? 1 : 0)
                .scaleEffect(pulsing ? 1.05 : 1)
                .animation(.spring(response: 0.6, dampingFraction: 0.7).delay(0.1), value: appeared)
                .animation(.easeInOut(duration: 1.5).repeatForever(autoreverses: true), value: pulsing)
                .onAppear {
                    DispatchQueue.main.asyncAfter(deadline: .now() + 0.7) {
                        pulsing = true
                    }
                }

            VStack(spacing: 12) {
                Text("Vector")
                    .font(.system(size: 48, weight: .bold, design: .rounded))

                Text("Your health, intelligently understood.")
                    .font(.title3)
                    .foregroundStyle(.secondary)

                Text("Track recovery, exertion, and sleep with AI-powered insights from your Apple Watch and HealthKit data.")
                    .font(.subheadline)
                    .foregroundStyle(.tertiary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.top, 4)
            }
            .offset(y: appeared ? 0 : 20)
            .opacity(appeared ? 1 : 0)
            .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)

            Spacer()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.05) {
                appeared = true
            }
        }
    }
}
