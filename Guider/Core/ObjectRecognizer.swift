import AVFoundation
import Vision
import CoreML
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
    private var vnModel: VNCoreMLModel?

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

    init() {
        loadModel()
    }

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

    // MARK: - Model Loading

    private func loadModel() {
        do {
            let config = MLModelConfiguration()
            config.computeUnits = .cpuAndNeuralEngine
            let model = try MobileNetV2FP16(configuration: config)
            vnModel = try VNCoreMLModel(for: model.model)
            print("[ObjectRecognizer] MobileNetV2 loaded")
        } catch {
            print("[ObjectRecognizer] Failed to load model: \(error)")
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
                        self.state = .result("Yes")
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

        let delegate = PhotoDelegate { [weak self] image in
            if let image {
                self?.classifyImage(image)
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

    private func classifyImage(_ image: CGImage) {
        DispatchQueue.main.async { self.state = .recognizing }

        guard let vnModel else {
            DispatchQueue.main.async {
                self.state = .error("Model not loaded")
                self.tearDownCamera()
            }
            return
        }

        let request = VNCoreMLRequest(model: vnModel) { [weak self] request, error in
            guard let self else { return }

            if let error {
                DispatchQueue.main.async {
                    self.state = .error("Recognition failed")
                    self.tearDownCamera()
                }
                print("[ObjectRecognizer] Error: \(error)")
                return
            }

            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async {
                    self.state = .error("No results")
                    self.tearDownCamera()
                }
                return
            }

            let topResults = results
                .prefix(3)
                .filter { $0.confidence > 0.05 }
                .map { observation -> (label: String, confidence: Int) in
                    let name = observation.identifier
                        .components(separatedBy: ",")
                        .first?
                        .trimmingCharacters(in: .whitespaces) ?? observation.identifier
                    let cleanedName = name.replacingOccurrences(of: "_", with: " ")
                    return (cleanedName, Int(observation.confidence * 100))
                }

            let description = self.buildSpokenDescription(from: topResults)

            DispatchQueue.main.async {
                self.state = .result(description)
                self.tearDownCamera()
            }
        }
        request.imageCropAndScaleOption = .centerCrop

        let handler = VNImageRequestHandler(cgImage: image, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([request])
        }
    }

    private func buildSpokenDescription(from topResults: [(label: String, confidence: Int)]) -> String {
        guard let bestMatch = topResults.first else {
            return "I'm not confident enough to describe this scene."
        }

        if topResults.count == 1 {
            return "This looks like \(bestMatch.label). Confidence \(bestMatch.confidence) percent."
        }

        let alternatives = topResults
            .dropFirst()
            .map { "\($0.label) \($0.confidence) percent" }
            .joined(separator: ", ")

        return "This looks like \(bestMatch.label). Confidence \(bestMatch.confidence) percent. Other possibilities: \(alternatives)."
    }
}

private final class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
    let completion: (CGImage?) -> Void

    init(completion: @escaping (CGImage?) -> Void) {
        self.completion = completion
    }

    func photoOutput(_ output: AVCapturePhotoOutput, didFinishProcessingPhoto photo: AVCapturePhoto, error: Error?) {
        guard error == nil,
              let data = photo.fileDataRepresentation(),
              let uiImage = UIImage(data: data),
              let cgImage = uiImage.cgImage else {
            completion(nil)
            return
        }
        completion(cgImage)
    }
}
