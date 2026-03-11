# CheerComCalculatorApp

A 3D visualization tool to calculate and display the center of mass (CoM) for cheerleading poses using SceneKit.

## 📦 Project Structure

```
CheerComCaluculatorApp/
├── CheerComCaluculatorApp/
│   ├── CheerCOMApp.swift         # App entry point (UIKit)
│   ├── SceneViewController.swift # 3D scene rendering & controls
│   ├── COMCalculator.swift       # CoM calculation algorithm
│   ├── Managers/                 # Scene, Visualization, and Validation managers
│   ├── Views/                    # UI Panels and Overlays
│   └── art.scnassets/
│       └── character.dae         # 3D character model
└── tests/
```

## 🚀 Quick Start

1.  **Open in Xcode**: Open `CheerComCaluculatorApp.xcodeproj`.
2.  **Add Character**: Ensure `character.dae` (Mixamo T-Pose, Collada format) is in `art.scnassets`.
3.  **Build & Run**: Run on Simulator or Device.

## 🎮 Features

*   **Real-time 3D Visualization**: Renders a character model and updates CoM in real-time.
*   **CoM Marker**: A green sphere indicates the total body Center of Mass.
*   **Advanced Visualizations**:
    *   Segment CoM markers (Cyan spheres).
    *   Base of Support (BOS) polygon.
    *   CoM Trail.
    *   Gravity Line.
*   **Pose Library**: Apply preset poses (Liberty, Scale, Squat, etc.) or save custom poses.
*   **Pose Mirroring**: Flip any pose left↔right with one tap.
*   **Joint Control**: Manually rotate individual joints with visual highlighting.
*   **Keyboard Shortcuts**: Arrow keys for transform, M to mirror, R to reset, F for fine control.
*   **Copy CoM Data**: Export coordinates to clipboard for external use.
*   **FPS Overlay**: Debug performance indicator.
*   **Diagnostics**: Built-in validation harness to audit the CoM model.

## 📊 CoM Model

The app uses a 17-segment anthropometric model.
See [docs/com_model.md](docs/com_model.md) for detailed documentation on the segments, coordinate system, and assumptions.

## 🧪 Verification

To verify the model's accuracy:
1.  Run the app.
2.  Tap **"Run Diagnostics"** in the top right.
3.  The app will cycle through key poses (T-Pose, Touchdown, Squat, Pike, Layout).
4.  Observe the logs in the on-screen overlay or Xcode console.

## ⚙️ Requirements

*   iOS 15.0+
*   Xcode 13+
*   Mixamo-compatible character rig (`mixamorig_` bone names).

## 📝 License

Proprietary / Closed Source.
