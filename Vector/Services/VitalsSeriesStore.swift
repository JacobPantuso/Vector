import SwiftUI
import HealthKit

@Observable
@MainActor
final class VitalsSeriesStore {
    private(set) var series: [VitalMetric: [(date: Date, value: Double)]] = [:]
    /// Time-of-day-matched history for the metrics whose value accumulates or swings across the
    /// day. Each prior day is truncated to the current clock time so today's partial value is
    /// judged against a comparable figure instead of a full-day total.
    private(set) var paceSeries: [VitalMetric: [(date: Date, value: Double)]] = [:]
    private(set) var isLoaded = false
    private var lastLoad: Date?

    func load(service: HealthKitService, force: Bool = false) async {
        // Skip if loaded < 10 minutes ago and !force
        if let last = lastLoad, Date().timeIntervalSince(last) < 600, !force {
            return
        }

        var newSeries: [VitalMetric: [(date: Date, value: Double)]] = [:]

        async let hrSamples = service.fetchHeartRateSamples(
            for: DateInterval(start: Calendar.current.startOfDay(for: Date()), end: Date())
        )
        async let hrvSeries = service.dailyAverageSeries(
            for: .heartRateVariabilitySDNN,
            unit: HealthKitService.msUnit,
            days: 14
        )
        async let restingHRSeries = service.dailyAverageSeries(
            for: .restingHeartRate,
            unit: HealthKitService.bpmUnit,
            days: 14
        )
        async let vo2Series = service.dailyAverageSeries(
            for: .vo2Max,
            unit: HKUnit(from: "ml/kg·min"),
            days: 90
        )
        async let wristTempSeries = service.dailyAverageSeries(
            for: .appleSleepingWristTemperature,
            unit: .degreeCelsius(),
            days: 14
        )
        async let spo2Series = service.dailyAverageSeries(
            for: .oxygenSaturation,
            unit: .percent(),
            days: 14
        )
        async let respiratoryRateSeries = service.dailyAverageSeries(
            for: .respiratoryRate,
            unit: HKUnit.count().unitDivided(by: .minute()),
            days: 14
        )
        async let activeEnergySeries = service.dailySumSeries(
            for: .activeEnergyBurned,
            unit: HealthKitService.kcalUnit,
            days: 14
        )
        async let restingEnergySeries = service.dailySumSeries(
            for: .basalEnergyBurned,
            unit: HealthKitService.kcalUnit,
            days: 14
        )
        async let stepsSeries = service.dailySumSeries(
            for: .stepCount,
            unit: .count(),
            days: 14
        )
        async let physicalEffortSeries = service.dailyAverageSeries(
            for: .physicalEffort,
            unit: HealthKitService.metUnit,
            days: 21
        )
        async let hrrSeries = service.dailyAverageSeries(
            for: .heartRateRecoveryOneMinute,
            unit: HealthKitService.bpmUnit,
            days: 30
        )
        async let stepsPace = service.timeOfDaySumSeries(
            for: .stepCount,
            unit: .count(),
            days: 14
        )
        async let activeEnergyPace = service.timeOfDaySumSeries(
            for: .activeEnergyBurned,
            unit: HealthKitService.kcalUnit,
            days: 14
        )
        async let restingEnergyPace = service.timeOfDaySumSeries(
            for: .basalEnergyBurned,
            unit: HealthKitService.kcalUnit,
            days: 14
        )
        async let effortPace = service.timeOfDayAverageSeries(
            for: .physicalEffort,
            unit: HealthKitService.metUnit,
            days: 21
        )
        async let heartRatePace = service.timeOfDayWindowAverageSeries(
            for: .heartRate,
            unit: HealthKitService.bpmUnit,
            days: 14,
            window: 45 * 60
        )

        let (hr, hrv, rhr, vo2, wristTemp, spo2, rr, ae, re, stps, effort, hrr) = await (
            hrSamples,
            hrvSeries,
            restingHRSeries,
            vo2Series,
            wristTempSeries,
            spo2Series,
            respiratoryRateSeries,
            activeEnergySeries,
            restingEnergySeries,
            stepsSeries,
            physicalEffortSeries,
            hrrSeries
        )

        let (sp, aep, rep, efp, hrp) = await (stepsPace, activeEnergyPace, restingEnergyPace, effortPace, heartRatePace)

        // Downsample heart rate to ~60 points for waveform display
        let downsampledHR = downsample(hr, to: 60)
        newSeries[.heartRate] = downsampledHR
        newSeries[.hrv] = hrv
        newSeries[.restingHR] = rhr
        newSeries[.vo2Max] = vo2
        newSeries[.wristTemp] = wristTemp
        // Scale SpO2 from 0...1 to 0...100 for consistency
        newSeries[.spo2] = spo2.map { (date: $0.date, value: $0.value * 100) }
        newSeries[.respiratoryRate] = rr
        newSeries[.activeEnergy] = ae
        newSeries[.restingEnergy] = re
        newSeries[.steps] = stps
        newSeries[.physicalEffort] = effort
        newSeries[.hrr] = hrr
        // Sleep has no series
        newSeries[.sleep] = []

        var newPaceSeries: [VitalMetric: [(date: Date, value: Double)]] = [:]
        newPaceSeries[.steps] = sp
        newPaceSeries[.activeEnergy] = aep
        newPaceSeries[.restingEnergy] = rep
        newPaceSeries[.physicalEffort] = efp
        newPaceSeries[.heartRate] = hrp

        series = newSeries
        paceSeries = newPaceSeries
        lastLoad = Date()
        isLoaded = true
    }

    /// Downsamples a chronological series to approximately `maxPoints` evenly spaced points.
    private func downsample(_ data: [(date: Date, value: Double)], to maxPoints: Int) -> [(date: Date, value: Double)] {
        guard data.count > maxPoints else { return data }

        let bucketSize = Double(data.count) / Double(maxPoints)
        var result: [(date: Date, value: Double)] = []

        for i in 0..<maxPoints {
            let start = Int(Double(i) * bucketSize)
            let end = Int(Double(i + 1) * bucketSize)
            let bucket = Array(data[start..<min(end, data.count)])

            guard !bucket.isEmpty else { continue }

            let avgValue = bucket.map(\.value).reduce(0, +) / Double(bucket.count)
            let midIndex = bucket.count / 2
            let date = bucket[midIndex].date

            result.append((date: date, value: avgValue))
        }

        return result
    }
}
