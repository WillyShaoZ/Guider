import Foundation

struct FeedbackProfile {
    let hapticEnabled: Bool
    let audioEnabled: Bool
    let voiceEnabled: Bool
    let sensitivity: Float

    static let `default` = FeedbackProfile(
        hapticEnabled: true,
        audioEnabled: true,
        voiceEnabled: true,
        sensitivity: 1.0
    )
}
