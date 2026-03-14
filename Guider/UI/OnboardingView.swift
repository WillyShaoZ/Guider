import SwiftUI
import AVFoundation
import Speech
import Contacts

struct OnboardingView: View {
    @EnvironmentObject var appState: AppState
    @State private var currentStep = 0
    @StateObject private var contactSetup = EmergencyContactSetup()

    private let introSteps: [(icon: String, text: String, speech: String)] = [
        ("lidar.iphone", "Welcome to Guider",
         "Welcome to Guider. This app detects obstacles using your phone's LiDAR sensor."),
        ("figure.stand", "Wear on Your Chest",
         "Wear your phone on your chest. It scans ahead and alerts you with vibration and sound."),
        ("gauge.with.dots.needle.33percent", "4 Distance Zones",
         "4 zones: Safe is clear. Caution gives a light pulse. Warning gives medium vibration. Danger gives strong vibration and voice alert."),
        ("hand.tap", "Simple Controls",
         "Tap anywhere to pause or resume. Long press to switch modes."),
        ("stairs", "Stair Detection",
         "The app also detects stairs with a special double-tap vibration."),
    ]

    // Total steps = intro steps + emergency contact step + final step
    private var totalSteps: Int { introSteps.count + 2 }
    private var isEmergencyStep: Bool { currentStep == introSteps.count }
    private var isFinalStep: Bool { currentStep == introSteps.count + 1 }

    var body: some View {
        ZStack {
            Color.black
                .ignoresSafeArea()

            if isEmergencyStep {
                emergencyContactView
            } else if isFinalStep {
                finalStepView
            } else {
                introStepView
            }
        }
        .contentShape(Rectangle())
        .onTapGesture {
            handleTap()
        }
        .onLongPressGesture(minimumDuration: 0.8) {
            handleLongPress()
        }
        .onAppear {
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.5) {
                contactSetup.speak(introSteps[0].speech)
            }
        }
        .accessibilityElement(children: .ignore)
        .accessibilityLabel(currentAccessibilityLabel)
        .accessibilityAddTraits(.allowsDirectInteraction)
    }

    // MARK: - Intro Step View

    private var introStepView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: introSteps[currentStep].icon)
                .font(.system(size: 80))
                .foregroundColor(.white)

            Text(introSteps[currentStep].text)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(introSteps[currentStep].speech)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            progressDots
            bottomHint("Tap to continue")
        }
    }

    // MARK: - Emergency Contact View

    private var emergencyContactView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: emergencyIcon)
                .font(.system(size: 80))
                .foregroundColor(emergencyIconColor)

            Text("Emergency Contact")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text(emergencyStatusText)
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            if contactSetup.state == .found {
                Text("\(contactSetup.foundName) — \(contactSetup.foundNumber)")
                    .font(.system(size: 22, weight: .semibold))
                    .foregroundColor(.green)
                    .multilineTextAlignment(.center)
                    .padding(.horizontal, 40)
            }

            Spacer()
            progressDots
            bottomHint(emergencyHint)
        }
    }

    // MARK: - Final Step View

    private var finalStepView: some View {
        VStack(spacing: 32) {
            Spacer()

            Image(systemName: "checkmark.circle")
                .font(.system(size: 80))
                .foregroundColor(.green)

            Text("You're All Set")
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(.white)
                .multilineTextAlignment(.center)
                .padding(.horizontal, 32)

            Text("You're all set. Tap to start scanning.")
                .font(.system(size: 20, weight: .medium))
                .foregroundColor(.white.opacity(0.8))
                .multilineTextAlignment(.center)
                .padding(.horizontal, 40)

            Spacer()
            progressDots
            bottomHint("Tap to start scanning")
        }
    }

    // MARK: - Shared UI

    private var progressDots: some View {
        HStack(spacing: 12) {
            ForEach(0..<totalSteps, id: \.self) { index in
                Circle()
                    .fill(index == currentStep ? Color.white : Color.white.opacity(0.3))
                    .frame(width: 12, height: 12)
            }
        }
    }

    private func bottomHint(_ text: String) -> some View {
        Text(text)
            .font(.system(size: 18, weight: .medium))
            .foregroundColor(.white.opacity(0.6))
            .padding(.bottom, 40)
    }

    // MARK: - Emergency Step Helpers

    private var emergencyIcon: String {
        switch contactSetup.state {
        case .idle, .asking: return "person.crop.circle.badge.plus"
        case .listening: return "waveform.circle.fill"
        case .searching: return "magnifyingglass"
        case .found: return "checkmark.circle.fill"
        case .notFound: return "xmark.circle"
        case .confirmed: return "checkmark.shield.fill"
        case .skipped: return "arrow.forward.circle"
        }
    }

    private var emergencyIconColor: Color {
        switch contactSetup.state {
        case .idle, .asking: return .blue
        case .listening: return .purple
        case .searching: return .orange
        case .found: return .green
        case .notFound: return .red
        case .confirmed: return .green
        case .skipped: return .gray
        }
    }

    private var emergencyStatusText: String {
        switch contactSetup.state {
        case .idle, .asking: return "Say the name of your emergency contact."
        case .listening: return "Listening..."
        case .searching: return "Searching contacts..."
        case .found: return "Is this your emergency contact?"
        case .notFound: return "Could not find that contact. Tap to try again, or long press to skip."
        case .confirmed: return "Emergency contact saved!"
        case .skipped: return "Skipped. You can set it up later."
        }
    }

    private var emergencyHint: String {
        switch contactSetup.state {
        case .idle, .asking: return "Tap to start listening"
        case .listening: return "Say a name from your contacts"
        case .searching: return "Please wait..."
        case .found: return "Say yes to confirm, or tap to try again"
        case .notFound: return "Tap to retry, long press to skip"
        case .confirmed, .skipped: return "Tap to continue"
        }
    }

    private var currentAccessibilityLabel: String {
        if isEmergencyStep { return emergencyStatusText }
        if isFinalStep { return "You're all set. Tap to start scanning." }
        return introSteps[currentStep].speech
    }

    // MARK: - Tap Handler

    private func handleTap() {
        let generator = UIImpactFeedbackGenerator(style: .medium)
        generator.impactOccurred()

        if isEmergencyStep {
            handleEmergencyTap()
        } else if isFinalStep {
            appState.hasCompletedOnboarding = true
        } else {
            currentStep += 1
            if isEmergencyStep {
                contactSetup.start()
            } else {
                contactSetup.speak(introSteps[currentStep].speech)
            }
        }
    }

    private func handleLongPress() {
        let generator = UIImpactFeedbackGenerator(style: .heavy)
        generator.impactOccurred()

        if isEmergencyStep {
            contactSetup.skip()
        }
    }

    private func handleEmergencyTap() {
        switch contactSetup.state {
        case .idle, .asking:
            contactSetup.startListening()
        case .listening:
            break // wait for speech
        case .found:
            // tap = try again
            contactSetup.retry()
        case .notFound:
            contactSetup.retry()
        case .confirmed, .skipped:
            currentStep += 1
            contactSetup.speak("You're all set. Tap to start scanning.")
        case .searching:
            break
        }
    }
}

