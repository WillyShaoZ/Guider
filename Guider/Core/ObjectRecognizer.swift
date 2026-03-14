import AVFoundation
import UIKit
import Speech

final class ObjectRecognizer: ObservableObject {
    enum State: Equatable {
        case idle
        case listening
        case capturing
        case recognizing
        case result(String)
        case error(String)
    }

    @Published var state: State = .idle

    private var captureSession: AVCaptureSession?
    private var photoOutput: AVCapturePhotoOutput?
    private var delegate: PhotoDelegate?
    private let geminiService = GeminiVisionService()

    private var audioEngine: AVAudioEngine?
    private var recognitionRequest: SFSpeechAudioBufferRecognitionRequest?
    private var recognitionTask: SFSpeechRecognitionTask?
    private let speechRecognizer = SFSpeechRecognizer(locale: Locale(identifier: "en-US"))
    private var listenTimer: Timer?

    private let listenTimeout: TimeInterval = 6.0
    private let supportedQueries = [
        "what am i looking at",
        "what am i seeing",
        "what do you see",
        "what is this",
        "what's this",
        "describe this",
        "describe what you see",
        "look at this"
    ]

    func startVoiceAssistant() {
        guard state == .idle || isFinished else { return }

        guard SFSpeechRecognizer.authorizationStatus() == .authorized else {
            state = .error("Speech recognition is not available. Please enable it in Settings.")
            return
        }

        state = .listening
        startListeningForPrompt()
    }

    func recognize() {
        guard state == .idle || isFinished else { return }
        state = .capturing
        setupCameraAndCapture()
    }

    func reset() {
        stopListening()
        tearDownCamera()
        state = .idle
    }

    var isFinished: Bool {
        switch state {
        case .result, .error: return true
        default: return false
        }
    }

    // MARK: - Speech Input

    private func startListeningForPrompt() {
        guard let speechRecognizer, speechRecognizer.isAvailable else {
            state = .error("Speech recognition is currently unavailable.")
            return
        }

        do {
            let audioSession = AVAudioSession.sharedInstance()
            try audioSession.setCategory(.record, mode: .measurement, options: [.duckOthers])
            try audioSession.setActive(true, options: .notifyOthersOnDeactivation)

            let audioEngine = AVAudioEngine()
            let request = SFSpeechAudioBufferRecognitionRequest()
            request.shouldReportPartialResults = true

            let inputNode = audioEngine.inputNode
            let recordingFormat = inputNode.outputFormat(forBus: 0)
            inputNode.installTap(onBus: 0, bufferSize: 1024, format: recordingFormat) { [weak self] buffer, _ in
                self?.recognitionRequest?.append(buffer)
            }

            self.audioEngine = audioEngine
            self.recognitionRequest = request

            audioEngine.prepare()
            try audioEngine.start()

            recognitionTask = speechRecognizer.recognitionTask(with: request) { [weak self] result, error in
                guard let self else { return }

                if let text = result?.bestTranscription.formattedString.lowercased(),
                   self.matchesSceneQuery(text) {
                    self.stopListening()
                    DispatchQueue.main.async {
                        self.recognize()
                    }
                    return
                }

                if error != nil || result?.isFinal == true {
                    DispatchQueue.main.async {
                        self.stopListening()
                        self.state = .error("Ask: what am I looking at?")
                    }
                }
            }

            listenTimer = Timer.scheduledTimer(withTimeInterval: listenTimeout, repeats: false) { [weak self] _ in
                guard let self, self.state == .listening else { return }
                self.stopListening()
                self.state = .error("I didn't hear a question. Ask: what am I looking at?")
            }
        } catch {
            stopListening()
            state = .error("Could not start listening.")
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

    private func matchesSceneQuery(_ text: String) -> Bool {
        if supportedQueries.contains(where: { text.contains($0) }) {
            return true
        }

        let mentionsQuestion = text.contains("what") || text.contains("describe")
        let mentionsVision = text.contains("looking") || text.contains("see") || text.contains("this")
        return mentionsQuestion && mentionsVision
    }

    // MARK: - Camera

    private func setupCameraAndCapture() {
        let session = AVCaptureSession()
        session.sessionPreset = .photo

        guard let device = AVCaptureDevice.default(.builtInWideAngleCamera, for: .video, position: .back),
              let input = try? AVCaptureDeviceInput(device: device) else {
            DispatchQueue.main.async { self.state = .error("Camera not available") }
            return
        }

        let output = AVCapturePhotoOutput()

        guard session.canAddInput(input), session.canAddOutput(output) else {
            DispatchQueue.main.async { self.state = .error("Cannot configure camera") }
            return
        }

        session.addInput(input)
        session.addOutput(output)
        self.captureSession = session
        self.photoOutput = output

        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            session.startRunning()
            DispatchQueue.main.asyncAfter(deadline: .now() + 0.8) {
                self?.takePhoto()
            }
        }
    }

    private func takePhoto() {
        guard let photoOutput else {
            state = .error("Camera not ready")
            return
        }

        let settings = AVCapturePhotoSettings()
        settings.flashMode = .auto

        let delegate = PhotoDelegate { [weak self] imageData in
            if let imageData {
                self?.describeImageWithGemini(imageData)
            } else {
                DispatchQueue.main.async {
                    self?.state = .error("Failed to capture photo")
                    self?.tearDownCamera()
                }
            }
        }
        self.delegate = delegate
        photoOutput.capturePhoto(with: settings, delegate: delegate)
    }

    private func tearDownCamera() {
        DispatchQueue.global(qos: .userInitiated).async { [weak self] in
            self?.captureSession?.stopRunning()
            self?.captureSession = nil
            self?.photoOutput = nil
            self?.delegate = nil
        }
    }

    // MARK: - Image Understanding

    private func describeImageWithGemini(_ imageData: Data) {
        DispatchQueue.main.async { self.state = .recognizing }

        Task { [weak self] in
            guard let self else { return }

            do {
                let description = try await geminiService.describeImage(
                    jpegData: imageData,
                    prompt: "The user is visually impaired and asks what they are looking at. Give a short, direct description of the main object or scene in one or two sentences."
                )

                await MainActor.run {
                    self.state = .result(description)
                    self.tearDownCamera()
                }
            } catch {
                await MainActor.run {
                    self.state = .error(error.localizedDescription.isEmpty ? "Gemini request failed." : error.localizedDescription)
                    self.tearDownCamera()
                }
            }
        }
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (Data?) -> Void

    init(completion: @escaping (Data?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation() else {
            completion(nil)
            return
        }
        completion(data)
    }
}
