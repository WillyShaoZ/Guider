# Guider — User Guide

## What is Guider?

Guider is an iOS app that helps visually impaired users navigate safely. Wear your iPhone on your chest with a lanyard — the app uses LiDAR to detect obstacles ahead and alerts you through vibration and voice.

Guider also has a Daily Mode that identifies objects using the camera.

---

## Getting Started

### Requirements

- iPhone Pro 12 or later (LiDAR required)
- iOS 17.0+
- Lanyard or chest mount to hold the phone

### First Launch

1. Open Guider
2. The app will ask for **camera** and **microphone** permissions — tap **Allow** for both
3. Scanning starts automatically — you'll hear: *"Guider is scanning. Tap to pause."*

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

### Daily Mode

Point the phone at an object and tap the screen. The app takes a photo, identifies the object, and speaks the result.

Examples: *"water bottle 92%"*, *"coffee mug 85%"*, *"remote control 78%"*

The camera only turns on when you tap — it's off the rest of the time to save battery.

---

## Controls

### Screen Touch

| Action | Navigation Mode | Daily Mode |
|--------|----------------|------------|
| **Tap screen** | Pause / Resume scanning | Take photo & identify object |

### Back Tap (Recommended)

You can control Guider by tapping the back of your iPhone — no need to look at or touch the screen.

| Gesture | Action |
|---------|--------|
| **Double tap back** | Same as tapping the screen (pause/resume or identify) |
| **Triple tap back** | Switch between Navigation and Daily mode |

#### How to Set Up Back Tap

1. On your iPhone, open **Settings**
2. Go to **Accessibility → Touch → Back Tap**
3. Set **Double Tap** → select shortcut **"Guider Pause"**
4. Set **Triple Tap** → select shortcut **"Switch Guider Mode"**

To create these shortcuts:
1. Open the **Shortcuts** app on your iPhone
2. Tap **+** to create a new shortcut
3. Add action **"Open URLs"**
4. For pause: enter `guider://pause`, name it **"Guider Pause"**
5. For mode switch: enter `guider://switch`, name it **"Switch Guider Mode"**

### Siri

You can also say:
- *"Hey Siri, open Guider"* — launch the app

---

## Drop Detection & Emergency

If the phone detects a fall (e.g. you drop it), it will:

1. Vibrate strongly
2. Ask: *"It seems like your phone dropped. Are you okay? Say yes, or say help."*
3. Listen for 10 seconds
4. If you say **"yes"** or **"okay"** → resumes scanning
5. If you say **"help"** or don't respond → calls your emergency contact

### Setting Up Emergency Contact

Emergency contact is set during first launch or through the settings (long press screen in Navigation mode):

- **Contact Name**: e.g. "Mom", "Partner"
- **Phone Number**: e.g. "+61 400 123 456"

If no emergency contact is set, Guider will play a loud voice alert: *"This person may need help"* for nearby people to hear.

---

## Tips for Best Results

### Navigation Mode

- **Mount the phone on your chest** pointing forward — this gives the best scanning angle
- **Walk at normal pace** — the app updates 60 times per second
- **Outdoors in direct sunlight**: LiDAR range may be reduced. Stay alert.
- **Battery**: continuous scanning uses about 30-40% per hour. Charge before going out.

### Daily Mode

- **Hold the object 20-50 cm from the camera** for best results
- **Good lighting helps** — the flash will turn on automatically if needed
- **Wait for the beep** before moving the object — identification takes about 1 second
- The app recognizes 1000+ common objects including food, electronics, furniture, animals, and household items

---

## Accessibility

Guider is designed for visually impaired users:

- **All state changes are voice-announced** — you never need to see the screen
- **Full VoiceOver support** on all screens
- **High contrast UI** for low-vision users
- **Large touch targets** — the entire screen is the button
- **No complex gestures** — just tap and hold

---

## Troubleshooting

| Problem | Solution |
|---------|----------|
| No vibration | Check iPhone silent mode switch is off |
| No voice announcements | Turn up iPhone volume |
| "LiDAR not available" | You need an iPhone Pro (12 Pro or later) |
| App won't start scanning | Check camera permission in Settings → Guider |
| Object recognition is wrong | Try better lighting, hold object closer, try again |
| Back Tap not working | Make sure you set it up in Settings → Accessibility → Touch → Back Tap |
| Drop detection triggers too often | This can happen during vigorous movement — you can dismiss by tapping the screen |

---

## Privacy

- **All processing is done on your iPhone** — no data is sent to any server
- **No internet required** — Guider works fully offline
- **No data collection** — no analytics, no tracking
- Camera is only active during scanning (Navigation) or when you tap to identify (Daily)