// MARK: - Emergency Contact Setup ViewModel

final class EmergencyContactSetup: NSObject, ObservableObject, AVSpeechSynthesizerDelegate {
    enum SetupState {
        case idle
        case asking
        case listening
        case searching
        case found
        case notFound
        case confirmed
        case skipped
    }

    @Published var state: SetupState = .idle
    @Published var foundName: String = ""
    @Published var foundNumber: String = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var speechCompletion: (() -> Void)?
    private var listenTimer: Timer?
    private var lastTranscription: String = ""

    override init() {
        super.init()
        synthesizer.delegate = self
    }

    func start() {
        state = .asking
        speak("Would you like to set an emergency contact? Say the name of someone in your contacts. Or long press to skip.") {
            // wait for user tap to start listening
        }
    }

    func startListening() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            speak("Speech recognition is not available.")
            return
        }

        state = .listening
        lastTranscription = ""

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            audioEngine = AVAudioEngine()
            guard let audioEngine else { return }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, error in
                guard let self, self.state == .listening else { return }

                if let result {
                    self.lastTranscription = result.bestTranscription.formattedString

                    // Check for "yes" confirmation when in found state
                    // (handled separately)

                    if result.isFinal {
                        self.handleSpeechResult(self.lastTranscription)
                    }
                }

                if error != nil {
                    self.handleSpeechResult(self.lastTranscription)
                }
            }

            // 5 second timeout
            listenTimer = Timer.scheduledTimer(withTimeInterval: 5.0, repeats: false) { [weak self] _ in
                guard let self, self.state == .listening else { return }
                self.handleSpeechResult(self.lastTranscription)
            }

        } catch {
            speak("Failed to start listening. Tap to try again.")
            state = .asking
        }
    }

    func retry() {
        state = .asking
        speak("Say the name of your emergency contact.") {
            // wait for tap
        }
    }

    func skip() {
        stopListening()
        state = .skipped
        speak("Skipped. You can set your emergency contact later.")
    }

    // MARK: - Private

    private func handleSpeechResult(_ text: String) {
        stopListening()

        let trimmed = text.trimmingCharacters(in: .whitespacesAndNewlines)
        guard !trimmed.isEmpty else {
            state = .notFound
            speak("I didn't hear a name. Tap to try again, or long press to skip.")
            return
        }

        state = .searching
        speak("Searching for \(trimmed).") { [weak self] in
            self?.searchContacts(name: trimmed)
        }
    }

    private func searchContacts(name: String) {
        let store = CNContactStore()

        store.requestAccess(for: .contacts) { [weak self] granted, error in
            guard let self else { return }

            guard granted else {
                DispatchQueue.main.async {
                    self.state = .notFound
                    self.speak("Contacts access was denied. Please grant access in Settings.")
                }
                return
            }

            let keysToFetch: [CNKeyDescriptor] = [
                CNContactGivenNameKey as CNKeyDescriptor,
                CNContactFamilyNameKey as CNKeyDescriptor,
                CNContactPhoneNumbersKey as CNKeyDescriptor,
                CNContactNicknameKey as CNKeyDescriptor,
            ]

            let request = CNContactFetchRequest(keysToFetch: keysToFetch)
            let searchLower = name.lowercased()

            var bestMatch: CNContact?
            var bestScore = 0

            do {
                try store.enumerateContacts(with: request) { contact, _ in
                    let fullName = "\(contact.givenName) \(contact.familyName)".lowercased().trimmingCharacters(in: .whitespaces)
                    let givenLower = contact.givenName.lowercased()
                    let familyLower = contact.familyName.lowercased()
                    let nickLower = contact.nickname.lowercased()

                    guard !contact.phoneNumbers.isEmpty else { return }

                    var score = 0

                    // Exact full name match
                    if fullName == searchLower { score = 100 }
                    // Exact first name match
                    else if givenLower == searchLower { score = 80 }
                    // Exact nickname match
                    else if !nickLower.isEmpty && nickLower == searchLower { score = 80 }
                    // Exact last name match
                    else if familyLower == searchLower { score = 70 }
                    // Full name contains search
                    else if fullName.contains(searchLower) { score = 50 }
                    // First name starts with search
                    else if givenLower.hasPrefix(searchLower) { score = 40 }

                    if score > bestScore {
                        bestScore = score
                        bestMatch = contact
                    }
                }
            } catch {
                DispatchQueue.main.async {
                    self.state = .notFound
                    self.speak("Error searching contacts. Tap to try again.")
                }
                return
            }

            DispatchQueue.main.async {
                if let match = bestMatch, let phone = match.phoneNumbers.first {
                    let fullName = "\(match.givenName) \(match.familyName)".trimmingCharacters(in: .whitespaces)
                    let number = phone.value.stringValue
                    self.foundName = fullName
                    self.foundNumber = number
                    self.state = .found
                    self.speak("I found \(fullName), phone number \(number). Say yes to confirm, or tap to try a different name.")  { [weak self] in
                        self?.listenForConfirmation()
                    }
                } else {
                    self.state = .notFound
                    self.speak("I couldn't find anyone named \(name) in your contacts. Tap to try again, or long press to skip.")
                }
            }
        }
    }

    private func listenForConfirmation() {
        guard let speechRecognizer, speechRecognizer.isAvailable else { return }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.playAndRecord, mode: .default, options: [.defaultToSpeaker, .allowBluetooth])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            audioEngine = AVAudioEngine()
            guard let audioEngine else { return }

            recognitionRequest = SFSpeechAudioBufferRecognitionRequest()
            guard let recognitionRequest else { return }
            recognitionRequest.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)

            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            audioEngine.prepare()
            try audioEngine.start()

            let positiveWords = ["yes", "yeah", "yep", "correct", "confirm", "right", "sure", "okay"]

            recognitionTask = speechRecognizer.recognitionTask(with: recognitionRequest) { [weak self] result, _ in
                guard let self, self.state == .found else { return }

                if let result {
                    let text = result.bestTranscription.formattedString.lowercased()
                    if positiveWords.contains(where: { text.contains($0) }) {
                        self.stopListening()
                        // Post to main thread to update state
                        DispatchQueue.main.async {
                            // We need appState to save — post a notification
                            NotificationCenter.default.post(
                                name: .emergencyContactConfirmed,
                                object: nil,
                                userInfo: ["name": self.foundName, "number": self.foundNumber]
                            )
                            self.state = .confirmed
                            self.speak("Emergency contact saved. \(self.foundName).")
                        }
                    }
                }
            }

            // 8 second timeout for confirmation
            listenTimer = Timer.scheduledTimer(withTimeInterval: 8.0, repeats: false) { [weak self] _ in
                self?.stopListening()
            }

        } catch {
            // silently fail — user can still tap
        }
    }

    private func stopListening() {
        listenTimer?.invalidate()
        listenTimer = nil
        audioEngine?.inputNode.removeTap(onBus: 0)
        audioEngine?.stop()
        audioEngine = nil
        recognitionRequest?.endAudio()
        recognitionRequest = nil
        recognitionTask?.cancel()
        recognitionTask = nil
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }

    func speak(_ message: String, completion: (() -> Void)? = nil) {
        synthesizer.stopSpeaking(at: .immediate)
        speechCompletion = completion
        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        synthesizer.speak(utterance)
    }

    // MARK: - AVSpeechSynthesizerDelegate

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.speechCompletion?()
            self?.speechCompletion = nil
        }
    }
}

// MARK: - Notification for confirmation

extension Notification.Name {
    static let emergencyContactConfirmed = Notification.Name("emergencyContactConfirmed")
}
