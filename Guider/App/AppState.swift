import SwiftUI
import Combine

@MainActor
final class AppState: ObservableObject {
    @Published var isScanning = false
    @Published var currentZone: DistanceZone = .safe
    @Published var closestDistance: Float = .infinity
    @Published var closestDirection: ObstacleDirection = .center
    @Published var detectionResult: DetectionResult = .empty
    @Published var isEmergencyActive = false

    // Settings
    @AppStorage("hapticEnabled") var hapticEnabled = true
    @AppStorage("audioEnabled") var audioEnabled = true
    @AppStorage("voiceEnabled") var voiceEnabled = true
    @AppStorage("sensitivity") var sensitivity: Double = 1.0

    // Emergency
    @AppStorage("emergencyContact") var emergencyContact: String = ""
    @AppStorage("emergencyContactName") var emergencyContactName: String = ""
    @AppStorage("dropDetectionEnabled") var dropDetectionEnabled = true

    var hasEmergencyContact: Bool {
        !emergencyContact.isEmpty
    }
}
