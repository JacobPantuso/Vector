import SwiftUI

struct DashboardCardInfo: Identifiable {
    let id: String
    let title: String
    let icon: String
    let color: Color
    let headline: String
    let description: String
    let factors: [String]
    let metricExample: String
    let metricLabel: String

    static let allCards: [DashboardCardInfo] = [
        DashboardCardInfo(
            id: "recovery",
            title: "Recovery",
            icon: "battery.100",
            color: .green,
            headline: "Know when to push",
            description: "Your recovery score tells you whether your body is ready to train hard or needs rest. It's calculated overnight so you wake up with a clear picture.",
            factors: ["Heart Rate Variability (HRV)", "Resting Heart Rate", "Sleep Quality", "HRV & RHR Baselines"],
            metricExample: "82",
            metricLabel: "Recovery Score"
        ),
        DashboardCardInfo(
            id: "exertion",
            title: "Exertion",
            icon: "flame.fill",
            color: .orange,
            headline: "Stay balanced",
            description: "Tracks your daily strain and weekly training load to help you avoid overtraining. Compares your recent load to your long-term average to keep you in the sweet spot.",
            factors: ["Active Energy Burned", "Workout Intensity", "Acute vs Chronic Load Ratio", "Heart Rate Zones"],
            metricExample: "65",
            metricLabel: "Exertion Score"
        ),
        DashboardCardInfo(
            id: "sleep",
            title: "Sleep",
            icon: "moon.fill",
            color: .blue,
            headline: "Understand your nights",
            description: "Breaks down your sleep architecture and scores its quality. Good sleep is the single biggest lever for recovery, performance, and stress resilience.",
            factors: ["Total Duration", "REM & Deep Sleep", "Sleep Efficiency", "Bedtime & Wake Time"],
            metricExample: "7h 30m",
            metricLabel: "Total Sleep"
        ),
        DashboardCardInfo(
            id: "stress",
            title: "Stress",
            icon: "waveform.path.ecg",
            color: .indigo,
            headline: "Read your nervous system",
            description: "Estimates physiological stress by reading signals from your autonomic nervous system. Adjusts for your circadian rhythm so morning readings stay accurate.",
            factors: ["Heart Rate Variability", "Resting Heart Rate", "Sleep Quality", "Respiratory Rate"],
            metricExample: "35",
            metricLabel: "Stress Level"
        )
    ]
}
