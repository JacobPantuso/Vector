import Foundation

/// Detects windows where several physiological signals drift off baseline together,
/// surfacing a confirmable hypothesis about body strain. This is an observation of the data,
/// never a diagnosis — the app will ask the user to confirm and learn their personal patterns.
enum StrainPatternDetector {
    // MARK: - Types

    /// One physiological channel the detector watches.
    enum BodySignal: String, Codable, Sendable, CaseIterable {
        case hrv
        case restingHR
        case respiratoryRate
        case wristTemperature
        case bloodOxygen

        var label: String {
            switch self {
            case .hrv: return "HRV"
            case .restingHR: return "Resting Heart Rate"
            case .respiratoryRate: return "Respiratory Rate"
            case .wristTemperature: return "Wrist Temperature"
            case .bloodOxygen: return "Blood Oxygen"
            }
        }

        var icon: String {
            switch self {
            case .hrv: return "waveform.path.ecg"
            case .restingHR: return "heart.fill"
            case .respiratoryRate: return "lungs.fill"
            case .wristTemperature: return "thermometer.medium"
            case .bloodOxygen: return "lungs.fill"
            }
        }

        /// Whether a RISE in this signal indicates strain. HRV and blood oxygen strain when they FALL.
        var risingMeansStrain: Bool {
            switch self {
            case .hrv: return false
            case .restingHR: return true
            case .respiratoryRate: return true
            case .wristTemperature: return true
            case .bloodOxygen: return false
            }
        }
    }

    /// How far one signal sat from the user's own baseline on a given day.
    struct SignalDeviation: Codable, Sendable, Hashable, Identifiable {
        var id: String { signal.rawValue }
        let signal: BodySignal
        /// Robust z-score oriented so POSITIVE always means "in the straining direction",
        /// regardless of whether this signal strains by rising or falling.
        let strainZ: Double
        let value: Double
        let baseline: Double

        /// Plain-language phrase for the UI, e.g. "HRV 18% below your baseline"
        /// or "wrist temperature +0.4°C vs baseline".
        ///
        /// Interpolates the words and formats only the numbers: passing a Swift
        /// `String` to a `%s` specifier crashes, because `%s` dereferences the
        /// bridged object as a C string.
        var summary: String {
            let delta = value - baseline
            switch signal {
            case .hrv:
                guard baseline != 0 else { return "HRV off your baseline" }
                let pct = delta / baseline * 100
                return "HRV \(Int(abs(pct).rounded()))% \(pct < 0 ? "below" : "above") your baseline"
            case .restingHR:
                let amount = String(format: "%.0f", abs(delta))
                return "Resting HR \(amount) bpm \(delta > 0 ? "above" : "below") your baseline"
            case .respiratoryRate:
                let amount = String(format: "%.1f", abs(delta))
                return "Respiratory rate \(amount) breaths/min \(delta > 0 ? "above" : "below") baseline"
            case .wristTemperature:
                let amount = String(format: "%+.1f", delta)
                return "Wrist temperature \(amount)°C vs baseline"
            case .bloodOxygen:
                let amount = String(format: "%.1f", abs(delta))
                return "Blood oxygen \(amount)% \(delta < 0 ? "below" : "above") baseline"
            }
        }
    }

    enum StrainSeverity: String, Codable, Sendable {
        case mild
        case notable
        case strong

        var label: String {
            switch self {
            case .mild: return "Slightly off"
            case .notable: return "Noticeably off"
            case .strong: return "Well off baseline"
            }
        }
    }

    /// A window where several independent signals drifted off baseline together.
    /// This is a hypothesis to confirm with the user, never a diagnosis.
    struct StrainEpisode: Identifiable, Codable, Sendable, Hashable {
        let id: UUID
        let startDate: Date
        let endDate: Date
        /// Only the signals that actually sat off baseline (strainZ >= signalThreshold),
        /// each represented by its strongest reading across the episode.
        let deviations: [SignalDeviation]
        let severity: StrainSeverity

        var dayCount: Int {
            let calendar = Calendar.current
            let startDay = calendar.startOfDay(for: startDate)
            let endDay = calendar.startOfDay(for: endDate)
            let components = calendar.dateComponents([.day], from: startDay, to: endDay)
            return (components.day ?? 0) + 1
        }

