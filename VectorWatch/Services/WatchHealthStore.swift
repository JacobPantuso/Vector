import Foundation
import HealthKit
import WatchKit

@Observable
final class WatchHealthStore: NSObject {
	@ObservationIgnored private lazy var healthStore = HKHealthStore()
	private var workoutSession: HKWorkoutSession?
	private var liveBuilder: HKLiveWorkoutBuilder?

	var heartRate: Double = 0
	var hrv: Double = 0
	var sleepHours: Double = 0
	var isAuthorized = false
	var isWorkoutSessionActive = false
	private var isStartingSession = false
	private var needsActivation = false
	private var lastConfiguration: HKWorkoutConfiguration?
	private var pendingDiscard = false

	var onHeartRateUpdate: ((Double) -> Void)?

	static let shared = WatchHealthStore()

	func requestAuthorization() async {
		guard HKHealthStore.isHealthDataAvailable() else { return }

		let readTypes: Set<HKObjectType> = [
			HKQuantityType.quantityType(forIdentifier: .heartRate)!,
			HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
			HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
		]

		let writeTypes: Set<HKSampleType> = [
			HKObjectType.workoutType()
		]

		do {
			try await healthStore.requestAuthorization(toShare: writeTypes, read: readTypes)
			isAuthorized = true
			await fetchAll()
		} catch {
			isAuthorized = false
		}
	}

	func startWorkoutSession(configuration: HKWorkoutConfiguration? = nil) {
		// Guard against concurrent starts: the mirrored-launch (`handle(_:)`) path and
		// the WatchConnectivity workout-update path can both fire near-simultaneously.
		guard !isWorkoutSessionActive, !isStartingSession else { return }
		isStartingSession = true
		let config = configuration ?? {
			let cfg = HKWorkoutConfiguration()
			cfg.activityType = .traditionalStrengthTraining
			cfg.locationType = .indoor
			return cfg
		}()

		Task {
			// Cold launches triggered by `startWatchApp` invoke `handle(_:)` before any
			// view has requested authorization, so ensure it is granted before creating
			// the session. HealthKit returns immediately (no UI) when already authorized.
			if !isAuthorized { await requestAuthorization() }
			await MainActor.run { self.beginWorkoutSession(config: config) }
		}
	}

	private func beginWorkoutSession(config: HKWorkoutConfiguration) {
		defer { isStartingSession = false }
		guard !isWorkoutSessionActive else { return }
		do {
			let session = try HKWorkoutSession(healthStore: healthStore, configuration: config)
			let builder = session.associatedWorkoutBuilder()
			builder.dataSource = HKLiveWorkoutDataSource(healthStore: healthStore, workoutConfiguration: config)
			builder.delegate = self
			session.delegate = self
			self.workoutSession = session
			self.liveBuilder = builder
			self.lastConfiguration = config
			self.isWorkoutSessionActive = true
			self.needsActivation = false
			// Launches triggered by the iPhone's `startWatchApp` arrive in the background,
			// and starting the session there is both permitted (it's the sanctioned
			// `handle(_:)` path) and required: a running session is what makes watchOS
			// bring the app to the foreground.
			let now = Date()
			session.startActivity(with: now)
			builder.beginCollection(withStart: now) { success, error in
				if let error {
					print("[WatchHealthStore] beginCollection error: \(error.localizedDescription)")
				}
			}
		} catch {
			print("[WatchHealthStore] failed to start workout session: \(error.localizedDescription)")
		}
	}

	/// Fallback: if a background `startActivity` was ever rejected (see
	/// `workoutSession(_:didFailWithError:)`), retry the session once the app is active.
	/// Safe to call repeatedly; it no-ops unless a retry is pending.
	func activateSessionIfForeground() {
		guard needsActivation,
			  WKApplication.shared().applicationState == .active else { return }
		needsActivation = false
		startWorkoutSession(configuration: lastConfiguration)
	}

	func stopWorkoutSession() {
		DispatchQueue.main.async {
			self.isWorkoutSessionActive = false
			self.isStartingSession = false
			self.needsActivation = false
		}
		guard let session = workoutSession else {
			liveBuilder?.discardWorkout()
			liveBuilder = nil
			return
		}
		// A merely-ended session is still finalized by watchOS into a phantom HKWorkout,
		// duplicating the phone's. We defer the discard until the session reaches .ended,
		// then discardWorkout() prevents the phantom. The sensor HR/energy samples are
		// system-authored and survive the discard; the phone associates them with its own
		// workout once they sync.
		pendingDiscard = true
		session.end()
	}

