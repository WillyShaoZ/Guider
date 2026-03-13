import SwiftUI
import AVFoundation

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @State private var synthesizer = AVSpeechSynthesizer()

    private let steps: [(icon: String, text: String, speech: String)] = [
        ("lidar.iphone", "Welcome to Guider",
         "Welcome to Guider. This app detects obstacles using your phone's LiDAR sensor."),
        ("figure.stand", "Wear on Your Chest",
         "Wear your phone on your chest. It scans ahead and alerts you with vibration and sound."),
        ("gauge.with.dots.needle.33percent", "4 Distance Zones",
         "4 zones: Safe is clear. Caution gives a light pulse. Warning gives medium vibration. Danger gives strong vibration and voice alert."),
        ("hand.tap", "Simple Controls",
         "Tap anywhere to pause or resume. Long press for settings."),
        ("stairs", "Stair Detection",
         "The app also detects stairs with a special double-tap vibration."),
        ("checkmark.circle", "You're All Set",
         "You're all set. Tap to start.")
    ]

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            VStack(spacing: 32) {
                Spacer()

                Image(systemName: steps[currentStep].icon)
                    .font(.system(size: 80))
                    .foregroundColor(.white)

                Text(steps[currentStep].text)
                    .font(.system(size: 36, weight: .bold))
                    .foregroundColor(.white)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 32)

                Text(steps[currentStep].speech)
                    .font(.system(size: 20, weight: .medium))
                    .foregroundColor(.white.opacity(0.8))
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)

                Spacer()

                // Progress dots
                HStack(spacing: 12) {
                    ForEach(0..<steps.count, id: \.self) { index in
                        Circle()
                            .fill(index == currentStep ? Color.white : Color.white.opacity(0.3))
                            .frame(width: 12, height: 12)
                    }
                }

                Text(currentStep < steps.count - 1 ? "Tap to continue" : "Tap to start scanning")
                    .font(.system(size: 18, weight: .medium))
                    .foregroundColor(.white.opacity(0.6))
                    .padding(.bottom, 40)
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            advanceStep()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                speak(steps[currentStep].speech)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(steps[currentStep].speech)
        .accessibilityHint(currentStep < steps.count - 1
            ? "Tap to continue to next step."
            : "Tap to finish onboarding and start scanning.")
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    private func advanceStep() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if currentStep < steps.count - 1 {
            currentStep += 1
            speak(steps[currentStep].speech)
        } else {
            appState.hasCompletedOnboarding = true
        }
    }

    private func speak(_ message: String) {
        synthesizer.stopSpeaking(at: .immediate)
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }
}
