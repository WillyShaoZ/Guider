import SwiftUI
import AVFoundation
import CoreLocation

@main
struct GuiderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var lidarManager = LiDARSessionManager()
    private let locationManager = CLLocationManager()

    init() {
        configureAudioSession()
        locationManager.requestWhenInUseAuthorization()
    }

    var body: some Scene {
        WindowGroup {
            if !lidarManager.allPermissionsGranted {
                PermissionView()
                    .environmentObject(lidarManager)
            } else if !appState.hasCompletedOnboarding {
                OnboardingView()
                    .environmentObject(appState)
                    .onReceive(NotificationCenter.default.publisher(for: .emergencyContactConfirmed)) { notification in
                        if let name = notification.userInfo?["name"] as? String,
                           let number = notification.userInfo?["number"] as? String {
                            appState.emergencyContactName = name
                            appState.emergencyContact = number
                        }
                    }
            } else {
                MainView()
                    .environmentObject(appState)
                    .environmentObject(lidarManager)
            }
        }
    }

    private func configureAudioSession() {
        do {
            let session = AVAudioSession.sharedInstance()
            try session.setCategory(.playback, mode: .default, options: [.mixWithOthers])
            try session.setActive(true)
        } catch {
            print("[App] Failed to configure audio session: \(error)")
        }
    }
}
