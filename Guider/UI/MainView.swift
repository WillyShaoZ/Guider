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
    @StateObject private var objectRecognizer = ObjectRecognizer()
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        ZStack {
            if appState.isEmergencyActive {
                emergencyView
            } else if appState.currentMode == .navigation {
                navigationModeView
            } else {
                dailyModeView
            }
        }
        .contentShape(Rectangle())
        .onTapGesture(count: 1) {
            handleTap()
        }
        .onAppear {
            startUp()
        }
        .onDisappear {
            shutdown()
        }
        .onReceive(detector.detectionSubject.receive(on: DispatchQueue.main)) { result in
            guard appState.currentMode == .navigation else { return }
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
                appState.isEmergencyActive = false
                if appState.currentMode == .navigation && !appState.isScanning {
                    startScanning()
                    speak("Scanning resumed.")
                }
            }
        }
        .onChange(of: objectRecognizer.state) { _, newState in
            if case .result(let description) = newState {
                speak("I see: \(description)")
            } else if case .error(let msg) = newState {
                speak(msg)
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: .guiderSwitchMode)) { _ in
            switchMode()
        }
        .onReceive(NotificationCenter.default.publisher(for: .guiderPause)) { _ in
            handleTap()
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(accessibilityDescription)
        .accessibilityHint(accessibilityHint)
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    // MARK: - Navigation Mode View

    private var navigationModeView: some View {
        ZStack {
            zoneBackgroundColor
                .ignoresSafeArea()

            VStack(spacing: 16) {
                Spacer()

                // Mode indicator
                Text("Navigation Mode")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

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

    // MARK: - Daily Mode View

    private var dailyModeView: some View {
        ZStack {
            Color(.systemBackground)
                .ignoresSafeArea()

            VStack(spacing: 24) {
                Spacer()

                // Mode indicator
                Text("Daily Mode")
                    .font(.system(size: 14, weight: .medium))
                    .foregroundColor(.secondary)
                    .textCase(.uppercase)
                    .tracking(2)

                Image(systemName: dailyModeIcon)
                    .font(.system(size: 100))
                    .foregroundColor(dailyModeColor)

                Text(dailyModeStatusText)
                    .font(.system(size: 32, weight: .bold))
                    .foregroundColor(.primary)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                if case .result(let description) = objectRecognizer.state {
                    Text(description)
                        .font(.system(size: 22, weight: .medium))
                        .foregroundColor(.secondary)
                        .multilineTextAlignment(.center)
                        .padding(.horizontal, 32)
                }

                Spacer()

                Text("Tap to identify an object")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.secondary)

                Spacer()
                    .frame(height: 40)
            }
        }
    }

    // MARK: - Emergency View

    private var emergencyView: some View {
        ZStack {
            Color.red.opacity(0.3)
                .ignoresSafeArea()

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
        }
    }

    // MARK: - Tap Handler

    private func handleTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if appState.isEmergencyActive {
            dismissEmergency()
        } else if appState.currentMode == .navigation {
            toggleScanning()
        } else {
            // Daily mode — trigger object recognition
            triggerObjectRecognition()
        }
    }

    // MARK: - Mode Switching

    func switchMode() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        if appState.currentMode == .navigation {
            // Switch to daily mode
            stopScanning()
            objectRecognizer.reset()
            appState.currentMode = .daily
            speak("Daily mode. Tap to identify objects.")
        } else {
            // Switch to navigation mode
            objectRecognizer.reset()
            appState.currentMode = .navigation
            startScanning()
            speak("Navigation mode. Scanning.")
        }
    }

    // MARK: - Object Recognition

    private func triggerObjectRecognition() {
        if objectRecognizer.isFinished || objectRecognizer.state == .idle {
            objectRecognizer.reset()
            speak("Identifying...")
            // Small delay so voice doesn't overlap with camera
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
                objectRecognizer.recognize()
            }
        }
    }

    // MARK: - Lifecycle

    private func startUp() {
        feedbackManager.prepare()
        detector.bind(to: lidarManager)
        feedbackManager.bind(to: detector)
        dropDetector.bind(to: lidarManager)

        startScanning()

        DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
            speak("Guider is scanning. Tap to pause.")
        }
    }

    private func shutdown() {
        stopScanning()
        feedbackManager.shutdown()
        dropDetector.reset()
        emergencyAssistant.reset()
        objectRecognizer.reset()
    }

    // MARK: - Emergency

    private func handleDropDetected() {
        guard appState.dropDetectionEnabled else { return }
        appState.isEmergencyActive = true
        feedbackManager.stop()
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

    // MARK: - Daily Mode Helpers

    private var dailyModeIcon: String {
        switch objectRecognizer.state {
        case .idle: return "camera.fill"
        case .capturing: return "camera.shutter.button"
        case .recognizing: return "sparkle.magnifyingglass"
        case .result: return "checkmark.circle.fill"
        case .error: return "xmark.circle.fill"
        }
    }

    private var dailyModeColor: Color {
        switch objectRecognizer.state {
        case .idle: return .blue
        case .capturing, .recognizing: return .orange
        case .result: return .green
        case .error: return .red
        }
    }

    private var dailyModeStatusText: String {
        switch objectRecognizer.state {
        case .idle: return "Ready to Identify"
        case .capturing: return "Capturing..."
        case .recognizing: return "Recognizing..."
        case .result: return "Identified"
        case .error(let msg): return msg
        }
    }

    // MARK: - Navigation Mode Helpers

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
        if appState.isEmergencyActive {
            return "Emergency. \(emergencyStatusText)"
        }
        if appState.currentMode == .daily {
            return "Daily mode. \(dailyModeStatusText)"
        }
        if !appState.isScanning {
            return "Guider is paused."
        }
        if appState.closestDistance < DistanceZone.maxDetectionRange {
            return "Zone: \(appState.currentZone.label). Obstacle \(appState.closestDirection.rawValue) at \(String(format: "%.1f", appState.closestDistance)) meters."
        }
        return "Zone: safe. Path is clear."
    }

    private var accessibilityHint: String {
        if appState.isEmergencyActive {
            return "Tap to dismiss the emergency alert."
        }
        if appState.currentMode == .daily {
            return "Tap to identify an object."
        }
        return "Tap to pause or resume scanning."
    }
}
