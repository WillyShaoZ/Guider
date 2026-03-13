import XCTest
@testable import Guider

final class DepthProcessorTests: XCTestCase {

    // MARK: - closestPerDirection

    func testSkipsBottomRowByDefault() {
        let cells = [
            DepthGridCell(direction: .center, row: 0, minDistance: 3.0),
            DepthGridCell(direction: .center, row: 1, minDistance: 2.0),
            DepthGridCell(direction: .center, row: 2, minDistance: 0.5)  // ground — should be skipped
        ]

        let processor = DepthProcessor()
        let result = processor.closestPerDirection(cells: cells)

        XCTAssertEqual(result[.center], 2.0)
    }

    func testReturnsMinDistancePerDirection() {
        let cells = [
            DepthGridCell(direction: .left, row: 0, minDistance: 3.0),
            DepthGridCell(direction: .left, row: 1, minDistance: 1.5),
            DepthGridCell(direction: .center, row: 0, minDistance: 2.0),
            DepthGridCell(direction: .center, row: 1, minDistance: 0.8),
            DepthGridCell(direction: .right, row: 0, minDistance: 4.0),
            DepthGridCell(direction: .right, row: 1, minDistance: 2.5),
        ]

        let processor = DepthProcessor()
        let result = processor.closestPerDirection(cells: cells)

        XCTAssertEqual(result[.left], 1.5)
        XCTAssertEqual(result[.center], 0.8)
        XCTAssertEqual(result[.right], 2.5)
    }

    func testAllInfinityWhenNoObstacles() {
        let cells = [
            DepthGridCell(direction: .left, row: 0, minDistance: .infinity),
            DepthGridCell(direction: .left, row: 1, minDistance: .infinity),
            DepthGridCell(direction: .center, row: 0, minDistance: .infinity),
            DepthGridCell(direction: .center, row: 1, minDistance: .infinity),
            DepthGridCell(direction: .right, row: 0, minDistance: .infinity),
            DepthGridCell(direction: .right, row: 1, minDistance: .infinity),
        ]

        let processor = DepthProcessor()
        let result = processor.closestPerDirection(cells: cells)

        XCTAssertEqual(result[.left], .infinity)
        XCTAssertEqual(result[.center], .infinity)
        XCTAssertEqual(result[.right], .infinity)
    }

    func testGroundPlaneFiltering() {
        let cells = [
            DepthGridCell(direction: .center, row: 0, minDistance: 3.0),
            DepthGridCell(direction: .center, row: 1, minDistance: 2.0),
            DepthGridCell(direction: .center, row: 2, minDistance: 0.5)  // bottom row, close range
        ]

        let processor = DepthProcessor()
        // With ground plane info, bottom row at close range should be filtered
        let result = processor.closestPerDirection(cells: cells, groundPlaneY: -1.0)

        // Bottom row (row 2) has heightAboveGround=0.1 which is < 0.3, and distance 0.5 < 2.0 → filtered
        XCTAssertEqual(result[.center], 2.0)
    }
}
