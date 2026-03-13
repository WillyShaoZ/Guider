import ARKit
import Combine

/// Detects phone drops by monitoring the device's Y-position from ARKit's camera transform.
/// When the device falls rapidly (Y drops significantly over a short window), it fires a drop event.
final class DropDetector: ObservableObject {
    let dropSubject = PassthroughSubject<Void, Never>()
    @Published var isDropDetected = false

    private var cancellables = Set<AnyCancellable>()
    private var positionHistory: [(y: Float, time: TimeInterval)] = []

    // Tuning parameters
    private let historyWindow: TimeInterval = 0.5    // Track positions over 0.5s
    private let dropThreshold: Float = 0.4            // 40cm drop in the window = fall
    private let cooldownInterval: TimeInterval = 10.0 // Don't re-trigger for 10s after a drop
    private var lastDropTime: Date = .distantPast

    func bind(to lidarManager: LiDARSessionManager) {
        cancellables.removeAll()
        positionHistory.removeAll()

        lidarManager.frameSubject
            .receive(on: DispatchQueue(label: "com.guider.dropdetector", qos: .userInteractive))
            .sink { [weak self] frame in
                self?.processFrame(frame)
            }
            .store(in: &cancellables)
    }

    func reset() {
        positionHistory.removeAll()
        isDropDetected = false
    }

    func acknowledge() {
        isDropDetected = false
    }

    private func processFrame(_ frame: ARFrame) {
        let transform = frame.camera.transform
        let y = transform.columns.3.y  // Device Y position in world space (meters)
        let time = frame.timestamp

        positionHistory.append((y: y, time: time))

        // Trim history to window
        positionHistory.removeAll { time - $0.time > historyWindow }

        guard positionHistory.count >= 2 else { return }

        // Check if Y has dropped significantly from the max in the window
        let maxY = positionHistory.map(\.y).max() ?? y
        let drop = maxY - y

        if drop >= dropThreshold {
            let now = Date()
            guard now.timeIntervalSince(lastDropTime) > cooldownInterval else { return }
            lastDropTime = now

            positionHistory.removeAll()

            DispatchQueue.main.async { [weak self] in
                guard let self else { return }
                self.isDropDetected = true
                self.dropSubject.send()
                print("[DropDetector] Drop detected! Y dropped \(String(format: "%.2f", drop))m in \(self.historyWindow)s")
            }
        }
    }
}
