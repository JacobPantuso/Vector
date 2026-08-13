import SwiftUI

@Observable
final class VitalsLayoutStore {
    private static let orderKey = "vitals.layout.order"
    private static let enabledKey = "vitals.layout.enabled"
    private static let sizesKey = "vitals.layout.sizes"

    var order: [VitalMetric] {
        didSet { persistOrder() }
    }

    var enabled: Set<VitalMetric> {
        didSet { persistEnabled() }
    }

    var sizes: [VitalMetric: VitalCardSize] {
        didSet { persistSizes() }
    }

    var visibleMetrics: [VitalMetric] {
        order.filter { enabled.contains($0) }
    }

    static let shared = VitalsLayoutStore()

    init() {
        // Load from UserDefaults or use defaults
        self.order = Self.loadOrder()
        self.enabled = Self.loadEnabled()
        self.sizes = Self.loadSizes()
    }

    private static func loadOrder() -> [VitalMetric] {
        if let data = UserDefaults.standard.data(forKey: orderKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            var order: [VitalMetric] = []
            for rawValue in decoded {
                if let metric = VitalMetric(rawValue: rawValue) {
                    order.append(metric)
                }
            }
            // Union in any new cases added since last load, appended at the end
            let loadedSet = Set(order)
            for metric in VitalMetric.allCases {
                if !loadedSet.contains(metric) {
                    order.append(metric)
                }
            }
            return order
        }
        return VitalMetric.allCases.map { $0 }
    }

    private static func loadEnabled() -> Set<VitalMetric> {
        if let data = UserDefaults.standard.data(forKey: enabledKey),
           let decoded = try? JSONDecoder().decode([String].self, from: data) {
            var enabled = Set<VitalMetric>()
            for rawValue in decoded {
                if let metric = VitalMetric(rawValue: rawValue) {
                    enabled.insert(metric)
                }
            }
            return enabled
        }
        return Set(VitalMetric.allCases.filter { $0.defaultEnabled })
    }

    private static func loadSizes() -> [VitalMetric: VitalCardSize] {
        if let data = UserDefaults.standard.data(forKey: sizesKey),
           let decoded = try? JSONDecoder().decode([String: String].self, from: data) {
            var sizes: [VitalMetric: VitalCardSize] = [:]
            for (rawValue, sizeString) in decoded {
                if let metric = VitalMetric(rawValue: rawValue),
                   let size = VitalCardSize(rawValue: sizeString) {
                    sizes[metric] = size
                }
            }
            return sizes
        }
        var defaults: [VitalMetric: VitalCardSize] = [:]
        for metric in VitalMetric.allCases {
            defaults[metric] = metric.defaultSize
        }
        return defaults
    }

    private func persistOrder() {
        let rawValues = order.map { $0.rawValue }
        if let encoded = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(encoded, forKey: Self.orderKey)
        }
    }

    private func persistEnabled() {
        let rawValues = enabled.map { $0.rawValue }.sorted()
        if let encoded = try? JSONEncoder().encode(rawValues) {
            UserDefaults.standard.set(encoded, forKey: Self.enabledKey)
        }
    }

    private func persistSizes() {
        let dict = sizes.reduce(into: [String: String]()) { acc, pair in
            acc[pair.key.rawValue] = pair.value.rawValue
        }
        if let encoded = try? JSONEncoder().encode(dict) {
            UserDefaults.standard.set(encoded, forKey: Self.sizesKey)
        }
    }

    func toggle(_ metric: VitalMetric) {
        if enabled.contains(metric) {
            enabled.remove(metric)
        } else {
            enabled.insert(metric)
        }
    }

    func move(fromOffsets: IndexSet, toOffset: Int) {
        order.move(fromOffsets: fromOffsets, toOffset: toOffset)
    }

    func setSize(_ size: VitalCardSize, for metric: VitalMetric) {
        sizes[metric] = size
    }

    func resetToDefaults() {
        order = VitalMetric.allCases.map { $0 }
        enabled = Set(VitalMetric.allCases.filter { $0.defaultEnabled })
        sizes = VitalMetric.allCases.reduce(into: [:]) { acc, metric in
            acc[metric] = metric.defaultSize
        }
    }
}
