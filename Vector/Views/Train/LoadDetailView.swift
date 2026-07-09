import SwiftUI
import HealthKit

enum LoadDetailType {
    case training
    case cardio

    var title: String {
        switch self {
        case .training: return "Training Load"
        case .cardio: return "Cardio Load"
        }
    }

    var icon: String {
        switch self {
        case .training: return "flame.fill"
        case .cardio: return "heart.fill"
        }
    }

    var accentColor: Color {
        switch self {
        case .training: return .orange
        case .cardio: return .pink
        }
    }
}

enum LoadPeriod: String, CaseIterable, Identifiable {
    case month30 = "30D"
    case month3 = "3M"
    case month12 = "12M"

    var id: String { rawValue }

    var days: Int {
        switch self {
        case .month30: return 30
        case .month3: return 90
        case .month12: return 365
        }
    }

    var bucketLabel: String {
        switch self {
        case .month30, .month3: return "Week"
        case .month12: return "Month"
        }
    }
}

struct LoadBucket: Identifiable {
    let id = UUID()
    let label: String
    let load: Double
    let acwr: Double?

    var status: BucketStatus {
        guard let acwr else { return .noData }
        if acwr < 0.8 { return .detraining }
        else if acwr <= 1.3 { return .steady }
        else { return .overtraining }
    }

    enum BucketStatus {
        case detraining, steady, overtraining, noData
        var color: Color {
            switch self {
            case .detraining: return .blue
            case .steady: return .green
            case .overtraining: return .red
            case .noData: return .secondary.opacity(0.3)
            }
        }
    }
}

struct LoadDetailView: View {
    let type: LoadDetailType
    let workouts: [HKWorkout]
    let vo2Max: Double?

    @Environment(HealthKitService.self) var service
    @Environment(\.dismiss) private var dismiss
    @State private var selectedPeriod: LoadPeriod = .month30
    @State private var extendedWorkouts: [HKWorkout] = []
    @State private var isLoading = false

    private static let cardioTypes: Set<HKWorkoutActivityType> = [
        .running, .walking, .cycling, .swimming, .hiking,
        .rowing, .elliptical, .stairClimbing, .highIntensityIntervalTraining,
        .dance, .crossTraining
    ]

    private var relevantWorkouts: [HKWorkout] {
        let base = selectedPeriod.days <= 28 ? workouts : extendedWorkouts
        switch type {
        case .training: return base
        case .cardio: return base.filter { Self.cardioTypes.contains($0.workoutActivityType) }
        }
    }

    private var buckets: [LoadBucket] {
        let calendar = Calendar.current
        let now = Date()

        if selectedPeriod == .month12 {
            // Monthly buckets
            return (0..<12).reversed().map { monthsBack in
                let bucketEnd = calendar.date(byAdding: .month, value: -monthsBack, to: now) ?? now
                let bucketStart = calendar.date(byAdding: .month, value: -1, to: bucketEnd) ?? bucketEnd
                let chronicStart = calendar.date(byAdding: .month, value: -3, to: bucketEnd) ?? bucketEnd

                let bucketLoad = relevantWorkouts
                    .filter { $0.startDate >= bucketStart && $0.startDate < bucketEnd }
                    .reduce(0.0) { $0 + $1.activeEnergyKcal }

                let chronicTotal = relevantWorkouts
                    .filter { $0.startDate >= chronicStart && $0.startDate < bucketEnd }
                    .reduce(0.0) { $0 + $1.activeEnergyKcal }
                let chronic = chronicTotal / 3

                let acwr: Double? = chronic > 10 ? bucketLoad / chronic : nil
                let label = bucketStart.formatted(.dateTime.month(.abbreviated))
                return LoadBucket(label: label, load: bucketLoad, acwr: acwr)
            }
        } else {
            // Weekly buckets
            let weeks = selectedPeriod.days / 7
            return (0..<weeks).reversed().map { weeksBack in
                let bucketEnd = calendar.date(byAdding: .weekOfYear, value: -weeksBack, to: now) ?? now
                let bucketStart = calendar.date(byAdding: .weekOfYear, value: -1, to: bucketEnd) ?? bucketEnd
                let chronicStart = calendar.date(byAdding: .weekOfYear, value: -4, to: bucketEnd) ?? bucketEnd

                let bucketLoad = relevantWorkouts
                    .filter { $0.startDate >= bucketStart && $0.startDate < bucketEnd }
                    .reduce(0.0) { $0 + $1.activeEnergyKcal }

                let chronicTotal = relevantWorkouts
                    .filter { $0.startDate >= chronicStart && $0.startDate < bucketEnd }
                    .reduce(0.0) { $0 + $1.activeEnergyKcal }
                let chronic = chronicTotal / 4

                let acwr: Double? = chronic > 10 ? bucketLoad / chronic : nil
                let label = bucketStart.formatted(.dateTime.month(.abbreviated).day())
                return LoadBucket(label: label, load: bucketLoad, acwr: acwr)
            }
        }
    }

