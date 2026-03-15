# Guider

**LiDAR obstacle detection + AI object recognition for visually impaired users.**

Guider turns an iPhone Pro into a wearable navigation assistant. Wear it on your chest — it scans ahead with LiDAR, vibrates when obstacles are near, and speaks to tell you what's around you.

## Features

### Navigation Mode (Default)
- Real-time obstacle detection using **LiDAR** at 60fps
- **4-zone distance feedback**: Safe (>2m), Caution (1-2m), Warning (0.5-1m), Danger (<0.5m)
- **Haptic vibration** with intensity proportional to distance
- **Voice announcements**: "Obstacle left", "Obstacle right"
- 3x3 grid depth sampling for directional awareness (left / center / right)
- **Stair detection** with distinct double-tap vibration pattern
- Ground plane filtering via ARKit to reduce false positives
- **Adaptive frame rate** — faster scanning when walking, slower when stationary

### Object Scan
- **Tap to identify** — camera captures and recognizes what's in front of you
- **Online mode**: Gemini AI provides detailed natural language descriptions
- **Offline mode**: Apple Vision framework classifies 1000+ object categories on-device
- Automatic online/offline switching — no user action needed
- Voice announces results automatically

### Safety — Drop Detection & Emergency
- **Phone drop detection** using ARKit camera position tracking
- Voice prompt: "Are you okay? Say yes, or say help."
- **Speech recognition** listens for response (10 second window)
- If no response or "help": auto-calls emergency contact
- **Bystander guidance loop**: repeats "Please tap the blue Call button on screen" every 10 seconds for nearby people to help unconscious users
- Loud bystander alert if no emergency contact is set

### Emergency Contact Setup (Onboarding)
- **Voice-guided setup** during first launch
- Say a contact name → app searches your Contacts automatically
- Voice confirms: "I found Mom, phone number 0412345678. Say yes to confirm."
- Long press to skip — can be set up later

### Accessibility-First Design
- **No buttons to find** — tap anywhere to interact
- **Long press** to switch between Navigation and Object Scan modes
- All state changes voice-announced
- Full VoiceOver support
- High contrast UI for low-vision users

## Controls

| Gesture | Navigation Mode | Object Scan |
|---------|----------------|------------|
| **Tap screen** | Pause / Resume scanning | Identify object |
| **Long press (0.8s)** | Switch to Object Scan | Switch to Navigation Mode |

## Tech Stack

| Component | Technology |
|-----------|-----------|
| Language | Swift 5.9+ |
| UI | SwiftUI |
| Depth Sensing | ARKit + LiDAR |
| Object Recognition (Online) | Gemini API (gemini-2.5-flash) |
| Object Recognition (Offline) | Apple Vision (VNClassifyImageRequest) |
| Network Detection | Network framework (NWPathMonitor) |
| Haptics | Core Haptics |
| Voice | AVSpeechSynthesizer |
| Speech Recognition | Speech framework |
| Contacts | Contacts framework |

## Requirements

- **iPhone Pro 12 or later** (LiDAR required for Navigation mode)
- **iOS 17.0+**
- Camera, microphone, speech recognition, and contacts permissions

## Setup

### 1. Clone & Open

```bash
git clone https://github.com/WillyShaoZ/Guider.git
cd Guider
open Guider.xcodeproj
```

### 2. Configure Gemini API Key

The Gemini API key is stored in `Guider/Secrets.plist` which is **not included in the repository** for security.

To set up:

1. Go to [Google AI Studio](https://aistudio.google.com/apikey) and generate a free API key
2. Create the file `Guider/Secrets.plist`:

```xml
<?xml version="1.0" encoding="UTF-8"?>
<!DOCTYPE plist PUBLIC "-//Apple//DTD PLIST 1.0//EN" "http://www.apple.com/DTDs/PropertyList-1.0.dtd">
<plist version="1.0">
<dict>
	<key>GEMINI_API_KEY</key>
	<string>YOUR_API_KEY_HERE</string>
	<key>EMERGENCY_SMS_WEBHOOK_URL</key>
	<string>https://your-server.com/api/send-emergency-sms</string>
	<key>EMERGENCY_SMS_AUTH_TOKEN</key>
	<string>optional-bearer-token</string>
</dict>
</plist>
```

3. Make sure `Secrets.plist` is visible in Xcode's project navigator under the Guider folder

> **Note:** Without the API key, Object Scan will automatically use offline recognition (Apple Vision). Online mode provides much richer descriptions.
> **Note:** For hands-free emergency SMS, set `EMERGENCY_SMS_WEBHOOK_URL` to a backend endpoint that accepts JSON `{ "to": "...", "message": "..." }` and sends SMS server-side.

### 3. Build & Run

1. Select your **Team** in Signing & Capabilities
2. Connect an **iPhone Pro** via USB
3. Trust the developer certificate on the iPhone (Settings → General → VPN & Device Management)
4. Press `Cmd + R` to build and run

## Project Structure

```
Guider/
├── App/
│   ├── GuiderApp.swift           # App entry, onboarding flow
│   ├── AppState.swift            # Global state, settings
│   └── AppIntents.swift          # Siri Shortcuts
├── Core/
│   ├── LiDARSessionManager.swift # ARKit session + depth streaming
│   ├── DepthProcessor.swift      # Depth map → 3x3 grid sampling
│   ├── ObstacleDetector.swift    # Zone classification engine
│   ├── StairDetector.swift       # Stair pattern detection
│   ├── MotionClassifier.swift    # Walking/stationary classification
│   ├── ObjectRecognizer.swift    # Camera + online/offline recognition
│   ├── GeminiVisionService.swift # Gemini API client
│   ├── DropDetector.swift        # Phone fall detection via ARKit
│   └── EmergencyAssistant.swift  # Emergency flow + bystander guidance
├── Feedback/
│   ├── FeedbackManager.swift     # Coordinates haptic + audio + voice
│   ├── HapticEngine.swift        # Core Haptics patterns per zone
│   ├── SpatialAudioEngine.swift  # Spatial audio
│   └── VoiceAnnouncer.swift      # Speech announcements
├── Models/
│   ├── DistanceZone.swift        # Zone enum + thresholds
│   ├── FeedbackProfile.swift     # Feedback configuration
│   └── Obstacle.swift            # Obstacle data model
├── Resources/
│   └── MobileNetV2FP16.mlmodel   # Backup classification model
├── UI/
│   ├── MainView.swift            # Dual-mode main interface
│   ├── OnboardingView.swift      # Voice-guided first launch + emergency contact
│   ├── PermissionView.swift      # Voice-guided permission flow
│   ├── SettingsView.swift        # Emergency contact manual setup
│   └── DebugOverlayView.swift    # Dev-only depth visualization
├── Secrets.plist                 # API keys (git-ignored)
└── Info.plist
```

## Architecture

```
Navigation Mode:
  LiDAR → ARKit Depth Map → 3x3 Grid Sampling → Zone Classification → Haptic/Voice Feedback
  ARKit Plane Anchors → Stair Detection → Double-tap Vibration Alert

Object Scan (Online):
  Camera → JPEG → Gemini API → Natural Language Description → Voice Announcement

Object Scan (Offline):
  Camera → JPEG → Apple Vision VNClassifyImageRequest → Top Labels → Voice Announcement

Emergency:
  ARKit Camera Transform → Y-Position Drop → Voice Prompt → Speech Recognition → Call / Bystander Alert Loop
```

## Docs

- [Project Proposal](docs/PROJECT_PROPOSAL.md) — full technical specification
- [User Guide](docs/USER_GUIDE.md) — how to use Guider

## License

This is a hackathon project. All rights reserved.
