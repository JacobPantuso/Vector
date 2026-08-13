import ActivityKit
import Foundation

// Shared between the Vector app target and the VectorWidgets extension target.
// ActivityKit matches the Activity to the widget by this type's (unqualified) name,
// so the SAME source file must be compiled into both targets.
struct WorkoutActivityAttributes: ActivityAttributes {
    struct ContentState: Codable, Hashable {
        var exerciseName: String
        var exerciseIndex: Int
        var totalExercises: Int
        var setIndex: Int          // 0-based
        var totalSets: Int
        var isResting: Bool
        var restSecondsRemaining: Int
        var restEndDate: Date?     // when rest ends; drives a native per-second countdown. nil when not resting
        var heartRate: Int
        var weight: Double          // lbs; 0 == bodyweight
        var reps: Int
        var elapsedSeconds: Int
        var startDate: Date        // effective anchor for a live-counting timer (now - elapsedSeconds); shifts forward across pauses
        var isPaused: Bool
    }

    var workoutTitle: String
}
