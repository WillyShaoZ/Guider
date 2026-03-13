import AppIntents

struct OpenGuiderIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Guider"
    static var description = IntentDescription("Launch Guider and start navigation scanning.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        return .result()
    }
}

struct SwitchModeIntent: AppIntent {
    static var title: LocalizedStringResource = "Switch Guider Mode"
    static var description = IntentDescription("Toggle between Navigation mode and Daily mode.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
        await MainActor.run {
            NotificationCenter.default.post(name: .guiderSwitchMode, object: nil)
        }
        return .result()
    }
}

struct GuiderShortcuts: AppShortcutsProvider {
    static var appShortcuts: [AppShortcut] {
        AppShortcut(
            intent: OpenGuiderIntent(),
            phrases: [
                "Open \(.applicationName)",
                "Start \(.applicationName)",
                "Start scanning with \(.applicationName)"
            ],
            shortTitle: "Open Guider",
            systemImageName: "eye.fill"
        )
        AppShortcut(
            intent: SwitchModeIntent(),
            phrases: [
                "Switch \(.applicationName) mode",
                "Change \(.applicationName) mode"
            ],
            shortTitle: "Switch Mode",
            systemImageName: "arrow.triangle.2.circlepath"
        )
    }
}

extension Notification.Name {
    static let guiderSwitchMode = Notification.Name("guiderSwitchMode")
    static let guiderPause = Notification.Name("guiderPause")
}
