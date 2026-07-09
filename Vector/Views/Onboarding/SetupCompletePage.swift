import SwiftUI

struct SetupCompletePage: View {
    @AppStorage(UserProfileStorage.firstName) private var firstName = ""

    var body: some View {
        VStack(spacing: 32) {
            Spacer()

            Image("VectorIcon")
                .resizable()
                .frame(width: 120, height: 120)
                .clipShape(.rect(cornerRadius: 28))

            VStack(spacing: 12) {
                Text("You're All Set\(firstName.isEmpty ? "" : ", \(firstName)")")
                    .font(.title.bold())

                Text("Vector is ready to start tracking your health.")
                    .font(.subheadline)
                    .foregroundStyle(.secondary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 24)
            }

            VStack(spacing: 12) {
                recapRow(icon: "person.fill", color: .cyan, title: "Profile configured")
                recapRow(icon: "heart.fill", color: .red, title: "Health data connected")
                recapRow(icon: "square.grid.2x2.fill", color: .purple, title: "Dashboard metrics explored")
                recapRow(icon: "apple.intelligence", color: .blue, title: "Smart insights enabled")
            }
            .padding(.horizontal, 20)

            Spacer()
            Spacer().frame(height: 60)
        }
    }

    private func recapRow(icon: String, color: Color, title: String) -> some View {
        HStack(spacing: 14) {
            Image(systemName: icon)
                .font(.body.weight(.semibold))
                .foregroundStyle(color)
                .frame(width: 36, height: 36)
                .glassEffect(.regular.tint(color.opacity(0.3)), in: .circle)

            Text(title)
                .font(.subheadline.weight(.medium))

            Spacer()

            Image(systemName: "checkmark.circle.fill")
                .foregroundStyle(.green)
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(in: .rect(cornerRadius: 14))
    }
}
