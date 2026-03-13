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
