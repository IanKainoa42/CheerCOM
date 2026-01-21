# Center of Mass (CoM) Model

This document describes the current implementation of the Center of Mass calculation in the CheerComCalculatorApp.

## Overview

The CoM is calculated using a segmental method. The body is divided into 14 segments, each with a defined mass percentage of the total body mass and a Center of Mass location relative to its proximal and distal joints.

## Coordinate System

- **World Space**: The CoM is calculated in World Space coordinates.
- **Units**: SceneKit units (meters by default, but the app displays labels in cm).
- **Axes**:
    - **Y**: Up/Down (Gravity acts along negative Y).
    - **X**: Left/Right.
    - **Z**: Forward/Backward.

## Anthropometric Data

The model uses data derived from Winter (2009) and de Leva (1996).

Total Body Mass Assumption: **52.2 kg** (Default, configurable).

### Segments Table

| Segment Name | Proximal Joint | Distal Joint | Mass % | CoM % (from Proximal) |
| :--- | :--- | :--- | :--- | :--- |
| Trunk | Hips | Spine | 49.7% | 50% |
| Head/Neck | Spine2 | Head | 8.1% | 50% |
| R Upper Arm | RightShoulder | RightArm | 2.8% | 44% |
| R Forearm | RightArm | RightForeArm | 1.6% | 43% |
| R Hand | RightForeArm | RightHand | 0.6% | 50% |
| L Upper Arm | LeftShoulder | LeftArm | 2.8% | 44% |
| L Forearm | LeftArm | LeftForeArm | 1.6% | 43% |
| L Hand | LeftForeArm | LeftHand | 0.6% | 50% |
| R Thigh | RightUpLeg | RightLeg | 10.0% | 43% |
| R Shank | RightLeg | RightFoot | 4.65% | 43% |
| R Foot | RightFoot | RightToeBase | 1.45% | 50% |
| L Thigh | LeftUpLeg | LeftLeg | 10.0% | 43% |
| L Shank | LeftLeg | LeftFoot | 4.65% | 43% |
| L Foot | LeftFoot | LeftToeBase | 1.45% | 50% |

*Note: Joint names in the code are prefixed with `mixamorig_`.*

## Calculation Method

For each segment:
1.  **Position**: `SegmentCOM = ProximalPosition + (DistalPosition - ProximalPosition) * CoMRatio`
2.  **Mass**: `SegmentMass = TotalBodyMass * MassRatio`
3.  **Weighted Sum**: `TotalWeightedPosition += SegmentCOM * SegmentMass`
4.  **Final CoM**: `TotalWeightedPosition / TotalBodyMass`

## Assumptions & Limitations

- The segments are treated as rigid bodies.
- The CoM location within a segment is a fixed percentage along the line connecting the proximal and distal joints.
- The mass distribution is constant and does not account for muscle displacement during movement.
- The "Trunk" segment is simplified as Hips to Spine, which might not accurately represent the entire torso's complexity.
    - *Audit Note*: The current model defines "Trunk" (49.7% mass) using `Hips` -> `Spine`. In the Mixamo rig, `Spine` is low in the torso. This means the Trunk CoM is likely calculated lower than reality, as it ignores the upper torso (Ribcage) represented by `Spine1` and `Spine2`.

## Verification

To verify the CoM calculation, run the **CoM Validation Harness** (accessible via "Run Diagnostics" in the app). This will cycle through a set of deterministic poses and output the calculated values to the console.

### Expected Baselines

- **T-Pose**: CoM should be roughly central, slightly above the hips (approx Y=100-105cm).
- **High V**: Arms raised. CoM should shift upwards significantly.
- **Squat (Prep)**: Body lowered. CoM should shift downwards.
- **Pike**: Legs horizontal, Torso vertical, Arms up. CoM should shift forward and slightly up relative to hips.
- **Layout**: Straight body, arms up. Highest CoM position.
- **Bridge**: Arched back. CoM should be lower/outside the body.

### How to Run

1.  Launch the App.
2.  Wait for the scene to load.
3.  Tap the "Run Diagnostics" button in the top right.
4.  Observe the character cycling through poses.
5.  Check the Xcode Console for detailed output:
    - Segment Masses
    - Segment CoM positions
    - Total CoM position for each pose.