        /// Stable identity across recomputation so answered episodes stay answered even
        /// though `id` is fresh each run. Use the start/end day, e.g. "2026-08-03_2026-08-05".
        var key: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "yyyy-MM-dd"
            let startStr = formatter.string(from: Calendar.current.startOfDay(for: startDate))
            let endStr = formatter.string(from: Calendar.current.startOfDay(for: endDate))
            return "\(startStr)_\(endStr)"
        }

        var headline: String {
            return "Your body was working harder than usual"
        }

        var dateRangeLabel: String {
            let formatter = DateFormatter()
            formatter.dateFormat = "MMM d"
            let start = formatter.string(from: startDate)
            if dayCount == 1 {
                return start
            }
            formatter.dateFormat = "d"
            let end = formatter.string(from: endDate)
            return "\(start)–\(end)"
        }

        var signalSummaries: [String] {
            return deviations.map { $0.summary }
        }
    }

    // MARK: - Constants

    /// Minimum oriented z-score for a signal to count as off baseline.
    static let signalThreshold: Double = 1.5
    /// How many signals must be off together before it's an episode.
    static let minimumSignals: Int = 2

    // MARK: - Main Algorithm

    /// Finds strain episodes across the supplied daily series.
    /// Every series is `(date, value)` ascending, as returned by
    /// `HealthKitService.dailyAverageSeries(for:unit:days:)`. Pass whatever is available;
    /// missing or too-short series are simply skipped.
    static func episodes(
        hrv: [(date: Date, value: Double)] = [],
        restingHR: [(date: Date, value: Double)] = [],
        respiratoryRate: [(date: Date, value: Double)] = [],
        wristTemperature: [(date: Date, value: Double)] = [],
        bloodOxygen: [(date: Date, value: Double)] = []
    ) -> [StrainEpisode] {
        let calendar = Calendar.current
        var allDays = Set<Date>()
        var dayDeviations: [Date: [SignalDeviation]] = [:]

        // Collect all deviations by calendar day.
        for (signal, series) in [
            (BodySignal.hrv, hrv),
            (BodySignal.restingHR, restingHR),
            (BodySignal.respiratoryRate, respiratoryRate),
            (BodySignal.wristTemperature, wristTemperature),
            (BodySignal.bloodOxygen, bloodOxygen)
        ] {
            guard series.count >= 5 else { continue }

            let deviationForSignal = computeDeviations(signal: signal, series: series, calendar: calendar)
            for (day, deviation) in deviationForSignal {
                allDays.insert(day)
                if dayDeviations[day] == nil {
                    dayDeviations[day] = []
                }
                dayDeviations[day]?.append(deviation)
            }
        }

        // Return empty if fewer than 2 signals have usable history.
        let signalCount = [hrv, restingHR, respiratoryRate, wristTemperature, bloodOxygen]
            .filter { $0.count >= 5 }
            .count
        guard signalCount >= 2 else { return [] }

        // Flag days where at least minimumSignals qualify.
        let flaggedDays = allDays.filter { day in
            let deviations = dayDeviations[day] ?? []
            let qualifying = deviations.filter { $0.strainZ >= signalThreshold }
            return qualifying.count >= minimumSignals
        }.sorted()

        guard !flaggedDays.isEmpty else { return [] }

        // Merge adjacent or single-day-separated flagged days into episodes.
        let episodes = mergeIntoEpisodes(flaggedDays: flaggedDays, dayDeviations: dayDeviations, calendar: calendar)

        // Sort newest first.
        return episodes.sorted { $0.startDate > $1.startDate }
    }

    // MARK: - Helpers

    private static func computeDeviations(
        signal: BodySignal,
        series: [(date: Date, value: Double)],
        calendar: Calendar
    ) -> [Date: SignalDeviation] {
        var result: [Date: SignalDeviation] = [:]
        let values = series.map { $0.value }

        let baseline: Double
        let deviations: [(Date, Double, Double)]?

        switch signal {
        case .hrv:
            // Use log z-score; history is all values.
            baseline = BaselineStatistics.median(values) ?? 0
            guard baseline > 0 else { return result }
            deviations = series.compactMap { (date, value) -> (Date, Double, Double)? in
                guard let logZ = BaselineStatistics.logZScore(current: value, history: values) else { return nil }
                // Orient: negative z = strain (HRV falling means strain).
                let strainZ = -logZ
                return (date, strainZ, value)
            }

        default:
            // Robust z-score: median and MAD on outlier-rejected history.
            let rejected = BaselineStatistics.rejectOutliers(values)
            baseline = BaselineStatistics.median(rejected) ?? 0
            // Assume strictly-positive absolute measurements (bpm, °C, %, ms).
            // Would need revisiting if a deviation-style series were passed in.
            guard baseline > 0 else { return result }

            let scale: Double
            if let m = BaselineStatistics.mad(rejected), m > 0 {
                scale = 1.4826 * m
            } else if let sd = BaselineStatistics.standardDeviation(rejected), sd > 0 {
                scale = sd
            } else {
                return result
            }

            deviations = series.map { (date, value) in
                let z = (value - baseline) / scale
                let strainZ = signal.risingMeansStrain ? z : -z
                return (date, strainZ, value)
            }
        }

        guard let devs = deviations else { return result }
        for (date, strainZ, value) in devs {
            let day = calendar.startOfDay(for: date)
            let deviation = SignalDeviation(signal: signal, strainZ: strainZ, value: value, baseline: baseline)
            result[day] = deviation
        }

        return result
    }

    private static func mergeIntoEpisodes(
        flaggedDays: [Date],
        dayDeviations: [Date: [SignalDeviation]],
        calendar: Calendar
    ) -> [StrainEpisode] {
        var episodes: [StrainEpisode] = []
        var currentStart: Date?
        var currentEnd: Date?
        var currentDeviationMap: [String: SignalDeviation] = [:]

        for day in flaggedDays {
            if let start = currentStart, let end = currentEnd {
                // Check gap: is this day within 1 day of the current episode?
                let gapDays = calendar.dateComponents([.day], from: end, to: day).day ?? 0
                if gapDays <= 1 {
                    // Merge: extend current episode.
                    currentEnd = day
                    // Update deviations with the peak z-scores.
                    if let devs = dayDeviations[day] {
                        for dev in devs where dev.strainZ >= signalThreshold {
                            let key = dev.signal.rawValue
                            if let existing = currentDeviationMap[key] {
                                if dev.strainZ > existing.strainZ {
                                    currentDeviationMap[key] = dev
                                }
                            } else {
                                currentDeviationMap[key] = dev
                            }
                        }
                    }
                    continue
                }
            }

            // Start a new episode if we have a gap.
            if let start = currentStart, let end = currentEnd {
                let severity = calculateSeverity(deviations: Array(currentDeviationMap.values))
                let episode = StrainEpisode(
                    id: UUID(),
                    startDate: start,
                    endDate: end,
                    deviations: Array(currentDeviationMap.values).sorted { $0.signal.rawValue < $1.signal.rawValue },
                    severity: severity
                )
                episodes.append(episode)
            }

            currentStart = day
            currentEnd = day
            currentDeviationMap = [:]
            if let devs = dayDeviations[day] {
                for dev in devs where dev.strainZ >= signalThreshold {
                    currentDeviationMap[dev.signal.rawValue] = dev
                }
            }
        }

        // Finalize the last episode.
        if let start = currentStart, let end = currentEnd {
            let severity = calculateSeverity(deviations: Array(currentDeviationMap.values))
            let episode = StrainEpisode(
                id: UUID(),
                startDate: start,
                endDate: end,
                deviations: Array(currentDeviationMap.values).sorted { $0.signal.rawValue < $1.signal.rawValue },
                severity: severity
            )
            episodes.append(episode)
        }

        return episodes
    }

    private static func calculateSeverity(deviations: [SignalDeviation]) -> StrainSeverity {
        let n = deviations.count
        let peak = deviations.map { $0.strainZ }.max() ?? 0

        if n >= 3 && peak >= 2.5 {
            return .strong
        } else if n >= 3 || peak >= 2.5 {
            return .notable
        } else {
            return .mild
        }
    }
}
