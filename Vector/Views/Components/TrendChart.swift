import SwiftUI
import Charts

struct TrendChart: View {
    let data: [(date: Date, value: Double)]
    let color: Color
    let showAxis: Bool

    init(data: [(date: Date, value: Double)], color: Color = .blue, showAxis: Bool = true) {
        self.data = data
        self.color = color
        self.showAxis = showAxis
    }

    var body: some View {
        Chart(data, id: \.date) { item in
            LineMark(x: .value("Date", item.date), y: .value("Value", item.value))
                .foregroundStyle(color)
                .lineStyle(StrokeStyle(lineWidth: 2.5, lineCap: .round, lineJoin: .round))

            AreaMark(x: .value("Date", item.date), y: .value("Value", item.value))
                .foregroundStyle(
                    LinearGradient(
                        gradient: Gradient(colors: [color.opacity(0.3), color.opacity(0.05)]),
                        startPoint: .top,
                        endPoint: .bottom
                    )
                )
        }
        .chartXAxis(showAxis ? .visible : .hidden)
        .chartYAxis(showAxis ? .visible : .hidden)
        .chartXAxisLabel(position: .bottom) {
            Text("Time").font(.caption)
        }
        .chartYAxisLabel(position: .leading) {
            Text("Value").font(.caption)
        }
    }
}

#Preview {
    let mockData = (0..<7).map { i -> (Date, Double) in
        let date = Date(timeIntervalSinceNow: TimeInterval(-86400 * (6 - i)))
        let value = Double.random(in: 70...90)
        return (date, value)
    }

    TrendChart(data: mockData, color: .cyan)
        .frame(height: 200)
        .padding()
}
