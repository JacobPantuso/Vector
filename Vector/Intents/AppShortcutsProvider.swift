import AppIntents

struct VectorShortcuts: AppShortcutsProvider {
    @AppShortcutsBuilder
    static var appShortcuts: [AppShortcut] {
        AppShortcut(intent: GetRecoveryScoreIntent(), phrases: [
            "What's my recovery in \(.applicationName)",
            "How ready am I in \(.applicationName)",
            "Show my recovery score in \(.applicationName)",
        ], shortTitle: "Recovery Score", systemImageName: "heart.circle")

        AppShortcut(intent: GetExertionIntent(), phrases: [
            "How hard did I train in \(.applicationName)",
            "What's my exertion in \(.applicationName)",
            "Show my training load in \(.applicationName)",
        ], shortTitle: "Exertion Score", systemImageName: "flame")

        AppShortcut(intent: GetSleepSummaryIntent(), phrases: [
            "How did I sleep in \(.applicationName)",
            "Show my sleep summary in \(.applicationName)",
        ], shortTitle: "Sleep Summary", systemImageName: "moon.fill")

        AppShortcut(intent: GetHeartRateIntent(), phrases: [
            "What's my heart rate in \(.applicationName)",
        ], shortTitle: "Heart Rate", systemImageName: "heart.fill")

        AppShortcut(intent: GetWeeklySummaryIntent(), phrases: [
            "Show my weekly summary in \(.applicationName)",
            "How was my week in \(.applicationName)",
        ], shortTitle: "Weekly Summary", systemImageName: "chart.bar.fill")

        AppShortcut(intent: AskAdvisorIntent(), phrases: [
            "Ask \(.applicationName) about my fitness",
            "Open \(.applicationName) advisor",
        ], shortTitle: "Health Advisor", systemImageName: "brain.head.profile.fill")
    }
}
