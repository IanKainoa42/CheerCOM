# Body Model & Center of Mass (CoM) Documentation

This document describes the biomechanical model used to calculate the Center of Mass (CoM) for the character.

## Model Overview

The model uses a **17-segment** approach based on anthropometric data from Winter (2009) and de Leva (1996). The total body mass is distributed across these segments, and the CoM for each segment is calculated based on its proximal and distal joint positions.

*   **Y-Axis**: Vertical (Up is positive).
*   **X-Axis**: Lateral (Right is positive).
*   **Z-Axis**: Anterior-Posterior (Forward is positive in this scene, though standard Mixamo T-Pose faces +Z).
*   **Units**: SceneKit units (roughly corresponding to meters or centimeters depending on scale; relative positions matter most).

## Segment Definition

The total body mass is distributed across 17 segments. Each segment is defined by a proximal joint and a distal joint. The segment's Center of Mass is located at a percentage of the distance from the proximal joint to the distal joint.

| Segment Name | Proximal Joint | Distal Joint | Mass % | CoM % (from Proximal) |
| :--- | :--- | :--- | :---: | :---: |
| **Trunk** (Subdivided) | | | **49.7%** | |
| Pelvis | `mixamorig_Hips` | `mixamorig_Spine` | 14.6% | 50% |
| Abdomen Lower | `mixamorig_Spine` | `mixamorig_Spine1` | 8.55% | 50% |
| Abdomen Upper | `mixamorig_Spine1` | `mixamorig_Spine2` | 8.55% | 50% |
| Thorax | `mixamorig_Spine2` | `mixamorig_Neck` | 18.0% | 50% |
| **Head** | | | **8.1%** | |
| Head | `mixamorig_Neck` | `mixamorig_Head` | 8.1% | 50% |
| **Right Arm** | | | | |
| R Upper Arm | `mixamorig_RightArm` | `mixamorig_RightForeArm` | 2.8% | 44% |
| R Forearm | `mixamorig_RightForeArm` | `mixamorig_RightHand` | 1.6% | 43% |
| R Hand | `mixamorig_RightHand` | `mixamorig_RightHandMiddle1` | 0.6% | 50% |
| **Left Arm** | | | | |
| L Upper Arm | `mixamorig_LeftArm` | `mixamorig_LeftForeArm` | 2.8% | 44% |
| L Forearm | `mixamorig_LeftForeArm` | `mixamorig_LeftHand` | 1.6% | 43% |
| L Hand | `mixamorig_LeftHand` | `mixamorig_LeftHandMiddle1` | 0.6% | 50% |
| **Right Leg** | | | | |
| R Thigh | `mixamorig_RightUpLeg` | `mixamorig_RightLeg` | 10.0% | 43% |
| R Shank | `mixamorig_RightLeg` | `mixamorig_RightFoot` | 4.65% | 43% |
| R Foot | `mixamorig_RightFoot` | `mixamorig_RightToeBase` | 1.45% | 50% |
| **Left Leg** | | | | |
| L Thigh | `mixamorig_LeftUpLeg` | `mixamorig_LeftLeg` | 10.0% | 43% |
| L Shank | `mixamorig_LeftLeg` | `mixamorig_LeftFoot` | 4.65% | 43% |
| L Foot | `mixamorig_LeftFoot` | `mixamorig_LeftToeBase` | 1.45% | 50% |

### Assumptions
- **Rigid Bodies**: Each segment is treated as a rigid body with constant mass distribution.
- **Linear CoM**: The CoM for each segment is assumed to lie on the straight line connecting the proximal and distal joints.
- **Proximal Reference**: CoM position is defined as a percentage distance from the proximal joint.

## Validation

The `CoMValidationHarness` class is used to verify the correctness of the CoM calculation. It performs the following checks:

1.  **System Integrity**: Verifies that the sum of all segment mass ratios is approximately 1.0 (tolerance 0.001) and that the total calculated mass matches the defined body mass.
2.  **Pose Validation**: Checks CoM behavior in standard poses against expected outcomes:
    - **T-Pose**:
        - Symmetry check: X-axis deviation should be minimal (< 2.0 units).
        - Height check: CoM Y should be greater than Hips Y.
    - **Touchdown**:
        - CoM Y should rise significantly compared to T-Pose (> 5.0 units).
    - **Squat**:
        - CoM Y should lower significantly compared to T-Pose (> 10.0 units).
    - **Pike**:
        - CoM Z should shift significantly (> 5.0 units).
    - **Layout**:
        - CoM Y should be higher than T-Pose (> 2.0 units).

To run the validation:
1.  Launch the app.
2.  Tap "Run Diagnostics".
3.  Observe the 3D view (green CoM marker) and the log overlay.

## Audit Findings & Limitations

### Resolved Issues
*   **Trunk Simplified**: The single "Trunk" segment has been split into Pelvis, Lower Abdomen, Upper Abdomen, and Thorax segments. This allows the mass to follow the curve of the spine in poses like Pike and Bridge.
*   **Head/Neck Gap**: The "Head" segment is now defined from `Neck` to `Head`, and the `Thorax` segment connects `Spine2` to `Neck`, closing the gap.
*   **Arm Segment Mapping**: Fixed incorrect mapping of arm segments. "Upper Arm" was previously mapped to the Clavicle, "Forearm" to Upper Arm, and "Hand" to Forearm. These have been corrected to align with Mixamo anatomy (Upper Arm: Shoulder->Elbow, Forearm: Elbow->Wrist, Hand: Wrist->Middle Finger).

### Remaining Limitations
*   **Mass Distribution Source**: The mass ratios for the split trunk segments are approximations derived from De Leva (1996) scaled to match the original total trunk mass (49.7%).
*   **CoM Ratios**: Default CoM ratios of 0.50 are used for the new trunk segments. Further refinement based on specific anthropometric data could improve accuracy.

### Future Improvements
*   Implement geometric volume estimation for more accurate per-segment mass.
*   Add joint limits to prevent impossible spine curvature.

## Running Tests

Unit tests are included to verify the CoM calculation logic without running the full app UI. These tests simulate a skeleton and verify that the CoM responds correctly to pose changes.

### How to Run
1.  Open the project in Xcode.
2.  Select the **CheerComCalculatorApp** scheme.
3.  Press **Cmd+U** or select **Product > Test** from the menu.
4.  The tests will run and results will be displayed in the Test Navigator.

### Test Coverage
The `COMCalculatorTests` suite covers:
*   **T-Pose Symmetry**: Verifies that the CoM is centered (X ≈ 0) and at an appropriate height.
*   **Squat Response**: Verifies that lowering the body mass (simulated squat) lowers the total CoM.
*   **Pike Response**: Verifies that moving legs forward shifts the CoM forward (Z-axis).
*   **Touchdown Response**: Verifies that raising arms raises the total CoM.
