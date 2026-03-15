import SwiftUI
import AVFoundation

/// Settings for emergency contact and user profile.
struct SettingsView: View {
    @EnvironmentObject var appState: AppState
    @Environment(\.dismiss) var dismiss

    var body: some View {
        NavigationView {
            Form {
                Section {
                    VStack(alignment: .leading, spacing: 8) {
                        Text("Your Name")
                            .font(.subheadline)
                            .foregroundColor(.secondary)
                        TextField("e.g. John", text: $appState.userName)
                            .textContentType(.name)
                            .accessibilityLabel("Your name")
                            .accessibilityHint("Used in emergency messages so your contact knows who needs help")
                    }
                } header: {
                    Text("Your Profile")
                }

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
                        TextField("e.g. +61 400 123 456", text: $appState.emergencyContact)
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
                    Text("Emergency Contact")
                } footer: {
                    Text("When a fall is detected and you don't respond, an SMS with your GPS location will be sent automatically to this contact.")
                        .font(.caption)
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
