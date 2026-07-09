import SwiftUI

enum AppMode: String, CaseIterable, Codable {
    case active, sick, injured, vacation

    var displayName: String {
        switch self {
        case .active: "Active"
        case .sick: "Sick"
        case .injured: "Injured"
        case .vacation: "Vacation"
        }
    }

    var icon: String {
        switch self {
        case .active: "figure.run"
        case .sick: "thermometer"
        case .injured: "bandage.fill"
        case .vacation: "beach.umbrella.fill"
        }
    }

    var color: Color {
        switch self {
        case .active: .green
        case .sick: .orange
        case .injured: .red
        case .vacation: .blue
        }
    }

    var deemphasizesExertion: Bool {
        self != .active
    }

    var statusMessage: String? {
        switch self {
        case .active:
            nil
        case .sick:
            "You've indicated you are sick. Rest up and take this time to recover."
        case .injured:
            "You're marked as injured — take it easy, avoid aggravating movements, and check with a professional if needed."
        case .vacation:
            "You're on vacation — feel free to skip structured training and enjoy the break."
        }
    }
}

struct AppModePeriod: Codable, Identifiable {
    let id: UUID
    let mode: AppMode
    let startDate: Date
    var endDate: Date?

    init(id: UUID = UUID(), mode: AppMode, startDate: Date, endDate: Date? = nil) {
        self.id = id
        self.mode = mode
        self.startDate = startDate
        self.endDate = endDate
    }
}