    private var currentStatus: String {
        let latest = buckets.last { $0.load > 0 }
        guard let acwr = latest?.acwr else { return "No Data" }
        if acwr < 0.8 { return "Detraining" }
        else if acwr <= 1.3 { return "Steady" }
        else { return "Overtraining" }
    }

    private var currentStatusColor: Color {
        let latest = buckets.last { $0.load > 0 }
        guard let acwr = latest?.acwr else { return .secondary }
        if acwr < 0.8 { return .blue }
        else if acwr <= 1.3 { return .green }
        else { return .red }
    }

    var body: some View {
        NavigationStack {
            ScrollView {
                VStack(spacing: 24) {
                    statusHeader
                    periodSelector
                    loadChart
                    if type == .cardio { cardioFitnessSection }
                    phasesGuide
                }
                .padding(.horizontal, 20)
                .padding(.bottom, 30)
            }
            .scrollEdgeEffectStyle(.soft, for: .all)
            .navigationTitle(type.title)
            .navigationBarTitleDisplayMode(.inline)
            .toolbar {
                ToolbarItem(placement: .topBarTrailing) {
                    Button("Done") { dismiss() }
                        .fontWeight(.semibold)
                }
            }
            .task(id: selectedPeriod) {
                if selectedPeriod.days > 28 {
                    isLoading = true
                    extendedWorkouts = await service.fetchWorkoutsExtended(days: selectedPeriod.days)
                    isLoading = false
                }
            }
        }
    }

    // MARK: - Status Header

