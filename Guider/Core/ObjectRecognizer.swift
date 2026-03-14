import AVFoundation
import UIKit
import Vision
import Network

final class ObjectRecognizer: ObservableObject {
    enum State: Equatable {
        case idle
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

    // Network monitoring
    private let networkMonitor = NWPathMonitor()
    private var isOnline = true

    init() {
        networkMonitor.pathUpdateHandler = { [weak self] path in
            DispatchQueue.main.async {
                self?.isOnline = path.status == .satisfied
            }
        }
        networkMonitor.start(queue: DispatchQueue.global(qos: .utility))
    }

    deinit {
        networkMonitor.cancel()
    }

    func recognize() {
        guard state == .idle || isFinished else { return }
        state = .capturing
        setupCameraAndCapture()
    }

    func reset() {
        tearDownCamera()
        state = .idle
    }

    var isFinished: Bool {
        switch state {
        case .result, .error: return true
        default: return false
        }
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
            guard let self else { return }
            if let imageData {
                self.processImage(imageData)
            } else {
                DispatchQueue.main.async {
                    self.state = .error("Failed to capture photo")
                    self.tearDownCamera()
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

    // MARK: - Route to online or offline

    private func processImage(_ imageData: Data) {
        DispatchQueue.main.async { self.state = .recognizing }

        if isOnline {
            describeWithGemini(imageData)
        } else {
            describeOffline(imageData)
        }
    }

    // MARK: - Online: Gemini API

    private func describeWithGemini(_ imageData: Data) {
        Task { [weak self] in
            guard let self else { return }

            do {
                let description = try await geminiService.describeImage(
                    jpegData: imageData,
                    prompt: "The user is visually impaired. Describe what is in front of them in one or two short sentences. Be direct and helpful."
                )

                await MainActor.run {
                    self.state = .result(description)
                    self.tearDownCamera()
                }
            } catch {
                // If Gemini fails, fall back to offline
                await MainActor.run {
                    self.describeOffline(imageData)
                }
            }
        }
    }

    // MARK: - Offline: Apple Vision

    private func describeOffline(_ imageData: Data) {
        guard let cgImage = UIImage(data: imageData)?.cgImage else {
            DispatchQueue.main.async {
                self.state = .error("Could not process image")
                self.tearDownCamera()
            }
            return
        }

        let classifyRequest = VNClassifyImageRequest { [weak self] request, error in
            guard let self else { return }

            if error != nil {
                DispatchQueue.main.async {
                    self.state = .error("Offline recognition failed.")
                    self.tearDownCamera()
                }
                return
            }

            guard let results = request.results as? [VNClassificationObservation] else {
                DispatchQueue.main.async {
                    self.state = .error("No results from offline recognition.")
                    self.tearDownCamera()
                }
                return
            }

            // Take top results with confidence > 20%
            let topResults = results
                .filter { $0.confidence > 0.2 }
                .prefix(3)
                .map { $0.identifier.replacingOccurrences(of: "_", with: " ") }

            let description: String
            if topResults.isEmpty {
                description = "I couldn't identify anything clearly. Try moving closer or pointing the camera at an object."
            } else if topResults.count == 1 {
                description = "I see \(topResults[0])."
            } else {
                let items = topResults.joined(separator: ", ")
                description = "I see \(items)."
            }

            DispatchQueue.main.async {
                self.state = .result("(Offline) \(description)")
                self.tearDownCamera()
            }
        }

        let handler = VNImageRequestHandler(cgImage: cgImage, options: [:])
        DispatchQueue.global(qos: .userInitiated).async {
            try? handler.perform([classifyRequest])
        }
    }
}

// Need to inherit from NSObject for NWPathMonitor usage in init
extension ObjectRecognizer: @unchecked Sendable {}

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
