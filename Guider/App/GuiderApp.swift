import SwiftUI
import AVFoundation

@main
struct GuiderApp: App {
    @StateObject private var appState = AppState()
    @StateObject private var lidarManager = LiDARSessionManager()

    init() {
        configureAudioSession()
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
