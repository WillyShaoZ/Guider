# Guider — LiDAR Obstacle Detection for the Visually Impaired

## 1. Overview

> **Context**: This is a hackathon project. Speed of implementation and a working demo take priority over production polish.

Guider is a native iOS app that uses the iPhone's LiDAR sensor to detect obstacles in real-time and deliver haptic/audio feedback to visually impaired users. The phone is worn on the chest via a lanyard mount, continuously scanning the environment ahead — functioning like a parking radar for pedestrians.

It also features an Object Scan mode with AI-powered object recognition (Gemini API online, Apple Vision offline) and an emergency assistance system with drop detection.

**Target device**: iPhone Pro (12 Pro and later) with LiDAR scanner.

---

## 2. Problem Statement

| Fact | Source |
|------|--------|
| 253 million people worldwide live with visual impairment | WHO |
| Dedicated assistive hardware costs $300–600 | Smart canes, wearable devices |
| Most visually impaired users already own a smartphone | Global smartphone penetration |

**Opportunity**: Leverage hardware users already own (iPhone Pro LiDAR) to provide real-time obstacle avoidance at zero additional cost.

---

## 3. System Architecture

```
┌─────────────┐     ┌──────────────┐     ┌───────────────────┐     ┌──────────────┐
│  LiDAR +    │────▶│  ARKit       │────▶│  Obstacle          │────▶│  Feedback     │
│  TrueDepth  │     │  Depth Map   │     │  Detection Engine  │     │  Manager      │
│  (Pro only) │     │  (60 fps)    │     │                    │     │              │
└─────────────┘     └──────────────┘     │  - Region sampling │     │  ┌── Haptic  │
                                          │  - Ground filtering│     │  ├── Audio   │
                                          │  - Zone classify   │     │  └── Voice   │
                                          │  - Stair detect    │     └──────────────┘
                                          └───────────────────┘

┌─────────────┐     ┌──────────────┐     ┌───────────────────┐
│  Camera     │────▶│  Photo       │────▶│  Object            │────▶ Voice Announcement
│  (on tap)   │     │  Capture     │     │  Recognition       │
└─────────────┘     └──────────────┘     │  Online: Gemini AI │
                                          │  Offline: Apple    │
                                          │          Vision    │
                                          └───────────────────┘

┌─────────────┐     ┌──────────────┐     ┌───────────────────┐
│  ARKit      │────▶│  Y-Position  │────▶│  Emergency         │────▶ Call / Bystander Alert
│  Camera     │     │  Tracking    │     │  Assistant          │
│  Transform  │     │              │     │  + Speech Recognition│
└─────────────┘     └──────────────┘     └───────────────────┘
```

### Processing Pipeline (per frame)

1. **Capture** — ARKit provides a dense depth map from LiDAR at up to 60 fps
2. **Filter** — Discard ground plane using ARKit plane anchors
3. **Sample** — Divide the depth map into a 3x3 grid (left/center/right × top/mid/bottom)
4. **Classify** — Map the closest obstacle in each region to a distance zone
5. **Feedback** — Trigger haptic pattern + spatial audio based on zone and direction

---

## 4. Distance Zones & Feedback Model

| Zone | Distance | Haptic | Audio | Trigger |
|------|----------|--------|-------|---------|
| **Safe** | > 2.0 m | None | None | — |
| **Caution** | 1.0–2.0 m | Light pulse (1.5s interval) | Low tone, left/right panned | Closest obstacle enters zone |
| **Warning** | 0.5–1.0 m | Medium vibration (0.6s interval) | Mid tone, rapid | Closest obstacle enters zone |
| **Danger** | < 0.5 m | Strong burst (0.4s interval) | High tone + voice: "Obstacle, [direction]" | Immediate |

**Stair detection** triggers a distinct double-tap vibration pattern + voice alert ("Stairs ahead") regardless of distance zone.

---

## 5. Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Language** | Swift 5.9+ | Native ARKit/CoreHaptics/AVFoundation access |
| **UI** | SwiftUI | Declarative UI, VoiceOver-first design |
| **Depth Sensing** | ARKit + LiDAR | Real-time depth map, plane detection |
| **Object Recognition (Online)** | Gemini API (gemini-2.5-flash) | AI-powered image description |
| **Object Recognition (Offline)** | Apple Vision (VNClassifyImageRequest) | On-device classification (1000+ categories) |
| **Network Detection** | Network framework (NWPathMonitor) | Auto online/offline switching |
| **Haptic Engine** | Core Haptics | Fine-grained vibration patterns per zone |
| **Audio Engine** | AVAudioEngine | 3D spatial audio for directional cues |
| **Voice** | AVSpeechSynthesizer | All voice announcements |
| **Speech Recognition** | Speech framework | Emergency response + contact setup |
| **Contacts** | Contacts framework | Voice-guided emergency contact lookup |
| **Accessibility** | UIAccessibility | Full VoiceOver integration |

