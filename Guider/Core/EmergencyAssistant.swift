import AVFoundation
import Speech
import Combine
import UIKit
import CallKit
import CoreLocation

/// Handles the emergency flow after a phone drop is detected.
///
/// Flow:
/// 1. Strong haptic burst to alert the user
/// 2. Voice: "It seems like your phone dropped. Are you okay? Say yes or help."
/// 3. Listen via microphone for response (up to 10 seconds)
/// 4. If "yes" / "okay" / "fine" → resume normal scanning
/// 5. If "help" / no response / unclear → escalate (announce emergency message)
/// 6. User can also tap to dismiss at any time
final class EmergencyAssistant: NSObject, ObservableObject, CLLocationManagerDelegate {
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
    private let emergencySmsMessage = "Emergency alert from Guider. I may have fallen and need help"
    private var didSendEmergencySms = false
    private let locationManager = CLLocationManager()
    private var locationCompletion: ((String?) -> Void)?
    private var locationTimeoutTimer: Timer?
    private let locationTimeout: TimeInterval = 3.0
    private let emergencySmsWebhook: String
    private let emergencySmsAuthToken: String

    private let positiveKeywords = ["yes", "yeah", "okay", "ok", "fine", "good", "i'm okay", "i'm fine", "i'm good", "all good"]
    private let helpKeywords = ["help", "no", "emergency", "call", "fall", "fell", "hurt"]

    override init() {
        if let path = Bundle.main.path(forResource: "Secrets", ofType: "plist"),
           let dict = NSDictionary(contentsOfFile: path) {
            emergencySmsWebhook = (dict["EMERGENCY_SMS_WEBHOOK_URL"] as? String) ?? ""
            emergencySmsAuthToken = (dict["EMERGENCY_SMS_AUTH_TOKEN"] as? String) ?? ""
        } else {
            emergencySmsWebhook = ""
            emergencySmsAuthToken = ""
        }
        super.init()
    }

    // MARK: - Public

    func trigger() {
        guard state == .idle else { return }

        // 1. Strong haptic burst
        let generator = UINotificationFeedbackGenerator()
        generator.notificationOccurred(.warning)
        didSendEmergencySms = false
        locationManager.delegate = self

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
        clearLocationState()
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
        clearLocationState()
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
        resolveCurrentLocation { [weak self] locationText in
            guard let self else { return }

            let base = self.emergencySmsMessage
            let emergencyText = locationText == nil ? base : "\(base). Current location: \(locationText!)"

            self.sendEmergencySMSViaWebhook(to: cleaned, message: emergencyText) { [weak self] success in
                guard let self else { return }
                if !success {
                    self.openSmsComposer(to: cleaned, message: emergencyText)
                }
            }
        }
    }

    private func sendEmergencySMSViaWebhook(to number: String, message: String, completion: @escaping (Bool) -> Void) {
        guard !emergencySmsWebhook.isEmpty, let webhookURL = URL(string: emergencySmsWebhook) else {
            completion(false)
            return
        }

        var request = URLRequest(url: webhookURL)
        request.httpMethod = "POST"
        request.setValue("application/json", forHTTPHeaderField: "Content-Type")
        if !emergencySmsAuthToken.isEmpty {
            request.setValue("Bearer \(emergencySmsAuthToken)", forHTTPHeaderField: "Authorization")
        }

        let body: [String: String] = [
            "to": number,
            "message": message
        ]
        request.httpBody = try? JSONSerialization.data(withJSONObject: body)

        URLSession.shared.dataTask(with: request) { _, response, error in
            if let error {
                print("[Emergency] Webhook send failed: \(error)")
                completion(false)
                return
            }

            guard let response, let httpResponse = response as? HTTPURLResponse else {
                print("[Emergency] Webhook response missing")
                completion(false)
                return
            }

            guard 200...299 ~= httpResponse.statusCode else {
                print("[Emergency] Webhook failed with status \(httpResponse.statusCode)")
                completion(false)
                return
            }

            completion(true)
        }.resume()
    }

    private func openSmsComposer(to number: String, message: String) {
        var components = URLComponents()
        components.scheme = "sms"
        components.path = number
        components.queryItems = [
            URLQueryItem(name: "body", value: message)
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

    private func resolveCurrentLocation(completion: @escaping (String?) -> Void) {
        locationManager.delegate = self
        locationManager.desiredAccuracy = kCLLocationAccuracyNearestTenMeters

        locationCompletion = completion
        locationTimeoutTimer?.invalidate()
        locationTimeoutTimer = Timer.scheduledTimer(withTimeInterval: locationTimeout, repeats: false) { [weak self] _ in
            guard let self else { return }
            guard let locationCompletion else { return }
            self.clearLocationState()
            locationCompletion(nil)
        }

        let status = locationManager.authorizationStatus()
        if status == .notDetermined {
            locationManager.requestWhenInUseAuthorization()
            return
        }

        guard status == .authorizedWhenInUse || status == .authorizedAlways else {
            guard let completion = locationCompletion else { return }
            clearLocationState()
            completion(nil)
            return
        }

        locationManager.requestLocation()
    }

    func locationManager(_ manager: CLLocationManager, didUpdateLocations locations: [CLLocation]) {
        guard let location = locations.last else { return }

        let lat = String(format: "%.6f", location.coordinate.latitude)
        let lon = String(format: "%.6f", location.coordinate.longitude)
        let messageLocation = "\(lat), \(lon) (https://maps.apple.com/?ll=\(lat),\(lon))"

        guard let completion = locationCompletion else { return }
        clearLocationState()
        completion(messageLocation)
    }

    func locationManager(_ manager: CLLocationManager, didFailWithError error: Error) {
        guard let completion = locationCompletion else { return }
        clearLocationState()
        completion(nil)
    }

    func locationManagerDidChangeAuthorization(_ manager: CLLocationManager) {
        let status = manager.authorizationStatus()
        if status == .authorizedWhenInUse || status == .authorizedAlways {
            manager.requestLocation()
        } else if status == .denied || status == .restricted {
            guard let completion = locationCompletion else { return }
            clearLocationState()
            completion(nil)
        }
    }

    private func clearLocationState() {
        locationCompletion = nil
        locationTimeoutTimer?.invalidate()
        locationTimeoutTimer = nil
        locationManager.delegate = nil
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
