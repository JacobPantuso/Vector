import SwiftUI

/// The standard "About <metric>" half-sheet shown from a detail view's (?) toolbar button.
/// Looks the metric up in `DashboardCardInfo.allCards` by id; renders nothing if not found.
struct CardInfoSheet: View {
    let cardID: String

    var body: some View {
        VStack(alignment: .center, spacing: 16) {
            Spacer()
            if let cardInfo = DashboardCardInfo.allCards.first(where: { $0.id == cardID }) {
                HStack {
                    Image(systemName: cardInfo.icon)
                        .font(.title3)
                        .foregroundStyle(cardInfo.color)
                    Text("About " + cardInfo.title)
                        .font(.title3).bold()
                }
                .padding(.top, 20)

                Text(cardInfo.description)
                    .font(.body)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
            Spacer()
        }
        .padding(24)
        .multilineTextAlignment(.center)
        .presentationDetents([.height(180)])
        .presentationDragIndicator(.visible)
    }
}
