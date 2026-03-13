# Guider — LiDAR Obstacle Detection for the Visually Impaired

## 1. Overview

> **Context**: This is a hackathon project. Speed of implementation and a working demo take priority over production polish.

Guider is a native iOS app that uses the iPhone's LiDAR sensor to detect obstacles in real-time and deliver haptic/audio feedback to visually impaired users. The phone is worn on the chest via a lanyard mount, continuously scanning the environment ahead — functioning like a parking radar for pedestrians.

**Target device**: iPhone Pro (12 Pro and later) with LiDAR scanner.
**Fallback (stretch goal)**: Vision-based depth estimation (Depth Anything v2 via Core ML) for non-LiDAR iPhones, if time permits.

---

## 2. Problem Statement

| Fact | Source |
|------|--------|
| 253 million people worldwide live with visual impairment | WHO |
| Dedicated assistive hardware costs $300–600 | Smart canes, wearable devices |
| Most visually impaired users already own a smartphone | Global smartphone penetration |
| No mature LiDAR obstacle detection app exists in the Chinese market | App Store research |

**Opportunity**: Leverage hardware users already own (iPhone Pro LiDAR) to provide real-time obstacle avoidance at zero additional cost.

---

## 3. Fallback Strategy — Vision Depth Model (Stretch Goal)

If LiDAR is not available (non-Pro iPhone) and time permits, we fall back to **monocular depth estimation using a vision model**. The key insight is that a vision model outputs a depth map — the same format as LiDAR — so the entire detection pipeline remains unchanged.

```
LiDAR depth map (Pro)  ──┐
                          ├──▶  Obstacle Detection → Zones → Feedback
Vision depth map (All) ──┘
```

| | LiDAR (Primary) | Vision Model (Fallback) |
|---|---|---|
| **Model** | ARKit LiDAR Scanner | Depth Anything v2 via Core ML |
| **Depth type** | Absolute (meters) | Relative (needs calibration) |
| **Accuracy** | cm-level | ~10–30 cm error |
| **FPS** | 60 | 15–30 |
| **Low light** | Works (IR-based) | Degrades |
| **Device** | iPhone Pro only | Any iPhone |

The 4 distance zones (>2m / 1–2m / 0.5–1m / <0.5m) are coarse enough that the vision model can handle them without cm precision.

> **Priority**: This is a stretch goal. LiDAR is the primary focus for the hackathon. Vision fallback is only attempted if the core LiDAR pipeline is complete and stable.

---

## 4. System Architecture

```
┌─────────────┐     ┌──────────────┐
│  LiDAR +    │────▶│  ARKit       │──┐
│  TrueDepth  │     │  Depth Map   │  │
│  (Pro only) │     │  (60 fps)    │  │
└─────────────┘     └──────────────┘  │
                                      ├──▶ ┌───────────────────┐     ┌──────────────┐
┌─────────────┐     ┌──────────────┐  │    │  Obstacle          │────▶│  Feedback     │
│  Camera     │────▶│  Depth       │──┘    │  Detection Engine  │     │  Manager      │
│  (fallback) │     │  Anything v2 │       │                    │     │              │
│             │     │  (15-30 fps) │       │  - Region sampling │     │  ┌── Haptic  │
└─────────────┘     └──────────────┘       │  - Ground filtering│     │  │   (Core    │
                                           │  - Zone classify   │     │  │   Haptics) │
                                           │  - Stair detect    │     │  │           │
                                           └───────────────────┘     │  ├── Audio   │
                                                                      │  │   (Spatial │
                                                                      │  │   Audio)   │
                                                                      │  └── Voice   │
                                                                      │      (AVSpeech)│
                                                                      └──────────────┘
```

### Processing Pipeline (per frame)

1. **Capture** — ARKit provides a dense depth map from LiDAR at up to 60 fps
2. **Filter** — Discard ground plane using ARKit plane anchors
3. **Sample** — Divide the depth map into a 3x3 grid (left/center/right × top/mid/bottom)
4. **Classify** — Map the closest obstacle in each region to a distance zone
5. **Feedback** — Trigger haptic pattern + spatial audio based on zone and direction

---

