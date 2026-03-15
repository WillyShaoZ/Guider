import AVFoundation
import Speech
import Combine
import UIKit
import CallKit

/// Handles the emergency flow after a phone drop is detected.
///
/// Flow:
/// 1. Strong haptic burst to alert the user
/// 2. Voice: "It seems like your phone dropped. Are you okay? Say yes or help."
/// 3. Listen via microphone for response (up to 10 seconds)
/// 4. If "yes" / "okay" / "fine" → resume normal scanning
/// 5. If "help" / no response / unclear → escalate (announce emergency message)
/// 6. User can also tap to dismiss at any time
final class EmergencyAssistant: ObservableObject {
    enum State: Equatable {
        case idle
        case asking       // Speaking the prompt
        case listening    // Mic is on, waiting for response
        case resolved     // User said they're okay
        case escalated    // No response or user asked for help
    }

    @Published var state: State = .idle

    /// Set before triggering — the phone number to call on escalation
    var emergencyContact: String = ""
    var emergencyContactName: String = ""

    private let synthesizer = AVSpeechSynthesizer()
    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))

    private var listenTimer: Timer?
    private let listenTimeout: TimeInterval = 10.0
    private var bystanderTimer: Timer?
    private let emergencySmsMessage = "Emergency alert from Guider. I may have fallen and need help."
    private var didSendEmergencySms = false

    private let positiveKeywords = ["yes", "yeah", "okay", "ok", "fine", "good", "i'm okay", "i'm fine", "i'm good", "all good"]
    private let helpKeywords = ["help", "no", "emergency", "call", "fall", "fell", "hurt"]

    // MARK: - Public

    func trigger() {
        guard state == .idle else { return }

        // 1. Strong haptic burst
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        didSendEmergencySms = false

        // Additional strong haptic after short delay
        DispatchQueue.main.asyncAfter(deadline: .now() + 0.3) {
            let impact = UIImpactFeedbackGenerator(style: .heavy)
            impact.impactOccurred()
        }

        // 2. Ask the user
        state = .asking
        speak("It seems like your phone dropped. Are you okay? Say yes, or say help.") { [weak self] in
            self?.startListening()
        }
    }

    func dismiss() {
        // User tapped to dismiss — they're okay
        stopListening()
        stopBystanderGuidance()
        synthesizer.stopSpeaking(at: .immediate)
        didSendEmergencySms = false
        state = .resolved
        speak("Okay. Resuming scanning.") { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.state = .idle
            }
        }
    }

    func reset() {
        stopListening()
        stopBystanderGuidance()
        synthesizer.stopSpeaking(at: .immediate)
        didSendEmergencySms = false
        state = .idle
    }

    // MARK: - Voice

    private func speak(_ message: String, completion: (() -> Void)? = nil) {
        synthesizer.stopSpeaking(at: .immediate)

        let utterance = AVSpeechUtterance(string: message)
        utterance.rate = AVSpeechUtteranceDefaultSpeechRate * 0.85
        utterance.volume = 1.0
        utterance.voice = AVSpeechSynthesisVoice(language: "en-US")
        utterance.postUtteranceDelay = 0.5

        if let completion {
            let delegate = SpeechDelegate(completion: completion)
            speechDelegateStorage = delegate
            synthesizer.delegate = delegate
        }

        synthesizer.speak(utterance)
    }

    // Hold a strong reference to the delegate
    private var speechDelegateStorage: SpeechDelegate?

    // MARK: - Speech Recognition

    private func startListening() {
        state = .listening

        // Check if speech recognition is available
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            print("[Emergency] Speech recognition not available, escalating")
            handleNoResponse()
            return
        }

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
                guard let self else { return }

                if let result {
                    let text = result.bestTranscription.formattedString.lowercased()
                    self.evaluateResponse(text)
                }

                if error != nil || (result?.isFinal == true) {
                    // If we haven't resolved yet and recognition ended, wait for timer
                }
            }

            // Start timeout timer
            listenTimer = Timer.scheduledTimer(withTimeInterval: listenTimeout, repeats: false) { [weak self] _ in
                guard let self else { return }
                if self.state == .listening {
                    self.handleNoResponse()
                }
            }

            print("[Emergency] Listening for response...")

        } catch {
            print("[Emergency] Failed to start audio engine: \(error)")
            handleNoResponse()
        }
    }

    private func evaluateResponse(_ text: String) {
        guard state == .listening else { return }

        if helpKeywords.contains(where: { text.contains($0) }) {
            DispatchQueue.main.async { [weak self] in
                self?.handleHelpRequest()
            }
        } else if positiveKeywords.contains(where: { text.contains($0) }) {
            DispatchQueue.main.async { [weak self] in
                self?.handlePositiveResponse()
            }
        }
    }

    private func handlePositiveResponse() {
        stopListening()
        state = .resolved

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.success)

        speak("Glad you're okay. Resuming scanning.") { [weak self] in
            DispatchQueue.main.asyncAfter(deadline: .now() + 1.0) {
                self?.state = .idle
            }
        }
    }

    private func handleHelpRequest() {
        stopListening()
        escalate()
    }

    private func handleNoResponse() {
        DispatchQueue.main.async { [weak self] in
            self?.stopListening()
            self?.escalate()
        }
    }

    private func escalate() {
        state = .escalated

        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.error)

        let contactNumber = emergencyContact.trimmingCharacters(in: .whitespacesAndNewlines)
        let contactName = emergencyContactName.trimmingCharacters(in: .whitespacesAndNewlines)

        if !contactNumber.isEmpty {
            callEmergencyContact(contactNumber)
            sendEmergencySMS(to: contactNumber)
            let nameOrNumber = contactName.isEmpty ? contactNumber : contactName
            let guidance = "Emergency. This person has fallen and is not responding. Please tap the blue Call button on screen to call \(nameOrNumber) for help."
            speak(guidance) { [weak self] in
                self?.startBystanderGuidance(message: guidance)
            }
        } else {
            // No contact — loud alert for bystanders
            let guidance = "Emergency. This person has fallen and is not responding. If someone is nearby, please help this person."
            speak(guidance) { [weak self] in
                self?.startBystanderGuidance(message: guidance)
            }
        }
    }

    private func sendEmergencySMS(to number: String) {
        guard !didSendEmergencySms else { return }
        didSendEmergencySms = true

        let cleaned = number.filter { $0.isNumber || $0 == "+" }

        var components = URLComponents()
        components.scheme = "sms"
        components.path = cleaned
        components.queryItems = [
            URLQueryItem(name: "body", value: emergencySmsMessage)
        ]

        guard let url = components.url else {
            print("[Emergency] Failed to build SMS URL")
            return
        }

        DispatchQueue.main.async {
            UIApplication.shared.open(url) { success in
                if !success {
                    print("[Emergency] Failed to open SMS composer")
                }
            }
        }
    }

    private func startBystanderGuidance(message: String) {
        bystanderTimer?.invalidate()
        bystanderTimer = Timer.scheduledTimer(withTimeInterval: 10.0, repeats: true) { [weak self] _ in
            guard let self, self.state == .escalated else {
                self?.bystanderTimer?.invalidate()
                self?.bystanderTimer = nil
                return
            }
            self.speak(message)
        }
    }

    private func stopBystanderGuidance() {
        bystanderTimer?.invalidate()
        bystanderTimer = nil
    }

    private func callEmergencyContact(_ number: String) {
        let cleaned = number.filter { $0.isNumber || $0 == "+" }

        let callController = CXCallController()
        let handle = CXHandle(type: .phoneNumber, value: cleaned)
        let startCallAction = CXStartCallAction(call: UUID(), handle: handle)

        let transaction = CXTransaction(action: startCallAction)
        callController.request(transaction) { error in
            if let error {
                print("[Emergency] CallKit failed: \(error), falling back to tel://")
                // Fallback to tel:// if CallKit fails
                guard let url = URL(string: "tel://\(cleaned)") else { return }
                DispatchQueue.main.async {
                    UIApplication.shared.open(url)
                }
            }
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

        // Restore audio session for playback
        try? AVAudioSession.sharedInstance().setCategory(.playback, mode: .default, options: [.mixWithOthers])
        try? AVAudioSession.sharedInstance().setActive(true)
    }
}

// MARK: - Speech Delegate

private class SpeechDelegate: NSObject, AVSpeechSynthesizerDelegate {
    let completion: () -> Void

    init(completion: @escaping () -> Void) {
        self.completion = completion
    }

    func speechSynthesizer(_ synthesizer: AVSpeechSynthesizer, didFinish utterance: AVSpeechUtterance) {
        DispatchQueue.main.async { [weak self] in
            self?.completion()
        }
    }
}
