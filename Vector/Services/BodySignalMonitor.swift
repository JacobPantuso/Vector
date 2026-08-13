import Foundation
import HealthKit

/// Watches the user's physiological baselines over the last two weeks, runs
/// `StrainPatternDetector` over them, and tracks which flagged windows the user
/// has already told us about. The detector produces hypotheses; this decides
/// which ones are still worth asking about.
@MainActor
@Observable
final class BodySignalMonitor {
    static let shared = BodySignalMonitor()

    private(set) var episodes: [StrainPatternDetector.StrainEpisode] = []
    private(set) var isLoaded = false
    private var lastLoad: Date?

    /// How far back the initial review looks.
    static let lookbackDays = 14

    func refresh(service: HealthKitService, force: Bool = false) async {
        // Skip if loaded < 10 minutes ago and !force
        if let last = lastLoad, Date().timeIntervalSince(last) < 600, !force {
            return
        }

        // Fetch all five series concurrently with async let
        async let hrvSeries = service.dailyAverageSeries(
            for: .heartRateVariabilitySDNN,
            unit: HealthKitService.msUnit,
            days: Self.lookbackDays + 7
        )
        async let restingHRSeries = service.dailyAverageSeries(
            for: .restingHeartRate,
            unit: HealthKitService.bpmUnit,
            days: Self.lookbackDays + 7
        )
        async let respiratoryRateSeries = service.dailyAverageSeries(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: Self.lookbackDays + 7
        )
        async let wristTempSeries = service.dailyAverageSeries(
            for: .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            days: Self.lookbackDays + 7
        )
        async let bloodOxygenSeries = service.dailyAverageSeries(
            for: .oxygenSaturation,
            unit: .percent(),
            days: Self.lookbackDays + 7
        )

        let (hrv, restingHR, respiratoryRate, wristTemp, bloodOxygen) = await (
            hrvSeries,
            restingHRSeries,
            respiratoryRateSeries,
            wristTempSeries,
            bloodOxygenSeries
        )

        // Map blood oxygen from 0-1 fraction to percentage points
        let bloodOxygenPercent = bloodOxygen.map { (date: $0.date, value: $0.value * 100) }

        // Run detector on all five series
        var allEpisodes = StrainPatternDetector.episodes(
            hrv: hrv,
            restingHR: restingHR,
            respiratoryRate: respiratoryRate,
            wristTemperature: wristTemp,
            bloodOxygen: bloodOxygenPercent
        )

        // Filter out episodes whose endDate is older than lookbackDays ago
        let cutoffDate = Calendar.current.date(byAdding: .day, value: -Self.lookbackDays, to: Date()) ?? Date()
        allEpisodes.removeAll { $0.endDate < cutoffDate }

        episodes = allEpisodes
        isLoaded = true
        lastLoad = Date()
    }

    /// Flagged windows the user has neither answered nor skipped, newest first.
    var pendingEpisodes: [StrainPatternDetector.StrainEpisode] {
        episodes.filter { !BodyCheckInStore.shared.hasResponded(toKey: $0.key) }
    }

    /// The most recent pending window that is still current — it ended within the
    /// last 3 days — so the app can ask while the user still remembers how they felt.
    var liveEpisode: StrainPatternDetector.StrainEpisode? {
        let threeDaysAgo = Calendar.current.date(byAdding: .day, value: -3, to: Date()) ?? Date()
        return pendingEpisodes.first { $0.endDate >= threeDaysAgo }
    }

    /// Pending windows that are older than `liveEpisode`'s cutoff, for the
    /// retrospective two-week review.
    var reviewableEpisodes: [StrainPatternDetector.StrainEpisode] {
        if let live = liveEpisode {
            return pendingEpisodes.filter { $0.id != live.id }
        } else {
            return pendingEpisodes
        }
    }
}
