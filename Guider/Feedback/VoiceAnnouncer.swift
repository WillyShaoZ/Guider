import AVFoundation

final class VoiceAnnouncer {
    private let synthesizer = AVSpeechSynthesizer()
    private var lastAnnouncement: String = ""
    private var lastAnnouncementTime: Date = .distantPast

    // Don't repeat the same announcement within this interval
    private let cooldown: TimeInterval = 3.0

    func announce(_ message: String) {
        let now = Date()
        guard message != lastAnnouncement ||
              now.timeIntervalSince(lastAnnouncementTime) > cooldown else {
            return
        }

        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 1.2
        utterance.volume = 0.8
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")

        synthesizer.speak(utterance)
        lastAnnouncement = message
        lastAnnouncementTime = now
    }

    func announceObstacle(direction: ObstacleDirection, distance: Float) {
        let distStr = String(format: "%.1f meters", distance)
        announce("Obstacle \(direction.rawValue), \(distStr)")
    }

    func announceZoneChange(to zone: DistanceZone) {
        switch zone {
        case .safe:
            break
        case .caution:
            announce("Caution")
        case .warning:
            announce("Warning, obstacle ahead")
        case .danger:
            announce("Danger, very close")
        }
    }

    func stop() {
        synthesizer.stopSpeaking(at: .immediate)
    }
}
