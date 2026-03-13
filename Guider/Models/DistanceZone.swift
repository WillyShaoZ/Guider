import Foundation

enum DistanceZone: Int, CaseIterable, Comparable {
    case safe = 0
    case caution = 1
    case warning = 2
    case danger = 3

    var label: String {
        switch self {
        case .safe: return "Safe"
        case .caution: return "Caution"
        case .warning: return "Warning"
        case .danger: return "Danger"
        }
    }

    var maxDistance: Float {
        switch self {
        case .safe: return .infinity
        case .caution: return 2.0
        case .warning: return 1.0
        case .danger: return 0.5
        }
    }

    var minDistance: Float {
        switch self {
        case .safe: return 2.0
        case .caution: return 1.0
        case .warning: return 0.5
        case .danger: return 0.0
        }
    }

    static let maxDetectionRange: Float = 5.0

    static func from(distance: Float) -> DistanceZone {
        return from(distance: distance, sensitivity: 1.0)
    }

    static func from(distance: Float, sensitivity: Float) -> DistanceZone {
        let adjusted = distance / sensitivity
        if adjusted < 0.5 { return .danger }
        if adjusted < 1.0 { return .warning }
        if adjusted < 2.0 { return .caution }
        return .safe
    }

    static func < (lhs: DistanceZone, rhs: DistanceZone) -> Bool {
        lhs.rawValue < rhs.rawValue
    }
}
