# Center of Mass (CoM) Model

This document describes the 3D body model and Center of Mass (CoM) calculation logic used in the CheerComCalculatorApp.

## 1. Body Model & Segments

The human body is modeled as a system of **14 rigid segments**. The segmentation and mass properties are based on anthropometric data (adapted from Winter, 2009 and de Leva, 1996) and mapped to the Mixamo skeletal rig.

| Segment Name | Proximal Joint | Distal Joint | Mass Ratio (%) | CoM Ratio (%)* |
| :--- | :--- | :--- | :---: | :---: |
| Trunk | `mixamorig_Hips` | `mixamorig_Spine` | 49.7% | 50% |
| Head | `mixamorig_Spine2` | `mixamorig_Head` | 8.1% | 50% |
| R Upper Arm | `mixamorig_RightShoulder` | `mixamorig_RightArm` | 2.8% | 44% |
| R Forearm | `mixamorig_RightArm` | `mixamorig_RightForeArm` | 1.6% | 43% |
| R Hand | `mixamorig_RightForeArm` | `mixamorig_RightHand` | 0.6% | 50% |
| L Upper Arm | `mixamorig_LeftShoulder` | `mixamorig_LeftArm` | 2.8% | 44% |
| L Forearm | `mixamorig_LeftArm` | `mixamorig_LeftForeArm` | 1.6% | 43% |
| L Hand | `mixamorig_LeftForeArm` | `mixamorig_LeftHand` | 0.6% | 50% |
| R Thigh | `mixamorig_RightUpLeg` | `mixamorig_RightLeg` | 10.0% | 43% |
| R Shank | `mixamorig_RightLeg` | `mixamorig_RightFoot` | 4.65% | 43% |
| R Foot | `mixamorig_RightFoot` | `mixamorig_RightToeBase` | 1.45% | 50% |
| L Thigh | `mixamorig_LeftUpLeg` | `mixamorig_LeftLeg` | 10.0% | 43% |
| L Shank | `mixamorig_LeftLeg` | `mixamorig_LeftFoot` | 4.65% | 43% |
| L Foot | `mixamorig_LeftFoot` | `mixamorig_LeftToeBase` | 1.45% | 50% |

***CoM Ratio**: The distance from the proximal joint to the segment's center of mass, expressed as a percentage of the segment length.

## 2. Coordinate System

The application uses the standard **SceneKit World Coordinate System**:
*   **Y-Axis**: Vertical (Up/Down). Gravity acts along -Y.
*   **X-Axis**: Horizontal (Left/Right).
*   **Z-Axis**: Depth (Forward/Backward).
*   **Origin (0,0,0)**: Located on the floor (ground plane) at the center of the scene.

## 3. Calculation Method

The total Body Center of Mass ($CoM_{total}$) is calculated as the weighted average of all segment CoMs:

$$ CoM_{total} = \frac{\sum (m_i \times p_i)}{\sum m_i} $$

Where:
*   $m_i$ is the mass of segment $i$.
*   $p_i$ is the position of the CoM of segment $i$ in world coordinates.

### Segment CoM Calculation
For each segment, the CoM position is determined by linear interpolation between the proximal ($J_{prox}$) and distal ($J_{dist}$) joint positions:

$$ p_i = J_{prox} + (J_{dist} - J_{prox}) \times \text{CoM Ratio} $$

## 4. Verification & Validation

The `CoMValidationHarness` is included in the app to verify the model's accuracy.

### How to Run Verification
1.  Launch the app.
2.  Tap the **"Run Diagnostics"** button in the top-right corner.
3.  The app will automatically cycle through a set of deterministic poses:
    *   **T-Pose**: Baseline check for symmetry.
    *   **Touchdown**: Verifies CoM rises.
    *   **Squat**: Verifies CoM lowers.
    *   **Pike**: Verifies CoM shifts forward (Z-axis).
    *   **Layout**: Verifies extended body configuration.
4.  Observe the **Diagnostic Overlay** for pass/fail results and detailed log output.
5.  Visual markers (cyan spheres) will appear at each segment's CoM, and a large green marker will show the total CoM.

### Automated Checks
The harness asserts the following conditions:
*   **T-Pose**: X-position is symmetric (close to 0).
*   **Touchdown**: CoM Y-position > T-Pose Y-position + 5.0 units.
*   **Squat**: CoM Y-position < T-Pose Y-position - 10.0 units.
*   **Pike**: CoM Z-position shift > 2.0 units.
