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
            if lidarManager.allPermissionsGranted {
                MainView()
                    .environmentObject(appState)
                    .environmentObject(lidarManager)
            } else {
                PermissionView()
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
