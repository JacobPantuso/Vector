import SwiftUI
import HealthKit

struct HistoricalDataSheet: View {
    @Binding var selectedDate: Date
    @Environment(HealthKitService.self) var service
    @Environment(\.dismiss) private var dismiss

    @State private var sleep: SleepAnalysis?
    @State private var steps: Double = 0
    @State private var activeCalories: Double = 0
    @State private var isLoading = false
    @State private var displayedMonth: Date = Date()

    var body: some View {
        ScrollView {
            VStack(alignment: .leading, spacing: 16) {
                header
                calendarCard
                scoresTiles
                detailsSection
            }
            .padding(.horizontal, 20)
            .padding(.top, 20)
            .padding(.bottom, 32)
        }
        .scrollIndicators(.hidden)
        .gradientHeader(height: 320)
        .presentationDetents([.large])
        .presentationDragIndicator(.visible)
        .presentationCornerRadius(32)
        .task(id: selectedDate) {
            displayedMonth = startOfMonth(for: selectedDate)
            await fetchData(for: selectedDate)
        }
        .onAppear {
            displayedMonth = startOfMonth(for: selectedDate)
        }
    }

    // MARK: - Header

    private var header: some View {
        HStack(spacing: 14) {
            ZStack {
                Circle()
                    .fill(LinearGradient(
                        colors: [.indigo.opacity(0.28), .cyan.opacity(0.12)],
                        startPoint: .topLeading,
                        endPoint: .bottomTrailing
                    ))
                    .frame(width: 52, height: 52)
                Image(systemName: "calendar")
                    .font(.title3.weight(.semibold))
                    .foregroundStyle(VectorTheme.brandForeground)
            }

            VStack(alignment: .leading, spacing: 5) {
                Text("History")
                    .font(.title3.bold())
                Text(selectedDate.formatted(.dateTime.weekday(.wide).month(.abbreviated).day()))
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.cyan)
                    .padding(.horizontal, 8)
                    .padding(.vertical, 4)
                    .background(Color.cyan.opacity(0.14), in: Capsule())
            }

            Spacer()

            Button { dismiss() } label: {
                Image(systemName: "xmark")
                    .font(.footnote.weight(.bold))
                    .foregroundStyle(.secondary)
                    .frame(width: 30, height: 30)
                    .background(Color.secondary.opacity(0.15), in: Circle())
            }
            .buttonStyle(.plain)
        }
    }

    // MARK: - Calendar Card

    private var calendarCard: some View {
        VStack(alignment: .leading, spacing: 12) {
            // Month/Year header with chevrons
            HStack {
                Text(displayedMonth.formatted(.dateTime.month(.wide).year()))
                    .font(.headline)
                Spacer()
                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: -1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.left")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)

                Button {
                    withAnimation(.snappy(duration: 0.25)) {
                        displayedMonth = Calendar.current.date(byAdding: .month, value: 1, to: displayedMonth) ?? displayedMonth
                    }
                } label: {
                    Image(systemName: "chevron.right")
                        .font(.footnote.weight(.bold))
                        .foregroundStyle(.primary)
                        .frame(width: 30, height: 30)
                        .background(Color.secondary.opacity(0.15), in: Circle())
                }
                .buttonStyle(.plain)
                .disabled(isCurrentMonth(displayedMonth))
                .opacity(isCurrentMonth(displayedMonth) ? 0.35 : 1)
            }

            // Weekday headers
            HStack(spacing: 0) {
                ForEach(weekdaySymbols, id: \.self) { symbol in
                    Text(symbol)
                        .font(.caption2.weight(.semibold))
                        .foregroundStyle(.tertiary)
                        .frame(maxWidth: .infinity)
                }
            }

            // Day grid
            LazyVGrid(columns: Array(repeating: GridItem(.flexible(), spacing: 4), count: 7), spacing: 8) {
                ForEach(dayGridItems) { item in
                    dayCell(for: item)
                }
            }
            .frame(maxWidth: .infinity)
        }
        .padding(16)
        .glassEffect(.regular, in: .rect(cornerRadius: 24))
        .gesture(
            DragGesture(minimumDistance: 20)
                .onEnded { value in
                    guard abs(value.translation.width) > 50,
                          abs(value.translation.width) > abs(value.translation.height) else { return }
                    let step = value.translation.width > 0 ? -1 : 1
                    if step == 1 && isCurrentMonth(displayedMonth) { return }
                    withAnimation(.snappy(duration: 0.25)) {
                        displayedMonth = calendar.date(byAdding: .month, value: step, to: displayedMonth) ?? displayedMonth
                    }
                }
        )
    }

    // MARK: - Day Grid Helpers

    private var dayGridItems: [DayGridItem] {
        let calendar = Calendar.current
        let monthStart = startOfMonth(for: displayedMonth)
        guard let monthEnd = calendar.date(byAdding: DateComponents(month: 1, day: -1), to: monthStart) else { return [] }

        let firstWeekday = calendar.component(.weekday, from: monthStart)
        let offset = firstWeekday - calendar.firstWeekday
        let leadingBlanks = offset >= 0 ? offset : offset + 7

        let daysInMonth = calendar.component(.day, from: monthEnd)

        var items: [DayGridItem] = []

        // Leading blanks
        for i in 0..<leadingBlanks {
            items.append(DayGridItem(id: i, date: nil, dayNumber: 0, isBlank: true))
        }

        // Days of month
        for day in 1...daysInMonth {
            if let date = calendar.date(byAdding: .day, value: day - 1, to: monthStart) {
                items.append(DayGridItem(id: items.count, date: date, dayNumber: day, isBlank: false))
            }
        }

        return items
    }

    private func dayCell(for item: DayGridItem) -> some View {
        let date = item.date
        let isToday = date.map { calendar.isDateInToday($0) } ?? false
        let score = date.flatMap { d in
            if let s = ScoreHistoryStore.score(for: .recovery, on: d) { return s }
            if isToday { return resolvedScore(.recovery) }
            return nil
        }
        let isSelected = date.map { calendar.isDate($0, inSameDayAs: selectedDate) } ?? false
        let isFuture = date.map { $0 > Date() } ?? false

        return VStack(spacing: 3) {
            ZStack {
                if isSelected {
                    Circle().fill(VectorTheme.brandForeground)
                } else if isToday {
                    Circle().strokeBorder(Color.cyan.opacity(0.7), lineWidth: 1.5)
                }
                if !item.isBlank {
                    Text("\(item.dayNumber)")
                        .font(.subheadline.weight(isSelected ? .bold : (isToday ? .semibold : .regular)))
                        .monospacedDigit()
                        .foregroundStyle(dayNumberStyle(isSelected: isSelected, hasScore: score != nil, isFuture: isFuture))
                }
            }
            .frame(width: 32, height: 32)

            Circle()
                .fill(score.map(heatColor) ?? .clear)
                .frame(width: 5, height: 5)
                .opacity(isSelected ? 0 : 1)
        }
        .frame(maxWidth: .infinity)
        .contentShape(Rectangle())
        .onTapGesture {
            guard let date, !isFuture else { return }
            withAnimation(.snappy(duration: 0.25)) { selectedDate = date }
            UIImpactFeedbackGenerator(style: .light).impactOccurred()
        }
    }

    private func dayNumberStyle(isSelected: Bool, hasScore: Bool, isFuture: Bool) -> AnyShapeStyle {
        if isSelected { return AnyShapeStyle(Color.white) }
        if isFuture { return AnyShapeStyle(.quaternary) }
        return hasScore ? AnyShapeStyle(.primary) : AnyShapeStyle(.tertiary)
    }

    // MARK: - Score Tiles

    private var scoresTiles: some View {
        let recovery = resolvedScore(.recovery)
        let stress = resolvedScore(.stress)
        let exertion = resolvedScore(.exertion)
        let sleepScore = sleep.map { Int($0.quality * 100) } ?? resolvedScore(.sleep)

        return LazyVGrid(columns: [GridItem(.flexible()), GridItem(.flexible())], spacing: 12) {
            scoreTile("Recovery", recovery, "heart.fill", .green)
            scoreTile("Sleep", sleepScore, "moon.fill", .blue)
            scoreTile("Exertion", exertion, "flame.fill", .orange)
            scoreTile("Stress", stress, "waveform.path.ecg", .indigo)
        }
    }

    private func scoreTile(_ label: String, _ score: Int?, _ icon: String, _ tint: Color) -> some View {
        HStack(spacing: 12) {
            MetricRing(
                progress: Double(score ?? 0) / 100,
                lineWidth: 4,
                gradient: LinearGradient(
                    colors: [tint.opacity(0.7), tint],
                    startPoint: .topLeading,
                    endPoint: .bottomTrailing
                ),
                size: 34
            ) {
                Image(systemName: icon)
                    .font(.system(size: 12, weight: .bold))
                    .foregroundStyle(tint)
            }

            VStack(alignment: .leading, spacing: 2) {
                Text(label)
                    .font(.caption)
                    .foregroundStyle(.secondary)
                Text(score.map(String.init) ?? "—")
                    .font(.title3.bold().monospacedDigit())
                    .foregroundStyle(score != nil ? .primary : .secondary)
            }

            Spacer()
        }
        .padding(14)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Details Section

    @ViewBuilder
    private var detailsSection: some View {
        VStack(alignment: .leading, spacing: 10) {
            if !hasNoData {
                Text("Details")
                    .font(.caption.weight(.semibold))
                    .foregroundStyle(.secondary)
                    .textCase(.uppercase)
            }

            if isLoading {
                detailsCard()
                    .redacted(reason: .placeholder)
            } else if hasNoData {
                emptyState
            } else {
                detailsCard()
            }
        }
    }

    private var hasNoData: Bool {
        sleep == nil && steps == 0 && activeCalories == 0
        && resolvedScore(.recovery) == nil
        && resolvedScore(.exertion) == nil
        && resolvedScore(.stress) == nil
        && resolvedScore(.sleep) == nil
        && WorkoutCompletionStore.shared.records.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }.isEmpty
    }

    private func detailsCard() -> some View {
        VStack(alignment: .leading, spacing: 0) {
            if let sleep = sleep {
                detailRow(
                    icon: "moon.fill",
                    label: "Sleep",
                    value: sleep.formattedDuration,
                    statusText: sleep.qualityLevel.label,
                    statusColor: sleep.qualityLevel.color,
                    tint: .blue
                )
                Divider().padding(.leading, 56)
            }

            detailRow(
                icon: "figure.walk",
                label: "Steps",
                value: steps > 0 ? steps.formatted(.number.precision(.fractionLength(0))) : "No data",
                tint: .green
            )
            Divider().padding(.leading, 56)

            detailRow(
                icon: "flame.fill",
                label: "Active Energy",
                value: activeCalories > 0 ? String(format: "%.0f kcal", activeCalories) : "No data",
                tint: .orange
            )

            let workouts = WorkoutCompletionStore.shared.records.filter { calendar.isDate($0.date, inSameDayAs: selectedDate) }
            if !workouts.isEmpty {
                Divider().padding(.leading, 56)
                ForEach(Array(workouts.enumerated()), id: \.element.id) { index, record in
                    detailRow(
                        icon: "dumbbell.fill",
                        label: record.title ?? "Workout",
                        value: "\(record.durationMinutes) min",
                        tint: .purple
                    )
                    if index < workouts.count - 1 {
                        Divider().padding(.leading, 56)
                    }
                }
            }
        }
        .padding(.horizontal, 16)
        .padding(.vertical, 12)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    private func detailRow(
        icon: String,
        label: String,
        value: String,
        statusText: String? = nil,
        statusColor: Color? = nil,
        tint: Color
    ) -> some View {
        HStack(spacing: 12) {
            RoundedRectangle(cornerRadius: 9, style: .continuous)
                .fill(tint.opacity(0.16))
                .frame(width: 32, height: 32)
                .overlay(
                    Image(systemName: icon)
                        .font(.footnote.weight(.semibold))
                        .foregroundStyle(tint)
                )

            Text(label)
                .font(.subheadline)

            Spacer()

            VStack(alignment: .trailing, spacing: 2) {
                Text(value)
                    .font(.subheadline.weight(.semibold).monospacedDigit())
                if let statusText = statusText, let statusColor = statusColor {
                    Text(statusText)
                        .font(.caption.weight(.semibold))
                        .foregroundStyle(statusColor)
                }
            }
        }
        .padding(.vertical, 12)
    }

    private var emptyState: some View {
        VStack(spacing: 12) {
            Image(systemName: "calendar.badge.exclamationmark")
                .font(.largeTitle)
                .foregroundStyle(.tertiary)
            Text("No data for this day")
                .font(.subheadline.weight(.semibold))
            Text("Vector had nothing to record on this date.")
                .font(.caption)
                .foregroundStyle(.secondary)
        }
        .frame(maxWidth: .infinity)
        .padding(.vertical, 28)
        .glassEffect(.regular, in: .rect(cornerRadius: 20))
    }

    // MARK: - Helpers

    private var isSelectedDateToday: Bool {
        calendar.isDateInToday(selectedDate)
    }

    /// Archived score for the selected day, falling back to today's live score
    /// so the sheet isn't blank before the day has been written to history.
    private func resolvedScore(_ metric: ScoreHistoryStore.Metric) -> Int? {
        if let stored = ScoreHistoryStore.score(for: metric, on: selectedDate) { return stored }
        guard isSelectedDateToday else { return nil }
        switch metric {
        case .recovery: return service.recoveryScore.map { $0.score }
        case .exertion: return service.exertionScore.map { $0.score }
        case .stress:   return service.stressScore.map { $0.score }
        case .sleep:    return service.sleepAnalysis.map { Int($0.quality * 100) }
        default:        return nil
        }
    }

    /// First instant of the month containing `date`.
    private func startOfMonth(for date: Date) -> Date {
        calendar.date(from: calendar.dateComponents([.year, .month], from: date)) ?? date
    }

    private func heatColor(_ s: Int) -> Color {
        switch s {
        case ..<50: return .red
        case ..<70: return .orange
        case ..<85: return .green
        default:    return .mint
        }
    }

    private var calendar: Calendar { Calendar.current }

    private var weekdaySymbols: [String] {
        let symbols = Calendar.current.veryShortWeekdaySymbols
        let firstWeekday = Calendar.current.firstWeekday - 1
        return Array(symbols.dropFirst(firstWeekday)) + Array(symbols.prefix(firstWeekday))
    }

    private func isCurrentMonth(_ date: Date) -> Bool {
        calendar.dateComponents([.year, .month], from: date) == calendar.dateComponents([.year, .month], from: Date())
    }

    private func fetchData(for date: Date) async {
        isLoading = true
        defer { isLoading = false }
        async let sleepResult = service.fetchSleepAnalysis(for: date)
        async let stepsResult = service.fetchStatistic(for: .stepCount, unit: .count(), on: date)
        async let caloriesResult = service.fetchStatistic(for: .activeEnergyBurned, unit: .kilocalorie(), on: date)
        let (s, st, ac) = await (sleepResult, stepsResult, caloriesResult)
        sleep = s
        steps = st
        activeCalories = ac
    }
}

// MARK: - Day Grid Item

private struct DayGridItem: Identifiable {
    let id: Int
    let date: Date?
    let dayNumber: Int
    let isBlank: Bool
}

// MARK: - Preview

#Preview {
    @Previewable @State var selectedDate = Date()

    HistoricalDataSheet(selectedDate: $selectedDate)
        .environment(HealthKitService())
}
