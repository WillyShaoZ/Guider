import ARKit

final class StairDetector {

    private var consecutivePositiveFrames = 0
    private let confirmationThreshold = 3
    private var lastAlertTime: Date = .distantPast
    private let cooldownInterval: TimeInterval = 5.0

    func analyze(depthData: ARDepthData) -> StairDetectionResult? {
        let now = Date()
        guard now.timeIntervalSince(lastAlertTime) > cooldownInterval else { return nil }

        let depthMap = depthData.depthMap
        let confidenceMap = depthData.confidenceMap

        let width = CVPixelBufferGetWidth(depthMap)
        let height = CVPixelBufferGetHeight(depthMap)

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)

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

        // Sample lower 40% of the frame, center 60% width
        let startY = Int(Float(height) * 0.6)
        let marginX = Int(Float(width) * 0.2)
        let endX = width - marginX

        var scanlineDepths: [Float] = []

        for y in stride(from: startY, to: height, by: 2) {
            var sum: Float = 0
            var count = 0
            for x in stride(from: marginX, to: endX, by: 2) {
                let idx = y * width + x
                let depth = floatBuffer[idx]
                if depth.isNaN || depth <= 0 || depth > 5.0 { continue }
                if let conf = confidenceBuffer, conf[idx] < 1 { continue }
                sum += depth
                count += 1
            }
            if count > 0 {
                scanlineDepths.append(sum / Float(count))
            }
        }

        let (detected, confidence) = StairDetector.detectStairPattern(scanlineDepths: scanlineDepths)

        if detected {
            consecutivePositiveFrames += 1
        } else {
            consecutivePositiveFrames = 0
        }

        if consecutivePositiveFrames >= confirmationThreshold {
            consecutivePositiveFrames = 0
            lastAlertTime = now
            let distance = scanlineDepths.min() ?? 0
            return StairDetectionResult(isDetected: true, confidence: confidence, distance: distance)
        }

        return nil
    }

    /// Pure function: detect repeating step pattern in mean-depth scanlines.
    static func detectStairPattern(scanlineDepths: [Float]) -> (detected: Bool, confidence: Float) {
        guard scanlineDepths.count >= 5 else { return (false, 0) }

        // Compute first derivative
        var gradients: [Float] = []
        for i in 0..<(scanlineDepths.count - 1) {
            gradients.append(scanlineDepths[i + 1] - scanlineDepths[i])
        }

        // Find sign changes with magnitude filter
        var signChangeIndices: [Int] = []
        for i in 0..<(gradients.count - 1) {
            let current = gradients[i]
            let next = gradients[i + 1]
            // Sign change with sufficient magnitude
            if current * next < 0 {
                let magnitude = max(abs(current), abs(next))
                if magnitude >= 0.05 && magnitude <= 0.3 {
                    signChangeIndices.append(i + 1)
                }
            }
        }

        guard signChangeIndices.count >= 3 else { return (false, 0) }

        // Check regularity of intervals
        var intervals: [Int] = []
        for i in 0..<(signChangeIndices.count - 1) {
            intervals.append(signChangeIndices[i + 1] - signChangeIndices[i])
        }

        guard !intervals.isEmpty else { return (false, 0) }

        let meanInterval = Float(intervals.reduce(0, +)) / Float(intervals.count)
        guard meanInterval > 0 else { return (false, 0) }

        let variance = intervals.map { pow(Float($0) - meanInterval, 2) }.reduce(0, +) / Float(intervals.count)
        let stdDev = sqrt(variance)

        // Regular pattern: std dev < 30% of mean
        let isRegular = stdDev < meanInterval * 0.3

        if isRegular {
            let confidence = min(1.0, Float(signChangeIndices.count) / 5.0)
            return (true, confidence)
        }

        return (false, 0)
    }

    func reset() {
        consecutivePositiveFrames = 0
        lastAlertTime = .distantPast
    }
}
