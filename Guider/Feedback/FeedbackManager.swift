import Combine

final class FeedbackManager: ObservableObject {
    let hapticEngine = HapticEngine()
    let spatialAudio = SpatialAudioEngine()
    let voiceAnnouncer = VoiceAnnouncer()

    private var cancellables = Set<AnyCancellable>()
    private var previousZone: DistanceZone = .safe

    var hapticEnabled = true
    var audioEnabled = true
    var voiceEnabled = true

    func prepare() {
        hapticEngine.prepare()
        spatialAudio.prepare()
    }

    func bind(to detector: ObstacleDetector) {
        detector.detectionSubject
            .sink { [weak self] result in
                self?.handleDetection(result)
            }
            .store(in: &cancellables)
    }

    private func handleDetection(_ result: DetectionResult) {
        let zone = result.overallZone
        let direction = result.closestObstacle?.direction ?? .center
        let distance = result.closestObstacle?.distance ?? .infinity

        // Haptic feedback
        if hapticEnabled {
            hapticEngine.play(for: zone)
        }

        // Spatial audio
        if audioEnabled {
            spatialAudio.play(for: zone, direction: direction)
        }

        // Voice announcement on zone change (only when getting closer)
        if voiceEnabled && zone > previousZone {
            if zone == .danger, let obstacle = result.closestObstacle {
                voiceAnnouncer.announceObstacle(
                    direction: obstacle.direction,
                    distance: obstacle.distance
                )
            } else {
                voiceAnnouncer.announceZoneChange(to: zone)
            }
        }

        previousZone = zone
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
