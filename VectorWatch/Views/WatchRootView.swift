import SwiftUI

struct WatchRootView: View {
	@Environment(WatchHealthStore.self) private var healthStore
	@Environment(WatchConnectivityService.self) private var connectivityService

	var body: some View {
		TabView {
			NavigationStack { WatchDashboardView() }
				.tag(0)

			NavigationStack { WatchRecoveryView() }
				.tag(1)

			NavigationStack { WatchExertionView() }
				.tag(2)

			NavigationStack { WatchSleepView() }
				.tag(3)

			NavigationStack { WatchVitalsView() }
				.tag(4)
		}
		.tabViewStyle(.verticalPage)
		.fullScreenCover(isPresented: Binding(
			get: { connectivityService.activeWorkout != nil },
			set: { _ in }
		)) {
			WatchWorkoutView()
				.environment(connectivityService)
				.environment(healthStore)
		}
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
