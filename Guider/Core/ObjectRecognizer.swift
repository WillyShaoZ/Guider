import AVFoundation
import Vision
import CoreML
import UIKit

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
    private var vnModel: VNCoreMLModel?

    init() {
        loadModel()
    }

    /// Take a photo and recognize the object in it
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
            // Wait for auto-focus and auto-exposure
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

    // MARK: - MobileNetV2 Classification

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

            // Top result with readable name
            let topResults = results
                .prefix(3)
                .filter { $0.confidence > 0.05 }
                .map { observation -> String in
                    let name = observation.identifier
                        .components(separatedBy: ",")
                        .first?
                        .trimmingCharacters(in: .whitespaces) ?? observation.identifier
                    let confidence = Int(observation.confidence * 100)
                    return "\(name) \(confidence)%"
                }

            let description: String
            if topResults.isEmpty {
                description = "Cannot identify this object"
            } else {
                description = topResults.joined(separator: ", ")
            }

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
}

// MARK: - Photo Capture Delegate

private class PhotoDelegate: NSObject, AVCapturePhotoCaptureDelegate {
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
