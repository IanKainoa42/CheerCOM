# WARP.md

This file provides guidance to WARP (warp.dev) when working with code in this repository.

## Overview

This repo contains an iOS SceneKit app for visualizing and analyzing the center of mass (COM) of cheerleading poses using a Mixamo humanoid model. The main app is under `CheerComCaluculatorApp/` and is also exposed as a Swift Package (`CheerComCalculatorApp` library).

The root `README.md` is authoritative for setup and usage, but its example tree (`CheerCOM/CheerCOM/...`) is slightly outdated relative to the current layout. The actual app sources live under `CheerComCaluculatorApp/CheerComCaluculatorApp/`.

## Common Commands & Workflows

### Open the project

- Open the Xcode project (primary way to work on the app):
  - From the repo root:
    - `open CheerComCaluculatorApp/CheerComCaluculatorApp.xcodeproj`

- Open the Swift Package (if you want to treat it as a reusable library inside Xcode):
  - From the repo root:
    - `open CheerComCaluculatorApp/Package.swift`

### Build & run the app

Most development is done via Xcode, targeting the iOS simulator.

- Build & run in Xcode (from the Xcode UI):
  - Select the `CheerComCaluculatorApp` scheme.
  - Choose an iOS Simulator (e.g. iPhone).
  - Press `⌘R` to build and run.

- Build the SwiftPM target from the terminal (library only):
  - From the repo root:
    - `cd CheerComCaluculatorApp`
    - `swift build`

There is no dedicated CLI wrapper in this repo for running the app; use Xcode for running and debugging.

### Tests & linting

- Automated tests: there are currently **no unit test targets or test files** in this repo. Testing is manual via the running app.
  - The `README.md` includes a "Testing" section that shows how to temporarily add delayed pose calls (e.g. `applyLiberty()`, `applyScale()`, `resetPose()`) inside `SceneViewController.viewDidLoad()` to exercise COM behavior.
- Linting: there is **no linting configuration** (e.g. SwiftLint) defined in this repo.

When adding tests or linting in the future, prefer wiring them up via standard Xcode targets or Swift Package Manager so they can be driven by `xcodebuild` / `swift test` without custom scripts.

### Mixamo model setup (critical for a working run)

Key points from `README.md` that are required to get a usable scene:

- Obtain a character from Mixamo as `character.dae`:
  - Format: COLLADA (`.dae`)
  - Pose: T-pose
  - Skin: With Skin
- Place `character.dae` inside `CheerComCaluculatorApp/CheerComCaluculatorApp/art.scnassets/` and ensure it is added to the Xcode project as a folder reference (blue folder).
- On first run, check the Xcode console for the list of node names printed by `CheerCOMSceneManager.cacheBoneNodes()`. These must align with the bone names expected by `COMCalculator` and the pose presets (all use Mixamo-style `mixamorig_...` names).

If bone names differ from the defaults, COM calculation and pose presets will need to be updated to match your specific skeleton.

## High-Level Architecture

### App lifecycle & composition

- **Entry point:** `CheerCOMApp.swift`
  - `AppDelegate` is marked with `@main` and sets up a modern scene-based lifecycle.
  - `SceneDelegate` creates a `UIWindow` for the `UIWindowScene`, instantiates `SceneViewController`, and assigns it as `rootViewController`.

- **Root view controller:** `SceneViewController`
  - Owns and wires together all core managers and UI panels:
    - `CheerCOMSceneManager` – SceneKit scene + character loading & joint caching.
    - `CameraManager` – discrete camera viewpoints and camera animation.
    - `VisualizationsManager` – COM marker, trail, base-of-support, gravity line, stability analysis.
    - `COMCalculator` – COM computation using anthropometric segment data.
    - UI overlays: `COMInfoPanel`, `JointControlPanel`, `TransformControlPanel`, `PoseLibraryPanel`.
  - Runs a timer-driven update loop (~30 FPS) that recomputes COM only when `needsCOMUpdate` is set, to avoid unnecessary work.

### Scene & skeleton management

- **`CheerCOMSceneManager`** (in `Managers/`):
  - Creates the `SCNView` and attaches it to the root `UIView`.
  - Configures a basic `SCNScene` with:
    - Ambient, directional, and side lights.
    - A `SCNFloor` ground plane for reference.
  - Loads the Mixamo character from `art.scnassets/character.dae` into `characterNode`.
    - Removes all baked animations and actions recursively to ensure manual `eulerAngles` control works.
  - Maintains a curated list of **controllable joints** (Mixamo `mixamorig_...` names) and caches them in `cachedBoneNodes` for efficient access.
  - Provides helper APIs:
    - `cacheBoneNodes()` – prints all node names, caches expected joints, and logs missing ones.
    - `findBone(named:)` – lookup by name with caching.
    - `frameCharacter()` – positions the camera to frame the character automatically.

