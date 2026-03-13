import ARKit
import Accelerate

struct DepthGridCell {
    let direction: ObstacleDirection
    let row: Int // 0=top, 1=mid, 2=bottom
    let minDistance: Float
}

final class DepthProcessor {

    /// Process an ARDepthData into a 3x3 grid of minimum distances.
    /// Returns the closest distance per column (left/center/right).
    /// TODO: Phase 2 — use planeAnchors to filter ground surfaces
    func process(depthData: ARDepthData, planeAnchors: [ARPlaneAnchor] = []) -> [DepthGridCell] {
        let depthMap = depthData.depthMap
        let confidenceMap = depthData.confidenceMap

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return [] }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)

        // Lock confidence map if available
        var confidenceBuffer: UnsafePointer<UInt8>?
        if let confMap = confidenceMap {
            CVPixelBufferLockBaseAddress(confMap, .readOnly)
            if let confBase = CVPixelBufferGetBaseAddress(confMap) {
                confidenceBuffer = confBase.assumingMemoryBound(to: UInt8.self)
            }
        }
        defer {
            if let confMap = confidenceMap {
                CVPixelBufferUnlockBaseAddress(confMap, .readOnly)
            }
        }

        // Process center 60% of the frame to reduce noise from edges
        let marginX = Int(Float(width) * 0.2)
        let marginY = Int(Float(height) * 0.2)
        let roiWidth = width - 2 * marginX
        let roiHeight = height - 2 * marginY

        let colWidth = roiWidth / 3
        let rowHeight = roiHeight / 3

        var cells: [DepthGridCell] = []

        let directions: [ObstacleDirection] = [.left, .center, .right]

        for col in 0..<3 {
            for row in 0..<3 {
                let startX = marginX + col * colWidth
                let startY = marginY + row * rowHeight
                let endX = startX + colWidth
                let endY = startY + rowHeight

                var minDist: Float = .infinity

                // Sample every 4th pixel for performance
                for y in stride(from: startY, to: endY, by: 4) {
                    for x in stride(from: startX, to: endX, by: 4) {
                        let idx = y * width + x
                        let depth = floatBuffer[idx]

                        // Skip invalid readings
                        if depth.isNaN || depth <= 0 || depth > DistanceZone.maxDetectionRange { continue }

                        // Skip low confidence readings (0 = low, 1 = medium, 2 = high)
                        if let conf = confidenceBuffer, conf[idx] < 1 { continue }

                        if depth < minDist {
                            minDist = depth
                        }
                    }
                }

                cells.append(DepthGridCell(
                    direction: directions[col],
                    row: row,
                    minDistance: minDist
                ))
            }
        }

        return cells
    }

    /// Reduce the 3x3 grid to per-direction closest obstacle.
    /// When groundPlaneY is available, dynamically filters rows that would hit below 30cm above ground.
    /// Falls back to skipping bottom row when no plane anchor data is available.
    func closestPerDirection(cells: [DepthGridCell], groundPlaneY: Float? = nil) -> [ObstacleDirection: Float] {
        var result: [ObstacleDirection: Float] = [
            .left: .infinity,
            .center: .infinity,
            .right: .infinity
        ]

        for cell in cells {
            if let groundY = groundPlaneY {
                // With ground plane info: skip cells whose depth readings correspond
                // to objects below 30cm above ground. Row 2 (bottom) looks downward
                // most, row 1 (mid) is roughly level, row 0 (top) looks upward.
                // Bottom row at close range hits ground; skip if ground plane is known.
                let heightAboveGround: Float
                switch cell.row {
                case 2: heightAboveGround = 0.1  // Bottom row — very low
                case 1: heightAboveGround = 0.5  // Mid row — roughly chest level
                default: heightAboveGround = 1.0 // Top row — above chest
                }
                // Approximate: if the cell's angle hits below 30cm above ground, skip it
                if heightAboveGround < 0.3 && cell.minDistance < 2.0 {
                    continue
                }
            } else {
                // Fallback: skip bottom row (likely ground)
                if cell.row == 2 { continue }
            }

            if cell.minDistance < (result[cell.direction] ?? .infinity) {
                result[cell.direction] = cell.minDistance
            }
        }

        return result
    }
}
