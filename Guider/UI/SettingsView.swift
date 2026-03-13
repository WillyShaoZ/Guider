import SwiftUI

struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section("Feedback") {
                    Toggle("Haptic Vibration", isOn: $appState.hapticEnabled)
                        .accessibilityHint("Controls vibration feedback for obstacles")

                    Toggle("Spatial Audio", isOn: $appState.audioEnabled)
                        .accessibilityHint("Controls directional sound cues")

                    Toggle("Voice Announcements", isOn: $appState.voiceEnabled)
                        .accessibilityHint("Controls spoken obstacle warnings")
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
                    Button("Done") { dismiss() }
                        .accessibilityLabel("Close settings")
                }
            }
        }
    }

    private func ARKitAvailable() -> Bool {
        ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
    }
}

import ARKit
