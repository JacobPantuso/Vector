import SwiftUI

struct HealthUnavailableView: View {
    var body: some View {
        VStack(spacing: 20) {
            Image(systemName: "heart.slash")
                .font(.system(size: 60))
                .foregroundStyle(.red.opacity(0.6))

            VStack(spacing: 8) {
                Text("Health Data Unavailable")
                    .font(.headline)

                Text("This feature requires an Apple device with the Health app installed. Ensure you're using a compatible device with the latest software.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
            }
            .padding(.horizontal)
        }
        .frame(maxWidth: .infinity)
        .padding(32)
        .glassEffect(in: .rect(cornerRadius: 20))
    }
}

#Preview {
    HealthUnavailableView()
        .padding()
}