## 5. Distance Zones & Feedback Model

| Zone | Distance | Haptic | Audio | Trigger |
|------|----------|--------|-------|---------|
| **Safe** | > 2.0 m | None | None | — |
| **Caution** | 1.0–2.0 m | Light pulse (0.5s interval) | Low tone, left/right panned | Closest obstacle enters zone |
| **Warning** | 0.5–1.0 m | Medium vibration (0.2s interval) | Mid tone, rapid | Closest obstacle enters zone |
| **Danger** | < 0.5 m | Strong continuous vibration | High tone + voice: "Obstacle, [direction]" | Immediate |

**Stair detection** triggers a distinct vibration pattern + voice alert ("Stairs ahead") regardless of distance zone.

---

## 6. Tech Stack

| Layer | Technology | Purpose |
|-------|-----------|---------|
| **Language** | Swift 5.9+ | Native ARKit/CoreHaptics/AVFoundation access |
| **UI** | SwiftUI | Declarative UI, VoiceOver-first design |
| **Depth Sensing** | ARKit + LiDAR | Real-time depth map, plane detection, scene geometry |
| **Depth Fallback** | Core ML + Depth Anything v2 | Vision-based depth for non-LiDAR iPhones (stretch goal) |
| **Haptic Engine** | Core Haptics | Fine-grained vibration patterns per zone |
| **Audio Engine** | AVAudioEngine | 3D spatial audio for directional cues |
| **Voice** | AVSpeechSynthesizer | Object/stair voice announcements |
| **ML (Phase 2)** | Core ML + Vision | Stair detection classifier, object recognition |
| **Accessibility** | UIAccessibility | Full VoiceOver integration |

### Why Native Swift?

- ARKit LiDAR API is **only available natively** — no cross-platform support
- Core Haptics requires native access for sub-millisecond vibration control
- Real-time 60fps depth processing demands minimal overhead
- VoiceOver accessibility works best with native UIKit/SwiftUI

---

## 7. Project Structure

```
Guider/
├── App/
│   ├── GuiderApp.swift              # App entry point
│   └── AppState.swift               # Global app state
├── Core/
│   ├── LiDARSessionManager.swift    # ARKit session + depth capture
│   ├── DepthProcessor.swift         # Depth map → obstacle grid
│   ├── ObstacleDetector.swift       # Zone classification engine
│   ├── StairDetector.swift          # ML-based stair detection
│   └── VisionDepthProvider.swift     # Fallback: Depth Anything v2 via Core ML (stretch goal)
├── Feedback/
│   ├── FeedbackManager.swift        # Coordinates haptic + audio
│   ├── HapticEngine.swift           # Core Haptics patterns
│   ├── SpatialAudioEngine.swift     # 3D audio cues
│   └── VoiceAnnouncer.swift         # Speech announcements
├── UI/
│   ├── MainView.swift               # Primary scanning view
│   ├── SettingsView.swift           # User preferences
│   ├── OnboardingView.swift         # First-launch tutorial
│   └── DebugOverlayView.swift       # Dev-only depth visualization
├── Models/
│   ├── Obstacle.swift               # Obstacle data model
│   ├── DistanceZone.swift           # Zone enum + thresholds
│   └── FeedbackProfile.swift        # User feedback preferences
├── Resources/
│   ├── StairDetector.mlmodel        # Core ML stair classifier
│   ├── DepthAnythingV2.mlmodel      # Vision depth model (stretch goal)
│   └── Audio/                       # Spatial audio assets
└── Tests/
    ├── DepthProcessorTests.swift
    ├── ObstacleDetectorTests.swift
    └── FeedbackManagerTests.swift
```

---

## 8. Development Roadmap

### Phase 1 — Core Detection (Weeks 1–3)

| Task | Description | Priority |
|------|-------------|----------|
| ARKit LiDAR session | Set up depth capture at 60fps | P0 |
| Depth processing | Sample center region, compute min distance | P0 |
| Ground filtering | Use ARKit plane anchors to ignore floor | P0 |
| Zone classification | Map distance → 4 zones | P0 |
| Haptic feedback | 4 distinct vibration patterns | P0 |
| Basic UI | Start/stop button, VoiceOver labels | P0 |

