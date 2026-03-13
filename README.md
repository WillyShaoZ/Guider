# Guider

**LiDAR obstacle detection + object recognition for visually impaired users.**

Guider turns an iPhone Pro into a wearable navigation assistant. Wear it on your chest — it scans ahead with LiDAR, vibrates when obstacles are near, and speaks to tell you what's around you.

## Features

### Navigation Mode
- Real-time obstacle detection using **LiDAR** at 60fps
- **4-zone distance feedback**: Safe (>2m), Caution (1-2m), Warning (0.5-1m), Danger (<0.5m)
- **Haptic vibration** with intensity proportional to distance
- **Voice announcements**: "Obstacle left", "Obstacle right"
- 3x3 grid depth sampling for directional awareness (left / center / right)
- Ground plane filtering via ARKit to reduce false positives

### Daily Mode
- **Object recognition** powered by MobileNetV2 (1000+ categories)
- Tap to capture — camera only active during identification
- Auto-focus, auto-flash for best results
- Voice announces results: "water bottle 92%"

### Safety
- **Phone drop detection** using ARKit camera position tracking
- Voice prompt: "Are you okay? Say yes, or say help."
- **Speech recognition** listens for response (10 second window)
- Auto-calls emergency contact if no response
- Loud bystander alert if no contact is set

### Accessibility-First Design
- **No buttons to find** — tap anywhere to interact
- All state changes voice-announced
- Full VoiceOver support
- High contrast UI for low-vision users
- Back Tap and Siri Shortcuts for hands-free control

## Controls

| Gesture | Navigation Mode | Daily Mode |
|---------|----------------|------------|
| **Tap screen** | Pause / Resume | Identify object |
| **Double tap back** | Pause / Resume | Identify object |
| **Triple tap back** | Switch to Daily | Switch to Navigation |
| **"Hey Siri, open Guider"** | Launch app | Launch app |

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Depth Sensing | ARKit + LiDAR |
| Object Recognition | Core ML + MobileNetV2 |
| Haptics | Core Haptics |
| Voice | AVSpeechSynthesizer |
| Speech Recognition | Speech framework |
| Shortcuts | App Intents + URL Schemes |

## Requirements

- **iPhone Pro 12 or later** (LiDAR required for Navigation mode)
- **iOS 17.0+**
- Camera and microphone permissions

## Project Structure

```
Guider/
├── App/
│   ├── GuiderApp.swift           # App entry point, URL scheme handler
│   ├── AppState.swift            # Global state, mode management
│   └── AppIntents.swift          # Siri Shortcuts, notifications
├── Core/
│   ├── LiDARSessionManager.swift # ARKit session + depth streaming
│   ├── DepthProcessor.swift      # Depth map → 3x3 grid sampling
│   ├── ObstacleDetector.swift    # Zone classification engine
│   ├── ObjectRecognizer.swift    # Camera capture + MobileNetV2
│   ├── DropDetector.swift        # Phone fall detection via ARKit
│   └── EmergencyAssistant.swift  # Emergency flow + speech recognition
├── Feedback/
│   ├── FeedbackManager.swift     # Coordinates haptic + audio + voice
│   ├── HapticEngine.swift        # Core Haptics patterns per zone
│   ├── SpatialAudioEngine.swift  # Spatial audio (currently disabled)
│   └── VoiceAnnouncer.swift      # Speech announcements
├── Models/
│   ├── DistanceZone.swift        # Zone enum + thresholds
│   └── Obstacle.swift            # Obstacle data model
├── Resources/
│   └── MobileNetV2FP16.mlmodel   # Object classification model
├── UI/
│   ├── MainView.swift            # Dual-mode main interface
│   ├── PermissionView.swift      # Voice-guided permission flow
│   ├── SettingsView.swift        # Emergency contact setup
│   └── DebugOverlayView.swift    # Dev-only depth visualization
└── Info.plist
```

## Build & Run

```bash
# Install xcodegen (if not installed)
brew install xcodegen

# Generate Xcode project
cd Guider
xcodegen generate

# Open in Xcode
open Guider.xcodeproj
```

1. Select your **Team** in Signing & Capabilities
2. Connect an **iPhone Pro** via USB
3. Trust the developer certificate on the iPhone (Settings → General → VPN & Device Management)
4. Press `Cmd + R` to build and run

## Back Tap Setup

To control Guider by tapping the back of your iPhone:

1. Open **Shortcuts** app → create two shortcuts:
   - **"Guider Pause"**: Open URLs → `guider://pause`
   - **"Switch Guider Mode"**: Open URLs → `guider://switch`
2. Go to **Settings → Accessibility → Touch → Back Tap**
3. **Double Tap** → Guider Pause
4. **Triple Tap** → Switch Guider Mode

## Architecture

```
LiDAR → ARKit Depth Map → 3x3 Grid Sampling → Zone Classification → Haptic/Voice Feedback
Camera → MobileNetV2 → Object Label → Voice Announcement
ARKit Camera Transform → Y-Position Monitoring → Drop Detection → Emergency Flow
```

## Key Design Decisions

- **No motion sensors** — no gyroscope/accelerometer/IMU usage
- **Local processing only** — no network calls, everything on-device
- **Always-on feedback** — haptic, audio, and voice are always enabled (no settings toggles)
- **Battery-conscious haptics** — reduced vibration frequency with interval-based patterns
- **Camera on-demand** — Daily mode camera only active during identification

## Docs

- [Project Proposal](docs/PROJECT_PROPOSAL.md) — full technical specification
- [User Guide](docs/USER_GUIDE.md) — how to use Guider
- [Development Summary](docs/SUMMARY.md) — work completed so far

## License

This is a hackathon project. All rights reserved.