---

## 6. Project Structure

```
Guider/
├── App/
│   ├── GuiderApp.swift           # App entry, onboarding routing
│   ├── AppState.swift            # Global state, settings
│   └── AppIntents.swift          # Siri Shortcuts
├── Core/
│   ├── LiDARSessionManager.swift # ARKit session + depth streaming
│   ├── DepthProcessor.swift      # Depth map → 3x3 grid sampling
│   ├── ObstacleDetector.swift    # Zone classification engine
│   ├── StairDetector.swift       # Stair pattern detection
│   ├── MotionClassifier.swift    # Walking/stationary for adaptive frame rate
│   ├── ObjectRecognizer.swift    # Camera + online/offline recognition
│   ├── GeminiVisionService.swift # Gemini API client
│   ├── DropDetector.swift        # Phone fall detection via ARKit
│   └── EmergencyAssistant.swift  # Emergency flow + bystander guidance
├── Feedback/
│   ├── FeedbackManager.swift     # Coordinates haptic + audio + voice
│   ├── HapticEngine.swift        # Core Haptics patterns per zone
│   ├── SpatialAudioEngine.swift  # Spatial audio cues
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

---

## 7. Interaction Model

| Gesture | Navigation Mode | Object Scan |
|---------|----------------|------------|
| **Tap screen** | Pause / Resume scanning | Identify object |
| **Long press (0.8s)** | Switch to Object Scan | Switch to Navigation Mode |

Design principles:
- **No buttons to find** — the entire screen is the touch target
- **All state changes voice-announced** — user never needs to see the screen
- **Two gestures only** — tap and long press, nothing else to learn

---

## 8. Emergency Assistance

### Flow

```
Phone drop detected (ARKit Y-position drops 40cm+ in 0.5s)
  ↓
Strong haptic burst
  ↓
Voice: "Are you okay? Say yes, or say help."
  ↓
Listen for 10 seconds (SFSpeechRecognizer)
  ↓
┌─── "yes" / "okay" / "fine" → Resume scanning
├─── "help" / no response → Escalate:
│      ↓
│    Dial emergency contact (system call confirmation)
│      ↓
│    Loop every 10s: "Emergency. This person has fallen.
│    Please tap the blue Call button on screen."
│      (guides bystanders to help unconscious user)
└─── Tap screen → Dismiss, resume scanning
```

### Emergency Contact Setup (Onboarding)

1. Voice prompt: "Say the name of your emergency contact."
2. User says a name → app searches Contacts via `CNContactStore`
3. Voice confirms: "I found Mom, phone number 0412345678. Say yes to confirm."
4. Long press to skip

---

## 9. Key Technical Challenges

| Challenge | Impact | Mitigation |
|-----------|--------|------------|
| **Ground false positives** | High — constant false alerts | ARKit plane detection filters floor; height threshold (ignore below 30cm) |
| **Battery drain** | High — LiDAR + haptics is power-hungry | Adaptive frame rate (30fps walking, 15fps stationary) |
| **Stair detection accuracy** | Medium — critical safety feature | Depth gradient analysis + temporal filtering (3 consecutive frames) |
| **Feedback latency** | High — delay = danger | Target <50ms; pre-load haptic patterns; avoid main thread blocking |
| **Haptic engine invalidation** | Medium — stops after background | Auto-restart on foreground; nil-check before play |
| **Unconscious user emergency** | High — can't tap call button | Bystander guidance loop every 10s via voice |
| **Offline object recognition** | Medium — no internet available | Apple Vision on-device fallback; auto-switch via NWPathMonitor |

---

## 10. Target Users

- **Primary**: Visually impaired iPhone Pro users
- **Secondary**: Elderly users with declining vision
- **Tertiary**: Accessibility organizations and caregivers

---

## 11. Success Metrics

| Metric | Target |
|--------|--------|
| Detection latency (end-to-end) | < 50 ms |
| False positive rate | < 5% after ground filtering |
| Stair detection recall | > 90% |
| Battery life during continuous use | > 2 hours |
| Object recognition (online) | Natural language descriptions |
| Object recognition (offline) | Top-3 category labels |
| Emergency response time | < 15 seconds from drop to call |
