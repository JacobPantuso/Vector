import Foundation

@Observable
final class AppModeStore {
    static let shared = AppModeStore()

    private(set) var currentMode: AppMode

    init() {
        if let rawValue = UserDefaults.standard.string(forKey: "vector.appMode"),
           let mode = AppMode(rawValue: rawValue) {
            self.currentMode = mode
        } else {
            self.currentMode = .active
        }
    }

    func setMode(_ mode: AppMode) {
        guard mode != currentMode else { return }
        currentMode = mode
        UserDefaults.standard.set(mode.rawValue, forKey: "vector.appMode")
        AppModeHistoryStore.shared.recordModeChange(to: mode)
    }
}
