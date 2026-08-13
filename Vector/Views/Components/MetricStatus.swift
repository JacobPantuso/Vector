import Foundation

/// Derives a status label from where a metric's latest reading sits inside its
/// own recent history, so a status chip says something true about the data
/// instead of restating what the metric is.
enum MetricStatus {
    /// Derives a status label from where a metric's latest reading sits inside its
    /// own recent history.
    ///
    /// - Parameters:
    ///   - series: the metric's trend points, oldest first.
    ///   - higherIsBetter: `true` when a rise is favorable, `false` when a fall
    ///     is favorable, `nil` for informational metrics that aren't judged.
    ///   - baseline: optional explicit baseline; falls back to the mean of the
    ///     points before the latest reading.
    /// - Returns: a status label plus polarity for the chip, or `nil` when
    ///   there isn't enough history to say anything honest.
    static func relativeToHistory(
        series: [MetricTrendPoint],
        higherIsBetter: Bool?,
        baseline: Double? = nil
    ) -> (label: String, isPositive: Bool?)? {
        // Need at least 3 points AND a latest value, else return nil
        guard series.count >= 3 else { return nil }

        let latest = series.last!.value

        // Reference = baseline if provided and > 0, else the mean of series.dropLast()
        let reference: Double
        if let baseline, baseline > 0 {
            reference = baseline
        } else {
            let previousPoints = series.dropLast()
            guard !previousPoints.isEmpty else { return nil }
            reference = previousPoints.map(\.value).reduce(0, +) / Double(previousPoints.count)
        }

        // A series that oscillates around zero (a deviation metric) has a mean
        // near zero, which turns any wobble into a meaningless percentage.
        // Fall back to the spread of the data itself before giving up.
        let spread = (series.map(\.value).max() ?? 0) - (series.map(\.value).min() ?? 0)
        guard abs(reference) > max(spread * 0.1, 0.001) else { return nil }

        let delta = latest - reference
        let pct = delta / abs(reference) * 100

        // Band the result
        let label: String
        switch pct {
        case ..<(-12):      label = "Well below your average"
        case (-12)..<(-4):  label = "Slightly below your average"
        case (-4)..<4:      label = "Typical for you"
        case 4..<12:        label = "Slightly above your average"
        default:            label = "Well above your average"
        }

        let isPositive: Bool?
        switch higherIsBetter {
        case .none:        isPositive = nil
        case .some(true):  isPositive = abs(pct) < 4 ? true : delta >= 0
        case .some(false): isPositive = abs(pct) < 4 ? true : delta <= 0
        }

        return (label, isPositive)
    }

    /// Short "N of the last M days" style descriptor, e.g. for a stats row.
    ///
    /// Returns e.g. "Rising over 14 days" / "Falling over 14 days" / "Steady over 14 days"
    /// based on comparing the mean of the first half vs the second half (>5% change → rising/falling).
    /// Returns nil with fewer than 4 points.
    static func trendSummary(series: [MetricTrendPoint]) -> String? {
        guard series.count >= 4 else { return nil }

        let mid = series.count / 2
        let firstHalf = series[..<mid]
        let secondHalf = series[mid...]

        let firstMean = firstHalf.map(\.value).reduce(0, +) / Double(firstHalf.count)
        let secondMean = secondHalf.map(\.value).reduce(0, +) / Double(secondHalf.count)

        guard firstMean != 0 else { return nil }

        let pctChange = (secondMean - firstMean) / abs(firstMean) * 100

        let dayCount = series.count
        let trend: String
        if pctChange > 5 {
            trend = "Rising"
        } else if pctChange < -5 {
            trend = "Falling"
        } else {
            trend = "Steady"
        }

        return "\(trend) over \(dayCount) days"
    }
}
