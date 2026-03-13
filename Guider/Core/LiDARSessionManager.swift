import ARKit
import AVFoundation
import Combine

final class LiDARSessionManager: NSObject, ObservableObject {
    let session = ARSession()
    let depthSubject = PassthroughSubject<ARDepthData, Never>()
    let frameSubject = PassthroughSubject<ARFrame, Never>()

    @Published var isRunning = false
    @Published var isLiDARAvailable = false
    @Published var cameraPermission: AVAuthorizationStatus
    @Published var micPermission: AVAuthorizationStatus
    @Published var groundPlaneY: Float?

    // Adaptive frame rate
    private let motionClassifier = MotionClassifier()
    private var frameCounter = 0

    var allPermissionsGranted: Bool {
        cameraPermission == .authorized && micPermission == .authorized
    }

    override init() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
        super.init()
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        session.delegate = self
    }

    func requestPermissions() async {
        let cameraGranted = await AVCaptureDevice.requestAccess(for: .video)
        await MainActor.run {
            cameraPermission = cameraGranted ? .authorized : .denied
        }

        let micGranted = await AVCaptureDevice.requestAccess(for: .audio)
        await MainActor.run {
            micPermission = micGranted ? .authorized : .denied
        }
    }

    func refreshPermissions() {
        cameraPermission = AVCaptureDevice.authorizationStatus(for: .video)
        micPermission = AVCaptureDevice.authorizationStatus(for: .audio)
    }

    func start() {
        guard isLiDARAvailable else {
            print("[LiDAR] LiDAR not available on this device")
            return
        }

        guard cameraPermission == .authorized else {
            print("[LiDAR] Camera permission not granted")
            return
        }

        let config = ARWorldTrackingConfiguration()
        config.frameSemantics = [.sceneDepth, .smoothedSceneDepth]
        config.planeDetection = [.horizontal]

        session.run(config)
        isRunning = true
        print("[LiDAR] Session started")
    }

    func stop() {
        session.pause()
        isRunning = false
        print("[LiDAR] Session paused")
    }
}

extension LiDARSessionManager: ARSessionDelegate {
    func session(_ session: ARSession, didUpdate frame: ARFrame) {
        // Always send frames at full rate (DropDetector needs high temporal resolution)
        frameSubject.send(frame)

        // Extract ground plane Y from horizontal plane anchors
        let horizontalPlanes = frame.anchors.compactMap { $0 as? ARPlaneAnchor }.filter { $0.alignment == .horizontal }
        if let lowestPlane = horizontalPlanes.min(by: { $0.transform.columns.3.y < $1.transform.columns.3.y }) {
            DispatchQueue.main.async { [weak self] in
                self?.groundPlaneY = lowestPlane.transform.columns.3.y
            }
        }

        // Adaptive frame rate: walking = every 2nd frame (~30fps), stationary = every 4th (~15fps)
        let motionState = motionClassifier.classify(frame: frame)
        let skipRate = motionState == .walking ? 2 : 4
        frameCounter += 1

        if frameCounter % skipRate == 0 {
            if let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth {
                depthSubject.send(depthData)
            }
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[LiDAR] Session error: \(error.localizedDescription)")
    }
}
