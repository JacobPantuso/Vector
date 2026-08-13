import SwiftUI

struct ModeToolbarMenu: View {
    enum Style {
        case toolbar
        case headerChip
    }

    var style: Style = .toolbar

    var body: some View {
        Menu {
            ForEach(AppMode.allCases, id: \.self) { mode in
                Button {
                    AppModeStore.shared.setMode(mode)
                } label: {
                    Label(mode.displayName, systemImage: mode.icon)
                }
            }
        } label: {
            switch style {
            case .toolbar:
                Image(systemName: AppModeStore.shared.currentMode.icon)
                    .foregroundStyle(AppModeStore.shared.currentMode.color)
            case .headerChip:
                Image(systemName: AppModeStore.shared.currentMode.icon)
                    .font(.system(size: 15, weight: .semibold))
                    .foregroundStyle(AppModeStore.shared.currentMode.color)
                    .frame(width: 34, height: 34)
                    .glassEffect(.regular, in: .circle)
                    .contentTransition(.symbolEffect(.replace))
            }
        }
    }
}

#Preview {
    ModeToolbarMenu()
}
