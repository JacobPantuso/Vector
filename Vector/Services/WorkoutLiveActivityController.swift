import ActivityKit
import Foundation

/// Manages the lifecycle of the active-workout Live Activity on iOS.
@MainActor
final class WorkoutLiveActivityController {
    static let shared = WorkoutLiveActivityController()

    private var activity: Activity<WorkoutActivityAttributes>?

    func start(title: String, state: WorkoutActivityAttributes.ContentState) {
        guard ActivityAuthorizationInfo().areActivitiesEnabled else { return }
        guard activity == nil else { update(state); return }
        let attributes = WorkoutActivityAttributes(workoutTitle: title)
        do {
            activity = try Activity.request(
                attributes: attributes,
                content: ActivityContent(state: state, staleDate: nil),
                pushType: nil
            )
        } catch {
            activity = nil
        }
    }

    func update(_ state: WorkoutActivityAttributes.ContentState) {
        guard let activity else { return }
        Task {
            await activity.update(ActivityContent(state: state, staleDate: nil))
        }
    }

    func end() {
        guard let activity else { return }
        let finished = activity
        self.activity = nil
        Task {
            await finished.end(nil, dismissalPolicy: .immediate)
        }
    }
}
