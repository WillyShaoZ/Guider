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
        frameSubject.send(frame)

        if let depthData = frame.smoothedSceneDepth ?? frame.sceneDepth {
            depthSubject.send(depthData)
        }
    }

    func session(_ session: ARSession, didFailWithError error: Error) {
        print("[LiDAR] Session error: \(error.localizedDescription)")
    }
}
