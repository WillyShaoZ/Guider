import XCTest
@testable import Guider

final class DistanceZoneTests: XCTestCase {

    // MARK: - Basic Zone Classification

    func testDangerZone() {
        XCTAssertEqual(DistanceZone.from(distance: 0.0), .danger)
        XCTAssertEqual(DistanceZone.from(distance: 0.3), .danger)
        XCTAssertEqual(DistanceZone.from(distance: 0.49), .danger)
    }

    func testWarningZone() {
        XCTAssertEqual(DistanceZone.from(distance: 0.5), .warning)
        XCTAssertEqual(DistanceZone.from(distance: 0.75), .warning)
        XCTAssertEqual(DistanceZone.from(distance: 0.99), .warning)
    }

    func testCautionZone() {
        XCTAssertEqual(DistanceZone.from(distance: 1.0), .caution)
        XCTAssertEqual(DistanceZone.from(distance: 1.5), .caution)
        XCTAssertEqual(DistanceZone.from(distance: 1.99), .caution)
    }

    func testSafeZone() {
        XCTAssertEqual(DistanceZone.from(distance: 2.0), .safe)
        XCTAssertEqual(DistanceZone.from(distance: 5.0), .safe)
        XCTAssertEqual(DistanceZone.from(distance: 100.0), .safe)
    }

    // MARK: - Sensitivity Scaling

    func testSensitivity2x_doublesEffectiveRange() {
        // At 2.0x sensitivity, danger threshold moves from 0.5m to 1.0m
        XCTAssertEqual(DistanceZone.from(distance: 0.9, sensitivity: 2.0), .danger)
        // Warning at 1.5m (normally caution)
        XCTAssertEqual(DistanceZone.from(distance: 1.5, sensitivity: 2.0), .warning)
        // Caution at 3.0m (normally safe)
        XCTAssertEqual(DistanceZone.from(distance: 3.0, sensitivity: 2.0), .caution)
    }

    func testSensitivity0_5x_halvesEffectiveRange() {
        // At 0.5x, danger only at < 0.25m
        XCTAssertEqual(DistanceZone.from(distance: 0.3, sensitivity: 0.5), .warning)
        // 0.6m is now caution instead of warning
        XCTAssertEqual(DistanceZone.from(distance: 0.6, sensitivity: 0.5), .caution)
        // 1.5m is safe
        XCTAssertEqual(DistanceZone.from(distance: 1.5, sensitivity: 0.5), .safe)
    }

    func testDefaultSensitivityMatchesNoSensitivity() {
        for distance: Float in [0.1, 0.5, 1.0, 2.0, 5.0] {
            XCTAssertEqual(
                DistanceZone.from(distance: distance),
                DistanceZone.from(distance: distance, sensitivity: 1.0)
            )
        }
    }

    // MARK: - Comparable Ordering

    func testZoneOrdering() {
        XCTAssertTrue(DistanceZone.safe < .caution)
        XCTAssertTrue(DistanceZone.caution < .warning)
        XCTAssertTrue(DistanceZone.warning < .danger)
    }

    // MARK: - DetectionResult.overallZone

    func testOverallZoneReturnsWorst() {
        let obstacles = [
            Obstacle(distance: 3.0, direction: .left),   // safe
            Obstacle(distance: 0.3, direction: .center),  // danger
            Obstacle(distance: 1.5, direction: .right)    // caution
        ]
        let result = DetectionResult(closestObstacle: obstacles[1], obstacles: obstacles, stairDetection: nil, timestamp: Date())
        XCTAssertEqual(result.overallZone, .danger)
    }

    func testEmptyDetectionResultIsSafe() {
        XCTAssertEqual(DetectionResult.empty.overallZone, .safe)
    }
}
