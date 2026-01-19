# CoM Model Documentation

## Overview

This application calculates the Center of Mass (CoM) of a 3D human character model. The calculation is based on the **segmental method**, which sums the weighted CoM of individual body segments.

## Body Segments

The model uses 14 body segments. The mass percentages and segment CoM locations are based on anthropometric data from **Winter (2009)** and **de Leva (1996)**.

| Segment Name | Proximal Joint | Distal Joint | Mass % (of Total Body) | CoM % (from Proximal) |
| :--- | :--- | :--- | :--- | :--- |
| Trunk | Hips | Spine | 49.7% | 50% |
| Head/Neck | Spine2 | Head | 8.1% | 50% |
| R Upper Arm | R Shoulder | R Arm | 2.8% | 44% |
| R Forearm | R Arm | R ForeArm | 1.6% | 43% |
| R Hand | R ForeArm | R Hand | 0.6% | 50% |
| L Upper Arm | L Shoulder | L Arm | 2.8% | 44% |
| L Forearm | L Arm | L ForeArm | 1.6% | 43% |
| L Hand | L ForeArm | L Hand | 0.6% | 50% |
| R Thigh | R UpLeg | R Leg | 10.0% | 43% |
| R Shank | R Leg | R Foot | 4.65% | 43% |
| R Foot | R Foot | R ToeBase | 1.45% | 50% |
| L Thigh | L UpLeg | L Leg | 10.0% | 43% |
| L Shank | L Leg | L Foot | 4.65% | 43% |
| L Foot | L Foot | L ToeBase | 1.45% | 50% |

## Coordinate Space

*   **World Space**: All calculations are performed in the SceneKit world coordinate system (Y-up).
*   **Units**: SceneKit units (implicitly meters or centimeters depending on scale, but mass ratios are unitless). The application assumes the model is scaled appropriately.

## CoM Calculation Logic

1.  **Joint Positions**: The world position of each joint defining a segment is retrieved from the SceneKit node hierarchy.
2.  **Segment CoM**: For each segment, the CoM is calculated using linear interpolation:
    $$ CoM_{segment} = P_{proximal} + (P_{distal} - P_{proximal}) \times \%_{length} $$
3.  **Total CoM**: The total body CoM is the weighted sum of all segment CoMs:
    $$ CoM_{body} = \frac{\sum (CoM_{segment} \times Mass_{segment})}{\sum Mass_{segment}} $$

## Verification and Validation

### Validation Harness

A `CoMValidationHarness` class is included to run baseline checks on startup. It performs the following:

1.  Applies a set of deterministic poses (T-Pose, High V, Liberty, Bridge).
2.  Forces a transform update.
3.  Calculates the CoM for each pose.
4.  Logs the individual segment CoMs and the total CoM to the console.

To run the validation manually or check the output, look for logs starting with `🔎 === Starting CoM Validation Harness ===` in the debug console.

### Visual Debugging

*   **Total CoM**: Represented by a large **Green Sphere**.
*   **Segment CoMs**: Represented by smaller **Cyan Spheres**.
*   **Stability**: The CoM color changes to Yellow (warning) or Red (unstable) based on its relationship to the Base of Support (BoS).

To enable visual debugging, toggle "Visualizations" in the app UI.