This manager is the single source of truth for the skeleton and its node graph; all pose and visualization logic should go through it (or its cached nodes) rather than re-traversing the scene tree.

### Camera & viewpoints

- **`CameraManager`** (in `Managers/`):
  - Owns a dedicated `SCNNode` with an `SCNCamera` attached.
  - Defines a small set of canonical viewpoints (`Front`, `Right`, `Back`, `Left`, `Top`) as `(position, lookAt)` pairs.
  - Provides APIs to:
    - Initialize the camera and attach it to the scene root.
    - Switch views with smooth `SCNTransaction`-based animations (`nextView`, `previousView`, `fitToView`).

Note: `SCNView.allowsCameraControl` is enabled for free-form interaction, but `CameraManager` is used for deterministic, labeled views that can be triggered from UI.

### COM calculation & physics logic

- **`COMCalculator`** (root of COM math):
  - Configured with a `bodyMass` (default 52.2 kg, per `README.md`).
  - Encodes 14 body segments as tuples: `(proximalJointName, distalJointName, massFraction, comFraction)` based on anthropometric data (Winter 2009, de Leva 1996).
  - `calculateBodyCOM(jointPositions:)`:
    - Expects a dictionary of world-space `SCNVector3` joint positions (supplied by `SceneViewController` from `CheerCOMSceneManager.cachedBoneNodes`).
    - For each segment:
      - Computes segment COM along the line between proximal and distal joints.
      - Weights by segment mass and accumulates a global weighted average.
    - Logs warnings if expected joints are missing; falls back to origin if total mass is zero.
  - Local `SCNVector3` arithmetic extensions (`+`, `-`, `*`) support concise vector math.

All higher-level features that care about balance or COM should be built on top of this class, using world-space joint positions.

### Visualizations & stability analysis

- **`VisualizationsManager`** (in `Managers/`):
  - Owns and manages COM-related scene nodes:
    - `comMarker` – a green sphere marking the current COM.
    - `comTrailNode` – a sequence of small spheres rendering the COM path over time.
    - `gravityLineNode` – a cylinder projecting the COM vertically toward the ground.
    - `bosNode` – geometry approximating the **Base of Support** from foot and toe joints.
    - `gridNode` – orthogonal planes forming a reference grid.
  - Tracks COM history (`trailPositions`) with a cap to bound memory / node count.
  - Provides `updateCOM(position:)` which:
    - Moves the COM marker.
    - Updates the COM trail with fading opacity.
    - When advanced visualizations are enabled, updates the gravity line, BOS, and stability visuals.
  - Defines **stability analysis** APIs:
    - `calculateStabilityMargin(com:)` – 2D polygon containment + distance to nearest BOS edge.
      - Returns `(margin, isStable)` where `margin` is the minimum distance from COM projection to BOS boundary.
    - `updateStabilityVisuals(margin:isStable:)` – maps stability state to marker and gravity-line colors (green/yellow/red thresholds).
    - `highlightUnstableSegments(com:)` – uses BOS center vs COM vector and dot products over cached bone nodes to highlight the most "unstable" limb segments.
    - `resetSegmentHighlights()` – clears emission highlights when visualizations are disabled or pose becomes stable.

`SceneViewController` calls into `VisualizationsManager.updateCOM` every time COM is updated, and defers all visual logic to this manager.

### Pose system

- **`SharedTypes.swift`**:
  - Defines enums for pose-related concepts:
    - `PoseCategory` – `.fullBody`, `.armsOnly`, `.legsOnly`, `.saved`.
    - `PoseType` – a curated set of common cheerleading poses (e.g. `.liberty`, `.scale`, `.arabesque`, `.highV`, `.lowV`, `.standingSplit`, plus arm-only and leg-only variants).
    - `RotationDirection`, `TransformMode`, `TransformDirection` – used for incremental controls.
  - Each `PoseType` exposes:
    - `category` – which tab it belongs to.
    - `displayName` – UI-friendly label.
    - `emoji` – used as a compact visual representation in the pose library grid.

- **`PosePresets`** (in `Managers/`):
  - Singleton providing concrete `PoseDefinition` values for each `PoseType`.
  - `PoseDefinition` fields:
    - `name`, `category`.
    - `jointAngles: [String: SCNVector3]` – **radians**, keyed by Mixamo joint names.
    - `description` – human-readable explanation.
    - `affectedJoints` – optional subset to allow partial poses that only modify arms or legs.
  - `getPose(_:)` – switch over `PoseType` to return a complete pose definition.
  - `getPoses(for:)` – returns all `PoseType` values in a given `PoseCategory`.

