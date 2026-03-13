import AVFoundation

/// Spatial audio feedback engine.
/// Currently disabled to avoid AVAudioEngine crash when running alongside ARKit.
/// Haptic feedback and voice announcements remain active.
/// TODO: Re-enable with AVAudioPlayer-based approach.
final class SpatialAudioEngine {
    private var currentZone: DistanceZone = .safe

    func prepare() {
        print("[Audio] Spatial audio disabled (AVAudioEngine/ARKit conflict)")
    }

    func play(for zone: DistanceZone, direction: ObstacleDirection) {
        currentZone = zone
    }

    func stop() {
        currentZone = .safe
    }

    func shutdown() {
        stop()
    }
}
