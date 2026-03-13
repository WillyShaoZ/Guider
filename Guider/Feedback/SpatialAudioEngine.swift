import AVFoundation

final class SpatialAudioEngine {
    private var audioEngine: AVAudioEngine?
    private var playerNode: AVAudioPlayerNode?
    private var environmentNode: AVAudioEnvironmentNode?
    private var currentZone: DistanceZone = .safe
    private var toneBuffer: AVAudioPCMBuffer?

    func prepare() {
        let engine = AVAudioEngine()
        let player = AVAudioPlayerNode()
        let environment = AVAudioEnvironmentNode()

        engine.attach(player)
        engine.attach(environment)

        // Connect: player → environment → output
        guard let format = AVAudioFormat(standardFormatWithSampleRate: 44100, channels: 1) else {
            print("[Audio] Failed to create audio format")
            return
        }
        engine.connect(player, to: environment, format: format)
        engine.connect(environment, to: engine.mainMixerNode, format: format)

        // Listener at origin
        environment.listenerPosition = AVAudio3DPoint(x: 0, y: 0, z: 0)

        do {
            try engine.start()
            self.audioEngine = engine
            self.playerNode = player
            self.environmentNode = environment
            print("[Audio] Spatial audio engine started")
        } catch {
            print("[Audio] Failed to start: \(error)")
        }
    }

    func play(for zone: DistanceZone, direction: ObstacleDirection) {
        guard zone != .safe else {
            stop()
            return
        }

        guard let playerNode = playerNode else { return }

        // Update spatial position based on direction
        playerNode.position = AVAudio3DPoint(
            x: direction.spatialAngle * 2.0,
            y: 0,
            z: -1.0
        )

        // Generate tone based on zone
        let frequency = toneFrequency(for: zone)
        guard let buffer = generateTone(frequency: frequency, duration: toneDuration(for: zone)) else { return }

        playerNode.stop()
        playerNode.scheduleBuffer(buffer, at: nil, options: .loops)
        playerNode.play()
        playerNode.volume = volume(for: zone)

        currentZone = zone
    }

    func stop() {
        playerNode?.stop()
        currentZone = .safe
    }

    func shutdown() {
        stop()
        audioEngine?.stop()
        audioEngine = nil
    }

    private func toneFrequency(for zone: DistanceZone) -> Double {
        switch zone {
        case .safe: return 0
        case .caution: return 220    // Low A
        case .warning: return 440    // Mid A
        case .danger: return 880     // High A
        }
    }

    private func toneDuration(for zone: DistanceZone) -> Double {
        switch zone {
        case .safe: return 0
        case .caution: return 0.5
        case .warning: return 0.2
        case .danger: return 0.1
        }
    }

    private func volume(for zone: DistanceZone) -> Float {
        switch zone {
        case .safe: return 0
        case .caution: return 0.3
        case .warning: return 0.6
        case .danger: return 1.0
        }
    }

    private func generateTone(frequency: Double, duration: Double) -> AVAudioPCMBuffer? {
        let sampleRate: Double = 44100
        let frameCount = AVAudioFrameCount(sampleRate * duration)
        guard let format = AVAudioFormat(standardFormatWithSampleRate: sampleRate, channels: 1),
              let buffer = AVAudioPCMBuffer(pcmFormat: format, frameCapacity: frameCount) else {
            return nil
        }

        buffer.frameLength = frameCount
        guard let channelData = buffer.floatChannelData?[0] else { return nil }

        for frame in 0..<Int(frameCount) {
            let t = Double(frame) / sampleRate
            channelData[frame] = Float(sin(2.0 * .pi * frequency * t)) * 0.5
        }

        return buffer
    }
}
