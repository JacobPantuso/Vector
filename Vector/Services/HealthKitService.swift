import HealthKit
import Foundation
import CoreLocation

@Observable
class HealthKitService {
    private let store = HKHealthStore()

    var isAuthorized = false

    // Raw vitals
    var latestHeartRate: Double?
    var latestRestingHR: Double?
    var latestHRV: Double?
    var todaySteps: Double = 0
    var todayActiveCalories: Double = 0
    var todayBasalCalories: Double = 0

    // Computed scores — nil until first fetch completes
    var recoveryScore: RecoveryScore?
    var exertionScore: ExertionScore?
    var sleepAnalysis: SleepAnalysis?
    var nutritionSummary: NutritionSummary?
    var lastSyncedDate: Date?
    var stressScore: StressScore?
    var isSyncing: Bool = false
    var generatedOverview: GeneratedOverview?
    var isGeneratingOverview: Bool = false
    var latestVO2Max: Double?
    var latestWristTempDeviation: Double?  // overnight wrist-temp deviation from baseline (°C)
    var latestSpO2: Double?                // overnight average blood oxygen %
    var spo2Baseline: Double?              // 14-day SpO2 baseline %
    var todayPhysicalEffort: Double?       // today's average physical effort (METs)
    var physicalEffortSeries: [(date: Date, value: Double)] = []  // 21-day daily averages (METs)
    var latestHRR: Double?                 // most recent 1-min heart-rate recovery (bpm drop)
    var hrrBaseline: Double?               // baseline HRR from prior samples
    var recentWorkouts: [HKWorkout] = []
    private var backfillingRecordIDs: Set<UUID> = []
    private var attachingWorkoutIDs: Set<UUID> = []

    static let bpmUnit = HKUnit.count().unitDivided(by: .minute())
    static let msUnit = HKUnit.secondUnit(with: .milli)
    static let kcalUnit = HKUnit.kilocalorie()
    static let metUnit = HKUnit.kilocalorie().unitDivided(by: HKUnit.gramUnit(with: .kilo).unitMultiplied(by: .hour()))

    func requestAuthorization() async {
        guard HKHealthStore.isHealthDataAvailable() else { return }

        let readTypes: Set<HKObjectType> = [
            // Core heart rate
            HKQuantityType(.heartRate),
            HKQuantityType(.restingHeartRate),
            HKQuantityType(.walkingHeartRateAverage),

            // Heart rate variability & recovery
            HKQuantityType(.heartRateVariabilitySDNN),
            HKQuantityType(.heartRateRecoveryOneMinute),

            // Beat-to-beat & cardiac health
            HKSeriesType.heartbeat(),
            HKQuantityType(.atrialFibrillationBurden),
            HKQuantityType(.peripheralPerfusionIndex),
            HKCategoryType(.highHeartRateEvent),
            HKCategoryType(.lowHeartRateEvent),
            HKCategoryType(.irregularHeartRhythmEvent),
            HKCategoryType(.lowCardioFitnessEvent),

            // Blood oxygen & body measures
            HKQuantityType(.oxygenSaturation),
            HKQuantityType(.bodyTemperature),
            HKQuantityType(.appleSleepingWristTemperature),

            // Respiratory
            HKQuantityType(.respiratoryRate),

            // Sleep
            HKCategoryType(.sleepAnalysis),

            // Activity & energy
            HKQuantityType(.stepCount),
            HKQuantityType(.activeEnergyBurned),
            HKQuantityType(.basalEnergyBurned),
            HKQuantityType(.appleExerciseTime),
            HKQuantityType(.appleStandTime),

            // Fitness scores
            HKQuantityType(.vo2Max),
            HKQuantityType(.physicalEffort),
            HKQuantityType(.workoutEffortScore),
            HKQuantityType(.estimatedWorkoutEffortScore),

            // Distance & basic activity
            HKQuantityType(.distanceWalkingRunning),
            HKQuantityType(.distanceCycling),
            HKQuantityType(.distanceSwimming),
            HKQuantityType(.flightsClimbed),
            HKQuantityType(.pushCount),

            // Running metrics
            HKQuantityType(.runningSpeed),
            HKQuantityType(.runningPower),
            HKQuantityType(.runningStrideLength),
            HKQuantityType(.runningVerticalOscillation),
            HKQuantityType(.runningGroundContactTime),

            // Cycling metrics
            HKQuantityType(.cyclingPower),
            HKQuantityType(.cyclingCadence),
            HKQuantityType(.cyclingSpeed),
            HKQuantityType(.cyclingFunctionalThresholdPower),

            // Swimming
            HKQuantityType(.swimmingStrokeCount),

            // Nutrition
            HKQuantityType(.dietaryEnergyConsumed),
            HKQuantityType(.dietaryProtein),
            HKQuantityType(.dietaryCarbohydrates),
            HKQuantityType(.dietaryFatTotal),

            // Workout & series
            HKObjectType.workoutType(),
            HKSeriesType.workoutRoute()
        ]

        let shareTypes: Set<HKSampleType> = [
            HKWorkoutType.workoutType(),
            HKQuantityType(.workoutEffortScore)
        ]

        try? await store.requestAuthorization(toShare: shareTypes, read: readTypes)
        isAuthorized = store.authorizationStatus(for: HKWorkoutType.workoutType()) == .sharingAuthorized
        await backfillSleepMetricsIfNeeded()
        await backfillRMSSDIfNeeded()
    }

