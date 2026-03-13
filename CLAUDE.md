# Guider — Claude Code Guidelines

## Project Overview

Hackathon project: LiDAR-based obstacle detection iOS app for visually impaired users. Phone worn on chest, scans ahead, provides haptic/audio feedback. See `docs/PROJECT_PROPOSAL.md` for full details.

## Tech Stack

- **Language**: Swift 5.9+
- **UI**: SwiftUI
- **Primary sensor**: ARKit + LiDAR (iPhone Pro 12+)
- **Fallback (stretch goal)**: Depth Anything v2 via Core ML for non-LiDAR devices
- **Feedback**: Core Haptics, AVAudioEngine (spatial audio), AVSpeechSynthesizer
- **Accessibility**: Full VoiceOver support required on all screens
- **Target**: iOS 17+, iPhone Pro with LiDAR

## Project Structure

```
Guider/
├── App/           # App entry point, global state
├── Core/          # LiDAR session, depth processing, obstacle detection, stair detection
├── Feedback/      # Haptic engine, spatial audio, voice announcements
├── UI/            # SwiftUI views (main, settings, onboarding, debug overlay)
├── Models/        # Data models (Obstacle, DistanceZone, FeedbackProfile)
├── Resources/     # ML models, audio assets
└── Tests/         # Unit tests
```

## Architecture

Pipeline: `LiDAR → ARKit Depth Map → 3x3 Grid Sampling → Zone Classification → Haptic/Audio Feedback`

Four distance zones:
- Safe: > 2.0m (no feedback)
- Caution: 1.0–2.0m (light pulse + low tone)
- Warning: 0.5–1.0m (medium vibration + mid tone)
- Danger: < 0.5m (strong vibration + voice alert)

## Code Conventions

- Use SwiftUI for all UI — no UIKit unless absolutely necessary
- All UI must be VoiceOver accessible — add `.accessibilityLabel()` and `.accessibilityHint()` to every interactive element
- Keep real-time processing off the main thread — use `Task`, `AsyncStream`, or Combine for LiDAR/depth pipeline
- Target < 50ms end-to-end latency from depth capture to feedback
- Pre-load Core Haptics patterns at startup — never create them on the fly during detection
- Use ARKit plane anchors to filter ground surfaces — ignore obstacles below 30cm height

## Key Decisions

- **No motion sensors** — no gyroscope, accelerometer, Core Motion, or IMU usage
- **LiDAR first** — vision model fallback is a stretch goal only, do not prioritize it over core LiDAR features
- **Hackathon scope** — prioritize working demo over polish; no business model, no analytics
- **Local processing only** — no network calls, no cloud APIs, everything runs on-device

## Testing

- Test depth processing with mock depth maps
- Test zone classification with known distances
- Test feedback manager triggers correct haptic/audio for each zone
- Run on physical iPhone Pro — LiDAR cannot be simulated

## Common Pitfalls

- ARKit sessions must run on the main thread for setup, but delegate callbacks should dispatch work off main
- Core Haptics engine can be invalidated by the system — always check engine state before playing patterns
- `AVAudioEngine` spatial audio requires headphones for proper left/right panning
- LiDAR depth map resolution is lower than camera — don't assume pixel-level precision
