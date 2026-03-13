import ARKit
import Combine

final class LiDARSessionManager: NSObject, ObservableObject {
    let session = ARSession()
    let depthSubject = PassthroughSubject<ARDepthData, Never>()
    let frameSubject = PassthroughSubject<ARFrame, Never>()

    @Published var isRunning = false
    @Published var isLiDARAvailable = false

    override init() {
        super.init()
        isLiDARAvailable = ARWorldTrackingConfiguration.supportsFrameSemantics(.sceneDepth)
        session.delegate = self
    }

    func start() {
        guard isLiDARAvailable else {
            print("[LiDAR] LiDAR not available on this device")
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
