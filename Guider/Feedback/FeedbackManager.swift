import Foundation
import Combine

final class FeedbackManager: ObservableObject {
    let hapticEngine = HapticEngine()
    let spatialAudio = SpatialAudioEngine()
    let voiceAnnouncer = VoiceAnnouncer()

    private var cancellables = Set<AnyCancellable>()
    private var previousZone: DistanceZone = .safe
    private var previousDirection: ObstacleDirection = .center

    var hapticEnabled = true
    var audioEnabled = true
    var voiceEnabled = true

    func prepare() {
        hapticEngine.prepare()
        spatialAudio.prepare()
    }

    func bind(to detector: ObstacleDetector) {
        cancellables.removeAll()
        detector.detectionSubject
            .sink { [weak self] result in
                self?.handleDetection(result)
            }
            .store(in: &cancellables)
    }

    func apply(profile: FeedbackProfile) {
        hapticEnabled = profile.hapticEnabled
        audioEnabled = profile.audioEnabled
        voiceEnabled = profile.voiceEnabled
    }

    private func handleDetection(_ result: DetectionResult) {
        // Handle stair detection independently of obstacle zone changes
        if let stair = result.stairDetection, stair.isDetected {
            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                if self.hapticEnabled {
                    self.hapticEngine.play(for: .danger)
                }
                if self.voiceEnabled {
                    self.voiceAnnouncer.announceStairs()
                }
            }
        }

        let zone = result.overallZone
        let direction = result.closestObstacle?.direction ?? .center

        // Only update feedback when zone or direction actually changes
        guard zone != previousZone || direction != previousDirection else { return }

        DispatchQueue.main.async { [weak self] in
            guard let self else { return }

            // Haptic feedback
            if self.hapticEnabled {
                self.hapticEngine.play(for: zone)
            }

            // Spatial audio
            if self.audioEnabled {
                self.spatialAudio.play(for: zone, direction: direction)
            }

            // Voice announcement on zone change (only when getting closer)
            if self.voiceEnabled && zone > self.previousZone {
                if zone == .danger, let obstacle = result.closestObstacle {
                    self.voiceAnnouncer.announceObstacle(
                        direction: obstacle.direction,
                        distance: obstacle.distance
                    )
                } else {
                    self.voiceAnnouncer.announceZoneChange(to: zone)
                }
            }

            self.previousZone = zone
            self.previousDirection = direction
        }
    }

    func stop() {
        hapticEngine.stop()
        spatialAudio.stop()
        voiceAnnouncer.stop()
        previousZone = .safe
    }

    func shutdown() {
        stop()
        hapticEngine.shutdown()
        spatialAudio.shutdown()
        cancellables.removeAll()
    }
}