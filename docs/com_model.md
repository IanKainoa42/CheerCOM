# Center of Mass (CoM) Model

This document describes the human body model and Center of Mass calculation logic used in the CheerComCalculatorApp.

## Model Overview

The CoM calculation is based on a 14-segment model using anthropometric data from Winter (2009) and de Leva (1996). The total body Center of Mass is calculated as the weighted average of the CoM of individual body segments.

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

**Assumptions & Limitations:**
*   **Trunk Definition:** The "Trunk" segment is defined from `mixamorig_Hips` to `mixamorig_Spine`. This excludes the upper torso (Spine1, Spine2) and likely underestimates the height of the Trunk CoM.
*   **Rigid Bodies:** Segments are treated as rigid bodies; soft tissue deformation is not modeled.
*   **Joint Linearity:** Segment CoM is assumed to lie on the straight line connecting the proximal and distal joints.

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
- $m_i$ is the mass of segment $i$
- $p_i$ is the position of the CoM of segment $i$
- $M_{total}$ is the total body mass

## Body Segments

The model defines 14 segments. Mass percentages and CoM locations (as a percentage of segment length from the proximal joint) are defined as follows:

| Segment Name | Proximal Joint | Distal Joint | Mass % | CoM % (from Proximal) |
| :--- | :--- | :--- | :--- | :--- |
| Trunk | Hips | Spine | 49.7% | 50% |
| Head | Spine2 | Head | 8.1% | 50% |
| Upper Arm (R/L) | Shoulder | Arm | 2.8% | 44% |
| Forearm (R/L) | Arm | ForeArm | 1.6% | 43% |
| Hand (R/L) | ForeArm | Hand | 0.6% | 50% |
| Thigh (R/L) | UpLeg | Leg | 10.0% | 43% |
| Shank (R/L) | Leg | Foot | 4.65% | 43% |
| Foot (R/L) | Foot | ToeBase | 1.45% | 50% |

**Note**: Joint names correspond to the Mixamo rig convention (e.g., `mixamorig_Hips`).

## Coordinate Space

### Verification Criteria
*   **Visual Output**:
    *   The Green Sphere indicates the Total Body CoM.
    *   Cyan Spheres indicate the individual CoM for each segment.
    *   A cyan trail shows the history of the CoM position.
*   **T-Pose**: CoM should be approximately at the navel/hips level.
*   **Touchdown**: CoM should rise significantly compared to T-Pose.
*   **Squat**: CoM should lower significantly.
*   **Symmetry**: Poses like T-Pose and Touchdown should have a CoM X-coordinate near 0.0.

### Validation Report
The "Run Diagnostics" tool outputs a detailed Markdown-formatted report to the Xcode console (View > Debug Area > Activate Console). This report includes:

*   **Calculated CoM** for each pose (T-Pose, Touchdown, Squat, Pike, Layout).
*   **Segment Details Table** (for T-Pose), listing:
    *   Segment Name
    *   Mass (kg)
    *   CoM Position (x, y, z)

You can copy and paste this output into Pull Request descriptions or issue trackers to provide evidence of correctness.
