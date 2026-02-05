# Center of Mass (CoM) Model

This document describes the human body model and Center of Mass calculation logic used in the CheerComCalculatorApp.

## 1. Overview

The application uses a **17-segment rigid body model** to calculate the whole-body Center of Mass (CoM). The model is based on anthropometric data (Winter, 2009; de Leva, 1996) adapted for the Mixamo skeletal rig.

## 2. Coordinate Space

*   **System**: SceneKit (Right-handed, Y-up).
    *   **+X**: Left (from character's perspective, if facing +Z? No, typically +X is Right in world, need to verify character orientation). *Note: In standard SceneKit, +X is Right, +Y is Up, +Z is Backward (towards camera).*
*   **Units**: The calculation is unit-agnostic for position (uses World Position from SceneKit), but Mass is defined in **kg**.

## 3. Segment Definitions

The body is divided into the following segments. Each segment has a mass (as a percentage of total body mass) and a local CoM location (as a percentage of the length from the proximal joint to the distal joint).

| Segment Name | Proximal Joint (Start) | Distal Joint (End) | Mass % | CoM % (from Proximal) |
| :--- | :--- | :--- | :--- | :--- |
| **Pelvis** | mixamorig_Hips | mixamorig_Spine | 14.6% | 50% |
| **Abdomen Lower** | mixamorig_Spine | mixamorig_Spine1 | 8.55% | 50% |
| **Abdomen Upper** | mixamorig_Spine1 | mixamorig_Spine2 | 8.55% | 50% |
| **Thorax** | mixamorig_Spine2 | mixamorig_Neck | 18.0% | 50% |
| **Head** | mixamorig_Neck | mixamorig_Head | 8.1% | 50% |
| **R Upper Arm** | mixamorig_RightShoulder | mixamorig_RightArm | 2.8% | 44% |
| **R Forearm** | mixamorig_RightArm | mixamorig_RightForeArm | 1.6% | 43% |
| **R Hand** | mixamorig_RightForeArm | mixamorig_RightHand | 0.6% | 50% |
| **L Upper Arm** | mixamorig_LeftShoulder | mixamorig_LeftArm | 2.8% | 44% |
| **L Forearm** | mixamorig_LeftArm | mixamorig_LeftForeArm | 1.6% | 43% |
| **L Hand** | mixamorig_LeftForeArm | mixamorig_LeftHand | 0.6% | 50% |
| **R Thigh** | mixamorig_RightUpLeg | mixamorig_RightLeg | 10.0% | 43% |
| **R Shank** | mixamorig_RightLeg | mixamorig_RightFoot | 4.65% | 43% |
| **R Foot** | mixamorig_RightFoot | mixamorig_RightToeBase | 1.45% | 50% |
| **L Thigh** | mixamorig_LeftUpLeg | mixamorig_LeftLeg | 10.0% | 43% |
| **L Shank** | mixamorig_LeftLeg | mixamorig_LeftFoot | 4.65% | 43% |
| **L Foot** | mixamorig_LeftFoot | mixamorig_LeftToeBase | 1.45% | 50% |

**Total Mass Verification**: The sum of all segment mass ratios is approximately 1.0 (100%).

## 4. Calculation Method

The Whole-Body CoM is calculated using the weighted average method:

$$
CoM_{total} = \frac{\sum (m_i \cdot p_i)}{\sum m_i}
$$

Where:
*   $m_i$ is the mass of segment $i$.
*   $p_i$ is the world position of the Center of Mass of segment $i$.

The segment CoM ($p_i$) is approximated as a point on the line segment connecting the proximal joint ($J_{prox}$) and distal joint ($J_{dist}$):

$$
p_i = J_{prox} + (J_{dist} - J_{prox}) \cdot \text{ratio}_{com}
$$

## 5. Assumptions & Limitations

1.  **Rigidity**: Segments are treated as rigid bodies. Soft tissue deformation is not modeled.
2.  **Linear CoM**: The segment CoM always lies exactly on the vector between the two defining joints. This simplifies the geometry but may slightly deviate from true anatomical CoM for complex shapes like the torso.
3.  **Symmetry**: Left and right limbs are assumed to have identical mass properties.
4.  **Rig Dependency**: The accuracy depends on the skeletal rig ("mixamorig") matching standard human proportions.

## 6. Verification

To verify the CoM calculation:
1.  Launch the App.
2.  Tap the **"Run Diagnostics"** button in the UI.
3.  The **CoM Validation Harness** will execute a series of deterministic poses:
    *   **T-Pose**: Checks for bilateral symmetry (X ≈ 0) and height (Y > Hips).
    *   **Touchdown** (Arms overhead): CoM should rise significantly.
    *   **Squat**: CoM should lower significantly.
    *   **Pike** (Legs forward): CoM should shift forward (Z-axis).
4.  Review the "Validation Summary" in the debug overlay or console logs.
