# Baseline Audit

This document answers the specific questions outlined for the first step of our continuous improvement process.

## 1. Where the body model and CoM logic currently live

*   **Body Model & 3D Environment**: Managed primarily in `CheerComCaluculatorApp/Managers/CheerCOMSceneManager.swift`. The 3D model itself is stored as a Collada file at `art.scnassets/character.dae`.
*   **Center of Mass (CoM) Logic**: Computed in `CheerComCaluculatorApp/COMCalculator.swift`. The segment definitions and their mass ratios (anthropometric distribution) are hardcoded within this class.
*   **Poses & Joint Limits**: Managed in `CheerComCaluculatorApp/Managers/PosePresets.swift` and `CheerComCaluculatorApp/Managers/JointLimits.swift`.
*   **Validation Harness**: The code to run the CoM tests lives in `CheerComCaluculatorApp/Managers/CoMValidationHarness.swift` (for the iOS runtime) and `tests/verify_com_math.py` (for offline mathematical verification).
*   **Visualizations**: Handled by `CheerComCaluculatorApp/Managers/VisualizationsManager.swift`.

## 2. Summarize current architecture

### How the model is represented
*   **Mesh & Rig**: The application uses SceneKit to render a 3D character mesh loaded from `character.dae`.
*   **Skeleton**: The model is rigged using a standard **Mixamo** skeletal hierarchy. Bones are accessed via `SCNNode` instances, with joint names prefixed by `mixamorig_` (e.g., `mixamorig_Hips`, `mixamorig_RightArm`).
*   **Segments**: The body is logically divided into 17 segments (e.g., Thigh, Shank, Forearm). Each segment is defined by a pair of SceneKit nodes acting as the proximal (start) and distal (end) joints.

### How a "pose" is defined
*   **Joint Transforms**: A pose is fundamentally a dictionary mapping joint string names to `SCNVector3` Euler angles (in radians).
*   **Animation System**: The `eulerAngles` properties of the `SCNNode` bones are modified directly to set a pose. These modifications are wrapped in an `SCNTransaction` to automatically handle smooth interpolation and animation over a specified duration.
*   **Enforcement**: Before applying any angles to a bone, the angles are clamped by `JointLimits.swift` to prevent anatomically impossible configurations.

### How CoM is computed
*   **Method**: The total body Center of Mass is computed as a weighted average. The algorithm first calculates the position of each individual segment's CoM in world space. Then, it multiplies each segment's position by its respective mass ratio, sums these weighted positions, and divides by the total mass.
*   **Assumptions**: The segment CoM is assumed to lie on a straight line connecting the proximal and distal joints at a specific, fixed percentage distance from the proximal joint. If a distal joint (like a fingertip) is missing, the algorithm defaults back to using the proximal joint position for that segment.
*   **Segment Weights**: The model uses anthropometric mass distribution ratios based on Winter (2009) and de Leva (1996). Recent additions allow for "Body Presets" (e.g., Athletic Female) which dynamically scale the mass ratios for the trunk, upper limbs, and lower limbs while maintaining normalization so they sum to 1.0.
*   **Coordinate Space**: All CoM calculations are performed in World Coordinate Space by querying the `.presentation.worldPosition` property of the cached `SCNNode` bones to ensure accuracy even during animations.

## Conclusion

The initial baseline audit is complete. The application successfully implements a 17-segment model, and a validation harness has been confirmed operational across all required deterministic test poses, logging segment masses and COM points.

* Note: Added a ground plane visualization for baseline sanity checking.
*Audit updated on May 5, 2026. The codebase currently meets all "First Step: Baseline Audit" requirements, with the CoM test harness and documentation successfully integrated.*
