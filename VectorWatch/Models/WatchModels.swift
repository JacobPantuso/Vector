import Foundation
import SwiftUI

struct WatchRecoveryScore: Codable {
	let score: Int
	let hrvValue: Double
	let restingHeartRate: Double

	var level: WatchRecoveryLevel {
		switch score {
		case 0...25:
			return .poor
		case 26...50:
			return .good
		case 51...80:
			return .excellent
		default:
			return .superior
		}
	}
}

enum WatchRecoveryLevel: String {
	case poor
	case good
	case excellent
	case superior

	var color: Color {
		switch self {
		case .poor:
			return .red
		case .good:
			return .yellow
		case .excellent:
			return .green
		case .superior:
			return .cyan
		}
	}

	var label: String {
		rawValue.capitalized
	}

	var systemImage: String {
		switch self {
		case .poor:
			return "bolt.slash.fill"
		case .good:
			return "bolt.fill"
		case .excellent:
			return "bolt.and.battery.full.fill"
		case .superior:
			return "zap.fill"
		}
	}
}

struct WatchExertionScore: Codable {
	let score: Int
	let todayStrain: Double
	let acuteLoad: Double
	let chronicLoad: Double

	var loadStatusLabel: String {
		loadStatus.label
	}

	var loadStatusColor: Color {
		loadStatus.color
	}

	private var loadStatus: LoadStatus {
		let ratio = chronicLoad > 0 ? acuteLoad / chronicLoad : 0
		switch ratio {
		case 0..<0.5:
			return .detraining
		case 0.5..<1.5:
			return .optimal
		case 1.5..<2.0:
			return .overreaching
		default:
			return .overtraining
		}
	}

	enum LoadStatus {
		case detraining
		case optimal
		case overreaching
		case overtraining

		var label: String {
			switch self {
			case .detraining:
				return "Detraining"
			case .optimal:
				return "Optimal"
			case .overreaching:
				return "Overreaching"
			case .overtraining:
				return "Overtraining"
			}
		}

		var color: Color {
			switch self {
			case .detraining:
				return .blue
			case .optimal:
				return .green
			case .overreaching:
				return .orange
			case .overtraining:
				return .red
			}
		}
	}
}

struct WatchSleepAnalysis: Codable {
	let totalDuration: TimeInterval
	let remDuration: TimeInterval
	let deepDuration: TimeInterval
	let quality: Double

	var formattedDuration: String {
		let hours = Int(totalDuration) / 3600
		let minutes = (Int(totalDuration) % 3600) / 60
		if hours > 0 {
			return "\(hours)h \(minutes)m"
		} else {
			return "\(minutes)m"
		}
	}

	var qualityColor: Color {
		switch quality {
		case 0..<0.4:
			return .red
		case 0.4..<0.7:
			return .orange
		case 0.7..<0.85:
			return .yellow
		default:
			return .green
		}
	}

	var qualityLabel: String {
		switch quality {
		case 0..<0.4:
			return "Poor"
		case 0.4..<0.7:
			return "Fair"
		case 0.7..<0.85:
			return "Good"
		default:
			return "Excellent"
		}
	}
}

enum WatchTheme {
	case recovery
	case exertion
	case sleep
	case vitals
	case nutrition
	case accent

	var color: Color {
		switch self {
		case .recovery:
			return .green
		case .exertion:
			return .orange
		case .sleep:
			return .blue
		case .vitals:
			return .purple
		case .nutrition:
			return .pink
		case .accent:
			return .cyan
		}
	}
}
