import SwiftUI
import Combine

enum AppMode: String {
    case navigation
    case daily
}

@MainActor
final class AppState: ObservableObject {
    @Published var currentMode: AppMode = .navigation
    @Published var isScanning = false
    @Published var currentZone: DistanceZone = .safe
    @Published var closestDistance: Float = .infinity
    @Published var closestDirection: ObstacleDirection = .center
    @Published var detectionResult: DetectionResult = .empty
    @Published var isEmergencyActive = false

    // Settings — always on, no settings page needed
    var hapticEnabled = true
    var audioEnabled = true
    var voiceEnabled = true

    // Emergency
    @AppStorage("emergencyContact") var emergencyContact: String = ""
    @AppStorage("emergencyContactName") var emergencyContactName: String = ""
    @AppStorage("dropDetectionEnabled") var dropDetectionEnabled = true

    // Onboarding
    @AppStorage("hasCompletedOnboarding") var hasCompletedOnboarding = false

    var hasEmergencyContact: Bool {
        !emergencyContact.isEmpty
    }

    var feedbackProfile: FeedbackProfile {
        FeedbackProfile(
            hapticEnabled: hapticEnabled,
            audioEnabled: audioEnabled,
            voiceEnabled: voiceEnabled,
            sensitivity: Float(sensitivity)
        )
    }
}
