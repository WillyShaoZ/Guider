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
                    .onOpenURL { url in
                        handleURL(url)
                    }
            } else {
                MainView()
                    .environmentObject(appState)
                    .environmentObject(lidarManager)
            }
        }
    }

    private func handleURL(_ url: URL) {
        guard url.scheme == "guider" else { return }

        switch url.host {
        case "switch":
            NotificationCenter.default.post(name: .guiderSwitchMode, object: nil)
        case "pause":
            NotificationCenter.default.post(name: .guiderPause, object: nil)
        default:
            break
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
