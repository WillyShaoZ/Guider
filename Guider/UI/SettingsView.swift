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

                Section {
                    Toggle("Drop Detection", isOn: $appState.dropDetectionEnabled)
                        .accessibilityHint("Detects if the phone falls and checks if you need help")
                        .onChange(of: appState.dropDetectionEnabled) { _, newValue in
                            speak("Drop detection \(newValue ? "on" : "off")")
                        }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Contact Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("e.g. Mom, Partner", text: $appState.emergencyContactName)
                            .textContentType(.name)
                            .accessibilityLabel("Emergency contact name")
                            .accessibilityHint("Enter the name of your emergency contact")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Phone Number")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("e.g. +1 234 567 8900", text: $appState.emergencyContact)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .accessibilityLabel("Emergency phone number")
                            .accessibilityHint("Enter the phone number to call if you fall and don't respond")
                    }

                    if appState.hasEmergencyContact {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            if appState.emergencyContactName.isEmpty {
                                Text("Contact set: \(appState.emergencyContact)")
                            } else {
                                Text("Contact set: \(appState.emergencyContactName)")
                            }
                        }
                        .font(.subheadline)
                        .accessibilityLabel("Emergency contact is set to \(appState.emergencyContactName.isEmpty ? appState.emergencyContact : appState.emergencyContactName)")
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("No emergency contact set. If you fall, only a loud alert will play.")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                        .accessibilityLabel("No emergency contact set. If you fall, only a loud alert will play for nearby people.")
                    }
                } header: {
                    Text("Emergency Assistance")
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
        let drop = appState.dropDetectionEnabled ? "on" : "off"
        let contact = appState.hasEmergencyContact
            ? "set to \(appState.emergencyContactName.isEmpty ? appState.emergencyContact : appState.emergencyContactName)"
            : "not set"
        speak("Settings. Haptic vibration is \(haptic). Spatial audio is \(audio). Voice announcements is \(voice). Drop detection is \(drop). Emergency contact is \(contact). Swipe to navigate options. Double tap to toggle.")
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
