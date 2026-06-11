import Foundation
import HealthKit
import Observation

@Observable
final class WatchHealthStore {
	var heartRate: Double?
	var todaySteps: Double = 0
	var activeCalories: Double = 0
	var restingHR: Double?
	var hrv: Double?

	private let healthStore = HKHealthStore()
	private let readTypes: Set<HKObjectType> = [
		HKQuantityType.quantityType(forIdentifier: .heartRate)!,
		HKQuantityType.quantityType(forIdentifier: .stepCount)!,
		HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned)!,
		HKQuantityType.quantityType(forIdentifier: .restingHeartRate)!,
		HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!
	]

	func requestAuthorization() async {
		do {
			try await healthStore.requestAuthorization(toShare: [], read: readTypes)
			await startHeartRateQuery()
			await fetchTodayStats()
		} catch {
			print("HealthKit authorization failed: \(error)")
		}
	}

	func startHeartRateQuery() async {
		guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

		let query = HKObserverQuery(sampleType: hrType, predicate: nil) { [weak self] _, _, error in
			if error == nil {
				self?.fetchLatestHeartRate()
			}
		}

		healthStore.execute(query)
	}

	private func fetchLatestHeartRate() {
		guard let hrType = HKQuantityType.quantityType(forIdentifier: .heartRate) else { return }

		let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
		let query = HKSampleQuery(sampleType: hrType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
			if let sample = samples?.first as? HKQuantitySample {
				let hr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
				DispatchQueue.main.async {
					self?.heartRate = hr
				}
			}
		}

		healthStore.execute(query)
	}

	func fetchTodayStats() async {
		let now = Date()
		let startOfDay = Calendar.current.startOfDay(for: now)
		let predicate = HKQuery.predicateForSamples(withStart: startOfDay, end: now)

		await fetchSteps(predicate: predicate)
		await fetchActiveCalories(predicate: predicate)
		await fetchRestingHeartRate()
		await fetchHRV()
	}

	private func fetchSteps(predicate: NSPredicate) async {
		guard let stepsType = HKQuantityType.quantityType(forIdentifier: .stepCount) else { return }

		let query = HKStatisticsQuery(
			quantityType: stepsType,
			quantitySamplePredicate: predicate,
			options: .cumulativeSum
		) { [weak self] _, result, _ in
			if let sum = result?.sumQuantity() {
				let steps = sum.doubleValue(for: HKUnit.count())
				DispatchQueue.main.async {
					self?.todaySteps = steps
				}
			}
		}

		healthStore.execute(query)
	}

	private func fetchActiveCalories(predicate: NSPredicate) async {
		guard let caloriesType = HKQuantityType.quantityType(forIdentifier: .activeEnergyBurned) else { return }

		let query = HKStatisticsQuery(
			quantityType: caloriesType,
			quantitySamplePredicate: predicate,
			options: .cumulativeSum
		) { [weak self] _, result, _ in
			if let sum = result?.sumQuantity() {
				let calories = sum.doubleValue(for: HKUnit.kilocalorie())
				DispatchQueue.main.async {
					self?.activeCalories = calories
				}
			}
		}

		healthStore.execute(query)
	}

	private func fetchRestingHeartRate() async {
		guard let restingHRType = HKQuantityType.quantityType(forIdentifier: .restingHeartRate) else { return }

		let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
		let query = HKSampleQuery(sampleType: restingHRType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
			if let sample = samples?.first as? HKQuantitySample {
				let rhr = sample.quantity.doubleValue(for: HKUnit.count().unitDivided(by: .minute()))
				DispatchQueue.main.async {
					self?.restingHR = rhr
				}
			}
		}

		healthStore.execute(query)
	}

	private func fetchHRV() async {
		guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

		let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
		let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
			if let sample = samples?.first as? HKQuantitySample {
				let hrv = sample.quantity.doubleValue(for: HKUnit.millisecond())
				DispatchQueue.main.async {
					self?.hrv = hrv
				}
			}
		}

		healthStore.execute(query)
	}
}
