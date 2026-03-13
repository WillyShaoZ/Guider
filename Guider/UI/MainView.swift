import SwiftUI
import Combine
import AVFoundation

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @EnvironmentObject var lidarManager: LiDARSessionManager
    @StateObject private var detector = ObstacleDetector()
    @StateObject private var feedbackManager = FeedbackManager()
    @StateObject private var dropDetector = DropDetector()
    @StateObject private var emergencyAssistant = EmergencyAssistant()
    @State private var showSettings = false
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            // Emergency state: red background
            if appState.isEmergencyActive {
                Color.red.opacity(0.3)
                    .ignoresSafeArea()
            } else {
                zoneBackgroundColor
                    .ignoresSafeArea()
            }

            if appState.isEmergencyActive {
                // Emergency visual (for sighted helpers)
                VStack(spacing: 20) {
                    Spacer()

                    Image(systemName: "exclamationmark.triangle.fill")
                        .font(.system(size: 100))
                        .foregroundColor(.red)

                    Text("Drop Detected")
                        .font(.system(size: 40, weight: .bold))
                        .foregroundColor(.red)

                    Text(emergencyStatusText)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.primary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)

                    Spacer()

                    Text("Tap anywhere to dismiss")
                        .font(.system(size: 18, weight: .medium))
                        .foregroundColor(.secondary)

                    Spacer()
                        .frame(height: 40)
                }
            } else {
                // Normal scanning visual — for sighted helpers or demos
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
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            if appState.isEmergencyActive {
                dismissEmergency()
            } else {
                toggleScanning()
            }
        }
        .onLongPressGesture(minimumDuration: 1.0) {
            guard !appState.isEmergencyActive else { return }
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
        .onReceive(dropDetector.dropSubject.receive(on: DispatchQueue.main)) { _ in
            handleDropDetected()
        }
        .onChange(of: appState.sensitivity) { _, newValue in
            detector.sensitivity = Float(newValue)
        }
        .onChange(of: appState.hapticEnabled) { _, _ in
            feedbackManager.apply(profile: appState.feedbackProfile)
        }
        .onChange(of: appState.audioEnabled) { _, _ in
            feedbackManager.apply(profile: appState.feedbackProfile)
        }
        .onChange(of: appState.voiceEnabled) { _, _ in
            feedbackManager.apply(profile: appState.feedbackProfile)
        }
        .onReceive(lidarManager.$groundPlaneY) { groundY in
            detector.groundPlaneY = groundY
        }
        .onChange(of: emergencyAssistant.state) { _, newState in
            if newState == .idle {
                // Emergency resolved — resume scanning
                appState.isEmergencyActive = false
                if !appState.isScanning {
                    startScanning()
                    speak("Scanning resumed.")
                }
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(appState.isEmergencyActive
            ? "Tap to dismiss the emergency alert."
            : "Tap to pause or resume scanning. Hold for settings.")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    // MARK: - Lifecycle

    private func startUp() {
        feedbackManager.prepare()
        detector.bind(to: lidarManager)
        feedbackManager.bind(to: detector)
        dropDetector.bind(to: lidarManager)

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
        dropDetector.reset()
        emergencyAssistant.reset()
    }

    // MARK: - Emergency

    private func handleDropDetected() {
        guard appState.dropDetectionEnabled else { return }
        appState.isEmergencyActive = true
        // Pause obstacle feedback so it doesn't talk over the emergency
        feedbackManager.stop()
        // Pass emergency contact info
        emergencyAssistant.emergencyContact = appState.emergencyContact
        emergencyAssistant.emergencyContactName = appState.emergencyContactName
        emergencyAssistant.trigger()
    }

    private func dismissEmergency() {
        emergencyAssistant.dismiss()
    }

    private var emergencyStatusText: String {
        switch emergencyAssistant.state {
        case .idle: return ""
        case .asking: return "Asking if you're okay..."
        case .listening: return "Listening for your response..."
        case .resolved: return "You're okay. Resuming."
        case .escalated:
            if appState.hasEmergencyContact {
                let name = appState.emergencyContactName.isEmpty ? appState.emergencyContact : appState.emergencyContactName
                return "No response. Calling \(name)."
            }
            return "No response. Alerting nearby people."
        }
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
        detector.sensitivity = Float(appState.sensitivity)
        feedbackManager.apply(profile: appState.feedbackProfile)
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
