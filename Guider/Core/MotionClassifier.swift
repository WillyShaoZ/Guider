import ARKit

enum UserMotionState {
    case stationary
    case walking
}

final class MotionClassifier {
    private var positionHistory: [(position: simd_float3, time: TimeInterval)] = []
    private let windowDuration: TimeInterval = 1.0
    private let walkingThreshold: Float = 0.15  // 15cm displacement = walking

    func classify(frame: ARFrame) -> UserMotionState {
        let position = simd_float3(
            frame.camera.transform.columns.3.x,
            frame.camera.transform.columns.3.y,
            frame.camera.transform.columns.3.z
        )
        let time = frame.timestamp

        positionHistory.append((position: position, time: time))
        positionHistory.removeAll { time - $0.time > windowDuration }

        guard let oldest = positionHistory.first else { return .stationary }

        let displacement = simd_distance(position, oldest.position)
        return displacement > walkingThreshold ? .walking : .stationary
    }

    func reset() {
        positionHistory.removeAll()
    }
}
