import SwiftUI
import WatchKit

@main
struct VectorWatchApp: App {
	@State private var watchHealthStore = WatchHealthStore()
	@State private var watchConnectivityService = WatchConnectivityService()

	var body: some Scene {
		WindowGroup {
			WatchRootView()
				.environment(watchHealthStore)
				.environment(watchConnectivityService)
		}
	}
}
