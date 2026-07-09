import SwiftUI

struct DashboardHelpSheet: View {
    @Environment(\.dismiss) private var dismiss

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 16) {
                    ForEach(DashboardCardInfo.allCards) { info in
                        VStack(alignment: .leading, spacing: 12) {
                            HStack(spacing: 14) {
                                Image(systemName: info.icon)
                                    .font(.title2)
                                    .foregroundStyle(info.color)
                                    .frame(width: 44, height: 44)
                                    .glassEffect(.regular.tint(info.color), in: .circle)

                                VStack(alignment: .leading, spacing: 4) {
                                    Text(info.title)
                                        .font(.headline)
                                    Text(info.headline)
                                        .font(.subheadline)
                                        .foregroundStyle(.secondary)
                                }
                                Spacer()
                            }

                            Text(info.description)
                                .font(.caption)
                                .foregroundStyle(.secondary)

                            HStack(spacing: 6) {
                                ForEach(info.factors, id: \.self) { factor in
                                    Text(factor)
                                        .font(.caption2)
                                        .padding(.horizontal, 8)
                                        .padding(.vertical, 4)
                                        .glassEffect(.regular.tint(info.color.opacity(0.15)), in: .capsule)
                                }
                            }
                        }
                        .padding()
                        .glassEffect(in: .rect(cornerRadius: 16))
                    }
                }
                .padding(.horizontal, 20)
                .padding(.vertical, 16)
            }
            .navigationTitle("Dashboard Guide")
            .navigationBarTitleDisplayMode(.inline)
        }
    }
}
