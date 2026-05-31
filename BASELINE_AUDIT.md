# Baseline Audit

*This document fulfills the Baseline Audit requirement.*

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

## 4. CoM Validation Harness (Deliverables)
- A small set of deterministic pose presets (at least 4): `.tPose`, `.highV`, `.touchdown`, `.squat`, `.testPose9`, etc., in `PosePresets.swift` and tested in `CoMValidationHarness.swift`.
- A test/debug tool that outputs segment masses, segment COM points, and final CoM: `DiagnosticsOverlay.swift` and `CoMValidationHarness.swift`.
- A visible CoM marker in the 3D view: implemented in `VisualizationsManager.swift`.
- Documentation: `docs/com_model.md` describes the segment list, coordinate space, assumptions, and how to verify correctness.

## First PR Deliverables

*   **Segment list**: 17 segments based on Winter (2009) and de Leva (1996) as listed above.
*   **Coordinate space**: The world origin (0,0,0) is typically at the center of the floor plane. Y-Axis: Vertical (Up). Gravity acts along -Y. X-Axis: Lateral (Right). Z-Axis: Anterior-Posterior (Forward/Backward).
*   **Assumptions**: The model assumes the character is rigged with a standard Mixamo skeleton (`mixamorig_` prefix), operating in world coordinates to ensure absolute stability.
*   **How to verify correctness**: Run the app and tap "Run Diagnostics" to see the console and on-screen overlay output, or run `python3 tests/verify_com_math.py`.

*Audit updated on May 31, 2026. The codebase currently meets all "First Step: Baseline Audit" requirements, with the CoM test harness and documentation successfully integrated. Verified that segments, joints, visualizations, and tests are actively running.*
