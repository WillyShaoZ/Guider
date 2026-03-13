# Guider — Project Summary

## Overview

Guider is a LiDAR-based obstacle detection iOS app for visually impaired users. The phone is worn on the chest, scans ahead using LiDAR depth sensing, and provides haptic/audio feedback to help users navigate safely.

## Work Completed

### 1. Project Proposal & Guidelines

- Wrote project proposal defining scope, tech stack, and architecture (`docs/PROJECT_PROPOSAL.md`)
- Created `CLAUDE.md` with coding conventions, architecture decisions, and project structure
- Established key constraint: no motion sensors, LiDAR-first, local processing only

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
- General robustness improvements across the prototype

### 4. Permission Handling & Accessibility-First UI Redesign

- Added camera and microphone permission management to `LiDARSessionManager`
- Created `PermissionView` — voice-guided permission flow designed for blind/low-vision users:
  - High contrast design: white text and buttons on black background
  - Explicit, large button targets ("Allow Permissions", "Skip for Now", "Open Settings") — works with VoiceOver swipe-to-navigate and double-tap-to-activate
  - `AVSpeechSynthesizer` speaks instructions on appear (1.5s delay to avoid VoiceOver collision), slightly slower speech rate
  - "Repeat Instructions" button always available
  - Haptic confirmation on every button press via `UIImpactFeedbackGenerator`
  - Re-checks permissions and re-announces when returning from Settings
- Redesigned `MainView` for blind-first interaction (no buttons):
  - **Auto-starts scanning** on launch — no "Start Scanning" button to find
  - **Tap anywhere** to pause/resume scanning (whole screen is the target)
  - **Long press (1s)** to open settings — haptic confirms activation
  - **Voice announces every state change**: startup instructions, "Scanning paused. Tap to resume.", "Scanning resumed."
  - Visual elements (zone icon, distance, color) kept only for sighted helpers / demo
  - Single VoiceOver element for entire screen with combined description
- Redesigned `SettingsView` with voice guidance:
  - Speaks all current setting values on open ("Haptic vibration is on. Spatial audio is on...")
  - Announces each toggle change ("Haptic vibration off")
  - Announces close ("Closing settings")
- Updated `GuiderApp` to conditionally show `PermissionView` or `MainView` based on permission state
- Updated `Info.plist` microphone usage description for emergency assistance feature

### 5. Phone Drop Detection & Emergency Assistance

- **DropDetector** (`Core/DropDetector.swift`) — detects phone falls using ARKit's camera transform:
  - Monitors device Y-position (height) from `ARFrame.camera.transform` at 60fps
  - Triggers when Y drops 40cm+ within a 0.5s window (rapid freefall)
  - 10s cooldown to prevent repeated triggers
  - Uses ARKit visual-inertial odometry — no motion sensors (per project constraints)
- **EmergencyAssistant** (`Core/EmergencyAssistant.swift`) — orchestrates the full emergency flow:
  1. Strong haptic burst (`UINotificationFeedbackGenerator`)
  2. Voice prompt: "It seems like your phone dropped. Are you okay? Say yes, or say help."
  3. Listens via `SFSpeechRecognizer` for up to 10 seconds
  4. Positive response ("yes", "okay", "fine") → resolved, resumes scanning
  5. Help request ("help", "no") or no response → escalate
  6. Tap to dismiss at any time
- **Escalation with emergency contact**:
  - If contact is set: announces "Calling [name] for help" then dials via `tel://` URL
  - If no contact: loud repeated voice alert for bystanders ("This person may need help")
- **Emergency contact setup** in Settings:
  - Drop detection toggle (on by default)
  - Emergency contact name and phone number fields (persisted via `@AppStorage`)
  - Status indicator showing whether contact is set
  - Voice announces emergency contact status when settings open
- **MainView integration**:
  - DropDetector bound to LiDARSessionManager frame stream
  - On drop: pauses obstacle feedback, triggers emergency flow
  - Emergency state shown visually (red background, status text) for sighted helpers
  - Tap to dismiss emergency, resumes scanning automatically

### 6. Sensitivity Slider, FeedbackProfile, Ground Filtering, Stair Detection, Battery Optimization, Onboarding & Tests

