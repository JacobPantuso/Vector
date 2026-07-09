import SwiftUI
import WatchKit
import HealthKit

class VectorWatchExtensionDelegate: NSObject, WKApplicationDelegate {
	func handle(_ workoutConfiguration: HKWorkoutConfiguration) {
		WatchHealthStore.shared.startWorkoutSession(configuration: workoutConfiguration)
	}

	func applicationDidBecomeActive() {
		// Retry a workout session whose background start was rejected.
		WatchHealthStore.shared.activateSessionIfForeground()
	}
}

@main
struct VectorWatchApp: App {
	@WKApplicationDelegateAdaptor(VectorWatchExtensionDelegate.self) var delegate
	@State private var watchHealthStore = WatchHealthStore.shared
	@State private var watchConnectivityService = WatchConnectivityService()

	var body: some Scene {
		WindowGroup {
			WatchRootView()
				.environment(watchHealthStore)
				.environment(watchConnectivityService)
				.task {
					watchConnectivityService.configure(healthStore: watchHealthStore)
				}
		}
	}
}
