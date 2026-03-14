# Guider — Project Summary

## Overview

Guider is a LiDAR-based obstacle detection iOS app for visually impaired users. The phone is worn on the chest, scans ahead using LiDAR depth sensing, and provides haptic/audio feedback to help users navigate safely. It also features AI object recognition and emergency drop detection.

## Work Completed

### 1. Project Proposal & Guidelines

- Wrote project proposal defining scope, tech stack, and architecture (`docs/PROJECT_PROPOSAL.md`)
- Created `CLAUDE.md` with coding conventions, architecture decisions, and project structure
- Established key constraint: no motion sensors, LiDAR-only, voice-first UX

### 2. LiDAR Obstacle Detection Prototype

- **LiDARSessionManager** — ARKit session management with depth data streaming via Combine subjects
- **ObstacleDetector** — 3x3 grid sampling of depth maps, zone classification (Safe/Caution/Warning/Danger), direction detection (left/center/right)
- **FeedbackManager** — Core Haptics patterns and spatial audio feedback mapped to distance zones
- **SwiftUI UI** — MainView with zone indicator and distance readout (visual elements for sighted helpers)
- **AppState** — Global state management for scanning status, current zone, and feedback preferences
- Full VoiceOver accessibility labels on all interactive elements

### 3. Code Review Fixes

- Fixed memory leaks in Combine subscriptions (stored `AnyCancellable` references properly)
- Replaced unsafe force-unwraps with safe optional handling
- Set appropriate QoS on background processing queues
- Fixed median calculation in depth sampling
- Extracted shared constants (distance thresholds) to avoid magic numbers

### 4. Permission Handling & Accessibility-First UI Redesign

- Created `PermissionView` — voice-guided permission flow for blind/low-vision users
- Redesigned `MainView` for blind-first interaction (tap anywhere, no buttons)
- Auto-starts scanning on launch, voice announces every state change
- Updated `GuiderApp` routing: Permissions → Onboarding → MainView

### 5. Phone Drop Detection & Emergency Assistance

- **DropDetector** — detects phone falls using ARKit camera Y-position tracking (40cm drop in 0.5s)
- **EmergencyAssistant** — full emergency flow: haptic alert → voice prompt → speech recognition → escalate
- Escalation: auto-dials emergency contact or plays loud bystander alert

### 6. Stair Detection, Battery Optimization, Ground Filtering

- **StairDetector** — depth gradient analysis detecting repeating step patterns, 3-frame temporal filtering
- **MotionClassifier** — adaptive frame rate (30fps walking, 15fps stationary) using ARKit camera displacement
- **Ground filtering** — ARKit plane anchors filter obstacles below 30cm height
- **FeedbackProfile** — aggregates haptic/audio/voice preferences

### 7. Onboarding Flow

- **OnboardingView** — voice-guided multi-step first-launch tutorial
- High contrast white-on-black design, tap to advance
- AVSpeechSynthesizer auto-speaks each step

### 8. Daily Mode — AI Object Recognition (New)

- **Removed voice input requirement** — Daily Mode now uses simple tap to identify:
  - Tap screen → camera captures → AI identifies → voice announces result
  - No "what am I looking at" speech recognition needed
- **Online mode (Gemini API)** — rich natural language descriptions via `GeminiVisionService`:
  - Uses gemini-2.5-flash model
  - Prompt optimized for visually impaired users
  - Example: "A red coffee mug on a wooden desk next to a laptop."
- **Offline mode (Apple Vision)** — on-device classification via `VNClassifyImageRequest`:
  - 1000+ object categories, no internet needed
  - Top 3 results with >20% confidence
  - Example: "(Offline) I see coffee mug, desk, laptop."
- **Automatic switching** — `NWPathMonitor` detects network status, routes to Gemini or Vision
- **Gemini fallback** — if Gemini API fails mid-request, automatically falls back to offline mode
- **API key security** — key stored in `Secrets.plist` (git-ignored), loaded at runtime from Bundle

