# Guider — Claude Code Guidelines

## Project Overview

Hackathon project: LiDAR-based obstacle detection iOS app for visually impaired users. Phone worn on chest, scans ahead, provides haptic/audio feedback. Daily mode identifies objects via Gemini AI (online) or Apple Vision (offline).

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI
- **Depth Sensing**: ARKit + LiDAR (iPhone Pro 12+)
- **Object Recognition**: Gemini API (online) / Apple Vision VNClassifyImageRequest (offline)
- **Feedback**: Core Haptics, AVAudioEngine (spatial audio), AVSpeechSynthesizer
- **Speech Recognition**: Speech framework (emergency + onboarding)
- **Contacts**: Contacts framework (voice-guided emergency contact setup)
- **Network**: NWPathMonitor for online/offline detection
- **Accessibility**: Full VoiceOver support required on all screens
- **Target**: iOS 17+, iPhone Pro with LiDAR

## Project Structure

```
Guider/
├── App/           # App entry point, global state, Siri shortcuts
├── Core/          # LiDAR session, depth processing, obstacle detection, stair detection,
│                  # object recognition (Gemini + Vision), drop detection, emergency
├── Feedback/      # Haptic engine, spatial audio, voice announcements
├── UI/            # SwiftUI views (main, onboarding, settings, permissions, debug)
├── Models/        # Data models (Obstacle, DistanceZone, FeedbackProfile)
├── Resources/     # ML models
├── Secrets.plist  # API keys (git-ignored)
└── Tests/         # Unit tests (moved to project root, not in app target)
```

## Architecture

Navigation: `LiDAR → ARKit Depth Map → 3x3 Grid Sampling → Zone Classification → Haptic/Audio Feedback`
Daily (Online): `Camera → JPEG → Gemini API → Description → Voice`
Daily (Offline): `Camera → JPEG → Apple Vision → Labels → Voice`
Emergency: `ARKit Camera Transform → Drop Detection → Voice Prompt → Speech Recognition → Call / Bystander Loop`

Four distance zones:
- Safe: > 2.0m (no feedback)
- Caution: 1.0–2.0m (light pulse)
- Warning: 0.5–1.0m (medium vibration)
- Danger: < 0.5m (strong vibration + voice alert)

## Code Conventions

- Use SwiftUI for all UI — no UIKit unless absolutely necessary
- All UI must be VoiceOver accessible — add `.accessibilityLabel()` and `.accessibilityHint()` to every interactive element
- Keep real-time processing off the main thread — use `Task`, `AsyncStream`, or Combine for LiDAR/depth pipeline
- Target < 50ms end-to-end latency from depth capture to feedback
- Pre-load Core Haptics patterns at startup — never create them on the fly during detection
- Use ARKit plane anchors to filter ground surfaces — ignore obstacles below 30cm height
- API keys must be stored in `Secrets.plist` (git-ignored), never hardcoded

## Key Decisions

- **No motion sensors** — no gyroscope, accelerometer, Core Motion, or IMU usage
- **LiDAR only** — no fallback for non-LiDAR devices
- **Hackathon scope** — prioritize working demo over polish
- **Online + Offline** — Gemini API for rich descriptions, Apple Vision for offline fallback
- **Two gestures only** — tap and long press, no complex interactions
- **Voice-first UX** — all setup and state changes are voice-announced

## Controls

- **Tap**: pause/resume (navigation) or identify object (daily)
- **Long press (0.8s)**: switch modes

## Testing

- Test depth processing with mock depth maps
- Test zone classification with known distances
- Test feedback manager triggers correct haptic/audio for each zone
- Run on physical iPhone Pro — LiDAR cannot be simulated

## Common Pitfalls

- ARKit sessions must run on the main thread for setup, but delegate callbacks should dispatch work off main
- Core Haptics engine can be invalidated by the system — always check engine state and auto-restart
- `AVAudioEngine` spatial audio requires headphones for proper left/right panning
- LiDAR depth map resolution is lower than camera — don't assume pixel-level precision
- Haptic engine stops when app enters background — re-prepare on foreground return
- `Secrets.plist` is git-ignored — new clones must create it manually with Gemini API key