	/// Discards the watch's live workout WITHOUT saving anything. Used when the user
	/// discards on the phone: a merely-ended session (see `stopWorkoutSession`) is still
	/// finalized by watchOS into a phantom ~1-min HKWorkout, so we must explicitly
	/// `discardWorkout()`. HealthKit requires the session to reach `.ended` first, so the
	/// actual discard happens in `workoutSession(_:didChangeTo:)` once `pendingDiscard` is set.
	func discardWorkoutSession() {
		DispatchQueue.main.async {
			self.isWorkoutSessionActive = false
			self.isStartingSession = false
			self.needsActivation = false
		}
		guard let session = workoutSession else {
			liveBuilder?.discardWorkout()
			liveBuilder = nil
			return
		}
		pendingDiscard = true
		session.end()
	}

	func pauseWorkoutSession() {
		workoutSession?.pause()
	}

	func resumeWorkoutSession() {
		workoutSession?.resume()
	}

	func fetchAll() async {
		await fetchHeartRate()
		await fetchHRV()
		await fetchSleep()
	}

	private func fetchHeartRate() async {
		guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }
		let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
		let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
			if let sample = samples?.first as? HKQuantitySample {
				let bpm = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
				DispatchQueue.main.async { self?.heartRate = bpm }
			}
		}
		healthStore.execute(query)
	}

	private func fetchSleep() async {
		guard let sleepType = HKCategoryType.categoryType(forIdentifier: .sleepAnalysis) else { return }
		let calendar = Calendar.current
		let start = calendar.startOfDay(for: Date())
		let predicate = HKQuery.predicateForSamples(withStart: start, end: Date(), options: .strictStartDate)
		let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
		let query = HKSampleQuery(sampleType: sleepType, predicate: predicate, limit: HKObjectQueryNoLimit, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
			let totalMinutes = samples?.reduce(0.0) { acc, sample in
				guard let categorySample = sample as? HKCategorySample else { return acc }
				if categorySample.value == HKCategoryValueSleepAnalysis.asleepCore.rawValue ||
				   categorySample.value == HKCategoryValueSleepAnalysis.asleepDeep.rawValue ||
				   categorySample.value == HKCategoryValueSleepAnalysis.asleepREM.rawValue {
					return acc + sample.endDate.timeIntervalSince(sample.startDate) / 60
				}
				return acc
			} ?? 0
			DispatchQueue.main.async { self?.sleepHours = totalMinutes / 60 }
		}
		healthStore.execute(query)
	}

	private func fetchHRV() async {
		guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }
		let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
		let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
			if let sample = samples?.first as? HKQuantitySample {
				let hrv = sample.quantity.doubleValue(for: HKUnit(from: "ms"))
				DispatchQueue.main.async { self?.hrv = hrv }
			}
		}
		healthStore.execute(query)
	}
}

extension WatchHealthStore: HKWorkoutSessionDelegate {
	func workoutSession(_ workoutSession: HKWorkoutSession, didChangeTo toState: HKWorkoutSessionState, from fromState: HKWorkoutSessionState, date: Date) {
		print("[WatchHealthStore] workout state \(fromState.rawValue) -> \(toState.rawValue)")
		if toState == .ended, pendingDiscard {
			pendingDiscard = false
			liveBuilder?.discardWorkout()
			self.workoutSession = nil
			self.liveBuilder = nil
		}
	}
	func workoutSession(_ workoutSession: HKWorkoutSession, didFailWithError error: Error) {
		print("[WatchHealthStore] workout session failed: \(error.localizedDescription)")
		// A background start outside the sanctioned launch path can be rejected; tear
		// down and let `activateSessionIfForeground` retry on the next foreground.
		DispatchQueue.main.async {
			self.workoutSession = nil
			self.liveBuilder = nil
			self.isWorkoutSessionActive = false
			self.isStartingSession = false
			self.needsActivation = true
		}
	}
}

extension WatchHealthStore: HKLiveWorkoutBuilderDelegate {
	func workoutBuilderDidCollectEvent(_ workoutBuilder: HKLiveWorkoutBuilder) {}

	func workoutBuilder(_ workoutBuilder: HKLiveWorkoutBuilder, didCollectDataOf collectedTypes: Set<HKSampleType>) {
		guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate),
			  collectedTypes.contains(hrType),
			  let stats = workoutBuilder.statistics(for: hrType),
			  let bpm = stats.mostRecentQuantity()?.doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute())) else { return }
		DispatchQueue.main.async {
			self.heartRate = bpm
			self.onHeartRateUpdate?(bpm)
		}
	}
}
