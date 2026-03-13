import SwiftUI
import Combine
import AVFoundation

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lidarManager: LiDARSessionManager
    @StateObject private var detector = ObstacleDetector()
    @StateObject private var feedbackManager = FeedbackManager()
    @State private var showSettings = false
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            zoneBackgroundColor
                .ignoresSafeArea()

            // Minimal visual — only useful for sighted helpers or demos
            VStack(spacing: 16) {
                Spacer()

                Image(systemName: zoneIcon)
                    .font(.system(size: 100))
                    .foregroundColor(zoneColor)

                Text(appState.currentZone.label)
                    .font(.system(size: 44, weight: .bold))
                    .foregroundColor(zoneColor)

                if appState.closestDistance < DistanceZone.maxDetectionRange {
                    Text(String(format: "%.1f m", appState.closestDistance))
                        .font(.system(size: 60, weight: .light, design: .monospaced))
                        .foregroundColor(.primary)
                } else {
                    Text("Clear")
                        .font(.system(size: 48, weight: .light))
                        .foregroundColor(.secondary)
                }

                Spacer()

                // Scanning status indicator
                if appState.isScanning {
                    Text("Scanning")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                } else {
                    Text("Paused — Tap to resume")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)
                }

                Spacer()
                    .frame(height: 40)
            }
        }
        .contentShape(Rectangle())
        // Tap anywhere: pause / resume
        .onTapGesture(count: 1) {
            toggleScanning()
        }
        // Long press: open settings
        .onLongPressGesture(minimumDuration: 1.0) {
            let generator = UIImpactFeedbackGenerator(style: .heavy)
            generator.impactOccurred()
            speak("Settings")
            showSettings = true
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
                .environmentObject(appState)
        }
        .onAppear {
            startUp()
        }
        .onDisappear {
            shutdown()
        }
        .onReceive(detector.detectionSubject.receive(on: DispatchQueue.main)) { result in
            appState.detectionResult = result
            appState.currentZone = result.overallZone
            appState.closestDistance = result.closestObstacle?.distance ?? .infinity
            appState.closestDirection = result.closestObstacle?.direction ?? .center
        }
        // VoiceOver: the entire screen is one element
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint("Tap to pause or resume scanning. Hold for settings.")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    // MARK: - Lifecycle

    private func startUp() {
        feedbackManager.prepare()
        detector.bind(to: lidarManager)
        feedbackManager.bind(to: detector)

        // Auto-start scanning — no button needed
        startScanning()

        // Tell the user what's happening
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            speak("Guider is scanning. Tap anywhere to pause. Hold for settings.")
        }
    }

    private func shutdown() {
        stopScanning()
        feedbackManager.shutdown()
    }

    // MARK: - Scanning Control

    private func toggleScanning() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if appState.isScanning {
            stopScanning()
            speak("Scanning paused. Tap to resume.")
        } else {
            startScanning()
            speak("Scanning resumed.")
        }
    }

    private func startScanning() {
        guard lidarManager.cameraPermission == .authorized else { return }
        lidarManager.start()
        appState.isScanning = true
        feedbackManager.hapticEnabled = appState.hapticEnabled
        feedbackManager.audioEnabled = appState.audioEnabled
        feedbackManager.voiceEnabled = appState.voiceEnabled
    }

    private func stopScanning() {
        lidarManager.stop()
        detector.reset()
        feedbackManager.stop()
        appState.isScanning = false
        appState.currentZone = .safe
        appState.closestDistance = .infinity
    }

    // MARK: - Voice

    private func speak(_ message: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    // MARK: - Visual Helpers (for sighted helpers / demo)

    private var zoneIcon: String {
        switch appState.currentZone {
        case .safe: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.triangle"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }

    private var zoneColor: Color {
        switch appState.currentZone {
        case .safe: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .danger: return .red
        }
    }

    private var zoneBackgroundColor: Color {
        switch appState.currentZone {
        case .safe: return Color(.systemBackground)
        case .caution: return Color.yellow.opacity(0.05)
        case .warning: return Color.orange.opacity(0.1)
        case .danger: return Color.red.opacity(0.15)
        }
    }

    private var accessibilityDescription: String {
        if !appState.isScanning {
            return "Guider is paused."
        }
        if appState.closestDistance < DistanceZone.maxDetectionRange {
            return "Zone: \(appState.currentZone.label). Obstacle \(appState.closestDirection.rawValue) at \(String(format: "%.1f", appState.closestDistance)) meters."
        }
        return "Zone: safe. Path is clear."
    }
}
