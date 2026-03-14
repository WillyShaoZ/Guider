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
        // FIX 1: Use bytesPerRow to account for row padding, not bare width
        let depthStride = CVPixelBufferGetBytesPerRow(depthMap) / MemoryLayout<Float32>.size

        CVPixelBufferLockBaseAddress(depthMap, .readOnly)
        defer { CVPixelBufferUnlockBaseAddress(depthMap, .readOnly) }

        guard let baseAddress = CVPixelBufferGetBaseAddress(depthMap) else { return nil }
        let floatBuffer = baseAddress.assumingMemoryBound(to: Float32.self)

        var confidenceBuffer: UnsafeMutablePointer<UInt8>?
        var confStride = 0
        if let confMap = confidenceMap {
            CVPixelBufferLockBaseAddress(confMap, .readOnly)
            if let confBase = CVPixelBufferGetBaseAddress(confMap) {
                confidenceBuffer = confBase.assumingMemoryBound(to: UInt8.self)
                confStride = CVPixelBufferGetBytesPerRow(confMap)
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
                let depthIdx = y * depthStride + x
                let depth = floatBuffer[depthIdx]
                if depth.isNaN || depth <= 0 || depth > 5.0 { continue }
                if let conf = confidenceBuffer {
                    if conf[y * confStride + x] < 1 { continue }
                }
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
    /// Stairs produce a monotonic profile with periodic same-sign depth spikes (risers).
    static func detectStairPattern(scanlineDepths: [Float]) -> (detected: Bool, confidence: Float) {
        guard scanlineDepths.count >= 5 else { return (false, 0) }

        // Compute first derivative
        var gradients: [Float] = []
        for i in 0..<(scanlineDepths.count - 1) {
            gradients.append(scanlineDepths[i + 1] - scanlineDepths[i])
        }

        let minStepHeight: Float = 0.05  // 5 cm — minimum riser height
        let maxStepHeight: Float = 0.30  // 30 cm — maximum riser height

        // FIX 2: Collect all sharp gradient spikes (riser candidates)
        var spikeIndices: [Int] = []
        var spikeValues: [Float] = []
        for i in 0..<gradients.count {
            let g = gradients[i]
            if abs(g) >= minStepHeight && abs(g) <= maxStepHeight {
                spikeIndices.append(i)
                spikeValues.append(g)
            }
        }

        guard spikeIndices.count >= 3 else { return (false, 0) }

        // Enforce same-sign: a real staircase has risers all going the same direction.
        // Keep only spikes matching the dominant sign.
        let positiveCount = spikeValues.filter { $0 > 0 }.count
        let dominantPositive = positiveCount >= spikeValues.count - positiveCount

        let filteredIndices = zip(spikeIndices, spikeValues)
            .filter { dominantPositive ? $0.1 > 0 : $0.1 < 0 }
            .map { $0.0 }

        guard filteredIndices.count >= 3 else { return (false, 0) }

        // Check regularity of intervals between spikes
        var intervals: [Int] = []
        for i in 0..<(filteredIndices.count - 1) {
            intervals.append(filteredIndices[i + 1] - filteredIndices[i])
        }

        guard !intervals.isEmpty else { return (false, 0) }

        let meanInterval = Float(intervals.reduce(0, +)) / Float(intervals.count)
        guard meanInterval > 0 else { return (false, 0) }

        let variance = intervals.map { pow(Float($0) - meanInterval, 2) }.reduce(0, +) / Float(intervals.count)
        let stdDev = sqrt(variance)

        // Regular pattern: std dev < 30% of mean
        let isRegular = stdDev < meanInterval * 0.3

        if isRegular {
            let confidence = min(1.0, Float(filteredIndices.count) / 5.0)
            return (true, confidence)
        }

        return (false, 0)
    }

    func reset() {
        consecutivePositiveFrames = 0
        lastAlertTime = .distantPast
    }
}