**Deliverable**: App detects obstacles ahead and vibrates with intensity proportional to distance.

### Phase 2 — Spatial Feedback (Weeks 4–5)

| Task | Description | Priority |
|------|-------------|----------|
| 3x3 grid sampling | Detect obstacle direction (left/center/right) | P0 |
| Spatial audio | Pan audio cues based on obstacle position | P0 |
| Stair detection | Train + integrate Core ML classifier | P0 |
| Voice announcements | "Obstacle left", "Stairs ahead" | P1 |
| Settings screen | Sensitivity, feedback mode, volume | P1 |

**Deliverable**: App provides directional feedback and warns about stairs.

### Phase 3 — Polish & Ship (Weeks 6–8)

| Task | Description | Priority |
|------|-------------|----------|
| Onboarding flow | Accessible tutorial for first-time users | P0 |
| Battery optimization | Adaptive frame rate (30fps walking, 15fps standing) | P0 |
| Object recognition | Identify common obstacles (chair, pole, person) | P1 |
| Volume button shortcuts | Physical button to toggle modes | P1 |
| Beta testing | Test with visually impaired users | P0 |
| App Store submission | Metadata, screenshots, accessibility review | P0 |
| **Vision depth fallback** | Integrate Depth Anything v2 for non-LiDAR devices | **Stretch** |

**Deliverable**: Production-ready app on the App Store. Vision fallback if time permits.

---

## 9. Key Technical Challenges

| Challenge | Impact | Mitigation |
|-----------|--------|------------|
| **Ground false positives** | High — constant false alerts | ARKit plane detection filters floor; height threshold (ignore below 30cm) |
| **Chest mount instability** | High — noisy depth readings | Temporal smoothing (rolling average over 5 frames) |
| **Battery drain** | High — LiDAR + haptics is power-hungry | Adaptive frame rate; process only center 60% of depth map |
| **Stair detection accuracy** | Medium — critical safety feature | Dedicated Core ML model; supplement with depth gradient analysis |
| **Outdoor sunlight interference** | Medium — LiDAR degrades in direct sunlight | Fuse LiDAR depth with camera-based depth hints from ARKit |
| **Feedback latency** | High — delay = danger | Target <50ms end-to-end; pre-load haptic patterns; avoid main thread blocking |

---

## 10. Competitor Landscape

| App | Approach | Key Limitation | Our Advantage |
|-----|----------|---------------|---------------|
| Super Lidar | LiDAR audio mapping | No haptic feedback | Multi-modal feedback (haptic + spatial audio + voice) |
| Obstacle Detector | LiDAR + basic vibration | Single vibration level | 4-zone graduated haptic response |
| EyeGuide | LiDAR + voice prompts | No directional cues | Spatial audio panning (left/center/right) |
| Be My Eyes | Human volunteers | Not real-time | Autonomous real-time detection |
| 轻松无障碍 | Camera, 10s intervals | Not real-time | 60fps continuous scanning |

---

## 11. Target Users

- **Primary**: Visually impaired iPhone Pro users
- **Secondary**: Elderly users with declining vision
- **Tertiary**: Accessibility organizations and caregivers

---

## 12. Success Metrics

| Metric | Target |
|--------|--------|
| Detection latency (end-to-end) | < 50 ms |
| False positive rate | < 5% after ground filtering |
| Stair detection recall | > 90% |
| Battery life during continuous use | > 2 hours |
| App Store accessibility rating | Full VoiceOver compliance |
| Beta tester satisfaction | > 80% "would use daily" |

---

## 13. Summary

| Dimension | Assessment |
|-----------|------------|
| **Technical Feasibility** | High — ARKit LiDAR APIs are mature, well-documented, 60fps capable |
| **Implementation Difficulty** | Medium — MVP in 3 weeks; main challenge is tuning feedback UX |
| **User Value** | High — zero additional hardware cost, solves real daily safety needs |
| **Market Opportunity** | Strong — Chinese market has no mature LiDAR obstacle detection app |
| **Biggest Risk** | Social acceptance of wearing phone on chest; LiDAR-only limits to Pro devices (vision fallback mitigates if time permits) |
