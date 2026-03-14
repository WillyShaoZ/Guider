import SwiftUI
import AVFoundation

struct PermissionView: View {
    @EnvironmentObject var lidarManager: LiDARSessionManager
    @State private var synthesizer = AVSpeechSynthesizer()
    @State private var hasSpoken = false

    private var isNotDetermined: Bool {
        lidarManager.cameraPermission == .notDetermined ||
        lidarManager.micPermission == .notDetermined ||
        lidarManager.speechPermission == .notDetermined
    }

    private var isDenied: Bool {
        lidarManager.cameraPermission == .denied ||
        lidarManager.micPermission == .denied ||
        lidarManager.speechPermission == .denied ||
        lidarManager.speechPermission == .restricted
    }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 0) {
                Spacer()
                    .frame(height: 60)

                // App identity — large, high contrast
                Image(systemName: "figure.walk")
                    .font(.system(size: 72))
                    .foregroundColor(.white)
                    .accessibilityHidden(true)
                    .padding(.bottom, 16)

                Text("Guider")
                    .font(.system(size: 40, weight: .bold))
                    .foregroundColor(.white)
                    .accessibilityLabel("Guider")
                    .padding(.bottom, 8)

                // Status message — high contrast, large text
                Text(statusMessage)
                    .font(.system(size: 22, weight: .medium))
                    .foregroundColor(.white.opacity(0.9))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)
                    .padding(.bottom, 40)
                    .accessibilityLabel(statusMessage)

                Spacer()

                // MARK: - Action Buttons
                // Explicit, large buttons instead of tap gestures.
                // VoiceOver users navigate to these with swipe and activate with double-tap.

                if isNotDetermined {
                    notDeterminedButtons
                } else if isDenied {
                    deniedButtons
                }

                Spacer()
                    .frame(height: 40)

                // Repeat instructions button — always available
                Button(action: { speakPrompt() }) {
                    HStack(spacing: 10) {
                        Image(systemName: "speaker.wave.2.fill")
                            .font(.system(size: 20))
                        Text("Repeat Instructions")
                            .font(.system(size: 18, weight: .medium))
                    }
                    .foregroundColor(.white.opacity(0.8))
                    .padding(.vertical, 14)
                    .frame(maxWidth: .infinity)
                }
                .accessibilityLabel("Repeat instructions")
                .accessibilityHint("Speaks the permission instructions again")
                .padding(.horizontal, 32)
                .padding(.bottom, 40)
            }
        }
        .onAppear {
            // Delay speech slightly so VoiceOver can finish its screen-change announcement
            if !hasSpoken {
                hasSpoken = true
                DispatchQueue.main.asyncAfter(deadline: .now() + 1.5) {
                    speakPrompt()
                }
            }
        }
        .onReceive(NotificationCenter.default.publisher(for: UIApplication.willEnterForegroundNotification)) { _ in
            lidarManager.refreshPermissions()
            // Re-announce if still on this screen after returning from Settings
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                if !lidarManager.allPermissionsGranted {
                    speakPrompt()
                }
            }
        }
    }

    // MARK: - Not Determined State

    private var notDeterminedButtons: some View {
        VStack(spacing: 20) {
            // Primary action — large, high contrast, full width
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                Task {
                    await lidarManager.requestPermissions()
                }
            }) {
                Text("Allow Permissions")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .accessibilityLabel("Allow permissions")
            .accessibilityHint("Requests camera, microphone, and speech recognition access for obstacle detection and voice assistance")
            .padding(.horizontal, 32)

            // Secondary action — outlined, still large
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .light)
                generator.impactOccurred()
                // Refresh picks up the "not determined" → stays on this screen,
                // but user has explicitly chosen to skip for now
                lidarManager.refreshPermissions()
            }) {
                Text("Skip for Now")
                    .font(.system(size: 20, weight: .semibold))
                    .foregroundColor(.white)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 20)
                    .background(Color.white.opacity(0.15))
                    .cornerRadius(16)
                    .overlay(
                        RoundedRectangle(cornerRadius: 16)
                            .stroke(Color.white.opacity(0.4), lineWidth: 2)
                    )
            }
            .accessibilityLabel("Skip for now")
            .accessibilityHint("Skips permission setup. The app will not work without camera access.")
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Denied State

    private var deniedButtons: some View {
        VStack(spacing: 20) {
            Button(action: {
                let generator = UIImpactFeedbackGenerator(style: .medium)
                generator.impactOccurred()
                openSettings()
            }) {
                Text("Open Settings")
                    .font(.system(size: 24, weight: .bold))
                    .foregroundColor(.black)
                    .frame(maxWidth: .infinity)
                    .padding(.vertical, 24)
                    .background(Color.white)
                    .cornerRadius(16)
            }
            .accessibilityLabel("Open Settings")
            .accessibilityHint("Opens iPhone Settings so you can grant camera, microphone, and speech recognition access to Guider")
            .padding(.horizontal, 32)
        }
    }

    // MARK: - Helpers

    private var statusMessage: String {
        if isNotDetermined {
            return "This app needs camera, microphone, and speech recognition access for obstacle detection and voice assistance."
        } else {
            return "Guider needs camera, microphone, and speech recognition access to work. Please grant access in Settings."
        }
    }

    private func speakPrompt() {
        synthesizer.stopSpeaking(at: .immediate)

        let message: String
        if isNotDetermined {
            message = "Welcome to Guider. This app needs camera, microphone, and speech recognition access for obstacle detection and voice assistance. Use the Allow Permissions button to grant access, or Skip for Now to continue without permissions."
        } else {
            message = "Guider needs camera, microphone, and speech recognition access to work. Use the Open Settings button to grant access."
        }

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.preUtteranceDelay = 0.3
        synthesizer.speak(utterance)
    }

    private func openSettings() {
        guard let url = URL(string: UIApplication.openSettingsURLString) else { return }
        UIApplication.shared.open(url)
    }
}
