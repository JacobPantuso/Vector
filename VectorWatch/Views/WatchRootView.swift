import SwiftUI

struct WatchRootView: View {
	@Environment(WatchHealthStore.self) private var healthStore
	@Environment(WatchConnectivityService.self) private var connectivityService

	var body: some View {
		TabView {
			WatchDashboardView()
				.tag(0)

			WatchRecoveryView()
				.tag(1)

			WatchExertionView()
				.tag(2)

			WatchSleepView()
				.tag(3)

			WatchVitalsView()
				.tag(4)
		}
		.tabViewStyle(.verticalPage)
		.onAppear {
			Task {
				await healthStore.requestAuthorization()
			}
		}
	}
}

#Preview {
	WatchRootView()
		.environment(WatchHealthStore())
		.environment(WatchConnectivityService())
}
