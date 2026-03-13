import SwiftUI

struct DebugOverlayView: View {
    @EnvironmentObject var appState: AppState

    var body: some View {
        VStack(alignment: .leading, spacing: 4) {
            Text("DEBUG")
                .font(.caption2.bold())
                .foregroundColor(.white)

            Text("Zone: \(appState.currentZone.label)")
                .font(.caption2.monospaced())
                .foregroundColor(debugColor)

            Text(String(format: "Dist: %.2f m", appState.closestDistance))
                .font(.caption2.monospaced())
                .foregroundColor(.white)

            Text("Dir: \(appState.closestDirection.rawValue)")
                .font(.caption2.monospaced())
                .foregroundColor(.white)

            Text("Obstacles: \(appState.detectionResult.obstacles.count)")
                .font(.caption2.monospaced())
                .foregroundColor(.white)
        }
        .padding(8)
        .background(Color.black.opacity(0.7))
        .cornerRadius(8)
        .accessibilityHidden(true)
    }

    private var debugColor: Color {
        switch appState.currentZone {
        case .safe: return .green
        case .caution: return .yellow
        case .warning: return .orange
        case .danger: return .red
        }
    }
}
