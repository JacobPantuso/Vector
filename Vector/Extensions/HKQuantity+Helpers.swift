import HealthKit

extension HKQuantity {
    var bpm: Double {
        doubleValue(for: HKUnit.count().unitDivided(by: HKUnit.minute()))
    }

    var ms: Double {
        doubleValue(for: HKUnit.secondUnit(with: .milli))
    }

    var kcal: Double {
        doubleValue(for: HKUnit.kilocalorie())
    }

    var count: Double {
        doubleValue(for: HKUnit.count())
    }

    var percentage: Double {
        doubleValue(for: HKUnit.percent())
    }
}
