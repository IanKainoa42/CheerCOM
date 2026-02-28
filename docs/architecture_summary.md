# Architecture Summary

This document summarizes the current architecture of the CheerCOM application, as discovered during the Baseline Audit.

## Where the code lives
* **App Entry & UI**: `CheerComCaluculatorApp/CheerComCaluculatorApp/`
* **Scene and Visuals**: `SceneViewController.swift` and `Managers/CheerCOMSceneManager.swift`, `Managers/VisualizationsManager.swift`
* **CoM Calculation**: `COMCalculator.swift`
* **Pose Management**: `Managers/PosePresets.swift` and `Managers/PoseStorageManager.swift`
* **Validation Harness**: `Managers/CoMValidationHarness.swift` and `tests/verify_com_math.py`

## How the model is represented
The 3D character is represented as a SceneKit (`SCNNode`) hierarchy, loaded from a Collada (`.dae`) file containing a Mixamo-compatible rig. The `CheerCOMSceneManager` finds and caches standard `mixamorig_` bones. The model does not use active animations; instead, it relies entirely on explicit Euler angle definitions to set poses.

## How a "pose" is defined
A pose is defined as a dictionary of bone names mapping to explicit Euler angles (`SCNVector3`) in radians (e.g. `["mixamorig_RightArm": SCNVector3(x, y, z)]`). These definitions live in `PosePresets.swift` (for preset poses like T-Pose, Touchdown, etc.) and can be modified or saved via user interactions. A pose is applied by writing these Euler angles directly to the local transforms (`eulerAngles`) of the corresponding `SCNNode` bones.

## How CoM is computed
CoM is computed in `COMCalculator.swift` using a 17-segment anthropometric model.
1. The human body is divided into 17 segments (Head, Thorax, Abdomen Upper/Lower, Pelvis, Thighs, Shanks, Feet, Upper Arms, Forearms, Hands).
2. Each segment has a predefined mass percentage of the total body mass and a center-of-mass location (represented as a percentage distance along the segment from the proximal joint to the distal joint).
3. The calculation fetches the absolute 3D position in world space (`worldPosition`) for every joint.
4. For each segment, it calculates the segment's CoM in 3D space, multiplies by the segment's mass to find the weighted position, and accumulates this to find the total weighted position.
5. The final total CoM is the sum of weighted positions divided by the total mass.

The `COMCalculator` handles fallbacks (e.g., if a hand tip joint is missing, it places the CoM directly at the wrist).

## Validation Harness
The CoM model is validated via a two-pronged approach:
1. **In-App (Swift)**: `CoMValidationHarness.swift` applies deterministic poses to the SceneKit model and verifies the CoM shifts relative to a baseline T-Pose. It logs detailed tables of segment coordinates and masses.
2. **Offline (Python)**: `tests/verify_com_math.py` creates a mocked vector space to simulate SceneKit logic, mathematically asserting the correctness of the total mass distribution and the resulting CoM calculations for the deterministic poses.
