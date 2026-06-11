import Foundation
import HealthKit

@Observable
final class WatchHealthStore {
	private let healthStore = HKHealthStore()

	var heartRate: Double = 0
	var hrv: Double = 0
	var recoveryScore: Int = 0
	var exertionScore: Int = 0
	var sleepHours: Double = 0
	var isAuthorized = false

	func requestAuthorization() async {
		guard HKHealthStore.isHealthDataAvailable() else { return }

		let readTypes: Set<HKObjectType> = [
			HKQuantityType.quantityType(forIdentifier: .heartRate)!,
			HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN)!,
			HKCategoryType.categoryType(forIdentifier: .sleepAnalysis)!,
		]

		do {
			try await healthStore.requestAuthorization(toShare: [], read: readTypes)
			isAuthorized = true
			await fetchAll()
		} catch {
			isAuthorized = false
		}
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
				DispatchQueue.main.async {
					self?.heartRate = bpm
				}
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

			DispatchQueue.main.async {
				self?.sleepHours = totalMinutes / 60
			}
		}

		healthStore.execute(query)
	}

	private func fetchHRV() async {
		guard let hrvType = HKQuantityType.quantityType(forIdentifier: .heartRateVariabilitySDNN) else { return }

		let sortDescriptor = NSSortDescriptor(key: HKSampleSortIdentifierStartDate, ascending: false)
		let query = HKSampleQuery(sampleType: hrvType, predicate: nil, limit: 1, sortDescriptors: [sortDescriptor]) { [weak self] _, samples, _ in
			if let sample = samples?.first as? HKQuantitySample {
				let hrv = sample.quantity.doubleValue(for: HKUnit(from: "ms"))
				DispatchQueue.main.async {
					self?.hrv = hrv
				}
			}
		}

		healthStore.execute(query)
	}
}
