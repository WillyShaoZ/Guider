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
- **SwiftUI UI** — MainView with zone indicator, distance readout, direction arrows, scan toggle, and settings
- **AppState** — Global state management for scanning status, current zone, and feedback preferences
- Full VoiceOver accessibility labels on all interactive elements

### 3. Code Review Fixes

- Fixed memory leaks in Combine subscriptions (stored `AnyCancellable` references properly)
- Replaced unsafe force-unwraps with safe optional handling
- Set appropriate QoS on background processing queues
- Fixed median calculation in depth sampling
- Extracted shared constants (distance thresholds) to avoid magic numbers
- General robustness improvements across the prototype

### 4. Permission Handling & Accessibility-First UI

- Added camera and microphone permission management to `LiDARSessionManager`
- Created `PermissionView` — voice-guided permission flow designed for blind/low-vision users:
  - High contrast design: white text and buttons on black background
  - Explicit, large button targets ("Allow Permissions", "Skip for Now", "Open Settings") instead of invisible tap gestures — works correctly with VoiceOver's swipe-to-navigate and double-tap-to-activate
  - `AVSpeechSynthesizer` speaks instructions automatically on appear (with 1.5s delay to avoid collision with VoiceOver screen-change announcement), slightly slower speech rate for clarity
  - "Repeat Instructions" button always available
  - Haptic confirmation on every button press via `UIImpactFeedbackGenerator`
  - Re-checks permissions and re-announces when returning from Settings
  - Detailed `.accessibilityHint()` on every button explaining what will happen
- Updated `MainView` for better accessibility:
  - Larger scan button with bolder text (22pt bold) and bigger tap target (24pt vertical padding)
  - Settings button expanded from icon-only to labeled button with background, much easier to discover and tap
  - Zone display now includes `.accessibilityValue` with descriptive text (e.g., "Obstacle is close, slow down")
  - VoiceOver hints updated to include "Double tap to..." phrasing matching iOS conventions
- Updated `GuiderApp` to conditionally show `PermissionView` or `MainView` based on permission state
- Updated `MainView` to receive `LiDARSessionManager` via `@EnvironmentObject`
- Updated `Info.plist` microphone usage description for emergency assistance feature
