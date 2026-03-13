import CoreHaptics

final class HapticEngine {
    private var engine: CHHapticEngine?
    private var currentPlayer: CHHapticAdvancedPatternPlayer?
    private var currentZone: DistanceZone = .safe

    func prepare() {
        guard CHHapticEngine.capabilitiesForHardware().supportsHaptics else {
            print("[Haptic] Device does not support haptics")
            return
        }

        do {
            engine = try CHHapticEngine()
            engine?.resetHandler = { [weak self] in
                try? self?.engine?.start()
            }
            engine?.stoppedHandler = { reason in
                print("[Haptic] Engine stopped: \(reason)")
            }
            try engine?.start()
            print("[Haptic] Engine started")
        } catch {
            print("[Haptic] Failed to start engine: \(error)")
        }
    }

    func play(for zone: DistanceZone) {
        guard zone != currentZone else { return }
        currentZone = zone

        stop()

        guard zone != .safe else { return }

        do {
            let pattern = try makePattern(for: zone)
            let player = try engine?.makeAdvancedPlayer(with: pattern)
            player?.loopEnabled = true
            try player?.start(atTime: CHHapticTimeImmediate)
            currentPlayer = player
        } catch {
            print("[Haptic] Failed to play pattern: \(error)")
        }
    }

    func stop() {
        try? currentPlayer?.stop(atTime: CHHapticTimeImmediate)
        currentPlayer = nil
        currentZone = .safe
    }

    func shutdown() {
        stop()
        engine?.stop()
        engine = nil
    }

    private func makePattern(for zone: DistanceZone) throws -> CHHapticPattern {
        let events: [CHHapticEvent]

        switch zone {
        case .safe:
            events = []

        case .caution:
            // Light pulse every 0.5s
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.3),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0.5
                )
            ]

        case .warning:
            // Medium vibration every 0.2s
            events = (0..<5).map { i in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.6),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.5)
                    ],
                    relativeTime: Double(i) * 0.2
                )
            }

        case .danger:
            // Strong continuous vibration
            events = [
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 1.0),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.8)
                    ],
                    relativeTime: 0,
                    duration: 1.0
                )
            ]
        }

        return try CHHapticPattern(events: events, parameters: [])
    }
}
