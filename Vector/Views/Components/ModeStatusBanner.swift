import SwiftUI

struct ModeStatusBanner: View {
    let mode: AppMode

    var body: some View {
        if let message = mode.statusMessage {
            HStack(spacing: 12) {
                Image(systemName: mode.icon)
                    .font(.headline)
                    .foregroundStyle(mode.color)
                    .frame(width: 24, alignment: .center)

                Text(message)
                    .font(.caption)
                    .lineLimit(3)
                    .fixedSize(horizontal: false, vertical: true)

                Spacer()
            }
            .padding()
            .frame(maxWidth: .infinity, alignment: .leading)
            .glassEffect(.regular, in: .rect(cornerRadius: 20))
        }
    }
}

#Preview {
    VStack(spacing: 12) {
        ModeStatusBanner(mode: .sick)
        ModeStatusBanner(mode: .injured)
        ModeStatusBanner(mode: .vacation)
    }
    .padding()
}
