import SwiftUI
import ARKit
import AVFoundation

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationView {
            Form {
                Section("Feedback") {
                    Toggle("Haptic Vibration", isOn: $appState.hapticEnabled)
                        .accessibilityHint("Controls vibration feedback for obstacles")
                        .onChange(of: appState.hapticEnabled) { _, newValue in
                            speak("Haptic vibration \(newValue ? "on" : "off")")
                        }

                    Toggle("Spatial Audio", isOn: $appState.audioEnabled)
                        .accessibilityHint("Controls directional sound cues")
                        .onChange(of: appState.audioEnabled) { _, newValue in
                            speak("Spatial audio \(newValue ? "on" : "off")")
                        }

                    Toggle("Voice Announcements", isOn: $appState.voiceEnabled)
                        .accessibilityHint("Controls spoken obstacle warnings")
                        .onChange(of: appState.voiceEnabled) { _, newValue in
                            speak("Voice announcements \(newValue ? "on" : "off")")
                        }
                }

                Section("Sensitivity") {
                    VStack(alignment: .leading) {
                        Text("Detection Range")
                        Slider(value: $appState.sensitivity, in: 0.5...2.0, step: 0.1)
                            .accessibilityLabel("Detection sensitivity")
                            .accessibilityValue(String(format: "%.1fx", appState.sensitivity))
                        HStack {
                            Text("Near").font(.caption).foregroundColor(.secondary)
                            Spacer()
                            Text("Far").font(.caption).foregroundColor(.secondary)
                        }
                    }
                }

                Section("Device Info") {
                    HStack {
                        Text("LiDAR Available")
                        Spacer()
                        Image(systemName: ARKitAvailable() ? "checkmark.circle.fill" : "xmark.circle.fill")
                            .foregroundColor(ARKitAvailable() ? .green : .red)
                    }
                    .accessibilityLabel("LiDAR sensor \(ARKitAvailable() ? "available" : "not available")")
                }

                Section("About") {
                    HStack {
                        Text("Version")
                        Spacer()
                        Text("1.0.0 (Hackathon)")
                            .foregroundColor(.secondary)
                    }
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        speak("Closing settings")
                        DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                            dismiss()
                        }
                    }
                    .accessibilityLabel("Close settings")
                    .accessibilityHint("Double tap to close settings and resume scanning")
                }
            }
        }
        .onAppear {
            speakCurrentSettings()
        }
    }

    private func speakCurrentSettings() {
        let haptic = appState.hapticEnabled ? "on" : "off"
        let audio = appState.audioEnabled ? "on" : "off"
        let voice = appState.voiceEnabled ? "on" : "off"
        speak("Settings. Haptic vibration is \(haptic). Spatial audio is \(audio). Voice announcements is \(voice). Swipe to navigate options. Double tap to toggle.")
    }

    private func speak(_ message: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.9
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    private func ARKitAvailable() -> Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }
}