- **Application of poses** (in `SceneViewController`):
  - Uses `PosePresets.shared.getPose` to obtain pose data.
  - For each `(jointName, angles)` pair, calls `sceneManager.findBone(named:)` and assigns `eulerAngles` on the corresponding `SCNNode` inside an `SCNTransaction` animation block.
  - Schedules COM recomputation on completion.

### UI panels & interaction model

All UI panels are custom `UIView` / `UIVisualEffectView` subclasses that overlay on top of the SceneKit view.

- **`COMInfoPanel`**:
  - Small blurred HUD showing:
    - COM coordinates (X/Y/Z).
    - Stability status (Stable/Unstable) and margin of stability.
    - Short textual feedback (e.g., "Good Balance", "Caution: Near Edge", "Shift Weight Back").
  - Updated from `SceneViewController.performCOMUpdate()` based on values returned from `VisualizationsManager.calculateStabilityMargin`.

- **`JointControlPanel`**:
  - Delegates to `JointControlPanelDelegate` (implemented by `SceneViewController`).
  - Responsibilities:
    - Selecting the active joint to control (via an action sheet listing `sceneManager.controllableJoints`).
    - Selecting the axis (`JointAxis`) and visualizing the current angle.
    - Providing fine-grained control via `+/-` buttons and a slider (angles in degrees mapped to `eulerAngles` in radians).
    - Exposing buttons for:
      - Pose library toggle.
      - Reset current pose to canonical T-pose.
      - "Fit View" (delegates to `CameraManager`).
      - Toggle COM visualizations (delegates to `VisualizationsManager`).

- **`PoseLibraryPanel`**:
  - Delegates to `PoseLibraryPanelDelegate` (implemented by `SceneViewController`).
  - Provides:
    - Category segmented control (Full Body / Arms / Legs).
    - Scrollable grid of pose buttons, each showing an emoji + short label.
    - Buttons for closing the panel, mirroring poses, and saving poses (mirror/save are currently placeholders with `TODO` printouts).
  - Converts tapped buttons back into `PoseType` instances via a simple string-based mapping.

- **`TransformControlPanel`**:
  - Delegates to `TransformControlPanelDelegate` (implemented by `SceneViewController`).
  - Controls global character transforms:
    - Modes: `.position`, `.rotation`, `.scale` (with different `transformStep` magnitudes).
    - Arrow-style controls for up/down/left/right that modify the `characterNode` accordingly.
    - "Reset Position" to restore default position, rotation, and scale.
  - `SceneViewController` responds by updating `characterNode` on `CheerCOMSceneManager` and scheduling COM updates.

### Input model & update loop

- `SceneViewController` enables hardware keyboard input and overrides `pressesBegan` to:
  - Map arrow keys to global transform actions via `TransformControlPanel` helpers.
  - Map the space bar to cycle through `TransformMode`.

- COM updates are **event-driven with throttling**:
  - Various actions (`didRotateJoint`, `didChangeJointAngle`, pose application, transform button presses, pose reset, etc.) call `scheduleUpdateCOM()`.
  - The timer (`updateTimer`) runs at ~30 FPS, and on each tick only recomputes COM if `needsCOMUpdate` is set, then clears the flag.

This pattern prevents redundant COM calculations while still keeping visuals responsive for interactive controls.

## Things to Keep in Mind When Editing

- All pose and COM logic assumes Mixamo-style `mixamorig_...` bone names. If you change models, update **both** `COMCalculator.segments` and the pose definitions in `PosePresets` (and validate using the bone-name debug printout in `CheerCOMSceneManager.cacheBoneNodes()`).
- Visual stability features (BOS, gravity line, unstable-segment highlighting) depend on foot and toe node names (`mixamorig_LeftFoot`, `mixamorig_RightFoot`, `mixamorig_LeftToeBase`, `mixamorig_RightToeBase`). If you rename or remove these, update `VisualizationsManager.getBOSPoints()` accordingly.
- When adding new poses, extend `PoseType`, `PosePresets.getPose(_:)`, and `PosePresets.getPoses(for:)`, and ensure any new joints are available in `CheerCOMSceneManager.cachedBoneNodes`.
- To avoid performance regressions, preserve the existing `needsCOMUpdate` throttling pattern rather than recalculating COM on every frame unconditionally.
