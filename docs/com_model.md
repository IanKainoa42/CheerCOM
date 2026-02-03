# Center of Mass (CoM) Model

This document describes the biomechanical model used to calculate the Center of Mass (CoM) in the CheerComCalculatorApp.

## 1. Overview

The CoM calculation is based on a 14-segment model derived from anthropometric data (Winter, 2009; de Leva, 1996). The total body CoM is computed as the weighted average of the CoMs of individual body segments.

Formula:
```
CoM_total = Σ (m_i * p_i) / Σ m_i
```
Where:
- `m_i` is the mass of segment `i`.
- `p_i` is the position of the CoM of segment `i` in world coordinates.

## 2. Segment Model

The body is divided into 14 segments. Each segment has a defined mass (as a percentage of total body mass) and a CoM location (as a percentage of the segment length from the proximal joint).

| Segment Name | Proximal Joint | Distal Joint | Mass Ratio | CoM Ratio (from Proximal) |
| :--- | :--- | :--- | :--- | :--- |
| Trunk | Hips | Spine | 0.497 | 0.50 |
| Head | Spine2 | Head | 0.081 | 0.50 |
| R Upper Arm | R Shoulder | R Arm | 0.028 | 0.44 |
| R Forearm | R Arm | R ForeArm | 0.016 | 0.43 |
| R Hand | R ForeArm | R Hand | 0.006 | 0.50 |
| L Upper Arm | L Shoulder | L Arm | 0.028 | 0.44 |
| L Forearm | L Arm | L ForeArm | 0.016 | 0.43 |
| L Hand | L ForeArm | L Hand | 0.006 | 0.50 |
| R Thigh | R UpLeg | R Leg | 0.100 | 0.43 |
| R Shank | R Leg | R Foot | 0.0465 | 0.43 |
| R Foot | R Foot | R ToeBase | 0.0145 | 0.50 |
| L Thigh | L UpLeg | L Leg | 0.100 | 0.43 |
| L Shank | L Leg | L Foot | 0.0465 | 0.43 |
| L Foot | L Foot | L ToeBase | 0.0145 | 0.50 |

*Note: Joint names in the code are prefixed with `mixamorig_`.*

## 3. Coordinate Space

The application uses a standard 3D coordinate system (SceneKit):
- **X-axis**: Lateral (Left/Right). Positive is typically to the character's left.
- **Y-axis**: Vertical (Up/Down). Positive is Up.
- **Z-axis**: Anterior/Posterior (Forward/Backward). Positive is typically Forward.

Units are arbitrary but consistent within the scene. The character is scaled such that 1 unit roughly corresponds to 1 cm (needs verification).

## 4. Verification & Diagnostics

To verify the accuracy of the CoM calculation, the app includes a "Diagnostics" mode.

### How to Run
1.  Launch the app.
2.  Tap the **"Run Diagnostics"** button in the top-right corner.

### What it Does
The `CoMValidationHarness` performs the following steps:
1.  **System Check**: Logs total mass and segment count.
2.  **Pose Cycle**: Automatically transitions the character through a set of deterministic poses:
    *   **T-Pose**: Baseline check. CoM should be vertically aligned and symmetric (X ≈ 0).
    *   **Touchdown**: Arms raised overhead. CoM Y should increase significantly.
    *   **Squat**: Deep knee bend. CoM Y should decrease significantly.
    *   **Pike**: Legs forward. CoM Z should shift forward.
    *   **Layout**: Straight body extension. CoM should be higher than T-Pose.
3.  **Visualization**:
    *   Green Sphere: Total Body CoM.
    *   Cyan Spheres: Individual Segment CoMs.
    *   Trail: Visualizes the path of the CoM during movement.
4.  **Reporting**: A detailed log is generated, showing the calculated CoM for each pose and pass/fail status based on expected biomechanical behavior.

### Acceptance Criteria
- **Symmetry**: In symmetric poses (T-Pose, Squat), CoM X should be within ±2.0 units of 0.
- **Responsiveness**: Moving heavy segments (legs/trunk) should shift the CoM in the corresponding direction.
- **Stability**: The calculated CoM should not jitter when the character is stationary.

## 5. Audit Findings & Limitations (Baseline Audit)

As of the initial audit, the following limitations in the model have been identified:

### Segment Definitions
*   **Trunk Simplified**: The "Trunk" segment is defined from `Hips` to `Spine`. This likely underestimates the mass contribution and height of the upper torso (`Spine1`, `Spine2`), as almost 50% of the body mass is concentrated in this lower-spine segment.
*   **Head/Neck Gap**: The "Head" segment is defined from `Spine2` to `Head`. The `Neck` joint is not explicitly included in a segment definition, potentially creating a small gap in mass distribution.

### Future Improvements
*   Split "Trunk" into Pelvis, Abdomen, and Thorax segments for more accurate mass distribution.
*   Explicitly include Neck segment.