    private var statusHeader: some View {
        HStack(spacing: 16) {
            ZStack {
                Circle()
                    .fill(type.accentColor.opacity(0.18))
                    .frame(width: 52, height: 52)
                Image(systemName: type.icon)
                    .font(.title2.weight(.semibold))
                    .foregroundStyle(type.accentColor)
            }
            VStack(alignment: .leading, spacing: 4) {
                Text(currentStatus)
                    .font(.title2.bold())
                    .foregroundStyle(.primary)
                Text("Measured based on your recent workouts.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
            Spacer()
        }
        .padding(.top, 8)
    }

    // MARK: - Period Selector

    private var periodSelector: some View {
        HStack(spacing: 0) {
            ForEach(LoadPeriod.allCases) { period in
                Button(period.rawValue) {
                    selectedPeriod = period
                }
                .font(.subheadline.weight(.medium))
                .frame(maxWidth: .infinity)
                .padding(.vertical, 10)
                .background(
                    selectedPeriod == period
                        ? type.accentColor.opacity(0.22)
                        : Color.clear
                )
                .foregroundStyle(selectedPeriod == period ? type.accentColor : .secondary)
                .clipShape(RoundedRectangle(cornerRadius: 10))
            }
        }
        .padding(4)
        .glassEffect(in: .rect(cornerRadius: 14))
    }

    // MARK: - Load Chart

    private var loadChart: some View {
        VStack(alignment: .leading, spacing: 12) {
            HStack {
                Text("Load over time")
                    .font(.subheadline.weight(.semibold))
                Spacer()
                if isLoading {
                    ProgressView().scaleEffect(0.8)
                }
            }

            let hasData = buckets.contains { $0.load > 0 }
            if !hasData {
                Text("No workout data for this period")
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .frame(maxWidth: .infinity, minHeight: 100, alignment: .center)
            } else {
                let maxLoad = max(buckets.map(\.load).max() ?? 1, 1)

                GeometryReader { geo in
                    let w = geo.size.width
                    let h = geo.size.height
                    let count = buckets.count
                    let step = count > 1 ? w / CGFloat(count - 1) : w

                    ZStack {
                        // Area fill
                        Path { path in
                            guard count > 0 else { return }
                            path.move(to: CGPoint(x: 0, y: h))
                            for (i, bucket) in buckets.enumerated() {
                                let x = CGFloat(i) * step
                                let y = h - CGFloat(bucket.load / maxLoad) * h
                                path.addLine(to: CGPoint(x: x, y: y))
                            }
                            path.addLine(to: CGPoint(x: CGFloat(count - 1) * step, y: h))
                            path.closeSubpath()
                        }
                        .fill(
                            LinearGradient(
                                colors: [type.accentColor.opacity(0.25), type.accentColor.opacity(0.0)],
                                startPoint: .top,
                                endPoint: .bottom
                            )
                        )

                        // Line
                        Path { path in
                            guard count > 0 else { return }
                            for (i, bucket) in buckets.enumerated() {
                                let x = CGFloat(i) * step
                                let y = h - CGFloat(bucket.load / maxLoad) * h
                                if i == 0 { path.move(to: CGPoint(x: x, y: y)) }
                                else { path.addLine(to: CGPoint(x: x, y: y)) }
                            }
                        }
                        .stroke(
                            type.accentColor,
                            style: StrokeStyle(lineWidth: 2, lineCap: .round, lineJoin: .round)
                        )

                        // Dots colored by zone
                        ForEach(Array(buckets.enumerated()), id: \.offset) { i, bucket in
                            Circle()
                                .fill(bucket.status.color)
                                .frame(width: 7, height: 7)
                                .position(
                                    x: CGFloat(i) * step,
                                    y: h - CGFloat(bucket.load / maxLoad) * h
                                )
                        }
                    }
                }
                .frame(height: 110)
                .padding(.vertical, 4)

                // X-axis month labels
                let labelStep = max(1, buckets.count / 5)
                HStack(spacing: 0) {
                    ForEach(Array(buckets.enumerated()), id: \.offset) { i, bucket in
                        Group {
                            if i % labelStep == 0 || i == buckets.count - 1 {
                                Text(bucket.label)
                                    .font(.caption2)
                                    .foregroundStyle(.secondary)
                            } else {
                                Color.clear
                            }
                        }
                        .frame(maxWidth: .infinity)
                    }
                }
            }

            // Zone color legend
            HStack(spacing: 16) {
                ForEach([("Detraining", Color.blue), ("Steady", Color.green), ("Overtraining", Color.red)], id: \.0) { label, color in
                    HStack(spacing: 4) {
                        Circle()
                            .fill(color)
                            .frame(width: 7, height: 7)
                        Text(label)
                            .font(.caption2)
                            .foregroundStyle(.secondary)
                    }
                }
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: - Phases Guide

    private var phasesGuide: some View {
        VStack(alignment: .leading, spacing: 14) {
            Text("Phase Definitions")
                .font(.headline.weight(.semibold))

            VStack(spacing: 10) {
                PhaseRow(
                    status: "Detraining",
                    color: .blue,
                    description: "Your recent training is below your baseline. Fitness may gradually decline. Consider increasing training frequency or volume.",
                    acwrRange: "ACWR < 0.8"
                )
                PhaseRow(
                    status: "Steady",
                    color: .green,
                    description: "You're in the optimal training zone. Recent load matches your baseline well — this is where long-term fitness is built.",
                    acwrRange: "ACWR 0.8 – 1.3"
                )
                PhaseRow(
                    status: "Overtraining",
                    color: .red,
                    description: "Recent load significantly exceeds your baseline. Injury risk rises and performance may drop. Prioritize recovery and reduce intensity.",
                    acwrRange: "ACWR > 1.3"
                )
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    // MARK: - Cardio Fitness Section

    private var cardioFitnessSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            HStack {
                Image(systemName: "lungs.fill")
                    .font(.headline)
                    .foregroundStyle(.pink.opacity(0.6))
                Text("Cardio Fitness")
                    .font(.headline.weight(.semibold))
            }
            if let vo2 = vo2Max {
                HStack {
                    VStack(alignment: .leading, spacing: 4) {
                        HStack(alignment: .lastTextBaseline, spacing: 4) {
                            Text(String(format: "%.1f", vo2))
                                .font(.title2.bold().monospacedDigit())
                            Text("ml/kg·min")
                                .font(.caption)
                                .foregroundStyle(.secondary)
                        }
                        Text(vo2MaxCategory(vo2))
                            .font(.caption)
                            .foregroundStyle(vo2MaxColor(vo2))
                    }
                    Spacer()
                }
            } else {
                Text("VO₂ Max not available. Wear Apple Watch during cardio to capture fitness data.")
                    .font(.caption)
                    .foregroundStyle(.secondary)
            }
        }
        .padding(16)
        .glassEffect(in: .rect(cornerRadius: 20))
    }

    private func vo2MaxCategory(_ vo2: Double) -> String {
        if vo2 >= 55 { return "Superior" }
        else if vo2 >= 48 { return "Excellent" }
        else if vo2 >= 42 { return "Good" }
        else if vo2 >= 35 { return "Average" }
        else { return "Below Average" }
    }

    private func vo2MaxColor(_ vo2: Double) -> Color {
        if vo2 >= 48 { return .green }
        else if vo2 >= 35 { return .orange }
        else { return .red }
    }

    // MARK: - Data Sources

    private var dataSourcesSection: some View {
        VStack(alignment: .leading, spacing: 8) {
            Text("Data used")
                .font(.caption.weight(.semibold))
                .foregroundStyle(.secondary)
            VStack(alignment: .leading, spacing: 4) {
                switch type {
                case .training:
                    DataSourceRow(label: "All workouts · Active Energy Burned")
                    DataSourceRow(label: "7-day acute load vs 28-day chronic avg")
                    DataSourceRow(label: "Apple Health workout history")
                case .cardio:
                    DataSourceRow(label: "Cardio workouts (Run, Cycle, Swim, etc.)")
                    DataSourceRow(label: "7-day acute cardio vs 28-day chronic avg")
                    DataSourceRow(label: "VO₂ Max via Apple Watch")
                    DataSourceRow(label: "Apple Health cardio history")
                }
            }
        }
        .padding(16)
        .glassEffect(.regular.tint(.clear), in: .rect(cornerRadius: 16))
    }
}

// MARK: - PhaseRow

private struct PhaseRow: View {
    let status: String
    let color: Color
    let description: String
    let acwrRange: String

    var body: some View {
        HStack(alignment: .top, spacing: 12) {
            RoundedRectangle(cornerRadius: 3)
                .fill(color)
                .frame(width: 4, height: 44)
            VStack(alignment: .leading, spacing: 3) {
                HStack {
                    Text(status)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(color)
                    Spacer()
                    Text(acwrRange)
                        .font(.caption2.monospacedDigit())
                        .foregroundStyle(.tertiary)
                }
                Text(description)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                    .fixedSize(horizontal: false, vertical: true)
            }
        }
    }
}

// MARK: - DataSourceRow

private struct DataSourceRow: View {
    let label: String

    var body: some View {
        HStack(spacing: 6) {
            Image(systemName: "checkmark")
                .font(.caption2)
                .foregroundStyle(.green)
            Text(label)
                .font(.caption)
                .foregroundStyle(.secondary)
        }
    }
}
