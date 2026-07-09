# Vector

Vector is an iOS 27 health & fitness app that turns HealthKit signals into four daily scores — **Recovery**, **Exertion**, **Sleep**, and **Stress** — plus AI-generated workouts and (flagged-off) nutrition tracking. It ships with a watchOS 26 companion, home-screen/Live Activity widgets, and App Intents / Siri shortcuts.

## Targets & platform
- **Vector** (`com.jacobpantuso.Vector`) — main iOS app, `IPHONEOS_DEPLOYMENT_TARGET = 27.0`.
- **VectorWatch** (`com.jacobpantuso.Vector.watchkitapp`) — watchOS 26 companion.
- **VectorWidgets** (`com.jacobpantuso.Vector.VectorWidgets`) — WidgetKit + Workout Live Activity.
- **Shared/** — code shared across targets (`WorkoutActivityAttributes`, `WorkoutLiveActivityIntents`).
- SwiftUI throughout; `@Observable` (Observation framework) for state, not `ObservableObject`.

## Architecture
- **Entry:** `Vector/VectorApp.swift` — owns `HealthKitService`, `WatchSyncService.shared`, `ProfileCloudSync`, `FoodLogService`. Root is a `TabView` (Home / Train / Nutrition* / Profile) gated behind onboarding; hosts the mini workout bar + `ActiveWorkoutView` sheet. Pushes score changes to the watch via `syncToWatch()`. *Nutrition tab is hidden by `FeatureFlags.nutritionEnabled` (currently `false`).
- **Services (`Vector/Services/`)** — the core logic layer:
  - `HealthKitService` — the central `@Observable` hub. Reads vitals from HealthKit, computes/holds all four scores, workouts, nutrition; has `applyMockData()` for DEBUG/simulator.
  - Score engines are pure `struct`s with `static func compute…`: `RecoveryEngine`, `StressEngine`, `TrainingLoadEngine` (exertion), plus `BaselineStatistics` (shared stats helpers). `SleepAnalysis` is computed from sleep data.
  - `InsightEngine`, `ProgressionAdvisor`, `AdvisorContext`/`AdvisorTools` — AI advisor + progressive-overload logic. `WorkoutPlanningEngine` generates plans.
  - Persistence stores (JSON/UserDefaults-backed `@Observable`s): `WorkoutStorageService`, `ExerciseProgressionStore`, `WorkoutCompletionStore`, `ScoreHistoryStore`, `StressHistoryStore`, `SleepDebtStore`, `CustomExerciseStore`, `FoodLogService`.
  - `WatchSyncService` — `WCSession` bridge (phone owns the `HKWorkout`; see watch-sync notes below).
  - `WorkoutLiveActivityController` — drives the Live Activity.
- **Models (`Vector/Models/`)** — value types: `RecoveryScore`, `ExertionScore`, `SleepAnalysis`, `StressScore`, `WorkoutDomain` (SavedWorkout, ManualExerciseEntry, WorkoutPlan), `ExerciseLibrary`, `UserProfile`, nutrition models, etc.
- **Views (`Vector/Views/`)** — grouped by feature: `Dashboard/` (Home = `DashboardView`, per-score cards), `Detail/` (per-metric detail screens), `Train/` (workout builder, AI generate, active workout under `WorkoutView/`, history), `Nutrition/`, `Advisor/`, `Insights/`, `Onboarding/`, `Settings/`, and reusable `Components/` (`GlassCard`, `MetricRing`, `MetricDetailSheet`, charts, rings).
- **Intents (`Vector/Intents/`)** — App Intents + Siri shortcuts (recovery, sleep, exertion, heart rate, weekly summary, ask-advisor) with entities and snippet views.

## AI / FoundationModels
- Uses Apple's on-device `FoundationModels` (`@Generable`/`@Guide` structs like `WorkoutPlan`, `LanguageModelSession`).
- **Private Cloud Compute is OFF by default.** `AIModel.isPCCEnabled = false`. PCC needs the restricted `com.apple.developer.private-cloud-compute` entitlement Vector lacks; touching `PrivateCloudComputeLanguageModel` (even `.availability`) without it is a **non-catchable fatal error**. Code short-circuits to `SystemLanguageModel.default`. Do not enable PCC unless the build is signed for it.

## Watch sync (important invariants)
- The **iPhone owns the `HKWorkout`** — the watch never finishes/authors the workout, avoiding duplicates and phantom entries. On teardown, the phone tells the watch whether the workout was *ended* (`sendWorkoutEnded`) or *discarded* (`sendWorkoutDiscarded`) so the watch discards its live session instead of leaving a phantom `HKWorkout` in Health (the phone can't delete watch-authored workouts).
- Score changes on the phone push to the watch via `WatchSyncService.shared.syncScores(...)`.

## Conventions
- Prefer `@Observable` + `@State`/`environment(...)` injection over Combine.
- Engines are stateless static functions; keep computation testable and out of views.
- Feature-gate WIP with `FeatureFlags` rather than deleting code.
- SwiftUI `#Preview`s: watch previews need `return` + preview-safe service inits (live render can crash on Xcode betas — an infra issue, not a code bug).
- Health entitlements: `com.apple.developer.healthkit` (+ health-records access) and iCloud KVS for profile sync.

## Working in this repo
- **Per user preference, delegate all code writes to Haiku subagents** — don't write Swift directly in the main turn (see auto-memory). Opus plans, Haiku implements.
- Use the Xcode MCP tools (`BuildProject`, `RunProject`, previews, etc.) to build/run/test.
- `.claude/worktrees/` holds agent worktrees — ignore them when searching the main tree.

# agent-device

Use agent-device only for app/device automation tasks.
Before planning device work, run `agent-device --version` and read `agent-device help workflow`.
For exploratory QA, read `agent-device help dogfood`.
For logs, network, audio, traces, or runtime failures, read `agent-device help debugging`.
For React Native component trees, props/state/hooks, slow renders, or rerenders, read `agent-device help react-devtools`.
For React Native JavaScript heap growth, heap snapshots, or retained-object leaks, read `agent-device help cdp`.
For React Native apps, overlays, Metro/Fast Refresh blockers, and routing to React DevTools or debugging evidence, read `agent-device help react-native`.

Use the CLI in the integrated terminal.
If `agent-device` is not on PATH but the user installed it globally in another shell, resolve the absolute binary path instead of using `npx -y agent-device@latest`.
Prefer `open -> snapshot -i -> act -> re-snapshot -> verify -> close`.
Keep mutating commands against one session serial.
