# Center of Mass (CoM) Model

This document describes the human body model and Center of Mass calculation logic used in the CheerComCalculatorApp.

## Model Overview

The CoM calculation is based on a 14-segment model using anthropometric data from Winter (2009) and de Leva (1996). The total body Center of Mass is calculated as the weighted average of the CoM of individual body segments.

$$ CoM_{total} = \frac{\sum (m_i \times p_i)}{M_{total}} $$

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

*   **World Space**: All calculations are performed in SceneKit World Space.
*   **Units**: Distance in SceneKit units (meters, assuming 1 unit = 1 meter or consistent scale), Mass in Kilograms (kg).
*   **Up Axis**: Y-axis is up.

## Assumptions & Limitations

1.  **Rig Structure**: The model assumes a standard Mixamo skeleton hierarchy (`mixamorig_` prefix).
2.  **Segment Definition**: Segments are modeled as straight lines between proximal and distal joints. The CoM is located along this line. This simplifies complex shapes (like the torso) into a linear segment.
    *   *Known Limitation*: The "Trunk" segment is defined from Hips to Spine, which might under-represent the full torso height/distribution.
3.  **Symmetry**: Left and right sides use identical mass and CoM properties.

## Verification

To verify the CoM calculation, use the **CoM Validation Harness** built into the application.

### Running the Harness
1.  Launch the app.
2.  Tap the **"Run Diagnostics"** button in the top right corner.
3.  The app will cycle through a set of deterministic poses:
    *   T-Pose
    *   Touchdown
    *   Squat
    *   Pike
    *   Layout
4.  Watch the visual markers:
    *   **Green Sphere**: Total CoM
    *   **Cyan Spheres**: Individual Segment CoMs
5.  Check the console output for detailed logs including:
    *   Total Body Mass
    *   Segment positions and masses for each pose.

### Debugging
The `CoMValidationHarness` class is located in `Managers/CoMValidationHarness.swift`. It prints detailed logs to the console which can be compared against expected values calculated manually or from external tools.
