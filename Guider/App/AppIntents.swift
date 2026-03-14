import AppIntents

struct OpenGuiderIntent: AppIntent {
    static var title: LocalizedStringResource = "Open Guider"
    static var description = IntentDescription("Launch Guider and start navigation scanning.")
    static var openAppWhenRun = true

    func perform() async throws -> some IntentResult {
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
    }
}