### 9. Emergency Flow Improvements (New)

- **Voice-guided emergency contact setup** during onboarding:
  - App asks user to say a contact name
  - Uses `CNContactStore` to search contacts by name (fuzzy matching: full name, first name, nickname)
  - Voice confirms match with name and number
  - User says "yes" to save, tap to retry, long press to skip
  - Added `NSContactsUsageDescription` to Info.plist
- **Bystander guidance loop** for unconscious users:
  - After escalation, app repeats every 10 seconds: "Emergency. This person has fallen and is not responding. Please tap the blue Call button on screen to call [name] for help."
  - Designed for nearby people to help when user is unconscious and cannot confirm the call
  - Loop stops when call is confirmed or user taps to dismiss
- **CallKit integration** — uses `CXStartCallAction` to initiate calls, falls back to `tel://`

### 10. Interaction Model Update (New)

- **Removed Back Tap** — no longer requires Shortcuts app setup or Back Tap configuration
- **Removed URL scheme handler** — `guider://pause` and `guider://switch` no longer used
- **New controls**: tap (pause/identify) + long press 0.8s (switch modes)
- Updated `AppIntents.swift` — removed `SwitchModeIntent` and notification extensions
- Kept `OpenGuiderIntent` for "Hey Siri, open Guider"

### 11. Bug Fixes (New)

- **Haptic engine recovery** — added foreground/background notification listeners in MainView to re-prepare haptic engine after app returns from background
- **HapticEngine auto-restart** — `play()` now checks if engine is nil and re-initializes before playing
- **StairDetector pointer type** — fixed `UnsafePointer<UInt8>` → `UnsafeMutablePointer<UInt8>`
- **Missing Xcode project files** — added FeedbackProfile, StairDetector, MotionClassifier, OnboardingView, GeminiVisionService to project.pbxproj
- **Test files excluded** — moved Tests/ out of app source directory to avoid XCTest import errors in main target

---

## Algorithm Documentation

### Stair Detection Algorithm

```
Input: ARDepthData depth buffer (Float32, LiDAR resolution ~256x192)

1. Lock depth buffer, focus on LOWER 40% of frame (stairs are below chest height)
2. Sample horizontal scanlines every 2nd row, center 60% width
3. For each scanline: compute mean depth (skip NaN, <=0, >5m, low confidence)
4. Compute first derivative: diff[i] = depth[i+1] - depth[i]
5. Collect gradient spikes with magnitude between 0.05m–0.30m (realistic step rise)
6. Filter to dominant sign (all positive or all negative — real stairs go one direction)
7. Validate: ≥3 spikes at regular intervals (std_dev < 30% of mean_interval)
8. Temporal filtering: 3 consecutive positive frames to confirm
9. Cooldown: 5 seconds between alerts
```

### Drop Detection Algorithm

```
Input: ARFrame.camera.transform (4x4 matrix, device pose in world space)

1. Extract Y position (device height in meters)
2. Maintain rolling position history over 0.5s window
3. Compute drop = max_y_in_window - current_y
4. If drop >= 0.4m → phone fell → fire event → 10s cooldown
```

### Obstacle Detection Pipeline

```
1. DEPTH GRID SAMPLING: 3x3 grid over center 60% of depth map, sample every 4th pixel
2. GROUND FILTERING: ARKit plane anchors, skip cells <30cm above ground
3. DIRECTION REDUCTION: closest distance per left/center/right
4. TEMPORAL SMOOTHING: median of 5-frame rolling window per direction
5. ZONE CLASSIFICATION: danger <0.5m, warning <1.0m, caution <2.0m, safe >2.0m
6. FEEDBACK: zone → haptic pattern; zone + direction → spatial audio; zone change → voice
```

### Emergency Assistance Flow

```
Drop detected → Haptic burst → "Are you okay?" → Listen 10s
  ├── Positive response → Resume scanning
  ├── "Help" or timeout → Dial contact + bystander guidance loop (every 10s)
  └── Tap screen → Dismiss
```
