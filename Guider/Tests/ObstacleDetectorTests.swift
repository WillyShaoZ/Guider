import XCTest
@testable import Guider

final class ObstacleDetectorTests: XCTestCase {

    // MARK: - Obstacle Zone Assignment

    func testObstacleZoneWithDefaultSensitivity() {
        let obstacle = Obstacle(distance: 0.3, direction: .center)
        XCTAssertEqual(obstacle.zone, .danger)

        let obstacle2 = Obstacle(distance: 1.5, direction: .left)
        XCTAssertEqual(obstacle2.zone, .caution)
    }

    func testObstacleZoneWithHighSensitivity() {
        // At 2.0x sensitivity, 0.9m should be danger (adjusted = 0.45m < 0.5)
        let obstacle = Obstacle(distance: 0.9, direction: .center, sensitivity: 2.0)
        XCTAssertEqual(obstacle.zone, .danger)
    }

    func testObstacleZoneWithLowSensitivity() {
        // At 0.5x, 0.3m should be warning (adjusted = 0.6m, 0.5 <= 0.6 < 1.0)
        let obstacle = Obstacle(distance: 0.3, direction: .center, sensitivity: 0.5)
        XCTAssertEqual(obstacle.zone, .warning)
    }

    // MARK: - DetectionResult

    func testEmptyDetectionResultIsSafe() {
        let result = DetectionResult.empty
        XCTAssertEqual(result.overallZone, .safe)
        XCTAssertNil(result.closestObstacle)
        XCTAssertTrue(result.obstacles.isEmpty)
        XCTAssertNil(result.stairDetection)
    }

    func testDetectionResultWithStairDetection() {
        let stairResult = StairDetectionResult(isDetected: true, confidence: 0.8, distance: 2.0)
        let result = DetectionResult(
            closestObstacle: nil,
            obstacles: [],
            stairDetection: stairResult,
            timestamp: Date()
        )
        XCTAssertNotNil(result.stairDetection)
        XCTAssertTrue(result.stairDetection!.isDetected)
    }
}
