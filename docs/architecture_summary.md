# Architecture Summary

This document summarizes the current architecture of the CheerCom Calculator App, specifically focusing on the 3D body model, posing system, and Center of Mass (CoM) calculation logic.

## 1. Body Model Representation

The application uses Apple's **SceneKit** framework for 3D rendering.

*   **Mesh & Rig**: The character model is loaded from a Collada (`.dae`) file (`art.scnassets/character.dae`).
*   **Skeleton**: The model uses a standard **Mixamo** skeletal rig. All controllable joints are represented as `SCNNode` objects whose names are prefixed with `mixamorig_` (e.g., `mixamorig_Hips`, `mixamorig_RightArm`).
*   **Hierarchy**: The joint hierarchy follows a standard bipedal structure originating from the `Hips` root node.
*   **Scene Manager**: The `CheerCOMSceneManager` class is responsible for loading the scene, caching bone nodes for fast access, and managing the 3D environment.

## 2. Posing System

A "pose" in the application is defined as a specific configuration of joint angles.

*   **Definition**: The `PoseDefinition` struct in `PosePresets.swift` maps joint names (strings) to `SCNVector3` objects representing Euler angles (in radians).
*   **Application**: Poses are applied by iterating through the definition dictionary and directly setting the `eulerAngles` property of the corresponding `SCNNode` in the SceneKit hierarchy.
*   **Animation**: Poses are applied within an `SCNTransaction` to allow for smooth interpolation (animation) between states.
*   **Presets**: `PosePresets.swift` contains a library of predefined cheerleading and gymnastic poses (e.g., T-Pose, Touchdown, Squat, Pike, Layout).

## 3. Center of Mass (CoM) Computation

The total body Center of Mass is calculated dynamically based on the current 3D pose.

*   **Model**: The calculation relies on a **17-segment anthropometric model** (detailed in `docs/com_model.md`), primarily based on data from Winter (2009) and de Leva (1996).
*   **Method**:
    1.  The body is divided into 17 segments (e.g., Pelvis, Thorax, Thigh, Upper Arm).
    2.  Each segment is defined by a proximal (start) and distal (end) joint node.
    3.  A segment's individual CoM is calculated as a fixed percentage along the 3D line connecting its proximal and distal joints in world space.
    4.  The total body CoM is the weighted average of all segment CoMs, multiplied by their respective mass ratios (percentages of total body mass).
*   **Formula**: $CoM_{total} = \frac{\sum (m_i \times p_i)}{\sum m_i}$
*   **Execution**: The `COMCalculator` class performs this math. It uses a `bind` method to cache references to the specific `SCNNode` joints to optimize the per-frame calculation loop.

## 4. CoM Validation Harness

To ensure the CoM calculation remains accurate as the model evolves, a validation harness is included.

*   **Harness**: `CoMValidationHarness.swift` systematically cycles the character through a set of deterministic baseline poses.
*   **Verification**: For each pose, it verifies specific CoM displacement criteria (e.g., ensuring the CoM rises significantly during a "Touchdown" pose compared to a "T-Pose").
*   **Offline Testing**: A Python script (`tests/verify_com_math.py`) allows for independent mathematical verification of the mass ratios and fallback logic without running the SceneKit app.