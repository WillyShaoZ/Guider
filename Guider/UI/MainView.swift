import SwiftUI

struct MainView: View {
    @EnvironmentObject var appState: AppState
    @StateObject private var lidarManager = LiDARSessionManager()
    @StateObject private var detector = ObstacleDetector()
    @StateObject private var feedbackManager = FeedbackManager()
    @State private var showSettings = false

    var body: some View {
        ZStack {
            backgroundColor
                .ignoresSafeArea()

            VStack(spacing: 40) {
                Spacer()

                // Zone indicator
                zoneDisplay

                // Distance readout
                distanceDisplay

                // Direction indicator
                directionDisplay

                Spacer()

                // Main scan button
                scanButton

                // Settings button
                settingsButton
            }
            .padding()
        }
        .sheet(isPresented: $showSettings) {
            SettingsView()
        }
        .onAppear {
            feedbackManager.prepare()
            detector.bind(to: lidarManager)
            feedbackManager.bind(to: detector)
            bindDetectionToState()
        }
        .onDisappear {
            stopScanning()
            feedbackManager.shutdown()
        }
    }

    // MARK: - Zone Display

    private var zoneDisplay: some View {
        VStack(spacing: 8) {
            Image(systemName: zoneIcon)
                .font(.system(size: 80))
                .foregroundColor(zoneColor)
                .accessibilityHidden(true)

            Text(appState.currentZone.label)
                .font(.system(size: 36, weight: .bold))
                .foregroundColor(zoneColor)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Zone: \(appState.currentZone.label)")
    }

    private var zoneIcon: String {
        switch appState.currentZone {
        case .safe: return "checkmark.shield.fill"
        case .caution: return "exclamationmark.triangle"
        case .warning: return "exclamationmark.triangle.fill"
        case .danger: return "xmark.octagon.fill"
        }
    }

    private var zoneColor: Color {
        switch appState.currentZone {
        case .safe: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .danger: return .red
        }
    }

    private var backgroundColor: Color {
        switch appState.currentZone {
        case .safe: return Color(.systemBackground)
        case .caution: return Color.yellow.opacity(0.05)
        case .warning: return Color.orange.opacity(0.1)
        case .danger: return Color.red.opacity(0.15)
        }
    }

    // MARK: - Distance Display

    private var distanceDisplay: some View {
        Group {
            if appState.closestDistance < 5.0 {
                Text(String(format: "%.1f m", appState.closestDistance))
                    .font(.system(size: 64, weight: .light, design: .monospaced))
                    .foregroundColor(.primary)
                    .accessibilityLabel(String(format: "%.1f meters", appState.closestDistance))
            } else {
                Text("Clear")
                    .font(.system(size: 48, weight: .light))
                    .foregroundColor(.secondary)
                    .accessibilityLabel("Path is clear")
            }
        }
    }

    // MARK: - Direction Display

    private var directionDisplay: some View {
        HStack(spacing: 30) {
            directionArrow(.left)
            directionArrow(.center)
            directionArrow(.right)
        }
        .accessibilityElement(children: .combine)
        .accessibilityLabel("Closest obstacle: \(appState.closestDirection.rawValue)")
    }

    private func directionArrow(_ direction: ObstacleDirection) -> some View {
        let isActive = appState.isScanning && appState.closestDirection == direction && appState.closestDistance < 5.0

        return Image(systemName: directionIcon(direction))
            .font(.system(size: 30))
            .foregroundColor(isActive ? zoneColor : .gray.opacity(0.3))
    }

    private func directionIcon(_ direction: ObstacleDirection) -> String {
        switch direction {
        case .left: return "arrow.left.circle.fill"
        case .center: return "arrow.up.circle.fill"
        case .right: return "arrow.right.circle.fill"
        }
    }

    // MARK: - Scan Button

    private var scanButton: some View {
        Button(action: toggleScanning) {
            HStack(spacing: 12) {
                Image(systemName: appState.isScanning ? "stop.fill" : "play.fill")
                Text(appState.isScanning ? "Stop Scanning" : "Start Scanning")
                    .font(.headline)
            }
            .frame(maxWidth: .infinity)
            .padding(.vertical, 20)
            .background(appState.isScanning ? Color.red : Color.blue)
            .foregroundColor(.white)
            .cornerRadius(16)
        }
        .accessibilityLabel(appState.isScanning ? "Stop scanning" : "Start scanning")
        .accessibilityHint(appState.isScanning ? "Stops obstacle detection" : "Begins detecting obstacles ahead")
    }

    private var settingsButton: some View {
        Button(action: { showSettings = true }) {
            Image(systemName: "gearshape")
                .font(.title2)
                .foregroundColor(.secondary)
        }
        .accessibilityLabel("Settings")
    }

    // MARK: - Actions

    private func toggleScanning() {
        if appState.isScanning {
            stopScanning()
        } else {
            startScanning()
        }
    }

    private func startScanning() {
        lidarManager.start()
        appState.isScanning = true
        feedbackManager.hapticEnabled = appState.hapticEnabled
        feedbackManager.audioEnabled = appState.audioEnabled
        feedbackManager.voiceEnabled = appState.voiceEnabled
    }

    private func stopScanning() {
        lidarManager.stop()
        detector.reset()
        feedbackManager.stop()
        appState.isScanning = false
        appState.currentZone = .safe
        appState.closestDistance = .infinity
    }

    private func bindDetectionToState() {
        detector.detectionSubject
            .receive(on: DispatchQueue.main)
            .sink { result in
                appState.detectionResult = result
                appState.currentZone = result.overallZone
                appState.closestDistance = result.closestObstacle?.distance ?? .infinity
                appState.closestDirection = result.closestObstacle?.direction ?? .center
            }
            .store(in: &cancellables)
    }

    // Need to store cancellables — use a wrapper since View is a struct
    @State private var cancellables = Set<AnyCancellable>()
}
