# Center of Mass (CoM) Model

This document describes the biomechanical model used to calculate the Center of Mass (CoM) for the character.

## Model Overview

The model uses a **17-segment** approach based on anthropometric data from Winter (2009) and de Leva (1996). The total body mass is distributed across these segments, and the CoM for each segment is calculated based on its proximal and distal joint positions.

### Coordinate System
- **Y-axis**: Up (Vertical)
- **X-axis**: Right (Lateral)
- **Z-axis**: Forward/Backward (Anterior/Posterior)
  - **Positive Z**: Forward
  - **Negative Z**: Backward
  *(Note: SceneKit coordinate system typically has -Z as forward. This should be verified in the implementation.)*

### Assumptions
- **Rigid Bodies**: Each segment is treated as a rigid body with constant mass distribution.
- **Linear CoM**: The CoM for each segment is assumed to lie on the straight line connecting the proximal and distal joints.
- **Proximal Reference**: CoM position is defined as a percentage distance from the proximal joint.

## Segment Definitions

| Segment Name | Proximal Joint | Distal Joint | Mass % | CoM % (from Proximal) |
| :--- | :--- | :--- | :--- | :--- |
| **Trunk** (Subdivided) | | | **49.7%** | |
| Pelvis | Hips | Spine | 14.6% | 50% |
| Abdomen Lower | Spine | Spine1 | 8.55% | 50% |
| Abdomen Upper | Spine1 | Spine2 | 8.55% | 50% |
| Thorax | Spine2 | Neck | 18.0% | 50% |
| **Head** | Neck | Head | 8.1% | 50% |
| **Right Arm** | | | | |
| R Upper Arm | R Shoulder | R Arm | 2.8% | 44% |
| R Forearm | R Arm | R Forearm | 1.6% | 43% |
| R Hand | R Forearm | R Hand | 0.6% | 50% |
| **Left Arm** | | | | |
| L Upper Arm | L Shoulder | L Arm | 2.8% | 44% |
| L Forearm | L Arm | L Forearm | 1.6% | 43% |
| L Hand | L Forearm | L Hand | 0.6% | 50% |
| **Right Leg** | | | | |
| R Thigh | R UpLeg | R Leg | 10.0% | 43% |
| R Shank | R Leg | R Foot | 4.65% | 43% |
| R Foot | R Foot | R ToeBase | 1.45% | 50% |
| **Left Leg** | | | | |
| L Thigh | L UpLeg | L Leg | 10.0% | 43% |
| L Shank | L Leg | L Foot | 4.65% | 43% |
| L Foot | L Foot | L ToeBase | 1.45% | 50% |

## Validation

The `CoMValidationHarness` class is used to verify the correctness of the CoM calculation. It performs the following checks:

1.  **System Integrity**: Verifies that the sum of all segment mass ratios is approximately 1.0 (tolerance 0.001).
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

## Known Issues & Notes

### Joint Mapping Discrepancy (Arms)
The current implementation maps "Upper Arm" to the segment between `Shoulder` (Clavicle) and `Arm` (Humerus), and "Forearm" to the segment between `Arm` and `ForeArm`. This effectively treats the Clavicle as the Upper Arm and shifts the arm segments proximally by one joint. The actual hand segment (distal to wrist) is currently not accounted for explicitly, with the "Hand" segment defined as `ForeArm` to `Hand` (which corresponds to the actual Forearm).
- **Impact**: Mass distribution for arms is slightly shifted towards the torso.
- **Mitigation**: Documented here. Future improvements should refine the segment definitions to accurately map Humerus, Radius/Ulna, and Hand segments, possibly requiring a virtual end-effector for the hand if the rig lacks finger joints.

### Head Segment
The Head segment is defined from `Neck` to `Head`. A more accurate representation might include an offset or a specific CoM point relative to the Head joint, as the CoM of the head is typically anterior to the atlanto-occipital joint.
