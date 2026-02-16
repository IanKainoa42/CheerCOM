# Body Model & Center of Mass (CoM) Documentation

This document describes the biomechanical model used to calculate the Center of Mass (CoM) for the character.

## Model Overview

The model uses a **17-segment** approach based on anthropometric data from Winter (2009) and de Leva (1996). The total body mass is distributed across these segments, and the CoM for each segment is calculated based on its proximal and distal joint positions.

### Coordinate System
*   **Y-Axis**: Vertical (Up is positive).
*   **X-Axis**: Lateral (Right is positive).
*   **Z-Axis**: Anterior-Posterior (Forward is positive in this scene, though standard Mixamo T-Pose faces +Z).
*   **Units**: SceneKit units (roughly corresponding to meters or centimeters depending on scale; relative positions matter most).

### Assumptions
- **Rigid Bodies**: Each segment is treated as a rigid body with constant mass distribution.
- **Linear CoM**: The CoM for each segment is assumed to lie on the straight line connecting the proximal and distal joints.
- **Proximal Reference**: CoM position is defined as a percentage distance from the proximal joint.
- **Mixamo Skeleton**: The model relies on the standard Mixamo rig naming convention (`mixamorig_*`).

## Segment Definition

The total body mass is distributed across 17 segments. Each segment is defined by a proximal joint and a distal joint. The segment's Center of Mass is located at a percentage of the distance from the proximal joint to the distal joint.

| Segment Name | Proximal Joint | Distal Joint | Mass % | CoM % (from Proximal) |
| :--- | :--- | :--- | :---: | :---: |
| **Trunk** | | | **49.7%** | |
| Pelvis | `mixamorig_Hips` | `mixamorig_Spine` | 14.6% | 50% |
| Abdomen Lower | `mixamorig_Spine` | `mixamorig_Spine1` | 8.55% | 50% |
| Abdomen Upper | `mixamorig_Spine1` | `mixamorig_Spine2` | 8.55% | 50% |
| Thorax | `mixamorig_Spine2` | `mixamorig_Neck` | 18.0% | 50% |
| **Head** | | | **8.1%** | |
| Head | `mixamorig_Neck` | `mixamorig_Head` | 8.1% | 50% |
| **Right Arm** | | | **5.0%** | |
| R Upper Arm | `mixamorig_RightArm` | `mixamorig_RightForeArm` | 2.8% | 44% |
| R Forearm | `mixamorig_RightForeArm` | `mixamorig_RightHand` | 1.6% | 43% |
| R Hand | `mixamorig_RightHand` | `mixamorig_RightHandMiddle1` | 0.6% | 50% |
| **Left Arm** | | | **5.0%** | |
| L Upper Arm | `mixamorig_LeftArm` | `mixamorig_LeftForeArm` | 2.8% | 44% |
| L Forearm | `mixamorig_LeftForeArm` | `mixamorig_LeftHand` | 1.6% | 43% |
| L Hand | `mixamorig_LeftHand` | `mixamorig_LeftHandMiddle1` | 0.6% | 50% |
| **Right Leg** | | | **16.1%** | |
| R Thigh | `mixamorig_RightUpLeg` | `mixamorig_RightLeg` | 10.0% | 43% |
| R Shank | `mixamorig_RightLeg` | `mixamorig_RightFoot` | 4.65% | 43% |
| R Foot | `mixamorig_RightFoot` | `mixamorig_RightToeBase` | 1.45% | 50% |
| **Left Leg** | | | **16.1%** | |
| L Thigh | `mixamorig_LeftUpLeg` | `mixamorig_LeftLeg` | 10.0% | 43% |
| L Shank | `mixamorig_LeftLeg` | `mixamorig_LeftFoot` | 4.65% | 43% |
| L Foot | `mixamorig_LeftFoot` | `mixamorig_LeftToeBase` | 1.45% | 50% |

## Validation

The `CoMValidationHarness` class is used to verify the correctness of the CoM calculation. It performs the following checks:

1.  **System Integrity**: Verifies that the sum of all segment mass ratios is approximately 1.0 (tolerance 0.001) and that the total calculated mass matches the defined body mass.
2.  **Pose Validation**: Checks CoM behavior in standard poses against expected outcomes:
    - **T-Pose**: Baseline. CoM should be symmetric (X ≈ 0) and above the hips.
    - **Touchdown**: CoM Y should rise significantly compared to T-Pose.
    - **Squat**: CoM Y should lower significantly compared to T-Pose.
    - **Pike**: CoM Z should shift significantly (forward/backward depending on orientation).
    - **Layout**: CoM Y should be higher than T-Pose (body extended).

To run the validation:
1.  Launch the app.
2.  Tap "Run Diagnostics".
3.  Observe the 3D view (green CoM marker) and the log overlay.

## Audit Findings & Limitations

### Model Verification Findings
*   **Trunk Segmentation**: The trunk is subdivided into Pelvis, Lower Abdomen, Upper Abdomen, and Thorax to allow mass to follow spine curvature.
*   **Head/Neck Continuity**: The Head segment is defined from Neck to Head, and Thorax connects Spine2 to Neck, ensuring a continuous mass chain.
*   **Arm Segment Mapping**: The Upper Arm is correctly mapped to the Humerus (Shoulder->Elbow) and Forearm to the Radius/Ulna (Elbow->Wrist), aligning with Mixamo anatomy. Previous documentation incorrectly stated this was mapped to the Clavicle.

### Remaining Limitations
*   **Mass Distribution Source**: The mass ratios for the split trunk segments are approximations derived from De Leva (1996) scaled to match the original total trunk mass (49.7%).
*   **CoM Ratios**: Default CoM ratios of 0.50 are used for the new trunk segments. Further refinement based on specific anthropometric data could improve accuracy.
*   **Hand Segment Definition**: The hand segment uses the wrist (`Hand`) as the proximal joint and the middle finger base (`HandMiddle1`) as the distal joint. If the distal joint is missing (some rigs), it falls back to a zero-length segment at the wrist.

### Future Improvements
*   Implement geometric volume estimation for more accurate per-segment mass.
*   Add joint limits to prevent impossible spine curvature.

## Running Tests

Unit tests are included to verify the CoM calculation logic without running the full app UI. These tests simulate a skeleton and verify that the CoM responds correctly to pose changes.

### How to Run
1.  Open the project in Xcode.
2.  Select the **CheerComCalculatorApp** scheme.
3.  Press **Cmd+U** or select **Product > Test** from the menu.
