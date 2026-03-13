import SwiftUI
import AVFoundation

/// Minimal settings — only emergency contact setup.
/// All other settings (haptic, audio, voice) are always on.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss
    @State private var synthesizer = AVSpeechSynthesizer()

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Contact Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("e.g. Mom, Partner", text: $appState.emergencyContactName)
                            .textContentType(.name)
                            .accessibilityLabel("Emergency contact name")
                    }

                    VStack(alignment: .leading, spacing: 8) {
                        Text("Emergency Phone Number")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("e.g. +1 234 567 8900", text: $appState.emergencyContact)
                            .keyboardType(.phonePad)
                            .textContentType(.telephoneNumber)
                            .accessibilityLabel("Emergency phone number")
                    }

                    if appState.hasEmergencyContact {
                        HStack {
                            Image(systemName: "checkmark.circle.fill")
                                .foregroundColor(.green)
                            Text("Contact set: \(appState.emergencyContactName.isEmpty ? appState.emergencyContact : appState.emergencyContactName)")
                        }
                        .font(.subheadline)
                    } else {
                        HStack {
                            Image(systemName: "exclamationmark.triangle.fill")
                                .foregroundColor(.orange)
                            Text("No emergency contact set.")
                        }
                        .font(.subheadline)
                        .foregroundColor(.secondary)
                    }
                } header: {
                    Text("Emergency Assistance")
                }
            }
            .navigationTitle("Settings")
            .toolbar {
                ToolbarItem(placement: .navigationBarTrailing) {
                    Button("Done") {
                        dismiss()
                    }
                }
            }
        }
    }
}
