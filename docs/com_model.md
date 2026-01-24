# Center of Mass (CoM) Model

This document describes the biomechanical model used to calculate the Center of Mass (CoM) in the CheerComCalculatorApp.

## 1. Segment Model

The body is modeled as a system of 14 rigid segments. The mass of each segment is calculated as a percentage of the total body mass, based on anthropometric data derived from **Winter (2009)** and **de Leva (1996)**.

| Segment Name | Proximal Joint | Distal Joint | Mass Fraction | CoM Location (%)* |
|--------------|----------------|--------------|---------------|-------------------|
| Trunk        | Hips           | Spine        | 0.497         | 50%               |
| Head         | Spine2         | Head         | 0.081         | 50%               |
| Upper Arm    | Shoulder       | Arm          | 0.028         | 44%               |
| Forearm      | Arm            | ForeArm      | 0.016         | 43%               |
| Hand         | ForeArm        | Hand         | 0.006         | 50%               |
| Thigh        | UpLeg          | Leg          | 0.100         | 43%               |
| Shank        | Leg            | Foot         | 0.0465        | 43%               |
| Foot         | Foot           | ToeBase      | 0.0145        | 50%               |

*\* CoM Location is measured from the proximal joint towards the distal joint.*

**Note on "Trunk":**
The current implementation defines the "Trunk" segment from `mixamorig_Hips` to `mixamorig_Spine`. This is a simplified representation that aggregates the mass of the pelvis, abdomen, and thorax.

## 2. Coordinate System

The application uses the **SceneKit Coordinate System** (Right-Handed, Y-Up):
*   **X-Axis**: Right (+X) / Left (-X)
*   **Y-Axis**: Up (+Y) / Down (-Y)
*   **Z-Axis**: Forward (+Z) / Backward (-Z) (relative to typical character orientation)

All CoM calculations are performed in **World Space**. Segment positions are derived from the world transform of the corresponding skeletal joints.

## 3. Calculation Method

The total Body CoM is calculated using the weighted average of all segment CoMs:

$$ CoM_{body} = \frac{\sum (m_i \cdot p_i)}{\sum m_i} $$

Where:
*   $m_i$ is the mass of segment $i$ ($Mass_{body} \times Ratio_i$)
*   $p_i$ is the world position of the CoM of segment $i$

Segment CoM ($p_i$) is interpolated between the proximal ($J_{prox}$) and distal ($J_{dist}$) joints:

$$ p_i = J_{prox} + (J_{dist} - J_{prox}) \times Ratio_{com} $$

## 4. Validation

A **CoM Validation Harness** is included to verify the stability and accuracy of the model across deterministic poses.

### How to Run Validation
1.  Launch the App.
2.  Tap the **"Run Diagnostics"** button in the top-right corner.
3.  The character will cycle through the following poses:
    *   **T-Pose** (Baseline)
    *   **Touchdown** (Arms overhead)
    *   **Squat** (Lowered CoM)
    *   **Pike** (Hips flexed, legs horizontal)
    *   **Layout** (Straight body)

### Verification Criteria
*   **T-Pose**: CoM should be approximately at the navel/hips level.
*   **Touchdown**: CoM should rise significantly compared to T-Pose.
*   **Squat**: CoM should lower significantly.
*   **Symmetry**: Poses like T-Pose and Touchdown should have a CoM X-coordinate near 0.0 (assuming the character is centered).

### Debug Output
The harness outputs detailed logs to the console, including:
*   Total calculated CoM (x, y, z) for each pose.
*   Per-segment mass and position details (for T-Pose).