- **Sensitivity slider wired** — `appState.sensitivity` (0.5x–2.0x) now scales all zone thresholds live:
  - `DistanceZone.from(distance:sensitivity:)` divides distance by sensitivity before classifying
  - `Obstacle.init` accepts `sensitivity` parameter
  - `ObstacleDetector.sensitivity` property set from AppState and updated via `.onChange`
- **FeedbackProfile model** (`Models/FeedbackProfile.swift`) — aggregates haptic/audio/voice/sensitivity preferences into a single struct:
  - `AppState.feedbackProfile` computed property builds it from `@AppStorage` values
  - `FeedbackManager.apply(profile:)` replaces individual property assignments
- **Ground filtering with plane anchors** — `DepthProcessor.closestPerDirection` now accepts optional `groundPlaneY`:
  - `LiDARSessionManager` extracts lowest horizontal `ARPlaneAnchor` Y position each frame
  - When ground plane is known, dynamically skips grid cells corresponding to <30cm above ground
  - Falls back to skipping bottom row when no plane anchors available
- **Stair detection** (`Core/StairDetector.swift`) — depth gradient analysis for stair detection:
  - Samples lower 40% of depth frame, computes mean depth per scanline
  - Detects repeating sign changes in vertical depth gradient (≥3 at regular intervals)
  - Temporal filtering: requires 3 consecutive positive frames to confirm
  - 5s cooldown between alerts
  - Triggers distinct double-tap haptic pattern + "Stairs ahead" voice announcement
- **Battery optimization** (`Core/MotionClassifier.swift`) — adaptive frame rate based on motion:
  - Classifies walking vs stationary using ARKit camera position displacement over 1s window
  - Walking: depth processing every 2nd frame (~30fps); Stationary: every 4th (~15fps)
  - DropDetector keeps full frame rate for accurate fall detection
- **Onboarding flow** (`UI/OnboardingView.swift`) — voice-guided 6-step first-launch tutorial:
  - High contrast white-on-black design, tap to advance
  - AVSpeechSynthesizer auto-speaks each step
  - Progress dots for sighted helpers, full VoiceOver support
  - `GuiderApp` routes: Permissions → Onboarding (once) → MainView
- **Unit tests** added for core algorithms:
  - `DistanceZoneTests` — zone classification, sensitivity scaling, comparable ordering
  - `DepthProcessorTests` — ground filtering, per-direction min distance, all-infinity handling
  - `StairDetectorTests` — flat surface, regular pattern, noise, single jump, edge cases
  - `ObstacleDetectorTests` — zone assignment with sensitivity, DetectionResult invariants

---

## Algorithm Documentation

### Stair Detection Algorithm

```
Input: ARDepthData depth buffer (Float32, LiDAR resolution ~256x192)

1. Lock depth buffer, focus on LOWER 40% of frame (stairs are below chest height)
2. Sample horizontal scanlines every 2nd row, center 60% width (skip noisy edges)
3. For each scanline: compute mean depth across all valid pixels (skip NaN, <=0, >5m, low confidence)
4. Build array of (row_index, mean_depth) pairs
5. Compute first derivative: diff[i] = depth[i+1] - depth[i]
6. Scan derivative for sign changes (positive→negative or negative→positive)
   - Each sign change = a "step edge" in the depth profile
7. Validate stair pattern:
   - Need ≥3 sign changes (at least 3 steps visible)
   - Intervals between changes must be regular (std_dev < 30% of mean_interval)
   - Each transition magnitude between 0.05m and 0.3m (realistic step rise)
8. Temporal filtering: require 3 consecutive positive frames to confirm
9. Cooldown: suppress re-alerting for 5 seconds after a detection
```

### Drop Detection Algorithm

```
Input: ARFrame.camera.transform (4x4 matrix, device pose in world space)

1. Extract Y position: transform.columns.3.y (device height in meters)
2. Maintain rolling position history over 0.5s window
3. On each frame:
   a. Append (y, timestamp) to history
   b. Trim entries older than 0.5s
   c. Find max Y in the window
   d. Compute drop = max_y - current_y
4. If drop >= 0.4m (40cm):
   → Phone fell from chest height (~1.2m) to ground
   → Fire drop event
   → Clear history, start 10s cooldown
5. Uses ARKit visual-inertial odometry — NOT accelerometer/gyroscope
```

