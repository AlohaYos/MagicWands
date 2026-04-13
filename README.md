# MagicWand

A Mixed Reality magic wand application for visionOS, powered by Logitech MUSE spatial stylus. Transform your MUSE into a wand with haptic feedback, motion detection, and physics interactions.

![visionOS](https://img.shields.io/badge/visionOS-26+-blue)
![Swift](https://img.shields.io/badge/Swift-6.2+-orange)
![License](https://img.shields.io/badge/license-MIT-green)

## In Action

https://github.com/user-attachments/assets/19f99db2-5f88-4349-96c1-a4070e3521c4

## Overview

MagicWand demonstrates advanced visionOS capabilities including:

- **Spatial Tracking**: Real-time 6DOF tracking of Logitech MUSE stylus
- **Haptic Feedback**: Dual-intensity haptics for motion and impact
- **Motion Detection**: Velocity-based swing detection
- **Physics Interactions**: Collision detection with RealityKit entities
- **Visual Effects**: Particle effects and dynamic color cycling

## Features

### 🎨 Wand Customization

- **Color Cycling**: 6 vibrant colors (White, Blue, Green, Red, Purple, Yellow)
- **Extension/Retraction**: Smooth animation between collapsed and extended states
- **Glowing Effect**: UnlitMaterial for glow

### 🎯 Motion & Haptics

- **Swing Detection**: Velocity-based motion detection (threshold: 0.8 m/s)
- **Light Haptic**: Subtle feedback when swinging the wand (intensity: 0.3)
- **Impact Haptic**: Strong feedback on collision (intensity: 1.0)

### ⚔️ Physics Interactions

- **Collision Detection**: RealityKit physics-based collision system
- **Target Destruction**: Hit floating spheres to trigger particle effects
- **Particle Effects**: Color-matched explosion effects on impact

### 🐛 Debug Tools

- **Visual Markers**: Red (tip), Green (center), Blue (tail) debug cubes
- **Position Logging**: Real-time position and velocity logging
- **Toggle Controls**: Easy debug mode switching

## Requirements

### Hardware

- **Apple Vision Pro** (visionOS 26 or later)
- **Logitech MUSE** (Spatial Stylus)

### Software

- **Xcode 26.0+**
- **Swift 6.2+**
- **visionOS SDK 26+**

### Entitlements

The app requires the following entitlements (already configured):

```xml
<key>NSAccessorySetupKitSupport</key>
<true/>
```

## Build & Run

### 1. Clone the Repository

```bash
git clone https://github.com/alohayos/MagicWands.git
cd MagicWand
```

### 2. Open in Xcode

```bash
open MagicWand.xcodeproj
```

### 3. Connect MUSE

1. Power on your Logitech MUSE
2. Pair with Vision Pro via Bluetooth Settings
3. Ensure MUSE is connected before launching the app

### 4. Build and Deploy

1. Select "MagicWand" scheme
2. Choose "Apple Vision Pro" or "Designed for iPad (visionOS)" destination
3. Press `Cmd + R` to build and run

## Usage

### Controls

| Input | Action |
|-------|--------|
| **Upper Side Button** | Cycle wand color |
| **Lower Side Button** | Extend/Retract wand |
| **Swing Motion** | Trigger light haptic feedback |
| **Hit Target** | Destroy sphere with particle effect |

### Initial Setup

1. **Launch App**: Tap "Toggle Immersive Space" button in the volumetric window
2. **MUSE Detection**: App automatically detects and connects to MUSE
3. **Extend Wand**: Press lower side button to extend the wand
4. **Start Playing**: Swing the wand and hit floating targets

### Debug Mode

Toggle debug visualization with the "Debug" button in the UI:

- **Red Cube**: MUSE tip position (0, 0, 0)
- **Green Cube**: MUSE center position
- **Blue Cube**: MUSE tail position

Enable position logging to see real-time tracking data in Xcode console.

## Technical Stack

### Frameworks

- **RealityKit**: 3D rendering and physics simulation
- **ARKit**: Spatial tracking session and accessory anchoring
- **GameController**: MUSE device integration and input handling
- **CoreHaptics**: Haptic feedback patterns
- **SwiftUI**: UI and app structure

### Key Technologies

- **AccessoryAnchoringSource**: MUSE position tracking
- **AnchorEntity**: Entity anchoring to MUSE location
- **PhysicsBodyComponent**: Collision detection (kinematic wand vs dynamic targets)
- **CollisionComponent**: Collision shape and filtering
- **ParticleEmitterComponent**: Particle effects on impact
- **CHHapticEngine**: Dual-pattern haptic feedback

### Architecture

- **AppModel**: Observable app-wide state management
- **WandModel**: MUSE tracking, motion detection, and wand state
- **HapticsModel**: Haptic pattern creation and triggering
- **ImmersiveView**: RealityKit scene and collision handling

## Project Structure

```
MagicWand/
├── MagicWand/
│   ├── MagicWandApp.swift          # App entry point
│   ├── AppModel.swift              # App state management
│   ├── ContentView.swift           # Volumetric window UI
│   ├── ImmersiveView.swift         # Immersive space scene
│   ├── WandModel.swift             # MUSE tracking & wand logic
│   ├── HapticsModel.swift          # Haptic feedback management
│   ├── ToggleImmersiveSpaceButton.swift
│   ├── ToggleDebugButton.swift
│   └── TogglePositionLoggingButton.swift
├── Packages/
│   └── RealityKitContent/          # RealityKit assets package
│       └── Sources/
│           └── RealityKitContent.rkassets/
│               └── Immersive.usda  # Immersive scene
└── docs/
```

## Known Issues

### MUSE Reconnection

If MUSE tracking stops working after any of the following events, power cycle the MUSE (OFF → ON):

1. **visionOS Restart**: Tracking session disconnects
2. **App Crash**: Spatial tracking session not properly terminated
3. **Long Sleep**: Coordinate system may reset after wake
4. **Repeated Connections**: Bluetooth connection becomes unstable


### MUSE Position Tracking Instability (visionOS Limitation)

**Symptom**: The wand entity occasionally jumps to incorrect positions (typically 6-11cm offset) while maintaining correct orientation. The position then spontaneously corrects itself after continued movement.

**Root Cause**: This is a **visionOS/MUSE hardware tracking limitation**, not an application-level issue. Our investigation revealed:

1. **Hardware/OS Level Issue**: Debug logging shows the `AnchorEntity` position itself jumps, proving the instability originates from visionOS's accessory tracking system, not our RealityKit implementation.

2. **Verified Tracking Modes**: Both `.predicted` (low latency, prediction-based) and `.continuous` (higher latency, measurement-only) tracking modes exhibit the same instability. `.continuous` only adds latency without improving stability.

3. **Verified Anchor Locations**: Testing both `"aim"` (stylus tip) and `"origin"` (grip position ~5cm from tip) anchor locations shows identical instability patterns.

4. **Proper Implementation Verified**: The RealityKit entity hierarchy (AnchorEntity → wandModel → debug cubes) correctly maintains relative positions with 0.000m offset, confirming our implementation follows Apple's best practices.

**Why Software Mitigation Isn't Feasible**:

- **Smoothing filters** would introduce lag and misalignment during actual movement
- **Jump threshold filters** would cause the wand to "stick" at incorrect positions
- The tracking jumps are unpredictable in timing and magnitude (6-11cm)
- Any software correction risks degrading the user experience more than the original issue

**Possible Hardware/OS Causes**:

- IMU (Inertial Measurement Unit) sensor precision limits in MUSE hardware
- Visual-inertial fusion algorithm accuracy in visionOS spatial tracking
- Prediction model errors during rapid motion in `.predicted` mode
- Environmental factors affecting optical tracking (lighting, reflections)

**Status**: This issue has been reported to Apple via Feedback Assistant (FB22487954) and requires a fix at the visionOS or MUSE firmware level.

**Workaround**: Game design can minimize impact through larger hit boxes, visual effects (glowing trails), and strong haptic feedback to compensate for occasional visual misalignment.

## Contributing

Contributions are welcome! Please feel free to submit a Pull Request.

### Development Guidelines

1. Follow Swift 6 concurrency best practices (@MainActor, sendable)
2. Use structured concurrency (async/await, Task)
3. Add comprehensive code comments
4. Test on real Vision Pro hardware with MUSE

## License

MIT License

Copyright (c) 2026 Yos

Permission is hereby granted, free of charge, to any person obtaining a copy
of this software and associated documentation files (the "Software"), to deal
in the Software without restriction, including without limitation the rights
to use, copy, modify, merge, publish, distribute, sublicense, and/or sell
copies of the Software, and to permit persons to whom the Software is
furnished to do so, subject to the following conditions:

The above copyright notice and this permission notice shall be included in all
copies or substantial portions of the Software.

THE SOFTWARE IS PROVIDED "AS IS", WITHOUT WARRANTY OF ANY KIND, EXPRESS OR
IMPLIED, INCLUDING BUT NOT LIMITED TO THE WARRANTIES OF MERCHANTABILITY,
FITNESS FOR A PARTICULAR PURPOSE AND NONINFRINGEMENT. IN NO EVENT SHALL THE
AUTHORS OR COPYRIGHT HOLDERS BE LIABLE FOR ANY CLAIM, DAMAGES OR OTHER
LIABILITY, WHETHER IN AN ACTION OF CONTRACT, TORT OR OTHERWISE, ARISING FROM,
OUT OF OR IN CONNECTION WITH THE SOFTWARE OR THE USE OR OTHER DEALINGS IN THE
SOFTWARE.

## Acknowledgments

- **Apple**: visionOS, RealityKit, ARKit frameworks
- **Logitech**: MUSE spatial stylus hardware

## Contact

- **Author**: Yos (@alohayos)
- **GitHub**: [https://github.com/alohayos](https://github.com/alohayos)
- **Issues**: [https://github.com/alohayos/MagicWands/issues](https://github.com/alohayos/MagicWands/issues)

---

Built with ❤️ for Apple Vision Pro
