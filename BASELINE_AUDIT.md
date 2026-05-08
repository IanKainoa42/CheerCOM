# Baseline Audit

## 1. Where do the body model and CoM logic currently live?
- **CoM Algorithm**: `CheerComCaluculatorApp/CheerComCaluculatorApp/COMCalculator.swift`
- **3D Scene Rendering & Controls**: `CheerComCaluculatorApp/CheerComCaluculatorApp/SceneViewController.swift`
- **Pose Presets**: `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/PosePresets.swift`
- **CoM Validation Harness**: `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/CoMValidationHarness.swift`
- **Visualizations (CoM Marker, BOS, Segments, Axes, Trail)**: `CheerComCaluculatorApp/CheerComCaluculatorApp/Managers/VisualizationsManager.swift`
- **Diagnostics Overlay**: `CheerComCaluculatorApp/CheerComCaluculatorApp/Views/DiagnosticsOverlay.swift`
- **Python Math Verification Harness**: `tests/verify_com_math.py`
- **CoM Model Documentation**: `docs/com_model.md`

## 2. Current Architecture Summary
- **Model Representation**: The 3D character is represented using a SceneKit mesh rigged to a Mixamo skeleton. Segments are defined as straight lines between a proximal joint and a distal joint. The 17-segment model uses anthropometric mass ratios.
- **Pose Definition**: A pose is defined by setting the Euler angles (`SCNVector3` in degrees/radians) of specific `mixamorig_` bones relative to their parent coordinate spaces. Pose definitions are stored in `PosePresets.swift` and use `SCNTransaction` to animate/apply.
- **CoM Computation**:
  - Each segment's mass is a predefined ratio of the total body mass.
  - A segment's local CoM position is computed as a fixed percentage along the vector from its proximal joint to its distal joint (`proxPos + (distPos - proxPos) * comRatio`).
  - Total CoM is the mass-weighted average of all 17 segment CoMs: `Sum(segMass * segCOM) / TotalMass`.
  - The coordinate system uses Y-up, X-right, Z-forward. CoM vectors are in world coordinates.

## 3. Realism Goals Assessment
- **A) Skeletal Rig + Joint Constraints**: A basic 17-segment Mixamo rig is implemented. Joint limits are currently enforced globally via `JointLimits.swift` but need to be visually reported or logged when clamped.
- **B) Anthropometric Mass Distribution**: Implemented based on Winter (2009) and de Leva (1996). Segment masses are ratios of total mass.
- **C) Pose -> Segment Transform -> CoM**: The transform order relies on SceneKit's internal scene graph updates. Debug visuals for segment CoM points, CoM marker, ground plane, and axes exist.
- **D) Move Body Into Any Shape**: Supported via explicit joint angle control and pose presets. IK or other control methods are not currently present.