### Obstacle Detection Pipeline

```
Input: ARDepthData (depth map + confidence map)

1. DEPTH GRID SAMPLING:
   - ROI: center 60% of frame (20% margin on each side)
   - Divide ROI into 3x3 grid (columns: left/center/right, rows: top/mid/bottom)
   - Sample every 4th pixel for performance
   - Filter: skip NaN, <=0, >5.0m (maxDetectionRange), confidence < 1 (of 0-2)
   - Per cell: track minimum distance

2. GROUND FILTERING:
   - Use ARKit horizontal plane anchors to find ground Y position
   - Skip grid cells whose depth readings correspond to <30cm above ground
   - Fallback: skip bottom row of grid when no plane anchors available

3. DIRECTION REDUCTION:
   - Reduce 3x3 grid to 3 values: closest distance per left/center/right

4. TEMPORAL SMOOTHING:
   - Rolling window of 5 frames per direction
   - Use MEDIAN (not mean) for robustness against outlier frames
   - Median of even-count windows: average of two middle values

5. ZONE CLASSIFICATION:
   - danger: < 0.5m × sensitivity
   - warning: < 1.0m × sensitivity
   - caution: < 2.0m × sensitivity
   - safe: everything else
   - Sensitivity slider (0.5x–2.0x) scales all thresholds

6. FEEDBACK ROUTING:
   - Zone → HapticEngine (looping Core Haptics patterns)
   - Zone + Direction → SpatialAudioEngine (panned sine wave)
   - Zone change (getting closer only) → VoiceAnnouncer
   - Stair detected → distinct double-tap haptic + "Stairs ahead" voice
```

### Adaptive Frame Rate (Battery Optimization)

```
Input: ARFrame.camera.transform position over time

1. Track device 3D position over 1-second sliding window
2. Compute displacement = distance(newest_position, oldest_position)
3. Classify:
   - displacement > 0.15m → WALKING (user moving)
   - displacement ≤ 0.15m → STATIONARY (user still)
4. Set frame skip rate:
   - WALKING: process every 2nd frame → ~30fps depth processing
   - STATIONARY: process every 4th frame → ~15fps depth processing
5. DropDetector keeps full frame rate (needs high temporal resolution for fall detection)
6. Uses ARKit camera transform only — no accelerometer/gyroscope
```

### Emergency Assistance Flow

```
Trigger: DropDetector fires drop event

1. HAPTIC ALERT: UINotificationFeedbackGenerator (.warning) + UIImpactFeedbackGenerator (.heavy)
2. VOICE PROMPT: "It seems like your phone dropped. Are you okay? Say yes, or say help."
   - Speech rate: 0.85x normal (slower for clarity)
   - Volume: 1.0 (maximum)
3. LISTEN: SFSpeechRecognizer (en-US) for up to 10 seconds
   - Audio session: .playAndRecord with .defaultToSpeaker
   - Positive keywords: "yes", "yeah", "okay", "ok", "fine", "good", "i'm okay/fine/good", "all good"
   - Help keywords: "help", "no", "emergency", "call", "fall", "fell", "hurt"
4. RESOLVE:
   - Positive detected → "Glad you're okay. Resuming scanning." → resume
   - Help detected or 10s timeout → ESCALATE
5. ESCALATE:
   - If emergency contact set → announce "Calling [name]" → dial via tel:// URL
   - If no contact → loud repeated alert: "This person may need help" (repeat every 8s)
6. DISMISS: user taps screen at any time → "Okay. Resuming scanning."
```

### Sensitivity Scaling

```
Slider range: 0.5x (near) to 2.0x (far), default 1.0x

Formula: adjusted_distance = raw_distance / sensitivity
Then classify adjusted_distance against fixed thresholds (0.5m, 1.0m, 2.0m)

Effect: sensitivity=2.0x doubles effective detection range
  - Danger triggers at 1.0m instead of 0.5m
  - Caution triggers at 4.0m instead of 2.0m
  - User detects obstacles further away

sensitivity=0.5x halves effective range (for tight spaces)
```
