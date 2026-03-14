# Guider — User Guide

## What is Guider?

Guider is an iOS app that helps visually impaired users navigate safely. Wear your iPhone on your chest with a lanyard — the app uses LiDAR to detect obstacles ahead and alerts you through vibration and voice.

Guider also has a Daily Mode that identifies objects using AI.

---

## Getting Started

### Requirements

- iPhone Pro 12 or later (LiDAR required)
- iOS 17.0+
- Lanyard or chest mount to hold the phone

### First Launch

1. Open Guider
2. The app will ask for **camera**, **microphone**, and **speech recognition** permissions — allow all
3. Walk through the **onboarding guide** — each step is voice-announced, tap to continue
4. Set up your **emergency contact** by voice — say a name from your contacts, the app will find and confirm it (long press to skip)
5. Scanning starts automatically — you'll hear: *"Guider is scanning. Tap to pause."*

---

## Two Modes

### Navigation Mode (Default)

The phone scans ahead using LiDAR and vibrates when obstacles are detected.

| Distance | Zone | Vibration |
|----------|------|-----------|
| > 2.0 m | Safe | None |
| 1.0–2.0 m | Caution | Light pulse every 1.5s |
| 0.5–1.0 m | Warning | Medium pulse every 0.6s |
| < 0.5 m | Danger | Strong burst every 0.4s + voice alert |

When an obstacle enters the Danger zone, you'll hear a voice announcement: *"Obstacle left"* or *"Obstacle right"*.

**Stair Detection**: The app also detects stairs ahead and alerts you with a distinct double-tap vibration pattern.

### Daily Mode

Point the phone at an object and **tap the screen**. The app takes a photo, identifies what's in front of you, and speaks the result.

- **With internet**: Uses Gemini AI for detailed descriptions — e.g. *"A red coffee mug on a wooden desk next to a laptop."*
- **Without internet**: Uses Apple's built-in Vision framework — e.g. *"(Offline) I see coffee mug, desk."*

The app automatically detects your network status and switches between online and offline mode. No setup needed.

---

## Controls

| Gesture | Navigation Mode | Daily Mode |
|---------|----------------|------------|
| **Tap screen** | Pause / Resume scanning | Identify object |
| **Long press (0.8s)** | Switch to Daily Mode | Switch to Navigation Mode |

That's it — just **tap** and **long press**. No buttons to find.

---

## Drop Detection & Emergency

If the phone detects a fall (e.g. you drop it or fall), it will:

1. **Vibrate strongly** to alert you
2. Ask: *"Are you okay? Say yes, or say help."*
3. **Listen for 10 seconds**
4. If you say **"yes"**, **"okay"**, or **"fine"** → resumes scanning
5. If you say **"help"** or **don't respond**:
   - Auto-dials your emergency contact
   - **Repeats every 10 seconds**: *"Emergency. This person has fallen and is not responding. Please tap the blue Call button on screen to call [contact name] for help."*
   - This bystander guidance continues until someone nearby taps the call button or you tap to dismiss
6. If **no emergency contact** is set → plays loud alert: *"This person has fallen. If someone is nearby, please help."*

### Setting Up Emergency Contact

**During first launch (recommended):**
1. The onboarding guide will ask: *"Say the name of your emergency contact."*
2. Say a name (e.g. "Mom", "John") — the app searches your contacts
3. It confirms: *"I found Mom, phone number 0412345678. Say yes to confirm."*
4. Say **"yes"** to save, or tap to try a different name
5. Long press to skip

**Later:**
You can also set it manually in the Settings view — accessible through the app.

---

## Online vs Offline Mode

| Feature | Online (Gemini AI) | Offline (Apple Vision) |
|---------|-------------------|----------------------|
| Object recognition | Detailed natural language descriptions | Category labels (1000+ categories) |
| Internet required | Yes | No |
| Speed | 2-3 seconds | < 1 second |
| Example output | "A golden retriever lying on a grey couch" | "I see golden retriever, couch" |

The app switches automatically — you don't need to do anything. If Gemini fails (e.g. network drops mid-request), it automatically falls back to offline mode.

---

## Tips for Best Results

### Navigation Mode

- **Mount the phone on your chest** pointing forward — this gives the best scanning angle
- **Walk at normal pace** — the app adjusts scanning speed automatically (faster when walking, slower when stationary)
- **Outdoors in direct sunlight**: LiDAR range may be reduced. Stay alert.
- **Battery**: continuous scanning uses about 30-40% per hour. Charge before going out.

### Daily Mode

- **Hold the object 20-50 cm from the camera** for best results
- **Good lighting helps** — the flash will turn on automatically if needed
- **Wait for the voice result** before tapping again — identification takes 1-3 seconds
- **Online mode** gives much better results — make sure you have internet for detailed descriptions

---

## Accessibility

Guider is designed for visually impaired users:

- **All state changes are voice-announced** — you never need to see the screen
- **Voice-guided onboarding** — the app talks you through setup on first launch
- **Voice-guided emergency contact setup** — say a name, the app finds the contact
- **Full VoiceOver support** on all screens
- **High contrast UI** for low-vision users
- **Large touch targets** — the entire screen is the button
- **No complex gestures** — just tap and long press

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No vibration | Check iPhone silent mode switch is off. Try leaving and re-entering the app |
| No voice announcements | Turn up iPhone volume |
| "LiDAR not available" | You need an iPhone Pro (12 Pro or later) |
| App won't start scanning | Check camera permission in Settings → Guider |
| Object recognition says "API key missing" | Create `Guider/Secrets.plist` with your Gemini API key (see README) |
| Object recognition gives basic labels only | You're in offline mode — connect to internet for detailed AI descriptions |
| Drop detection triggers too often | This can happen during vigorous movement — tap the screen to dismiss |
| Vibration stops after switching apps | Leave and re-enter the app — the haptic engine restarts automatically |
| Emergency call shows confirmation dialog | This is an iOS security requirement — nearby people can tap the Call button for you |

---

## Privacy

- **Navigation mode** is fully on-device — no data sent anywhere
- **Daily mode (online)** sends a photo to Google's Gemini API for recognition — the image is not stored
- **Daily mode (offline)** is fully on-device — no data sent anywhere
- **No analytics, no tracking, no data collection**
- Camera is only active during scanning (Navigation) or when you tap to identify (Daily)
