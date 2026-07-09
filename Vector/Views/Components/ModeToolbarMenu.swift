import SwiftUI

struct ModeToolbarMenu: View {
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
            Image(systemName: AppModeStore.shared.currentMode.icon)
                .foregroundStyle(AppModeStore.shared.currentMode.color)
        }
    }
}

#Preview {
    ModeToolbarMenu()
}
