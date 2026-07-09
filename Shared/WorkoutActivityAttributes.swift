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
        var heartRate: Int
        var weight: Double          // lbs; 0 == bodyweight
        var reps: Int
        var elapsedSeconds: Int
    }

    var workoutTitle: String
}
