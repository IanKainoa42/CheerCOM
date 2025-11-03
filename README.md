# CheerCOM - Center of Mass Calculator for Cheerleading

A 3D visualization tool to calculate and display the center of mass (COM) for cheerleading poses using SceneKit.

## 📦 Project Structure

```
CheerCOM/
├── CheerCOM/
│   ├── CheerCOMApp.swift         # App entry point (UIKit)
│   ├── SceneViewController.swift # 3D scene rendering & controls
│   ├── COMCalculator.swift       # COM calculation algorithm
│   └── art.scnassets/
│       └── character.dae         # 3D character model (download separately)
└── README.md
```

**Total: ~260 lines of code**

## 🚀 Quick Start

### 1. Create Xcode Project
```
Xcode → File → New → Project
├── Platform: iOS
├── Template: App
├── Interface: UIKit ⚠️ (NOT SwiftUI!)
├── Language: Swift
└── Product Name: CheerCOM
```

### 2. Add Source Files
1. In Xcode Navigator, **delete** the auto-generated `ViewController.swift`
2. **Drag & drop** these files from Finder into Xcode:
   - `CheerCOMApp.swift`
   - `SceneViewController.swift`
   - `COMCalculator.swift`
   - `art.scnassets/` folder (entire folder as folder reference - blue icon)
3. Check **"Copy items if needed"**

### 3. Get 3D Character Model
1. Go to **[mixamo.com](https://www.mixamo.com)** (free account required)
2. Browse **Characters** → Pick any humanoid
3. **Download** with settings:
   - Format: **COLLADA (.dae)** ⚠️
   - Pose: **T-Pose**
   - Skin: **With Skin**
4. Rename downloaded file to **`character.dae`**
5. Drag `character.dae` into `art.scnassets` folder in Xcode

### 4. Configure Info.plist
- Open `Info.plist` in Xcode
- Remove any `UISceneDelegate` or `Application Scene Manifest` entries
- The app uses traditional `AppDelegate` pattern

### 5. Build & Run
- Press **⌘R** to build and run
- Watch the console (**⌘⇧C**) for bone names
- After 2 seconds, character performs Liberty pose!

## 🎮 Features

**3D Visualization:**
- Real-time 3D character rendering with SceneKit
- Interactive camera controls (drag, pinch, pan)
- Red sphere marking the center of mass
- Automatic COM recalculation on pose changes

**Pose Library:**
- `applyLiberty()` - Single leg raised to 90°
- `applyScale()` - Both legs raised
- `resetPose()` - Return to T-pose

**Camera Controls (Built-in):**
- **One finger drag** - Rotate camera
- **Two finger drag** - Pan camera
- **Pinch** - Zoom in/out

## 📊 Technical Details

**COM Calculation Algorithm:**
- Based on validated anthropometric data (Winter 2009, de Leva 1996)
- 14 body segments with mass percentages and COM positions
- Default body mass: 52.2 kg (115 lbs) - configurable

**Body Segments:**
```
Trunk, Head/Neck
L/R Upper Arm, Forearm, Hand
L/R Thigh, Shank, Foot
```

## ⚙️ Critical: Map Your Bone Names

**After first run, check the console output** - it prints all bone names from your model.

Your Mixamo model's bones must match the names in `COMCalculator.swift`:

**Update the `segments` array** in `COMCalculator.swift`:
```swift
let segments: [(prox: String, dist: String, mass: Double, com: Double)] = [
    ("Hips", "Spine", 0.497, 0.50),              // Use YOUR bone names here
    ("Spine2", "Head", 0.081, 0.50),
    ("RightShoulder", "RightArm", 0.028, 0.44),
    // ... etc
]
```

**Common Mixamo bone names:**
```
Hips (root)
├── Spine → Spine1 → Spine2
│   ├── Neck → Head
│   ├── LeftShoulder → LeftArm → LeftForeArm → LeftHand
│   └── RightShoulder → RightArm → RightForeArm → RightHand
├── LeftUpLeg → LeftLeg → LeftFoot → LeftToeBase
└── RightUpLeg → RightLeg → RightFoot → RightToeBase
```

## 🔧 Troubleshooting

| Problem | Solution |
|---------|----------|
| "ERROR: Model not found" | Check `character.dae` is in `art.scnassets` folder |
| Character loads but bones don't move | Bone names don't match - update `COMCalculator.swift` |
| COM sphere stays at (0,0,0) | Check console for "⚠️ Missing joint" warnings |
| App crashes on launch | Verify you selected **UIKit** (not SwiftUI) |
| Black screen | Check lighting setup, camera position |

**Console Warnings:**
- `⚠️ Missing joint` - Bone name mismatch, update segment names
- `⚠️ Warning: Bone 'X' not found` - Update pose functions with correct names

## 🎯 Testing

Add to `viewDidLoad()` in `SceneViewController.swift`:
```swift
// Test liberty pose
DispatchQueue.main.asyncAfter(deadline: .now() + 2) {
    self.applyLiberty()
}

// Test scale pose
DispatchQueue.main.asyncAfter(deadline: .now() + 4) {
    self.applyScale()
}

// Reset
DispatchQueue.main.asyncAfter(deadline: .now() + 6) {
    self.resetPose()
}
```

## 📈 Expansion Ideas

**Phase 1: UI Controls** (~50 lines)
- Add buttons for each pose
- Stack view with Liberty, Scale, Arabesque buttons

**Phase 2: Body Mass Input** (~20 lines)
- UITextField for custom mass
- Update calculator on change

**Phase 3: COM Display** (~15 lines)
- UILabel showing COM coordinates
- Real-time updates

**Phase 4: More Poses** (~30 lines each)
- Heel Stretch
- Scorpion
- Arabesque
- Pike

**Phase 5: Data Export** (~30 lines)
- Export COM data as JSON
- Save pose configurations

## 📝 Architecture

```
CheerCOMApp.swift (@main)
    ↓
Creates UIWindow with SceneViewController
    ↓
SceneViewController
    ├── setupScene() - SceneKit configuration
    ├── loadCharacter() - Load .dae model
    ├── setupCOMMarker() - Red sphere indicator
    └── updateCOM() - Calculate & display
        ↓
    COMCalculator
        └── calculateBodyCOM() - Weighted segment average
```

## ✅ Success Checklist

- [ ] Xcode project created with UIKit interface
- [ ] All 3 Swift files added to project
- [ ] `art.scnassets` folder added (blue folder icon)
- [ ] `character.dae` downloaded from Mixamo
- [ ] `character.dae` placed in `art.scnassets`
- [ ] App builds without errors (⌘B)
- [ ] Character visible in simulator
- [ ] Red COM sphere visible
- [ ] Console shows bone names
- [ ] Bone names updated in `COMCalculator.swift`
- [ ] Liberty pose triggers and sphere moves
- [ ] COM coordinates print to console

## 🎉 You're Ready!

Get your Mixamo character, map the bone names, and see your center of mass calculator in action. The red sphere will follow your character's COM as they move through different cheerleading poses.

---

**Default Settings:**
- Body Mass: 52.2 kg (115 lbs)
- Camera Position: (0, 100, 300)
- COM Sphere Radius: 5 units
- Background: Black

**Data Sources:**
- Anthropometric data: Winter (2009), de Leva (1996)
- Segment mass percentages validated for athletic populations
