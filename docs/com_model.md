# Center of Mass (CoM) Model

This document describes the anthropometric model used to calculate the Center of Mass (CoM) in the CheerComCalculatorApp.

## Model Overview

The CoM calculation uses a **14-segment body model**. The mass distributions and segment center of mass locations are derived from anthropometric data provided by **Winter (2009)** and **de Leva (1996)**.

The model assumes a rigid body segment approach where each segment is defined by a proximal (start) joint and a distal (end) joint.

### Coordinate Space

*   **World Space**: All calculations are performed in World Space coordinates (SCNVector3).
*   **Units**: Distance in SceneKit units (meters/points depending on scale), Mass in Kilograms (kg).
*   **Skeleton**: The model is bound to a standard Mixamo skeleton rig (prefix `mixamorig_`).

## Segment Definitions

The total body mass is distributed across 14 segments. For each segment, the Center of Mass (CoM) is calculated as a percentage of the segment length from the proximal joint.

| Segment Name | Proximal Joint (Start) | Distal Joint (End) | Mass (% of Total) | CoM Location (% from Proximal) |
| :--- | :--- | :--- | :---: | :---: |
| **Trunk** | `mixamorig_Hips` | `mixamorig_Spine` | 49.70% | 50% |
| **Head** | `mixamorig_Spine2` | `mixamorig_Head` | 8.10% | 50% |
| **R Upper Arm** | `mixamorig_RightShoulder` | `mixamorig_RightArm` | 2.80% | 44% |
| **R Forearm** | `mixamorig_RightArm` | `mixamorig_RightForeArm` | 1.60% | 43% |
| **R Hand** | `mixamorig_RightForeArm` | `mixamorig_RightHand` | 0.60% | 50% |
| **L Upper Arm** | `mixamorig_LeftShoulder` | `mixamorig_LeftArm` | 2.80% | 44% |
| **L Forearm** | `mixamorig_LeftArm` | `mixamorig_LeftForeArm` | 1.60% | 43% |
| **L Hand** | `mixamorig_LeftForeArm` | `mixamorig_LeftHand` | 0.60% | 50% |
| **R Thigh** | `mixamorig_RightUpLeg` | `mixamorig_RightLeg` | 10.00% | 43% |
| **R Shank** | `mixamorig_RightLeg` | `mixamorig_RightFoot` | 4.65% | 43% |
| **R Foot** | `mixamorig_RightFoot` | `mixamorig_RightToeBase` | 1.45% | 50% |
| **L Thigh** | `mixamorig_LeftUpLeg` | `mixamorig_LeftLeg` | 10.00% | 43% |
| **L Shank** | `mixamorig_LeftLeg` | `mixamorig_LeftFoot` | 4.65% | 43% |
| **L Foot** | `mixamorig_LeftFoot` | `mixamorig_LeftToeBase` | 1.45% | 50% |

> **Note:** The "Trunk" segment currently approximates the torso using Hips to Spine. This may underestimate the height of the torso CoM compared to a multi-segment trunk model.

## Validation Harness

The application includes a built-in **CoM Validation Harness** to verify calculations against known poses.

### How to Run
1.  Launch the app.
2.  Tap the **"Run Diagnostics"** button in the top right corner.
3.  The app will cycle through a set of deterministic poses:
    *   T-Pose
    *   Touchdown (Arms Up)
    *   Squat
    *   Pike
    *   Layout
4.  View the **on-screen Diagnostics Overlay** (or console logs) for a detailed Markdown report of segment masses and CoM positions.
5.  Visual markers (Green sphere) will show the calculated CoM in the 3D scene.

### Verification Criteria

The harness automatically checks the following criteria and reports **PASS/FAIL**:

*   **T-Pose (Baseline)**:
    *   X-coordinate must be symmetric (approx. 0, tolerance < 2.0 units).
*   **Touchdown**:
    *   CoM Y must rise significantly (> 5.0 units) compared to T-Pose.
*   **Squat**:
    *   CoM Y must lower significantly (> 10.0 units) compared to T-Pose.
*   **Pike**:
    *   CoM Z must shift significantly (> 5.0 units) compared to T-Pose (reflecting forward leg movement).
*   **Layout**:
    *   CoM Y must be higher than T-Pose (> 2.0 units).
