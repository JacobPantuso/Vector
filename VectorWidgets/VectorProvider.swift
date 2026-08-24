import WidgetKit
import SwiftUI
import AppIntents

struct VectorEntry: TimelineEntry {
    let date: Date
    let snapshot: VectorWidgetSnapshot
    var kind: VectorMetricKind = .recovery
    var hasData: Bool { !snapshot.isEmpty }
}

// MARK: - VectorTimelineProvider (for static widgets)

struct VectorTimelineProvider: TimelineProvider {
    func placeholder(in context: Context) -> VectorEntry {
        VectorEntry(date: .now, snapshot: VectorWidgetStore.previewSnapshot())
    }

    func getSnapshot(in context: Context, completion: @escaping (VectorEntry) -> Void) {
        let snapshot = context.isPreview ? VectorWidgetStore.previewSnapshot() : (VectorWidgetStore.load() ?? VectorWidgetStore.previewSnapshot())
        let entry = VectorEntry(date: .now, snapshot: snapshot)
        completion(entry)
    }

    func getTimeline(in context: Context, completion: @escaping (Timeline<VectorEntry>) -> Void) {
        let snapshot = VectorWidgetStore.load() ?? VectorWidgetStore.previewSnapshot()
        let entry = VectorEntry(date: .now, snapshot: snapshot)
        let timeline = Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
        completion(timeline)
    }
}

// MARK: - VectorAppIntentProvider (for configurable widgets)

struct VectorAppIntentTimelineProvider: AppIntentTimelineProvider {
    func placeholder(in context: Context) -> VectorEntry {
        VectorEntry(date: .now, snapshot: VectorWidgetStore.previewSnapshot())
    }

    func snapshot(for configuration: SelectMetricIntent, in context: Context) -> VectorEntry {
        let snapshot = context.isPreview ? VectorWidgetStore.previewSnapshot() : (VectorWidgetStore.load() ?? VectorWidgetStore.previewSnapshot())
        let entry = VectorEntry(date: .now, snapshot: snapshot, kind: configuration.metric.kind)
        return entry
    }

    func timeline(for configuration: SelectMetricIntent, in context: Context) -> Timeline<VectorEntry> {
        let snapshot = VectorWidgetStore.load() ?? VectorWidgetStore.previewSnapshot()
        let entry = VectorEntry(date: .now, snapshot: snapshot, kind: configuration.metric.kind)
        return Timeline(entries: [entry], policy: .after(Date().addingTimeInterval(30 * 60)))
    }
}

// MARK: - SelectMetricIntent (App Intent for metric selection)

struct SelectMetricIntent: WidgetConfigurationIntent {
    static var title: LocalizedStringResource = "Select Metric"
    static var description: IntentDescription = IntentDescription("Choose which metric to display")

    @Parameter(title: "Metric", default: .recovery)
    var metric: MetricChoice
}

// MARK: - MetricChoice (AppEnum)

enum MetricChoice: String, AppEnum {
    case recovery, exertion, sleep, stress

    var id: String { rawValue }
    static var typeDisplayRepresentation: TypeDisplayRepresentation = "Metric"
    static var caseDisplayRepresentations: [Self: DisplayRepresentation] {
        [
            .recovery: DisplayRepresentation(title: "Recovery", image: .init(systemName: "heart.fill")),
            .exertion: DisplayRepresentation(title: "Exertion", image: .init(systemName: "bolt.fill")),
            .sleep: DisplayRepresentation(title: "Sleep", image: .init(systemName: "moon.stars.fill")),
            .stress: DisplayRepresentation(title: "Stress", image: .init(systemName: "waveform.path.ecg"))
        ]
    }

    var kind: VectorMetricKind {
        switch self {
        case .recovery: .recovery
        case .exertion: .exertion
        case .sleep: .sleep
        case .stress: .stress
        }
    }
}
