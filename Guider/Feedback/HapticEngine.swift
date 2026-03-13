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
            guard let player = try engine?.makeAdvancedPlayer(with: pattern) else {
                print("[Haptic] Failed to create player")
                return
            }
            player.loopEnabled = true
            try player.start(atTime: CHHapticTimeImmediate)
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
            // Light pulse every 1.5s — gentle reminder, low power
            events = [
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 0
                ),
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.25),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.2)
                    ],
                    relativeTime: 1.5
                )
            ]

        case .warning:
            // Medium vibration every 0.6s — noticeable but not draining
            events = (0..<3).map { i in
                CHHapticEvent(
                    eventType: .hapticTransient,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.5),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.4)
                    ],
                    relativeTime: Double(i) * 0.6
                )
            }

        case .danger:
            // Strong short bursts every 0.4s — urgent but not continuous
            events = (0..<3).map { i in
                CHHapticEvent(
                    eventType: .hapticContinuous,
                    parameters: [
                        CHHapticEventParameter(parameterID: .hapticIntensity, value: 0.9),
                        CHHapticEventParameter(parameterID: .hapticSharpness, value: 0.7)
                    ],
                    relativeTime: Double(i) * 0.4,
                    duration: 0.2
                )
            }
        }

        return try CHHapticPattern(events: events, parameters: [])
    }
}