    /// Recomputes `isAuthorized` from the current HealthKit share status without
    /// prompting the user. Call on launch and when Settings appears so the UI
    /// reflects real state instead of the default `false`.
    func refreshAuthorizationStatus() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        isAuthorized = store.authorizationStatus(for: HKWorkoutType.workoutType()) == .sharingAuthorized
    }

    private func backfillSleepMetricsIfNeeded() async {
        let key = "sleepMetricsBackfilled.v2"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let calendar = Calendar.current
        var results: [(date: Date, analysis: SleepAnalysis)] = []
        await withTaskGroup(of: (Date, SleepAnalysis?).self) { group in
            for daysAgo in 1...30 {
                group.addTask {
                    guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()) else { return (Date(), nil) }
                    return (date, await self.fetchSleepAnalysis(for: date))
                }
            }
            for await (date, analysis) in group {
                if let a = analysis, a.asleepDuration > 0 {
                    results.append((date, a))
                }
            }
        }
        for (date, analysis) in results {
            SleepDebtStore.record(date: date, asleepHours: analysis.asleepDuration / 3600)
            ScoreHistoryStore.saveHistorical(metric: .sleep, score: Int(analysis.quality * 100), date: date)
            ScoreHistoryStore.saveHistorical(metric: .sleepEfficiency, score: Int(analysis.efficiency * 100), date: date)
            let h = calendar.component(.hour, from: analysis.bedtime)
            let m = calendar.component(.minute, from: analysis.bedtime)
            let minsSinceMidnight = h * 60 + m
            ScoreHistoryStore.saveHistorical(metric: .bedtime, score: minsSinceMidnight >= 720 ? minsSinceMidnight - 720 : minsSinceMidnight + 720, date: date)
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    /// One-time backfill of nightly RMSSD for recent nights so Recovery has a beat-to-beat
    /// baseline immediately rather than after weeks of accumulation. Runs once (keyed flag).
    private func backfillRMSSDIfNeeded() async {
        let key = "rmssdBackfilled.v1"
        guard !UserDefaults.standard.bool(forKey: key) else { return }
        let calendar = Calendar.current
        await withTaskGroup(of: (Date, Double?).self) { group in
            for daysAgo in 1...14 {
                group.addTask {
                    guard let date = calendar.date(byAdding: .day, value: -daysAgo, to: Date()),
                          let sleep = await self.fetchSleepAnalysis(for: date), sleep.wakeTime > sleep.bedtime else {
                        return (Date(), nil)
                    }
                    let rmssd = await self.fetchSleepWindowRMSSD(window: DateInterval(start: sleep.bedtime, end: sleep.wakeTime))
                    return (sleep.bedtime, rmssd)
                }
            }
            for await (date, rmssd) in group {
                if let r = rmssd { HRVHistoryStore.record(date: date, rmssd: r) }
            }
        }
        UserDefaults.standard.set(true, forKey: key)
    }

    // MARK: - Launch Watch App

    /// Launches the companion watchOS app (bringing it to the foreground) and starts a
    /// mirrored workout session, so the watch is ready the moment a workout begins on iPhone.
    func launchWatchWorkout() {
        guard HKHealthStore.isHealthDataAvailable() else { return }
        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        store.startWatchApp(with: config) { success, error in
            if let error {
                print("[HealthKitService] startWatchApp failed: \(error.localizedDescription)")
            } else {
                print("[HealthKitService] startWatchApp launched (success=\(success))")
            }
        }
    }

    // MARK: - Save Workout

    func saveStrengthWorkout(
        title: String,
        startDate: Date,
        endDate: Date,
        exercises: [ManualExerciseEntry]
    ) async -> HKWorkout? {
        guard isAuthorized else { return nil }

        let totalVolume = exercises.reduce(0.0) { acc, ex in
            acc + Double(ex.sets * ex.reps) * (ex.weightKg ?? 0)
        }

        let config = HKWorkoutConfiguration()
        config.activityType = .traditionalStrengthTraining
        config.locationType = .indoor
        let builder = HKWorkoutBuilder(healthStore: store, configuration: config, device: .local())
        do {
            try await builder.beginCollection(at: startDate)
            try await builder.addMetadata([
                HKMetadataKeyWorkoutBrandName: "Vector",
                "VectorWorkoutTitle": title,
                "VectorTotalVolume": totalVolume
            ])

            // Attach the energy + heart-rate samples the Apple Watch recorded during the
            // session so the workout reports calories and HR (strength workouts don't
            // derive energy on their own).
            let windowPredicate = HKQuery.predicateForSamples(withStart: startDate, end: endDate)
            let energyType = HKQuantityType(.activeEnergyBurned)
            let energyDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: energyType, predicate: windowPredicate)],
                sortDescriptors: []
            )
            var samplesToAdd: [HKSample] = []
            if let energySamples = try? await energyDescriptor.result(for: store) {
                samplesToAdd.append(contentsOf: energySamples as [HKSample])
            }
            let hrDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: HKQuantityType(.heartRate), predicate: windowPredicate)],
                sortDescriptors: []
            )
            if let hrSamples = try? await hrDescriptor.result(for: store) {
                samplesToAdd.append(contentsOf: hrSamples as [HKSample])
            }
            if !samplesToAdd.isEmpty {
                await withCheckedContinuation { continuation in
                    builder.add(samplesToAdd) { _, _ in continuation.resume() }
                }
            }

            try await builder.endCollection(at: endDate)
            let workout = try await builder.finishWorkout()
            return workout
        } catch {
            print("[HealthKitService] failed to save workout: \(error.localizedDescription)")
            return nil
        }
    }

    /// The 1–10 Effort rating for a workout: the user/app-set score if present, else Apple's estimate.
    func effortScore(for workout: HKWorkout) async -> Double? {
        let effortPredicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
        let effortType = HKQuantityType(.workoutEffortScore)
        let effortDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: effortType, predicate: effortPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        if let latest = (try? await effortDescriptor.result(for: store))?.first {
            return latest.quantity.doubleValue(for: .appleEffortScore())
        }

        let estimatedPredicate = HKQuery.predicateForWorkoutEffortSamplesRelated(workout: workout, activity: nil)
        let estimatedType = HKQuantityType(.estimatedWorkoutEffortScore)
        let estimatedDescriptor = HKSampleQueryDescriptor(
            predicates: [.quantitySample(type: estimatedType, predicate: estimatedPredicate)],
            sortDescriptors: [SortDescriptor(\.startDate, order: .reverse)]
        )
        if let latest = (try? await estimatedDescriptor.result(for: store))?.first {
            return latest.quantity.doubleValue(for: .appleEffortScore())
        }

        return nil
    }

    /// Relates a 1–10 Effort rating to a Vector-authored workout (shows as "Effort" in Apple Fitness).
    func writeEffortScore(_ value: Double, for workout: HKWorkout) async {
        let sample = HKQuantitySample(
            type: HKQuantityType(.workoutEffortScore),
            quantity: HKQuantity(unit: .appleEffortScore(), doubleValue: min(10, max(1, value.rounded()))),
            start: workout.startDate,
            end: workout.endDate
        )
        _ = try? await store.relateWorkoutEffortSample(sample, with: workout, activity: nil)
    }

    // MARK: - Refresh

    /// Refreshes only when data is missing or older than `maxAge`.
    /// Used by tab-level `.task`s so tab switches don't refetch; pull-to-refresh
    /// still calls `refreshToday()` directly for a forced refresh.
    func refreshIfStale(maxAge: TimeInterval = 300) async {
        guard !isSyncing else { return }
        if let last = lastSyncedDate, Date().timeIntervalSince(last) < maxAge { return }
        await refreshToday()
    }

    func refreshToday() async {
        #if DEBUG && targetEnvironment(simulator)
        applyMockData()
        return
        #endif
        guard !isSyncing else { return }
        await backfillSleepMetricsIfNeeded()
        isSyncing = true
        defer { isSyncing = false }
        async let heartRate = fetchLatestQuantity(for: .heartRate, unit: Self.bpmUnit)
        async let restingHR = fetchLatestQuantity(for: .restingHeartRate, unit: Self.bpmUnit)
        async let hrv = fetchLatestQuantity(for: .heartRateVariabilitySDNN, unit: Self.msUnit)
        async let steps = fetchTodayStatistic(for: .stepCount, unit: .count())
        async let activeCalories = fetchTodayStatistic(for: .activeEnergyBurned, unit: Self.kcalUnit)
        async let basalCalories = fetchTodayStatistic(for: .basalEnergyBurned, unit: Self.kcalUnit)
        async let hrvSeriesTask = dailyAverageSeries(for: .heartRateVariabilitySDNN, unit: Self.msUnit, days: 21)
        async let rhrSeriesTask = dailyAverageSeries(for: .restingHeartRate, unit: Self.bpmUnit, days: 21)
        async let sleep = fetchSleepAnalysis(for: Date())
        async let nutrition = fetchNutritionSummary(for: Date())
        async let workouts = fetchWorkouts(for: DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date(),
            end: Date()
        ))
        async let vo2 = fetchLatestQuantityExtended(for: .vo2Max, unit: HKUnit(from: "ml/kg·min"), days: 90)
        async let dayHR = fetchHeartRateSamples(for: DateInterval(
            start: Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date(),
            end: Date()
        ))
        async let rrSeriesTask = dailyAverageSeries(for: .respiratoryRate, unit: HKUnit.count().unitDivided(by: .minute()), days: 21)
        // Wrist temperature: HealthKit exposes the absolute overnight skin temperature (~35°C),
        // NOT the deviation Apple surfaces in the Health app (which uses a private baseline).
        // Compute the deviation ourselves: most-recent night minus the baseline of prior nights.
        // nil until there are at least 2 nights of data, so the scoring engines skip it cleanly.
        async let wristTempHistoryTask = fetchDailyAverages(for: .appleSleepingWristTemperature, unit: .degreeCelsius(), days: 21)
        async let spo2HistTask = fetchDailyAverages(for: .oxygenSaturation, unit: .percent(), days: 21)
        async let effortSeriesTask = dailyAverageSeries(for: .physicalEffort, unit: Self.metUnit, days: 21)
        async let hrrHistTask = fetchDailyAverages(for: .heartRateRecoveryOneMinute, unit: Self.bpmUnit, days: 60)
        let strengthWindowStart = Calendar.current.date(byAdding: .day, value: -28, to: Date()) ?? Date()
        async let effortSamples28dTask = fetchQuantitySamples(for: .physicalEffort, unit: Self.metUnit, dateRange: DateInterval(start: strengthWindowStart, end: Date()))

        var (hr, rhr, hrvValue, stepsValue, activeValue, basalValue,
             hrvSeries, rhrSeries, sleepResult, nutritionResult, workoutResult, vo2Value, dayHRResult,
             rrSeries, wristTempHistResult, spo2HistRaw, effortSeries, hrrHist, effortSamples28d) = await (
            heartRate, restingHR, hrv, steps, activeCalories, basalCalories,
            hrvSeriesTask, rhrSeriesTask, sleep, nutrition, workouts, vo2, dayHR,
            rrSeriesTask, wristTempHistoryTask, spo2HistTask, effortSeriesTask, hrrHistTask, effortSamples28dTask
        )
        let spo2Hist = spo2HistRaw.map { $0 * 100 }

        // Derive plain value arrays for existing consumers (RecoveryEngine, etc.)
        let hrvHist = hrvSeries.map(\.value)
        let rhrHist = rhrSeries.map(\.value)
        let rrHistory = rrSeries.map(\.value)

        latestHeartRate = hr
        latestRestingHR = rhr
        latestHRV = hrvValue
        todaySteps = stepsValue
        todayActiveCalories = activeValue
        todayBasalCalories = basalValue
        nutritionSummary = nutritionResult
        latestVO2Max = vo2Value

        let wristTempStats: (deviation: Double, baseline: Double, overnight: Double)? = {
            guard wristTempHistResult.count > 1, let latest = wristTempHistResult.last else { return nil }
            let prior = wristTempHistResult.dropLast()
            let baseline = prior.reduce(0, +) / Double(prior.count)
            return (latest - baseline, baseline, latest)
        }()
        let wristTemp = wristTempStats?.deviation
        var overnightSpO2: Double? = nil
        if let s = sleepResult, s.wakeTime > s.bedtime {
            overnightSpO2 = await fetchOvernightSpO2(window: DateInterval(start: s.bedtime, end: s.wakeTime))
        }
        let spo2Base: Double? = spo2Hist.count > 1 ? spo2Hist.reduce(0, +) / Double(spo2Hist.count) : nil

        // Patch the local sleep result with wrist-temp fields BEFORE publishing it, so
        // `sleepAnalysis` only ever changes once (and `quality` never briefly reflects a
        // 1-signal vs 2-signal refinement average across the same night).
        sleepResult?.wristTempDeviation = wristTemp
        sleepResult?.wristTempBaseline = wristTempStats?.baseline
        sleepResult?.wristTempOvernight = wristTempStats?.overnight
        sleepAnalysis = sleepResult

        latestWristTempDeviation = wristTemp
        latestSpO2 = overnightSpO2
        spo2Baseline = spo2Base

        physicalEffortSeries = effortSeries
        todayPhysicalEffort = effortSeries.first { Calendar.current.isDateInToday($0.date) }?.value
        latestHRR = hrrHist.isEmpty ? nil : hrrHist.last
        hrrBaseline = hrrHist.count > 1 ? hrrHist.dropLast().reduce(0, +) / Double(hrrHist.count - 1) : nil

        // Recovery scores overnight physiology (nightly HRV, sleeping RHR) against nightly
        // baselines — all-day means dilute the illness/alcohol signal that shows up during
        // sleep. Falls back to all-day series when overnight data is missing (watch not worn
        // at night). Recomputed on every refresh so overnight data that syncs after the first
        // morning refresh still corrects the score.
        let nightlyHRVSeries = await nightlyAverageSeries(for: .heartRateVariabilitySDNN, unit: Self.msUnit, days: 21)
        let nightlyHRVValues = nightlyHRVSeries.map(\.value)
        // Prefer true beat-to-beat RMSSD over the actual sleep window — the physiological HRV
        // metric apps like Bevel report — instead of Apple's pre-computed 1-minute SDNN samples.
        // Tonight's value is persisted and the baseline is built from stored RMSSD nights so the
        // current value and baseline share units. Falls back to Apple's SDNN when no beat-to-beat
        // data exists (older watch, series unavailable).
        var recoveryHRVValues = HRVHistoryStore.recentValues(days: 21)
        if let sleep = sleepResult, sleep.wakeTime > sleep.bedtime,
           let rmssd = await fetchSleepWindowRMSSD(window: DateInterval(start: sleep.bedtime, end: sleep.wakeTime)) {
            HRVHistoryStore.record(date: sleep.bedtime, rmssd: rmssd)
            recoveryHRVValues = HRVHistoryStore.recentValues(days: 21)
        }
        if recoveryHRVValues.isEmpty {
            // No beat-to-beat RMSSD available — fall back to Apple's SDNN nightly series, using
            // the median of the sleep window for the current night to reject motion artifacts.
            var sdnn = nightlyHRVValues
            if let sleep = sleepResult, sleep.wakeTime > sleep.bedtime {
                let sleepWindowHRV = await fetchSleepWindowHRV(window: DateInterval(start: sleep.bedtime, end: sleep.wakeTime))
                if let m = Self.median(of: sleepWindowHRV) {
                    if sdnn.isEmpty { sdnn = [m] } else { sdnn[sdnn.count - 1] = m }
                }
            }
            recoveryHRVValues = sdnn.count > 1 ? sdnn : hrvHist
        }
        let nightlyRHRValues = Self.nightlyRestingHR(from: dayHRResult)
        recoveryScore = RecoveryEngine.computeScore(
            hrvValues: recoveryHRVValues.isEmpty ? hrvHist : recoveryHRVValues,
            restingHRValues: nightlyRHRValues.count > 1 ? nightlyRHRValues : rhrHist,
            sleepQuality: sleepResult?.quality ?? 0.5,
            respiratoryValues: rrHistory,
            wristTempDeviation: wristTemp,
            spo2: overnightSpO2,
            spo2Baseline: spo2Base,
            hrr: latestHRR,
            hrrBaseline: hrrBaseline
        )
        recoveryScore?.confidence = BaselineStatistics.confidence(days: max(recoveryHRVValues.count, hrvHist.count))

        let restingHRForLoad = (rhr ?? 0) > 0 ? rhr! : (rhrHist.isEmpty ? 60 : rhrHist.reduce(0, +) / Double(rhrHist.count))
        let maxHRForLoad = TrainingLoadEngine.estimatedMaxHR(age: Self.userAgeEstimate())
        let isFemaleForLoad = UserDefaults.standard.string(forKey: UserProfileStorage.biologicalSex) == BiologicalSex.female.rawValue
        let dailyLoads = TrainingLoadEngine.dailyLoads(
            hrSamples: dayHRResult,
            restingHR: restingHRForLoad,
            maxHR: maxHRForLoad,
            isFemale: isFemaleForLoad
        )
        // Workout-scoped HR zones: only the HR samples that fall inside an actual workout in the
        // acute (7-day) window — so "time in zone" reflects training, not all-day life.
        let zoneWindowStart = Calendar.current.date(byAdding: .day, value: -7, to: Date()) ?? Date()
        let acuteWorkouts = workoutResult.filter { $0.endDate >= zoneWindowStart }
        let workoutZoneLoads: [WorkoutLoad] = acuteWorkouts.map { workout in
            let samples = dayHRResult.filter { $0.date >= workout.startDate && $0.date <= workout.endDate }
            return TrainingLoadEngine.workoutLoad(
                date: workout.startDate,
                hrSamples: samples,
                restingHR: restingHRForLoad,
                maxHR: maxHRForLoad,
                fallbackEnergyKcal: workout.activeEnergyKcal,
                fallbackDuration: workout.duration,
                isFemale: isFemaleForLoad
            )
        }
        // Strength volume load: heart rate barely rises during lifting (and manually logged
        // sessions may carry no HR at all), so all-day HR alone under-counts strength work.
        // Top each Vector strength session up to a volume-based load estimate, sourced from
        // WorkoutCompletionStore so post-hoc edits (exercises added after a workout) and
        // no-watch entries are included. max(HR-derived, volume) avoids double-counting
        // watch-recorded sessions that already contributed real HR to the all-day stream.
        var mergedLoads = dailyLoads
        for record in WorkoutCompletionStore.shared.records
        where record.totalVolume > 0 && record.date >= strengthWindowStart {
            let end = record.date
            let start = record.durationMinutes > 0
                ? end.addingTimeInterval(-Double(record.durationMinutes) * 60)
                : end
            let hrSamples = dayHRResult.filter { $0.date >= start && $0.date <= end }
            let hrTrimp = TrainingLoadEngine.workoutLoad(
                date: start,
                hrSamples: hrSamples,
                restingHR: restingHRForLoad,
                maxHR: maxHRForLoad,
                fallbackEnergyKcal: 0,
                fallbackDuration: 0,
                isFemale: isFemaleForLoad
            ).trimp
            // Heuristic: ~1 TRIMP per 120 kg of total volume lifted, capped like other
            // estimates. (Bodyweight-only work records zero volume and is not counted here.)
            let volumeTrimp = min(120, record.totalVolume / 120)
            // ~1 TRIMP per minute spent above light effort; physicalEffort is Watch-measured METs,
            // so this captures strength strain HR misses without inventing load on rest days.
            let effortSamples = effortSamples28d.filter { $0.date >= start && $0.date <= end }
            let avgMET = effortSamples.isEmpty ? 0 : effortSamples.map(\.value).reduce(0, +) / Double(effortSamples.count)
            let effortTrimp = min(150, Double(record.durationMinutes) * max(0, avgMET - 1.5) * 0.35)
            let topUp = max(volumeTrimp, effortTrimp) - hrTrimp
            guard topUp > 0 else { continue }
            mergedLoads.append(WorkoutLoad(
                date: Calendar.current.startOfDay(for: record.date),
                trimp: topUp,
                zoneSeconds: [TimeInterval](repeating: 0, count: 5)
            ))
        }
        exertionScore = TrainingLoadEngine.computeExertion(
            loads: mergedLoads,
            zoneLoads: workoutZoneLoads,
            fitnessTargetMultiplier: Self.fitnessTargetMultiplier()
        )
        exertionScore?.confidence = BaselineStatistics.confidence(days: dailyLoads.count, full: 28)

        // Personalized sleep need (user target + a strain bump) and a decaying sleep debt.
        if let s = sleepAnalysis, s.asleepDuration > 0 {
            SleepDebtStore.record(date: s.date, asleepHours: s.asleepDuration / 3600)
            let storedTarget = UserDefaults.standard.double(forKey: UserProfileStorage.sleepTargetHours)
            let targetHours = storedTarget > 0 ? storedTarget : UserProfile.defaultSleepTargetHours
            let strainBump = min(0.75, Double(exertionScore?.score ?? 0) / 100.0 * 0.75)
            let needHours = targetHours + strainBump

            // Sleep debt: a recency-weighted *average* of nightly shortfalls vs the base
            // target over the past two weeks. Averaging (not summing) keeps the figure a
            // realistic "typical recent deficit" that can't balloon past a single night,
            // and comparing against the base target (not the strain-inflated need) avoids
            // permanent phantom debt on nights you actually hit your goal.
            let recent = SleepDebtStore.recentNights(days: 14).sorted { $0.date > $1.date }
            var weightedShortfall = 0.0
            var weightTotal = 0.0
            for (i, night) in recent.enumerated() {
                let w = pow(0.85, Double(i))
                weightedShortfall += max(0, targetHours - night.asleepHours) * w
                weightTotal += w
            }
            let debtHours = weightTotal > 0 ? weightedShortfall / weightTotal : 0

            sleepAnalysis?.sleepNeed = needHours * 3600
            sleepAnalysis?.sleepDebt = debtHours * 3600
            sleepAnalysis?.confidence = BaselineStatistics.confidence(days: SleepDebtStore.all().count)
        }

        // Disrupted-night / alcohol hypothesis (vs personal baselines) + sleep-amount consistency.
        if let analysis = sleepAnalysis {
            let efficiency = analysis.efficiency

            let disruption = SleepDisruptionDetector.evaluate(
                restingHR: recoveryScore?.restingHeartRate ?? rhr,
                rhrBaseline: recoveryScore?.rhrBaseline,
                hrv: recoveryScore?.hrvValue ?? hrvValue,
                hrvBaseline: recoveryScore?.hrvBaseline,
                wristTempDeviation: wristTemp,
                sleepEfficiency: efficiency
            )

            sleepAnalysis?.disruption = disruption
            sleepAnalysis?.consistency = SleepDisruptionDetector.consistency(nights: SleepDebtStore.all())

        }
        
        recentWorkouts = workoutResult.sorted { $0.startDate > $1.startDate }

        // Extract daytime HR samples (today only) and today's workouts for stress computation
        let todayStart = Calendar.current.startOfDay(for: Date())
        let todayHRSamples = dayHRResult.filter { $0.date >= todayStart }
        let todayWorkoutIntervals = workoutResult
            .filter { $0.endDate >= todayStart }
            .map { DateInterval(start: $0.startDate, end: $0.endDate) }

        stressScore = StressEngine.computeScore(
            hrvSeries: hrvSeries,
            restingHRSeries: rhrSeries,
            respiratorySeries: rrSeries,
            sleepQuality: sleepResult?.quality ?? 0.5,
            sleepWakeTime: sleepResult?.wakeTime,
            wristTempDeviation: wristTemp,
            daytimeHRSamples: todayHRSamples,
            workoutIntervals: todayWorkoutIntervals,
            restingHR: (rhr ?? 0) > 0 ? rhr : rhrHist.last
        )
        stressScore?.confidence = BaselineStatistics.confidence(days: hrvHist.count)
        if let s = stressScore { StressHistoryStore.save(s) }
        if let s = stressScore { ScoreHistoryStore.save(metric: .stress, score: s.score) }
        if let r = recoveryScore { ScoreHistoryStore.save(metric: .recovery, score: r.score) }
        if let e = exertionScore { ScoreHistoryStore.save(metric: .exertion, score: e.score) }
        if let s = sleepAnalysis { ScoreHistoryStore.save(metric: .sleep, score: Int(s.quality * 100)) }
        lastSyncedDate = Date()
        await backfillUnsyncedWorkouts()
        await attachPendingWorkoutSamples()
        await consolidateDuplicateWorkoutsIfNeeded()

        await NotificationService.shared.refreshMorningNotifications(
            recovery: recoveryScore,
            sleep: sleepAnalysis,
            exertion: exertionScore
        )
    }

    // MARK: - Backfill

    /// Recovers a workout that JUST failed to save to HealthKit (e.g. the save threw
    /// moments ago). Deliberately narrow: only the last hour, only records not already
    /// synced — so it never resurrects deleted workouts or floods Health on a fresh
    /// install from iCloud-restored records.
    func backfillUnsyncedWorkouts() async {
        guard isAuthorized else { return }
        let cutoff = Date().addingTimeInterval(-3600)
        let recent = WorkoutCompletionStore.shared.records.filter { $0.date >= cutoff }
        for record in recent {
            guard !backfillingRecordIDs.contains(record.id) else { continue }
            guard record.expectsHealthSync ?? true else { continue }
            guard !(record.syncedToHealth ?? false) else { continue }
            let alreadySynced = recentWorkouts.contains { wk in
                let hkTitle = wk.metadata?["VectorWorkoutTitle"] as? String
                if let t = record.title, let h = hkTitle, t != h { return false }
                return abs(record.date.timeIntervalSince(wk.endDate)) < 300
            }
            if alreadySynced {
                WorkoutCompletionStore.shared.markSynced(record.id)
                continue
            }
            backfillingRecordIDs.insert(record.id)
            let start = record.date.addingTimeInterval(-Double(record.durationMinutes) * 60)
            print("[HealthKitService] backfill saving workout: \(record.title ?? "Workout")")
            if let workout = await saveStrengthWorkout(
                title: record.title ?? "Workout",
                startDate: start,
                endDate: record.date,
                exercises: record.performedExercises ?? []
            ) {
                WorkoutCompletionStore.shared.markSynced(record.id)
                // Write the heuristic effort score for backfilled workouts
                let minutes = Double(record.durationMinutes)
                let effort = min(10, max(1, (minutes / 12) + (record.totalVolume / 2500) + 1)).rounded()
                await writeEffortScore(effort, for: workout)
            }
            backfillingRecordIDs.remove(record.id)
        }
    }

    /// Back-fills calories and heart-rate samples onto phone-authored workouts once watch
    /// samples sync to HealthKit. After a strength workout, the watch records HR/energy samples
    /// but the iPhone is the sole author of the HKWorkout. If watch samples haven't synced yet
    /// when the phone saves the workout, the workout has no associated energy. This method queries
    /// for new samples and associates them once they're available.
    func attachPendingWorkoutSamples() async {
        guard isAuthorized else { return }
        let oneDayAgo = Date().addingTimeInterval(-86400)
        let appBundleID = Bundle.main.bundleIdentifier

        let candidates = recentWorkouts.filter { wk in
            guard wk.metadata?["VectorWorkoutTitle"] != nil else { return false }
            guard wk.sourceRevision.source.bundleIdentifier == appBundleID else { return false }
            guard wk.endDate >= oneDayAgo else { return false }
            return true
        }

        for workout in candidates {
            guard !attachingWorkoutIDs.contains(workout.uuid) else { continue }

            // Skip if workout already has energy
            let existingEnergy = workout.statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: Self.kcalUnit) ?? 0
            guard existingEnergy <= 0 else { continue }

            attachingWorkoutIDs.insert(workout.uuid)
            defer { attachingWorkoutIDs.remove(workout.uuid) }

            // Query for energy and HR samples in the workout's time window
            let windowPredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
            let energyType = HKQuantityType(.activeEnergyBurned)
            let energyDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: energyType, predicate: windowPredicate)],
                sortDescriptors: []
            )
            var samplesToAdd: [HKSample] = []
            if let energySamples = try? await energyDescriptor.result(for: store) {
                samplesToAdd.append(contentsOf: energySamples as [HKSample])
            }

            let hrType = HKQuantityType(.heartRate)
            let hrDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: hrType, predicate: windowPredicate)],
                sortDescriptors: []
            )
            if let hrSamples = try? await hrDescriptor.result(for: store) {
                samplesToAdd.append(contentsOf: hrSamples as [HKSample])
            }

            // Query samples already associated with the workout to exclude them
            let workoutPredicate = HKQuery.predicateForObjects(from: workout)
            let energyAssociatedDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: energyType, predicate: workoutPredicate)],
                sortDescriptors: []
            )
            let associatedEnergyUUIDs = Set((try? await energyAssociatedDescriptor.result(for: store))?.map(\.uuid) ?? [])

            let hrAssociatedDescriptor = HKSampleQueryDescriptor(
                predicates: [.quantitySample(type: hrType, predicate: workoutPredicate)],
                sortDescriptors: []
            )
            let associatedHRUUIDs = Set((try? await hrAssociatedDescriptor.result(for: store))?.map(\.uuid) ?? [])

            // Filter to only new samples not already associated
            let newSamples = samplesToAdd.filter { sample in
                if let quantitySample = sample as? HKQuantitySample {
                    if quantitySample.quantityType == energyType {
                        return !associatedEnergyUUIDs.contains(quantitySample.uuid)
                    } else if quantitySample.quantityType == hrType {
                        return !associatedHRUUIDs.contains(quantitySample.uuid)
                    }
                }
                return true
            }

            guard !newSamples.isEmpty else { continue }

            // Associate new samples with the workout
            await withCheckedContinuation { continuation in
                store.add(newSamples, to: workout) { _, error in
                    if let error { print("[HealthKitService] attach samples failed: \(error.localizedDescription)") }
                    continuation.resume()
                }
            }
        }
    }

    /// One-time cleanup of duplicate Vector workouts created by the pre-fix recording bug
    /// (one session saved/registered as several HKWorkouts). Considers workouts this app
    /// authored OR tagged with Vector metadata, clusters by overlapping time span, keeps the
    /// longest-duration workout per cluster, and deletes the rest. HealthKit only permits
    /// deleting samples this app saved, so watch- or Apple-authored items are skipped safely.
    func consolidateDuplicateWorkoutsIfNeeded() async {
        let flagKey = "vector_dedupe_hk_v2"
        guard !UserDefaults.standard.bool(forKey: flagKey) else { return }
        guard isAuthorized else { return }

        let appBundleID = Bundle.main.bundleIdentifier
        let candidates = (await fetchWorkoutsExtended(days: 120))
            .filter { wk in
                if (wk.metadata?["VectorWorkoutTitle"] as? String) != nil { return true }
                return wk.sourceRevision.source.bundleIdentifier == appBundleID
            }
            .sorted { $0.startDate < $1.startDate }

        // Cluster workouts whose time spans overlap (with a 5-minute buffer) — fragments of
        // the same session. Keep the longest-duration one, mark the rest for deletion.
        var keepers: [HKWorkout] = []
        var toDelete: [HKWorkout] = []
        for wk in candidates {
            if let idx = keepers.firstIndex(where: { keeper in
                wk.startDate < keeper.endDate.addingTimeInterval(300) &&
                keeper.startDate < wk.endDate.addingTimeInterval(300)
            }) {
                if wk.duration > keepers[idx].duration {
                    toDelete.append(keepers[idx])
                    keepers[idx] = wk
                } else {
                    toDelete.append(wk)
                }
            } else {
                keepers.append(wk)
            }
        }

        guard !toDelete.isEmpty else {
            UserDefaults.standard.set(true, forKey: flagKey)
            return
        }

        // Delete individually so one un-deletable (foreign-source) item doesn't block the rest.
        var deleted = 0
        for wk in toDelete {
            let ok = await withCheckedContinuation { (continuation: CheckedContinuation<Bool, Never>) in
                store.delete(wk) { success, error in
                    if let error { print("[HealthKitService] dedupe delete skipped: \(error.localizedDescription)") }
                    continuation.resume(returning: success)
                }
            }
            if ok { deleted += 1 }
        }
        print("[HealthKitService] consolidated duplicate HK workouts, deleted \(deleted)/\(toDelete.count)")
        UserDefaults.standard.set(true, forKey: flagKey)
    }

    // MARK: - Quantity Queries

    func fetchLatestQuantity(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double? {
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: Date(timeIntervalSinceNow: -86400), end: Date())
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try? await descriptor.result(for: store).first?.quantity.doubleValue(for: unit)
    }

    func fetchLatestQuantityExtended(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> Double? {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: start, end: Date())
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.endDate, order: .reverse)],
            limit: 1
        )
        return try? await descriptor.result(for: store).first?.quantity.doubleValue(for: unit)
    }

    func fetchTodayStatistic(for identifier: HKQuantityTypeIdentifier, unit: HKUnit) async -> Double {
        let startOfDay = Calendar.current.startOfDay(for: Date())
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: startOfDay, end: Date())
        )
        let descriptor = HKStatisticsQueryDescriptor(predicate: predicate, options: .cumulativeSum)
        return (try? await descriptor.result(for: store))?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    func fetchQuantityHistory(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [Double] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: start, end: Date())
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { $0.quantity.doubleValue(for: unit) }
    }

    /// Returns one value per calendar day (the mean of that day's samples), in chronological order.
    /// Used for score baselines so "current" = today's mean and baseline = prior days' means,
    /// which centers deviations and avoids single-sample (e.g. overnight) bias.
    func fetchDailyAverages(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [Double] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date())
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: start, end: Date())
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        var sums: [Date: (total: Double, count: Int)] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            let value = sample.quantity.doubleValue(for: unit)
            let existing = sums[day] ?? (0, 0)
            sums[day] = (existing.total + value, existing.count + 1)
        }
        return sums.keys.sorted().map { sums[$0]!.total / Double(sums[$0]!.count) }
    }

    /// Like `fetchDailyAverages` but keeps the calendar day with each daily mean, for charting.
    /// Returns one (date, value) per day with samples, chronological order.
    func dailyAverageSeries(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date())
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: start, end: Date())
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        var sums: [Date: (total: Double, count: Int)] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            let value = sample.quantity.doubleValue(for: unit)
            let existing = sums[day] ?? (0, 0)
            sums[day] = (existing.total + value, existing.count + 1)
        }
        return sums.keys.sorted().map { (date: $0, value: sums[$0]!.total / Double(sums[$0]!.count)) }
    }

    /// Like `dailyAverageSeries`, but sums each day's samples instead of averaging — correct for
    /// cumulative quantities like steps and active energy, where HealthKit reports many small
    /// samples per day that should be totaled, not averaged.
    func dailySumSeries(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date())
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: start, end: Date())
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        var sums: [Date: Double] = [:]
        for sample in samples {
            let day = calendar.startOfDay(for: sample.startDate)
            sums[day, default: 0] += sample.quantity.doubleValue(for: unit)
        }
        return sums.keys.sorted().map { (date: $0, value: sums[$0]!) }
    }

    /// Like `dailyAverageSeries`, but restricted to overnight hours (18:00 → noon, keyed by
    /// the wake day), so each value reflects sleep-time physiology — the signal recovery
    /// platforms like Bevel/Whoop score — instead of an all-day mean that daytime readings dilute.
    func nightlyAverageSeries(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, days: Int) async -> [(date: Date, value: Double)] {
        let calendar = Calendar.current
        let start = calendar.startOfDay(for: calendar.date(byAdding: .day, value: -days, to: Date()) ?? Date())
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: start, end: Date())
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        var nights: [Date: (total: Double, count: Int)] = [:]
        for sample in samples {
            guard let night = Self.nightKey(for: sample.startDate, calendar: calendar) else { continue }
            let value = sample.quantity.doubleValue(for: unit)
            let existing = nights[night] ?? (0, 0)
            nights[night] = (existing.total + value, existing.count + 1)
        }
        return nights.keys.sorted().map { (date: $0, value: nights[$0]!.total / Double(nights[$0]!.count)) }
    }

    /// Attributes a timestamp to a "night", restricted to overnight sleep hours so nightly
    /// HRV/RHR reflect actual sleep rather than evening or late-morning wakefulness: samples
    /// from 22:00 onward belong to the next calendar day's night, samples before 09:00 to
    /// their own day, and all other times (daytime/evening) to no night.
    /// Median of a sample set — a robust central tendency that ignores outlier spikes.
    /// Returns nil for an empty input.
    static func median(of values: [Double]) -> Double? {
        guard !values.isEmpty else { return nil }
        let sorted = values.sorted()
        let mid = sorted.count / 2
        return sorted.count % 2 == 0 ? (sorted[mid - 1] + sorted[mid]) / 2 : sorted[mid]
    }

    static func nightKey(for date: Date, calendar: Calendar) -> Date? {
        let hour = calendar.component(.hour, from: date)
        let day = calendar.startOfDay(for: date)
        if hour >= 22 { return calendar.date(byAdding: .day, value: 1, to: day) }
        if hour < 9 { return day }
        return nil
    }

    /// Per-night sleeping resting HR: groups HR samples into nights and returns, per night in
    /// chronological order, the mean of the lowest 25% of that night's samples. This tracks the
    /// sleeping HR that actually rises with illness or alcohol, unlike Apple's all-day resting
    /// HR estimate. Nights with fewer than 8 samples are skipped.
    static func nightlyRestingHR(from samples: [(date: Date, value: Double)]) -> [Double] {
        let calendar = Calendar.current
        var nights: [Date: [Double]] = [:]
        for sample in samples {
            guard let night = nightKey(for: sample.date, calendar: calendar) else { continue }
            nights[night, default: []].append(sample.value)
        }
        return nights.keys.sorted().compactMap { key in
            let values = nights[key]!.sorted()
            guard values.count >= 8 else { return nil }
            let lowest = values.prefix(max(1, values.count / 4))
            return lowest.reduce(0, +) / Double(lowest.count)
        }
    }

    /// Average blood oxygen (%) within a sleep window. HealthKit returns oxygenSaturation
    /// as a 0–1 fraction, so we scale to a percentage. nil if no samples.
    func fetchOvernightSpO2(window: DateInterval) async -> Double? {
        guard window.duration > 0 else { return nil }
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.oxygenSaturation),
            predicate: HKQuery.predicateForSamples(withStart: window.start, end: window.end)
        )
        let descriptor = HKSampleQueryDescriptor(predicates: [predicate], sortDescriptors: [])
        let samples = (try? await descriptor.result(for: store)) ?? []
        guard !samples.isEmpty else { return nil }
        let values = samples.map { $0.quantity.doubleValue(for: .percent()) * 100 }
        return values.reduce(0, +) / Double(values.count)
    }

    /// HRV (SDNN, ms) samples restricted to a sleep window — Recovery's sleep-window HRV,
    /// which standardizes the signal the way Bevel does (vs. continuous HRV used for stress).
    func fetchSleepWindowHRV(window: DateInterval) async -> [Double] {
        guard window.duration > 0 else { return [] }
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.heartRateVariabilitySDNN),
            predicate: HKQuery.predicateForSamples(withStart: window.start, end: window.end)
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { $0.quantity.doubleValue(for: Self.msUnit) }
    }

    /// Overnight RMSSD (ms) computed from Apple Watch beat-to-beat (RR/IBI) data over a window —
    /// the true beat-to-beat HRV metric (what apps like Bevel report), rather than Apple's
    /// pre-computed 1-minute SDNN samples. Returns nil if there aren't enough clean intervals.
    func fetchSleepWindowRMSSD(window: DateInterval) async -> Double? {
        guard window.duration > 0 else { return nil }
        let predicate = HKQuery.predicateForSamples(withStart: window.start, end: window.end)
        let seriesSamples: [HKHeartbeatSeriesSample] = await withCheckedContinuation { cont in
            let q = HKSampleQuery(sampleType: HKSeriesType.heartbeat(), predicate: predicate,
                                  limit: HKObjectQueryNoLimit, sortDescriptors: nil) { _, samples, _ in
                cont.resume(returning: (samples as? [HKHeartbeatSeriesSample]) ?? [])
            }
            store.execute(q)
        }
        guard !seriesSamples.isEmpty else { return nil }

        var successiveDiffsSq: [Double] = []
        for series in seriesSamples {
            let ibis = await beatIntervals(for: series)   // ms, gap-aware
            guard ibis.count > 1 else { continue }
            for i in 1..<ibis.count {
                let prev = ibis[i - 1], cur = ibis[i]
                // Reject artifacts: physiologically implausible intervals (300–2000 ms ≈ 30–200 bpm)
                // or a >20% jump between consecutive beats (ectopic/motion).
                guard (300...2000).contains(prev), (300...2000).contains(cur) else { continue }
                guard prev > 0, abs(cur - prev) / prev <= 0.2 else { continue }
                let d = cur - prev
                successiveDiffsSq.append(d * d)
            }
        }
        guard successiveDiffsSq.count >= 20 else { return nil }
        let meanSq = successiveDiffsSq.reduce(0, +) / Double(successiveDiffsSq.count)
        return meanSq.squareRoot()
    }

    /// Extracts inter-beat intervals (ms) from one heartbeat series sample. Intervals that span a
    /// detected gap in the recording are skipped so they don't corrupt the RMSSD.
    private func beatIntervals(for series: HKHeartbeatSeriesSample) async -> [Double] {
        await withCheckedContinuation { cont in
            var lastTime: TimeInterval? = nil
            var ibis: [Double] = []
            var resumed = false
            let q = HKHeartbeatSeriesQuery(heartbeatSeries: series) { _, timeSinceSeriesStart, precededByGap, done, error in
                if error != nil {
                    if !resumed { resumed = true; cont.resume(returning: ibis) }
                    return
                }
                if let last = lastTime, !precededByGap {
                    ibis.append((timeSinceSeriesStart - last) * 1000.0)   // seconds → ms
                }
                lastTime = timeSinceSeriesStart
                if done, !resumed { resumed = true; cont.resume(returning: ibis) }
            }
            store.execute(q)
        }
    }

    // MARK: - Time-Series (for charts)

    func fetchHeartRateSamples(for dateRange: DateInterval) async -> [(date: Date, value: Double)] {
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.heartRate),
            predicate: HKQuery.predicateForSamples(withStart: dateRange.start, end: dateRange.end)
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: Self.bpmUnit)) }
    }

    func fetchQuantitySamples(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, dateRange: DateInterval) async -> [(date: Date, value: Double)] {
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: dateRange.start, end: dateRange.end)
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: unit)) }
    }

    func fetchHRVSamples(for dateRange: DateInterval) async -> [(date: Date, value: Double)] {
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.heartRateVariabilitySDNN),
            predicate: HKQuery.predicateForSamples(withStart: dateRange.start, end: dateRange.end)
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: Self.msUnit)) }
    }

    // MARK: - Sleep

    func fetchSleepAnalysis(for date: Date) async -> SleepAnalysis? {
        let calendar = Calendar.current
        let previousDay = calendar.date(byAdding: .day, value: -1, to: date) ?? date
        let nightStart = calendar.date(bySettingHour: 18, minute: 0, second: 0, of: previousDay) ?? date
        let nightEnd = calendar.date(bySettingHour: 12, minute: 0, second: 0, of: date) ?? date

        let predicate = HKSamplePredicate.categorySample(
            type: HKCategoryType(.sleepAnalysis),
            predicate: HKQuery.predicateForSamples(withStart: nightStart, end: nightEnd)
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        guard !samples.isEmpty else { return nil }

        var deep: TimeInterval = 0
        var core: TimeInterval = 0
        var rem: TimeInterval = 0
        var awake: TimeInterval = 0
        var segments: [SleepSegment] = []

        for sample in samples {
            let duration = sample.endDate.timeIntervalSince(sample.startDate)
            switch HKCategoryValueSleepAnalysis(rawValue: sample.value) {
            case .asleepDeep:
                deep += duration
                segments.append(SleepSegment(stage: 3, start: sample.startDate, end: sample.endDate))
            case .asleepCore:
                core += duration
                segments.append(SleepSegment(stage: 2, start: sample.startDate, end: sample.endDate))
            case .asleepREM:
                rem += duration
                segments.append(SleepSegment(stage: 1, start: sample.startDate, end: sample.endDate))
            case .awake:
                awake += duration
                segments.append(SleepSegment(stage: 0, start: sample.startDate, end: sample.endDate))
            case .asleepUnspecified:
                core += duration
                segments.append(SleepSegment(stage: 2, start: sample.startDate, end: sample.endDate))
            default: break
            }
        }

        let total = deep + core + rem + awake
        guard total > 0 else { return nil }

        let sleepStart = samples.first!.startDate
        let sleepEnd = samples.last!.endDate

        // Overnight respiratory rate: average within the sleep window, baselined against the last 14 days
        let rrUnit = HKUnit.count().unitDivided(by: .minute())
        let nightRRPredicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.respiratoryRate),
            predicate: HKQuery.predicateForSamples(withStart: sleepStart, end: sleepEnd)
        )
        let nightRRDescriptor = HKSampleQueryDescriptor(
            predicates: [nightRRPredicate],
            sortDescriptors: []
        )
        let nightRRSamples = (try? await nightRRDescriptor.result(for: store)) ?? []
        let nightRRValues = nightRRSamples.map { $0.quantity.doubleValue(for: rrUnit) }
        let overnightRR: Double? = nightRRValues.isEmpty ? nil : nightRRValues.reduce(0, +) / Double(nightRRValues.count)
        let rrBaselineHistory = await fetchQuantityHistory(for: .respiratoryRate, unit: rrUnit, days: 14)
        let rrBaseline: Double? = rrBaselineHistory.count > 1 ? rrBaselineHistory.reduce(0, +) / Double(rrBaselineHistory.count) : nil

        let storedTarget = UserDefaults.standard.double(forKey: UserProfileStorage.sleepTargetHours)
        let targetHours = storedTarget > 0 ? storedTarget : UserProfile.defaultSleepTargetHours

        return SleepAnalysis(
            totalDuration: total,
            remDuration: rem,
            deepDuration: deep,
            coreDuration: core,
            awakeDuration: awake,
            bedtime: sleepStart,
            wakeTime: sleepEnd,
            sleepTargetHours: targetHours,
            segments: segments.sorted { $0.start < $1.start },
            respiratoryRate: overnightRR,
            respiratoryBaseline: rrBaseline
        )
    }

    // MARK: - Nutrition

    func fetchNutritionSummary(for date: Date) async -> NutritionSummary {
        let startOfDay = Calendar.current.startOfDay(for: date)

        async let consumed = fetchTodayStatistic(for: .dietaryEnergyConsumed, unit: Self.kcalUnit)
        async let protein = fetchTodayStatistic(for: .dietaryProtein, unit: .gram())
        async let carbs = fetchTodayStatistic(for: .dietaryCarbohydrates, unit: .gram())
        async let fat = fetchTodayStatistic(for: .dietaryFatTotal, unit: .gram())
        async let burned = fetchTodayStatistic(for: .activeEnergyBurned, unit: Self.kcalUnit)

        _ = startOfDay
        let (cal, pro, car, fat_, burn) = await (consumed, protein, carbs, fat, burned)

        return NutritionSummary(
            caloriesConsumed: cal,
            caloriesBurned: burn,
            protein: pro,
            carbs: car,
            fat: fat_
        )
    }

    // MARK: - Workouts

    func fetchWorkouts(for dateRange: DateInterval) async -> [HKWorkout] {
        let predicate = HKSamplePredicate.workout(
            HKQuery.predicateForSamples(withStart: dateRange.start, end: dateRange.end)
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        return (try? await descriptor.result(for: store)) ?? []
    }

    func fetchStatistic(for identifier: HKQuantityTypeIdentifier, unit: HKUnit, on date: Date) async -> Double {
        let start = Calendar.current.startOfDay(for: date)
        let end = Calendar.current.date(byAdding: .day, value: 1, to: start) ?? start
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(identifier),
            predicate: HKQuery.predicateForSamples(withStart: start, end: end)
        )
        let descriptor = HKStatisticsQueryDescriptor(predicate: predicate, options: .cumulativeSum)
        return (try? await descriptor.result(for: store))?.sumQuantity()?.doubleValue(for: unit) ?? 0
    }

    // MARK: - Route Collector

    private final class RouteCollector: @unchecked Sendable {
        private let lock = NSLock()
        private var locations: [(latitude: Double, longitude: Double, altitude: Double, timestamp: Date)] = []

        func append(_ newLocations: [CLLocation]) {
            lock.lock()
            locations.append(contentsOf: newLocations.map {
                ($0.coordinate.latitude, $0.coordinate.longitude, $0.altitude, $0.timestamp)
            })
            lock.unlock()
        }

        var result: [(latitude: Double, longitude: Double, altitude: Double, timestamp: Date)] {
            lock.lock()
            defer { lock.unlock() }
            return locations
        }
    }

    // MARK: - Workout Details

    func fetchHeartRateDuringWorkout(_ workout: HKWorkout) async -> [(date: Date, value: Double)] {
        let predicate = HKSamplePredicate.quantitySample(
            type: HKQuantityType(.heartRate),
            predicate: HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let samples = (try? await descriptor.result(for: store)) ?? []
        return samples.map { ($0.startDate, $0.quantity.doubleValue(for: Self.bpmUnit)) }
    }

    func fetchWorkoutRoute(_ workout: HKWorkout) async -> [(latitude: Double, longitude: Double, altitude: Double, timestamp: Date)] {
        let routeType = HKSeriesType.workoutRoute()
        let predicate = HKQuery.predicateForObjects(from: workout)

        let route: HKWorkoutRoute? = await withCheckedContinuation { continuation in
            let query = HKSampleQuery(
                sampleType: routeType,
                predicate: predicate,
                limit: 1,
                sortDescriptors: nil
            ) { _, samples, _ in
                continuation.resume(returning: samples?.first as? HKWorkoutRoute)
            }
            store.execute(query)
        }

        guard let route else { return [] }

        let collector = RouteCollector()
        return await withCheckedContinuation { continuation in
            let routeQuery = HKWorkoutRouteQuery(route: route) { _, locations, done, _ in
                if let locations {
                    collector.append(locations)
                }
                if done {
                    continuation.resume(returning: collector.result)
                }
            }
            store.execute(routeQuery)
        }
    }

    func fetchWorkoutSplits(_ workout: HKWorkout, distancePerSplit: Double = 1000) async -> [(splitIndex: Int, duration: TimeInterval, avgHeartRate: Double?)] {
        guard let totalDistance = workout.totalDistance?.doubleValue(for: .meter()), totalDistance > 0 else { return [] }

        // Choose the distance quantity type matching the activity.
        let distanceType: HKQuantityType
        switch workout.workoutActivityType {
        case .cycling: distanceType = HKQuantityType(.distanceCycling)
        default: distanceType = HKQuantityType(.distanceWalkingRunning)
        }

        // Scope to samples associated with this workout to avoid double-counting
        // distance logged by multiple sources (e.g. Apple Watch + iPhone).
        let timePredicate = HKQuery.predicateForSamples(withStart: workout.startDate, end: workout.endDate)
        let workoutPredicate = HKQuery.predicateForObjects(from: workout)
        let predicate = HKSamplePredicate.quantitySample(
            type: distanceType,
            predicate: NSCompoundPredicate(andPredicateWithSubpredicates: [timePredicate, workoutPredicate])
        )
        let descriptor = HKSampleQueryDescriptor(
            predicates: [predicate],
            sortDescriptors: [SortDescriptor(\.startDate, order: .forward)]
        )
        let distanceSamples = (try? await descriptor.result(for: store)) ?? []

        let hrSamples = await fetchHeartRateDuringWorkout(workout)
        func avgHR(from start: Date, to end: Date) -> Double? {
            let s = hrSamples.filter { $0.date >= start && $0.date < end }
            return s.isEmpty ? nil : s.map(\.value).reduce(0, +) / Double(s.count)
        }

        // Fall back to even division only when distance samples are unavailable.
        guard !distanceSamples.isEmpty else {
            let splitCount = max(1, Int(ceil(totalDistance / distancePerSplit)))
            let durationPerSplit = workout.duration / Double(splitCount)
            return (0..<splitCount).map { i in
                let start = workout.startDate.addingTimeInterval(Double(i) * durationPerSplit)
                let end = workout.startDate.addingTimeInterval(Double(i + 1) * durationPerSplit)
                return (i, durationPerSplit, avgHR(from: start, to: end))
            }
        }

        // Walk the distance samples, accumulating meters and emitting a split each
        // time we cross a distance boundary. Boundary crossing times are linearly
        // interpolated within the sample that crosses them.
        var splits: [(splitIndex: Int, duration: TimeInterval, avgHeartRate: Double?)] = []
        var cumulative: Double = 0
        var nextBoundary = distancePerSplit
        var splitStartDate = workout.startDate
        var splitIndex = 0
        var lastSampleEnd = workout.startDate

        for sample in distanceSamples {
            let segDistance = sample.quantity.doubleValue(for: .meter())
            lastSampleEnd = sample.endDate
            guard segDistance > 0 else { continue }
            let segStart = sample.startDate
            let segDuration = sample.endDate.timeIntervalSince(segStart)
            let c0 = cumulative
            let c1 = cumulative + segDistance

            while nextBoundary <= c1 {
                let frac = (nextBoundary - c0) / segDistance
                let boundaryTime = segStart.addingTimeInterval(frac * segDuration)
                let duration = boundaryTime.timeIntervalSince(splitStartDate)
                splits.append((splitIndex, duration, avgHR(from: splitStartDate, to: boundaryTime)))
                splitStartDate = boundaryTime
                splitIndex += 1
                nextBoundary += distancePerSplit
            }
            cumulative = c1
        }

        // Emit the trailing partial split (the final, incomplete kilometer).
        let coveredByFullSplits = nextBoundary - distancePerSplit
        if cumulative - coveredByFullSplits > 1, lastSampleEnd > splitStartDate {
            let duration = lastSampleEnd.timeIntervalSince(splitStartDate)
            splits.append((splitIndex, duration, avgHR(from: splitStartDate, to: lastSampleEnd)))
        }

        return splits
    }

    func fetchWorkoutsExtended(days: Int) async -> [HKWorkout] {
        let start = Calendar.current.date(byAdding: .day, value: -days, to: Date()) ?? Date()
        return await fetchWorkouts(for: DateInterval(start: start, end: Date()))
    }

    func fetchLatestVO2Max() async -> Double? {
        return await fetchLatestQuantityExtended(for: .vo2Max, unit: HKUnit(from: "ml/kg·min"), days: 90)
    }

    static func userAgeEstimate() -> Int {
        let raw = UserDefaults.standard.string(forKey: "ageRange") ?? "25-34"
        switch raw {
        case "Under 18": return 16
        case "18-24": return 21
        case "25-34": return 30
        case "35-44": return 40
        case "45+": return 50
        default: return 30
        }
    }

    /// Scales the personal daily strain target by self-reported fitness level so the exertion
    /// score isn't pegged for athletes or overstated for sedentary users.
    static func fitnessTargetMultiplier() -> Double {
        switch UserDefaults.standard.string(forKey: UserProfileStorage.fitnessLevel) {
        case FitnessLevel.sedentary.rawValue:  return 0.8
        case FitnessLevel.trained.rawValue:    return 1.2
        case FitnessLevel.athlete.rawValue:    return 1.4
        default:                               return 1.0   // recreational / unset
        }
    }
}

extension HKWorkout {
    /// Active energy in kcal, preferring associated-sample statistics (which reflect
    /// samples attached after the workout was saved) over the frozen totalEnergyBurned.
    var activeEnergyKcal: Double {
        let stats = statistics(for: HKQuantityType(.activeEnergyBurned))?.sumQuantity()?.doubleValue(for: .kilocalorie()) ?? 0
        if stats > 0 { return stats }
        return totalEnergyBurned?.doubleValue(for: .kilocalorie()) ?? 0
    }
}
