import Foundation

enum ObstacleDirection: String {
    case left = "left"
    case center = "center"
    case right = "right"

    var spatialAngle: Float {
        switch self {
        case .left: return -0.5
        case .center: return 0.0
        case .right: return 0.5
        }
    }
}

struct Obstacle: Identifiable {
    let id = UUID()
    let distance: Float
    let direction: ObstacleDirection
    let zone: DistanceZone
    let timestamp: Date

    init(distance: Float, direction: ObstacleDirection) {
        self.distance = distance
        self.direction = direction
        self.zone = DistanceZone.from(distance: distance)
        self.timestamp = Date()
    }
}

struct DetectionResult {
    let closestObstacle: Obstacle?
    let obstacles: [Obstacle]
    let timestamp: Date

    var overallZone: DistanceZone {
        obstacles.map(\.zone).max() ?? .safe
    }

    static let empty = DetectionResult(closestObstacle: nil, obstacles: [], timestamp: Date())
}
