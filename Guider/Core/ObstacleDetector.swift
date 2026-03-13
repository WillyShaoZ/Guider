import ARKit
import Combine

final class ObstacleDetector: ObservableObject {
    private let depthProcessor = DepthProcessor()
    private var cancellables = Set<AnyCancellable>()

    // Rolling average for temporal smoothing (5 frames)
    private var distanceHistory: [ObstacleDirection: [Float]] = [
        .left: [],
        .center: [],
        .right: []
    ]
    private let smoothingWindow = 5

    let detectionSubject = PassthroughSubject<DetectionResult, Never>()

    func bind(to lidarManager: LiDARSessionManager) {
        lidarManager.depthSubject
            .receive(on: DispatchQueue.global(qos: .userInteractive))
            .map { [weak self] depthData -> DetectionResult in
                self?.detect(depthData: depthData) ?? .empty
            }
            .receive(on: DispatchQueue.main)
            .sink { [weak self] result in
                self?.detectionSubject.send(result)
            }
            .store(in: &cancellables)
    }

    private func detect(depthData: ARDepthData) -> DetectionResult {
        let cells = depthProcessor.process(depthData: depthData)
        let perDirection = depthProcessor.closestPerDirection(cells: cells)

        // Apply temporal smoothing
        let smoothed = smooth(distances: perDirection)

        // Build obstacles from smoothed distances
        var obstacles: [Obstacle] = []
        for (direction, distance) in smoothed {
            if distance < 5.0 { // Only report obstacles within 5m
                obstacles.append(Obstacle(distance: distance, direction: direction))
            }
        }

        let closest = obstacles.min(by: { $0.distance < $1.distance })

        return DetectionResult(
            closestObstacle: closest,
            obstacles: obstacles,
            timestamp: Date()
        )
    }

    private func smooth(distances: [ObstacleDirection: Float]) -> [ObstacleDirection: Float] {
        var result: [ObstacleDirection: Float] = [:]

        for (direction, distance) in distances {
            var history = distanceHistory[direction] ?? []
            history.append(distance)
            if history.count > smoothingWindow {
                history.removeFirst()
            }
            distanceHistory[direction] = history

            // Use median for robustness against outliers
            let sorted = history.sorted()
            let median = sorted[sorted.count / 2]
            result[direction] = median
        }

        return result
    }

    func reset() {
        distanceHistory = [
            .left: [],
            .center: [],
            .right: []
        ]
    }
}
