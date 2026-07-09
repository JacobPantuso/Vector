import Foundation
import SwiftUI

struct WatchRecoveryScore: Codable {
	let score: Int
	let hrvValue: Double
	let restingHeartRate: Double

	var level: WatchRecoveryLevel {
		if score <= 39 {
			return .poor
		} else if score <= 59 {
			return .good
		} else if score <= 79 {
			return .excellent
		} else {
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
			return .mint
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

	var exertionLevelLabel: String {
		exertionLevel.label
	}

	var exertionLevelColor: Color {
		exertionLevel.color
	}

	private var loadStatus: LoadStatus {
		let ratio = chronicLoad > 0 ? acuteLoad / chronicLoad : 0
		if ratio < 0.8 {
			return .detraining
		} else if ratio <= 1.3 {
			return .optimal
		} else if ratio <= 1.5 {
			return .overreaching
		} else {
			return .overtraining
		}
	}

	private var exertionLevel: ExertionLevel {
		switch score {
		case ..<1:  return .noStrain
		case ..<30: return .low
		case ..<60: return .moderate
		case ..<85: return .high
		default:    return .extreme
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

	enum ExertionLevel {
		case noStrain, low, moderate, high, extreme

		var label: String {
			switch self {
			case .noStrain: return "No strain"
			case .low:      return "Low"
			case .moderate: return "Moderate"
			case .high:     return "High"
			case .extreme:  return "Extreme"
			}
		}

		var color: Color {
			switch self {
			case .noStrain: return .secondary
			case .low:      return Color(hue: 0.12, saturation: 0.85, brightness: 0.95)
			case .moderate: return Color(hue: 0.08, saturation: 0.90, brightness: 0.97)
			case .high:     return Color(hue: 0.04, saturation: 0.92, brightness: 0.95)
			case .extreme:  return Color(hue: 0.0,  saturation: 0.85, brightness: 0.90)
			}
		}
	}
}

struct WatchSleepAnalysis: Codable {
	let totalDuration: TimeInterval
	let remDuration: TimeInterval
	let deepDuration: TimeInterval
	var awakeDuration: TimeInterval = 0
	var respiratoryRate: Double? = nil
	var respiratoryBaseline: Double? = nil
	var qualityScore: Int? = nil   // phone's computed 0–100 score (source of truth)

	/// Time actually asleep (time in bed minus awake).
	var asleepDuration: TimeInterval { max(0, totalDuration - awakeDuration) }

	var efficiency: Double {
		guard totalDuration > 0 else { return 0 }
		return (totalDuration - awakeDuration) / totalDuration
	}

	/// 0...1 — 1 means overnight respiratory rate is at or below baseline; drops as it rises above baseline.
	var respiratoryStability: Double? {
		guard let rr = respiratoryRate, let baseline = respiratoryBaseline, baseline > 0, rr > 0 else { return nil }
		let deviation = (rr - baseline) / baseline
		let stability = 1 - max(0, deviation) * 4
		return max(0, min(1, stability))
	}

	/// Fallback only: a local estimate used when the phone's `qualityScore` hasn't synced yet.
	var quality: Double {
		guard totalDuration > 0 else { return 0 }
		let durationTarget = min(totalDuration / (8 * 3600), 1)
		let efficiencyScore = efficiency
		let stageBalance = min((remDuration + deepDuration) / totalDuration, 1)
		if let stability = respiratoryStability {
			return (durationTarget * 0.40) + (efficiencyScore * 0.30) + (stageBalance * 0.15) + (stability * 0.15)
		}
		return (durationTarget * 0.45) + (efficiencyScore * 0.35) + (stageBalance * 0.20)
	}

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
		quality < 0.45 ? .red : .blue
	}

	var qualityLabel: String {
		if quality < 0.45 {
			return "Poor"
		} else if quality < 0.65 {
			return "Fair"
		} else if quality < 0.82 {
			return "Good"
		} else {
			return "Excellent"
		}
	}
}

struct WatchStressScore: Codable {
	let score: Int

	var level: String {
		if score <= 40 { return "Low" }
		else if score <= 65 { return "Moderate" }
		else { return "High" }
	}

	var color: Color {
		if score <= 65 { return .indigo }
		else { return .red }
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

struct WorkoutExerciseLite: Codable {
	var name: String
	var sets: Int
	var completedSets: Int
	var reps: Int
	var weight: Double
	var inputType: String
	var durationSeconds: Int
	var isSuperset: Bool
}

struct WatchWorkoutState: Codable {
	var status: String
	var title: String
	var exerciseName: String
	var exerciseIndex: Int
	var totalExercises: Int
	var setIndex: Int
	var totalSets: Int
	var restSecondsRemaining: Int
	var elapsedSeconds: Int
	var exercises: [WorkoutExerciseLite] = []
	var currentWeight: Double = 0
	var currentReps: Int = 0
	var isPaused: Bool = false

	var isResting: Bool { status == "resting" }
	var isFinished: Bool { status == "finished" }

	var formattedElapsed: String {
		let m = elapsedSeconds / 60
		let s = elapsedSeconds % 60
		return String(format: "%d:%02d", m, s)
	}

	var setProgressFraction: Double {
		guard totalSets > 0 else { return 0 }
		return Double(setIndex) / Double(totalSets)
	}

	init(from decoder: Decoder) throws {
		let container = try decoder.container(keyedBy: CodingKeys.self)
		status = try container.decode(String.self, forKey: .status)
		title = try container.decode(String.self, forKey: .title)
		exerciseName = try container.decode(String.self, forKey: .exerciseName)
		exerciseIndex = try container.decode(Int.self, forKey: .exerciseIndex)
		totalExercises = try container.decode(Int.self, forKey: .totalExercises)
		setIndex = try container.decode(Int.self, forKey: .setIndex)
		totalSets = try container.decode(Int.self, forKey: .totalSets)
		restSecondsRemaining = try container.decode(Int.self, forKey: .restSecondsRemaining)
		elapsedSeconds = try container.decode(Int.self, forKey: .elapsedSeconds)
		exercises = try container.decodeIfPresent([WorkoutExerciseLite].self, forKey: .exercises) ?? []
		currentWeight = try container.decodeIfPresent(Double.self, forKey: .currentWeight) ?? 0
		currentReps = try container.decodeIfPresent(Int.self, forKey: .currentReps) ?? 0
		isPaused = try container.decodeIfPresent(Bool.self, forKey: .isPaused) ?? false
	}

	enum CodingKeys: String, CodingKey {
		case status
		case title
		case exerciseName
		case exerciseIndex
		case totalExercises
		case setIndex
		case totalSets
		case restSecondsRemaining
		case elapsedSeconds
		case exercises
		case currentWeight
		case currentReps
		case isPaused
	}

	func encode(to encoder: Encoder) throws {
		var container = encoder.container(keyedBy: CodingKeys.self)
		try container.encode(status, forKey: .status)
		try container.encode(title, forKey: .title)
		try container.encode(exerciseName, forKey: .exerciseName)
		try container.encode(exerciseIndex, forKey: .exerciseIndex)
		try container.encode(totalExercises, forKey: .totalExercises)
		try container.encode(setIndex, forKey: .setIndex)
		try container.encode(totalSets, forKey: .totalSets)
		try container.encode(restSecondsRemaining, forKey: .restSecondsRemaining)
		try container.encode(elapsedSeconds, forKey: .elapsedSeconds)
		try container.encode(exercises, forKey: .exercises)
		try container.encode(currentWeight, forKey: .currentWeight)
		try container.encode(currentReps, forKey: .currentReps)
		try container.encode(isPaused, forKey: .isPaused)
	}

	init(
		status: String,
		title: String,
		exerciseName: String,
		exerciseIndex: Int,
		totalExercises: Int,
		setIndex: Int,
		totalSets: Int,
		restSecondsRemaining: Int,
		elapsedSeconds: Int,
		exercises: [WorkoutExerciseLite] = [],
		currentWeight: Double = 0,
		currentReps: Int = 0,
		isPaused: Bool = false
	) {
		self.status = status
		self.title = title
		self.exerciseName = exerciseName
		self.exerciseIndex = exerciseIndex
		self.totalExercises = totalExercises
		self.setIndex = setIndex
		self.totalSets = totalSets
		self.restSecondsRemaining = restSecondsRemaining
		self.elapsedSeconds = elapsedSeconds
		self.exercises = exercises
		self.currentWeight = currentWeight
		self.currentReps = currentReps
		self.isPaused = isPaused
	}
}
