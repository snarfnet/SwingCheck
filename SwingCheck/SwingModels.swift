import Foundation
import Vision
import SwiftUI

// MARK: - Body Pose

struct BodyPose: Equatable {
    var joints: [VNHumanBodyPoseObservation.JointName: CGPoint] = [:]
    func point(_ name: VNHumanBodyPoseObservation.JointName) -> CGPoint? { joints[name] }
}

// MARK: - Swing Phase

enum SwingPhase: String {
    case ready  = "READY"
    case load   = "LOAD"
    case swing  = "SWING"
    case follow = "FOLLOW"

    var displayName: String {
        switch self {
        case .ready:  return String(localized: "Ready")
        case .load:   return String(localized: "Load")
        case .swing:  return String(localized: "Swing!")
        case .follow: return String(localized: "Follow Through")
        }
    }

    var color: Color {
        switch self {
        case .ready:  return .white
        case .load:   return .yellow
        case .swing:  return .green
        case .follow: return .cyan
        }
    }
}

// MARK: - Pitch

enum PitchType: String, CaseIterable, Identifiable {
    case straight = "straight"
    case curve    = "curve"
    case slider   = "slider"
    var id: String { rawValue }

    var displayName: String {
        switch self {
        case .straight: return String(localized: "Straight")
        case .curve:    return String(localized: "Curve")
        case .slider:   return String(localized: "Slider")
        }
    }
}

enum PitchSpeed: String, CaseIterable, Identifiable {
    case slow   = "slow"
    case medium = "medium"
    case fast   = "fast"
    var id: String { rawValue }

    var duration: Double {
        switch self {
        case .slow:   return 2.6
        case .medium: return 1.8
        case .fast:   return 1.1
        }
    }

    var displayName: String {
        switch self {
        case .slow:   return String(localized: "Slow")
        case .medium: return String(localized: "Medium")
        case .fast:   return String(localized: "Fast")
        }
    }
}

// MARK: - Timing

enum TimingResult {
    case perfect, good, fair, miss, noSwing

    var label: String {
        switch self {
        case .perfect: return "PERFECT!"
        case .good:    return "GOOD"
        case .fair:    return "FAIR"
        case .miss:    return "MISS"
        case .noSwing: return String(localized: "NO SWING")
        }
    }

    var color: Color {
        switch self {
        case .perfect: return .yellow
        case .good:    return .green
        case .fair:    return .orange
        case .miss:    return .red
        case .noSwing: return .gray
        }
    }
}

// MARK: - Form Score

struct FormScore {
    var stance: Double = 0
    var hipRotation: Double = 0
    var headStability: Double = 0
    var followThrough: Double = 0

    var overall: Double {
        (stance + hipRotation + headStability + followThrough) / 4
    }

    var grade: String {
        switch overall {
        case 80...: return "S"
        case 65...: return "A"
        case 50...: return "B"
        case 35...: return "C"
        default:    return "D"
        }
    }
}

// MARK: - Session

struct SwingSession {
    var totalPitches: Int = 0
    var swings: Int = 0
    var timingResults: [TimingResult] = []
    var timingErrors: [Double] = []
    var formScore: FormScore = FormScore()

    var hitCount: Int {
        timingResults.filter {
            switch $0 { case .miss, .noSwing: false; default: true }
        }.count
    }
    var hitRate: Double { swings > 0 ? Double(hitCount) / Double(swings) * 100 : 0 }
    var avgTimingError: Double { timingErrors.isEmpty ? 0 : timingErrors.reduce(0,+) / Double(timingErrors.count) }
}
