import Foundation

/// Robust statistics shared by the scoring engines: median/MAD baselines, log z-scores,
/// gap-aware EWMA, and data-coverage confidence. Replaces the old "mean of dropLast" pattern.
enum BaselineStatistics {
    static func mean(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        return xs.reduce(0, +) / Double(xs.count)
    }

    static func median(_ xs: [Double]) -> Double? {
        guard !xs.isEmpty else { return nil }
        let s = xs.sorted()
        let n = s.count
        return n % 2 == 1 ? s[n / 2] : (s[n / 2 - 1] + s[n / 2]) / 2
    }

    /// Sample standard deviation (n-1). nil if fewer than 2 values.
    static func standardDeviation(_ xs: [Double]) -> Double? {
        guard xs.count > 1, let m = mean(xs) else { return nil }
        let ss = xs.reduce(0) { $0 + ($1 - m) * ($1 - m) }
        return (ss / Double(xs.count - 1)).squareRoot()
    }

    /// Median absolute deviation. nil if empty.
    static func mad(_ xs: [Double]) -> Double? {
        guard let med = median(xs) else { return nil }
        return median(xs.map { abs($0 - med) })
    }

    /// Outlier-rejected copy using the modified z-score (|Mi| > 3.5), per Iglewicz–Hoaglin.
    static func rejectOutliers(_ xs: [Double]) -> [Double] {
        guard xs.count >= 4, let med = median(xs), let madv = mad(xs), madv > 0 else { return xs }
        let filtered = xs.filter { abs(0.6745 * ($0 - med) / madv) <= 3.5 }
        return filtered.isEmpty ? xs : filtered
    }

    /// log-domain z-score of `current` vs `history` (lnRMSSD/lnSDNN, Plews method).
    /// Robust: history is outlier-rejected; center = median(ln), scale = 1.4826·MAD(ln)
    /// with a sample-SD fallback. Returns nil if there isn't enough data/spread.
    static func logZScore(current: Double, history: [Double]) -> Double? {
        guard current > 0 else { return nil }
        let lnHist = rejectOutliers(history.filter { $0 > 0 }).map { Foundation.log($0) }
        guard lnHist.count >= 3, let center = median(lnHist) else { return nil }
        let scale: Double
        if let m = mad(lnHist), m > 0 {
            scale = 1.4826 * m
        } else if let sd = standardDeviation(lnHist), sd > 0 {
            scale = sd
        } else {
            return nil
        }
        return (Foundation.log(current) - center) / scale
    }

    /// Gap-aware EWMA over chronologically ordered values (oldest→newest). nil if empty.
    static func ewma(_ xs: [Double], alpha: Double = 0.25) -> Double? {
        guard let first = xs.first else { return nil }
        var acc = first
        for x in xs.dropFirst() { acc = alpha * x + (1 - alpha) * acc }
        return acc
    }

    /// Data-coverage confidence 0...1, reaching ~1.0 at `full` days.
    static func confidence(days: Int, full: Int = 21) -> Double {
        guard full > 0 else { return 0 }
        return Swift.min(1.0, Swift.max(0.0, Double(days) / Double(full)))
    }
}

enum ConfidenceTier: String, Codable, Sendable {
    case low, moderate, high

    init(confidence: Double) {
        switch confidence {
        case ..<0.34: self = .low
        case ..<0.67: self = .moderate
        default: self = .high
        }
    }

    var label: String {
        switch self {
        case .low: return "Calibrating"
        case .moderate: return "Fair confidence"
        case .high: return "High confidence"
        }
    }
}
