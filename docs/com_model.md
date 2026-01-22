# Center of Mass (CoM) Model

## Overview

This document describes the biomechanical model used to calculate the Center of Mass (CoM) for the human character in the CheerComCalculatorApp.

## 1. Segment Model

The body is divided into **14 segments** based on anthropometric data from **Winter (2009)** and **de Leva (1996)**.

The CoM is calculated as the weighted average of the center of mass of each segment:

\[
\text{Total CoM} = \frac{\sum (\text{Segment Mass} \times \text{Segment CoM})}{\sum \text{Segment Mass}}
\]

### Segments Definition

| Segment Name | Proximal Joint | Distal Joint | Mass (% of Body) | CoM Location (% from Proximal) |
| :--- | :--- | :--- | :--- | :--- |
| **Trunk** | Hips | Spine | 49.7% | 50% |
| **Head** | Spine2 | Head | 8.1% | 50% |
| **R Upper Arm** | R Shoulder | R Arm | 2.8% | 44% |
| **R Forearm** | R Arm | R ForeArm | 1.6% | 43% |
| **R Hand** | R ForeArm | R Hand | 0.6% | 50% |
| **L Upper Arm** | L Shoulder | L Arm | 2.8% | 44% |
| **L Forearm** | L Arm | L ForeArm | 1.6% | 43% |
| **L Hand** | L ForeArm | L Hand | 0.6% | 50% |
| **R Thigh** | R UpLeg | R Leg | 10.0% | 43% |
| **R Shank** | R Leg | R Foot | 4.65% | 43% |
| **R Foot** | R Foot | R ToeBase | 1.45% | 50% |
| **L Thigh** | L UpLeg | L Leg | 10.0% | 43% |
| **L Shank** | L Leg | L Foot | 4.65% | 43% |
| **L Foot** | L Foot | L ToeBase | 1.45% | 50% |

**Total Mass:** 100%

*Note: "Trunk" definition currently spans from Hips to Spine. This is a simplified model and may underestimate the height of the Trunk CoM compared to a multi-segment trunk model (Pelvis + Abdomen + Thorax).*

## 2. Coordinate Space

*   **System**: SceneKit (Right-handed, Y-up).
*   **Units**: Arbitrary units (consistent with mesh scale).
*   **Axes**:
    *   **+Y**: Up
    *   **+X**: Right (Character's Left)
    *   **+Z**: Forward (Character's Back? - Verification needed based on model import)
        *   *Correction*: Standard Mixamo/SceneKit usually has +Z as forward or backward depending on rig.
        *   The visualizer outputs `[x, y, z]`.

## 3. Assumptions & Limitations

1.  **Rigidity**: Segments are treated as rigid bodies defined by the line connecting the proximal and distal joints.
2.  **Symmetry**: Left and right limbs have identical mass properties.
3.  **Gender/Body Type**: The mass percentages are average values. They do not currently account for specific somatotypes (e.g., athletic vs. sedentary) or gender differences explicitly (though Winter data is often gender-averaged).
4.  **Joint Locations**: The "Joint Position" is derived from the `worldPosition` of the corresponding bone node in the SceneKit hierarchy.

## 4. Verification

To verify the CoM calculation, use the built-in **CoM Validation Harness**.

### Running the Harness
1.  Launch the app.
2.  Tap "Run Diagnostics" (or equivalent button if exposed).
3.  The app will cycle through the following deterministic poses:
    *   **T-Pose**: Baseline. CoM should be central in X/Z and at roughly navel height.
    *   **Touchdown**: Arms up. CoM should rise.
    *   **Squat**: CoM should lower.
    *   **Pike**: Hips flexed. CoM should move forward.
    *   **Layout**: Body straight/arched. CoM should be central.

### Debug Output
The console will print:
*   Total Body Mass
*   CoM coordinates for each pose.
*   Detailed segment breakdown for T-Pose.

### Visual Confirmation
*   **Green Sphere**: Total CoM.
*   **Cyan Spheres**: Individual Segment CoMs (visible in debug mode).
