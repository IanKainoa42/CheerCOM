# Body Model & Center of Mass (CoM) Documentation

## Overview

This document describes the 17-segment human body model used for Center of Mass (CoM) calculations in the CheerComCalculatorApp. The model is based on anthropometric data from Winter (2009) and de Leva (1996), adapted for the Mixamo rig structure.

## Coordinate System

*   **Y-Axis**: Vertical (Up is positive).
*   **X-Axis**: Lateral (Right is positive).
*   **Z-Axis**: Anterior-Posterior (Forward is positive in this scene, though standard Mixamo T-Pose faces +Z).
*   **Units**: SceneKit units (roughly corresponding to meters or centimeters depending on scale; relative positions matter most).

## Segment Definition

The total body mass is distributed across 17 segments. Each segment is defined by a proximal joint and a distal joint. The segment's Center of Mass is located at a percentage of the distance from the proximal joint to the distal joint.

| Segment Name | Proximal Joint | Distal Joint | Mass % | CoM % (from Proximal) |
| :--- | :--- | :--- | :---: | :---: |
| **Head** | Neck | Head | 8.1% | 50% |
| **Thorax** | Spine2 | Neck | 18.0% | 50% |
| **Abdomen Upper** | Spine1 | Spine2 | 8.55% | 50% |
| **Abdomen Lower** | Spine | Spine1 | 8.55% | 50% |
| **Pelvis** | Hips | Spine | 14.6% | 50% |
| **R Upper Arm** | RightShoulder | RightArm | 2.8% | 44% |
| **R Forearm** | RightArm | RightForeArm | 1.6% | 43% |
| **R Hand** | RightForeArm | RightHand | 0.6% | 50% |
| **L Upper Arm** | LeftShoulder | LeftArm | 2.8% | 44% |
| **L Forearm** | LeftArm | LeftForeArm | 1.6% | 43% |
| **L Hand** | LeftForeArm | LeftHand | 0.6% | 50% |
| **R Thigh** | RightUpLeg | RightLeg | 10.0% | 43% |
| **R Shank** | RightLeg | RightFoot | 4.65% | 43% |
| **R Foot** | RightFoot | RightToeBase | 1.45% | 50% |
| **L Thigh** | LeftUpLeg | LeftLeg | 10.0% | 43% |
| **L Shank** | LeftLeg | LeftFoot | 4.65% | 43% |
| **L Foot** | LeftFoot | LeftToeBase | 1.45% | 50% |

**Total Mass**: 100% (approx)

## Assumptions

1.  **Symmetry**: Left and right sides have identical mass properties.
2.  **Rigidity**: Segments are treated as rigid bodies between joints.
3.  **Density**: Uniform density assumed for CoM location (mostly 50% or standard biomechanical estimates).
4.  **Neutral Pose**: The model assumes a standard T-Pose as the baseline for joint rotations.

## Validation & Verification

To verify the correctness of the CoM calculation:

1.  **Automated Diagnostics**:
    *   Launch the app.
    *   Tap the **"Run Diagnostics"** button in the top-right corner.
    *   The system will cycle through deterministic poses (T-Pose, Touchdown, Squat, Pike, Layout).
    *   Check the overlay log for:
        *   **Mass Sum Check**: Should be ~1.0.
        *   **Pose Verification**: Each pose has criteria (e.g., Squat CoM must be lower than T-Pose). Pass/Fail status is displayed.

2.  **Visual Verification**:
    *   **Green Sphere**: Represents the total Body CoM.
    *   **Cyan Spheres**: Represent individual segment CoMs (visible during diagnostics).
    *   **Visual Aids**: Gravity line, Base of Support (BOS) polygon, and stability coloring (Green=Stable, Red=Unstable) are available.

3.  **Unit Tests**:
    *   Run `CheerComCalculatorAppTests` to verify calculation logic without the UI.

## Known Limitations & Issues

1.  **Segment Mapping Shift**: The current implementation maps arm segments one joint higher than anatomically correct for the Mixamo rig:
    *   "R Upper Arm" maps to the Clavicle/Scapula region (`RightShoulder` -> `RightArm`).
    *   "R Forearm" maps to the Humerus/Upper Arm (`RightArm` -> `RightForeArm`).
    *   "R Hand" maps to the Radius/Ulna/Forearm (`RightForeArm` -> `RightHand`).
    *   This results in the actual Hand mass being placed on the Forearm, and the Forearm mass on the Upper Arm. This will be addressed in a future update.

2.  **Complex Deformations**: Soft tissue deformations are not modeled.
