import ActivityKit
import AppIntents
import WidgetKit
import SwiftUI

struct WorkoutLiveActivity: Widget {
    var body: some WidgetConfiguration {
        ActivityConfiguration(for: WorkoutActivityAttributes.self) { context in
            WorkoutLockScreenView(context: context)
                .padding(16)
                .activityBackgroundTint(Color.black.opacity(0.55))
                .activitySystemActionForegroundColor(.white)
        } dynamicIsland: { context in
            let accent: Color = context.state.isResting ? .blue : .red
            return DynamicIsland {
                DynamicIslandExpandedRegion(.leading) {
                    HStack(spacing: 5) {
                        Image(systemName: "heart.fill")
                            .foregroundStyle(accent)
                        Text(context.state.heartRate > 0 ? "\(context.state.heartRate)" : "--")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(accent)
                    }
                }
                DynamicIslandExpandedRegion(.trailing) {
                    if context.state.isResting {
                        Text("\(context.state.restSecondsRemaining)s")
                            .font(.title3.bold().monospacedDigit())
                            .foregroundStyle(.blue)
                    } else {
                        Text(elapsedClock(context.state.elapsedSeconds))
                            .font(.headline)
                            .foregroundStyle(.secondary)
                            .padding(.trailing, 5)
                    }
                }
                DynamicIslandExpandedRegion(.center) {
                    HStack {
                        Image("VectorIcon")
                            .resizable()
                            .frame(width: 20, height: 20)
                        Text(context.attributes.workoutTitle)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
                DynamicIslandExpandedRegion(.bottom) {
                    VStack(alignment: .leading) {
                        Spacer()
                        HStack {
                            VStack(alignment: .leading) {
                                Text(context.state.exerciseName)
                                    .font(.headline)
                                    .lineLimit(1)
                                Text(context.state.isResting ? "Resting" : weightText(context.state))
                                    .font(.caption)
                                    .foregroundStyle(.secondary)
                                HStack {
                                    ForEach(0..<context.state.totalExercises) { index in
                                        RoundedRectangle(cornerRadius: 13)
                                            .fill(index <= context.state.exerciseIndex ? .green : accent.opacity(0.3))
                                            .frame(width: 15, height: 8)
                                    }
                                }
                            }
                            Spacer()
                            if context.state.isResting {
                                Button(intent: SkipRestIntent()) {
                                    Image(systemName: "forward.fill")
                                        .font(.system(size: 20))
                                        .padding(10)
                                }
                                .clipShape(Circle())
                                .tint(.blue)
                            } else {
                                Button(intent: LogSetIntent()) {
                                    Image(systemName: "checkmark")
                                        .font(.system(size: 20))
                                        .padding(10)
                                }
                                .clipShape(Circle())
                                .tint(.red)
                            }
                        }
                        Spacer()
                    }
                }
            } compactLeading: {
                Image("VectorIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            } compactTrailing: {
                if (context.state.isResting) {
                    Text("\(context.state.restSecondsRemaining)s")
                        .font(.caption2.bold().monospacedDigit())
                        .foregroundStyle(accent)
                } else {
                    Image(systemName: "dumbbell.fill")
                        .foregroundStyle(.red)
                }
            } minimal: {
                Image("VectorIcon")
                    .resizable()
                    .scaledToFit()
                    .frame(width: 20, height: 20)
            }
            .keylineTint(accent)
        }
    }

    private func weightText(_ s: WorkoutActivityAttributes.ContentState) -> String {
        s.weight > 0 ? String(format: "%.0f lb × %d", s.weight, s.reps) : "Bodyweight × \(s.reps)"
    }

    private func elapsedClock(_ seconds: Int) -> String {
        seconds < 60 ? "\(seconds)" : String(format: "%d:%02d", seconds / 60, seconds % 60)
    }
}

private struct WorkoutLockScreenView: View {
    let context: ActivityViewContext<WorkoutActivityAttributes>

    private var accent: Color { context.state.isResting ? .blue : .red }

    var body: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle().fill(accent.opacity(0.18))
                Circle().stroke(accent.opacity(0.6), lineWidth: 2)
                VStack(spacing: 0) {
                    Image(systemName: "heart.fill")
                        .font(.caption2)
                        .foregroundStyle(accent)
                    Text(context.state.heartRate > 0 ? "\(context.state.heartRate)" : "--")
                        .font(.system(size: 20, weight: .bold).monospacedDigit())
                        .foregroundStyle(accent)
                }
            }
            .frame(width: 58, height: 58)

            VStack(alignment: .leading, spacing: 3) {
                Text(context.attributes.workoutTitle)
                    .font(.caption2)
                    .foregroundStyle(.secondary)
                Text(context.state.exerciseName)
                    .font(.headline)
                    .lineLimit(1)
                if context.state.isResting {
                    Text("Rest · \(context.state.restSecondsRemaining)s")
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.blue)
                } else {
                    Text("Set \(context.state.setIndex + 1) of \(context.state.totalSets)" + (context.state.weight > 0 ? String(format: " · %.0f lb", context.state.weight) : ""))
                        .font(.subheadline.weight(.semibold))
                        .foregroundStyle(.red)
                }
            }

            Spacer()

            VStack(alignment: .trailing, spacing: 3) {
                Text(elapsed(context.state.elapsedSeconds))
                    .font(.system(.headline, design: .rounded).monospacedDigit())
                Text("\(context.state.exerciseIndex + 1)/\(context.state.totalExercises)")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
    }

    private func elapsed(_ s: Int) -> String {
        String(format: "%d:%02d", s / 60, s % 60)
    }
}

// MARK: - Previews

private let previewAttributes = WorkoutActivityAttributes(workoutTitle: "Push Day")

private let activeSetState = WorkoutActivityAttributes.ContentState(
    exerciseName: "Bench Press",
    exerciseIndex: 1,
    totalExercises: 5,
    setIndex: 2,
    totalSets: 4,
    isResting: false,
    restSecondsRemaining: 0,
    heartRate: 142,
    weight: 135.0,
    reps: 8,
    elapsedSeconds: 754
)

private let restingState = WorkoutActivityAttributes.ContentState(
    exerciseName: "Bench Press",
    exerciseIndex: 1,
    totalExercises: 5,
    setIndex: 2,
    totalSets: 4,
    isResting: true,
    restSecondsRemaining: 45,
    heartRate: 118,
    weight: 135.0,
    reps: 8,
    elapsedSeconds: 754
)

private let bodywightActiveState = WorkoutActivityAttributes.ContentState(
    exerciseName: "Pull Ups",
    exerciseIndex: 3,
    totalExercises: 5,
    setIndex: 1,
    totalSets: 3,
    isResting: false,
    restSecondsRemaining: 0,
    heartRate: 155,
    weight: 0.0,
    reps: 12,
    elapsedSeconds: 1245
)

#Preview("Lock Screen - Active Set", as: .content, using: previewAttributes) {
    WorkoutLiveActivity()
} contentStates: {
    activeSetState
    restingState
    bodywightActiveState
}

#Preview("Dynamic Island - Expanded", as: .dynamicIsland(.expanded), using: previewAttributes) {
    WorkoutLiveActivity()
} contentStates: {
    activeSetState
    restingState
    bodywightActiveState
}

#Preview("Dynamic Island - Compact", as: .dynamicIsland(.compact), using: previewAttributes) {
    WorkoutLiveActivity()
} contentStates: {
    activeSetState
    restingState
    bodywightActiveState
}

#Preview("Dynamic Island - Minimal", as: .dynamicIsland(.minimal), using: previewAttributes) {
    WorkoutLiveActivity()
} contentStates: {
    activeSetState
    restingState
}
