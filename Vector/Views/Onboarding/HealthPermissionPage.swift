import SwiftUI
import HealthKit

struct HealthPermissionPage: View {
    var onContinue: () -> Void
    @State private var isRequesting = false
    @State private var appeared = false
    @Environment(HealthKitService.self) private var healthService

    var body: some View {
        GeometryReader { geo in
        ScrollView {
            VStack(spacing: 24) {
                VStack(spacing: 8) {
                    Image(systemName: "heart.text.clipboard")
                        .font(.system(size: 32))
                        .foregroundStyle(.red)
                        .frame(width: 64, height: 64)
                        .glassEffect(in: .circle)

                    Text("Connect Your Health Data")
                        .font(.title.bold())

                    Text("Vector reads your health data to calculate your recovery, exertion, stress, and sleep scores.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 24)
                }
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 15)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.1), value: appeared)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "info.circle")
                            .foregroundStyle(.cyan)
                            .frame(width: 20, height: 20)

                        Text("Why we need this")
                            .font(.subheadline.bold())

                        Spacer()
                    }

                    Text("Vector reads your heart rate, HRV, sleep stages, workouts, and nutrition data to calculate your recovery, exertion, stress, and sleep scores. The more data you share, the more accurate and personalized your insights become.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
                .padding(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.3), value: appeared)

                VStack(spacing: 12) {
                    HStack(spacing: 12) {
                        Image(systemName: "lock.shield.fill")
                            .foregroundStyle(.green)
                            .frame(width: 20, height: 20)

                        Text("Your privacy matters")
                            .font(.subheadline.bold())

                        Spacer()
                    }

                    Text("Your data stays on your device. Vector uses Apple's HealthKit framework—your health information is never uploaded to external servers.")
                        .font(.subheadline)
                        .foregroundStyle(.secondary)
                }
                .padding()
                .glassEffect(in: .rect(cornerRadius: 16))
                .padding(.horizontal)
                .opacity(appeared ? 1 : 0)
                .offset(y: appeared ? 0 : 20)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.4), value: appeared)

                Text("We recommend sharing all available categories for the best experience.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
                    .opacity(appeared ? 1 : 0)
                    .offset(y: appeared ? 0 : 20)
                    .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.5), value: appeared)

                VStack(spacing: 12) {
                    Button {
                        isRequesting = true
                        Task {
                            await healthService.requestAuthorization()
                            isRequesting = false
                            onContinue()
                        }
                    } label: {
                        if isRequesting {
                            ProgressView()
                        } else {
                            Text("Allow Health Access")
                        }
                    }
                    .buttonStyle(.glassProminent)
                    .controlSize(.large)
                    .padding(.horizontal, 48)
                    .disabled(isRequesting)

                    Button("Skip for now", action: onContinue)
                        .font(.footnote)
                        .foregroundStyle(.secondary)
                }
                .opacity(appeared ? 1 : 0)
                .animation(.spring(response: 0.5, dampingFraction: 0.8).delay(0.8), value: appeared)
            }
            .padding(.vertical, 20)
            .frame(minHeight: geo.size.height)
        }
        .scrollEdgeEffectStyle(.soft, for: .top)
        }
        .onAppear {
            appeared = true
        }
    }
}
