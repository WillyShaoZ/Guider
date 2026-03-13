# Guider - Obstacle Detection App for the Visually Impaired

## Overview

Guider is a mobile app that helps visually impaired users detect obstacles in real-time using their smartphone's sensors. The phone is placed on the user's chest (via a lanyard/mount), scanning the environment ahead and providing haptic/audio feedback to warn of nearby obstacles — similar to a car's parking radar.

---

## Problem Statement

- 253 million people worldwide live with visual impairment (WHO)
- Existing solutions require expensive dedicated hardware ($300-600 for smart canes/wearables)
- Most visually impaired users already own a smartphone
- No widely adopted, high-quality obstacle detection app exists — especially in the Chinese market

---

## Core Features

1. **Real-time obstacle detection** using LiDAR / dual camera / AI depth estimation
2. **Haptic feedback** — vibration intensity increases as obstacles get closer
3. **Spatial audio cues** — left/right directional sound to indicate obstacle position
4. **Stair/step detection** — the most dangerous scenario for visually impaired users
5. **Full VoiceOver accessibility** — the entire app is usable without sight

---

## Technical Architecture

```
Camera/LiDAR → Depth Map → Obstacle Detection → Distance Zones → Feedback
                                                        ├── Haptic (Core Haptics)
                                                        └── Audio (Spatial Audio)
```

### Distance Zones & Feedback

| Zone | Distance | Haptic Feedback | Audio Feedback |
|------|----------|----------------|----------------|
| Safe | > 2m | None | None |
| Caution | 1-2m | Light intermittent vibration | Low-frequency beep |
| Warning | 0.5-1m | Medium continuous vibration | Mid-frequency beep |
| Danger | < 0.5m | Strong continuous vibration | High-frequency rapid beep |

---

## Tech Stack

| Component | Technology | Reason |
|-----------|-----------|--------|
| Language | **Swift** | Native access to ARKit, Core Haptics, AVFoundation |
| Depth Sensing | **ARKit + LiDAR** | cm-level accuracy, 0-5m range, 60fps |
| AI Depth (fallback) | **Core ML + Depth Anything** | Enables support for non-LiDAR devices |
| Haptic Feedback | **Core Haptics** | Fine-grained vibration control |
| Audio | **AVAudioEngine** | Spatial audio for directional cues |
| Accessibility | **UIAccessibility** | Full VoiceOver integration |

### Why Swift (Native iOS)?

- ARKit + LiDAR API is **only available natively** — no React Native/Flutter support
- Core Haptics requires native access for fine-grained vibration patterns
- Real-time camera processing needs minimal latency — native is fastest
- VoiceOver accessibility works best with native UIKit/SwiftUI

---

## Device Compatibility Strategy

| Device | Sensor Used | Accuracy | Experience |
|--------|------------|----------|------------|
| **iPhone Pro** (12 Pro+) | LiDAR | cm-level | Best — full precision |
| **Standard iPhone** (dual camera) | Stereo depth from dual cameras | ~10-20cm error | Good — reliable for basic avoidance |
| **Any iPhone** (single camera) | AI depth estimation (Depth Anything model) | Rough estimate | Basic — can distinguish near/mid/far |

This tiered approach ensures the app works on **all iPhones**, not just Pro models.

---

## Competitor Analysis

### International Apps

| App | Price | Sensors | Strengths | Weaknesses |
|-----|-------|---------|-----------|------------|
| **Super Lidar** | Free | LiDAR only | MIT-backed, good audio mapping | LiDAR-only, no camera fallback |
| **Obstacle Detector** | $5.99 | LiDAR + TrueDepth | cm-level accuracy, customizable alerts | LiDAR-only for rear camera |
| **EyeGuide** | Free | LiDAR | Voice prompts, privacy-focused (local processing) | iOS only, LiDAR only |
| **Be My Eyes** | Free | Camera | Connects to human volunteers | Not real-time obstacle detection |
| **Seeing AI** (Microsoft) | Free | Camera | Object recognition, text reading | No obstacle avoidance |

### Chinese Market Apps

| App | Strengths | Weaknesses |
|-----|-----------|------------|
| **EasyWZA (轻松无障碍)** | Scans every 10s, identifies obstacle types | Not real-time, slow refresh |
| **Bat Avoidance (蝙蝠避障)** | Sensor + image recognition | Limited adoption, basic feedback |

### Our Competitive Advantages

1. **Works on all iPhones** — AI depth fallback for non-LiDAR devices (competitors are LiDAR-only)
2. **Chinese market gap** — no mature LiDAR obstacle detection app exists in China
3. **Superior feedback** — fine-grained haptic zones + spatial audio (competitors have basic vibration)
4. **Local scenarios** — optimized for Chinese urban environments (shared bikes, electric scooters, etc.)

---

## Development Roadmap

### Phase 1 — MVP (2-3 weeks)
- iPhone Pro LiDAR support only
- ARKit depth map → center-region obstacle detection
- 4-zone haptic feedback (safe/caution/warning/danger)
- Minimal UI, full VoiceOver compatibility
- Basic settings (sensitivity, feedback mode)

### Phase 2 — Enhanced Experience (2-3 weeks)
- Spatial audio directional cues (left/right)
- Stair/step detection model
- Dual-camera depth support for standard iPhones
- AI depth estimation fallback for single-camera devices

### Phase 3 — Full Product (3-4 weeks)
- Object recognition with voice announcements ("Chair detected, 2 meters ahead")
- Route memory and navigation
- Apple Watch companion app (wrist vibration feedback)
- Usage analytics and battery optimization

---

## Key Technical Challenges

| Challenge | Severity | Solution |
|-----------|----------|----------|
| Phone instability on chest | High | Design a chest mount accessory; use gyroscope to compensate for motion |
| Battery drain | High | Reduce scan rate to 15fps; process only center region, not full frame |
| Ground surface false positives | Medium | Use ARKit plane detection to filter ground; only detect waist-height and above |
| Outdoor strong light interference | Medium | Fuse LiDAR + camera data for mutual compensation |
| Stair/step detection | Medium | Train a dedicated CoreML model for downward stair detection |
| App usability without sight | High | Full VoiceOver support; physical button (volume key) shortcuts |

---

## Target Users

- **Primary**: Visually impaired individuals who use iPhones
- **Secondary**: Elderly with declining vision
- **Tertiary**: Caregivers and accessibility organizations

---

## Business Model Options

| Model | Description |
|-------|-------------|
| **Freemium** | Basic detection free; advanced features (object recognition, spatial audio) as in-app purchase |
| **One-time purchase** | ~$4.99-9.99, like Obstacle Detector |
| **Free + donations** | Maximize adoption, accept donations |
| **Partnership** | Partner with disability organizations / government accessibility programs |

---

## Summary

| Dimension | Assessment |
|-----------|------------|
| Technical Feasibility | **High** — ARKit + LiDAR APIs are mature and well-documented |
| Implementation Difficulty | **Medium** — MVP in 2-3 weeks; core challenge is tuning feedback UX |
| User Value | **High** — zero additional hardware cost, solves a real daily pain point |
| Market Opportunity | **Strong** — existing apps are LiDAR-only; Chinese market is underserved |
| Biggest Risk | Phone placement may feel unnatural; social acceptance of wearing phone on chest |
