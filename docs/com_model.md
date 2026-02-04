# Center of Mass (CoM) Model

This document describes the 3D body model and Center of Mass (CoM) calculation logic used in the CheerComCalculatorApp.

## 1. Body Model & Segments

The human body is modeled as a system of **17 rigid segments**. The segmentation and mass properties are based on anthropometric data (adapted from Winter, 2009 and de Leva, 1996) and mapped to the Mixamo skeletal rig. The Trunk mass (49.7%) is distributed across 4 sub-segments (Pelvis, Abdomen, Thorax) to better approximate spinal curvature.

| Segment Name | Proximal Joint | Distal Joint | Mass Ratio (%) | CoM Ratio (%)* |
| :--- | :--- | :--- | :---: | :---: |
| Pelvis | `mixamorig_Hips` | `mixamorig_Spine` | 14.6% | 50% |
| Abdomen Lower | `mixamorig_Spine` | `mixamorig_Spine1` | 8.55% | 50% |
| Abdomen Upper | `mixamorig_Spine1` | `mixamorig_Spine2` | 8.55% | 50% |
| Thorax | `mixamorig_Spine2` | `mixamorig_Neck` | 18.0% | 50% |
| Head | `mixamorig_Neck` | `mixamorig_Head` | 8.1% | 50% |
| R Upper Arm | `mixamorig_RightArm` | `mixamorig_RightForeArm` | 2.8% | 44% |
| R Forearm | `mixamorig_RightForeArm` | `mixamorig_RightHand` | 1.6% | 43% |
| R Hand | `mixamorig_RightHand` | `mixamorig_RightHand` | 0.6% | 50% |
| L Upper Arm | `mixamorig_LeftArm` | `mixamorig_LeftForeArm` | 2.8% | 44% |
| L Forearm | `mixamorig_LeftForeArm` | `mixamorig_LeftHand` | 1.6% | 43% |
| L Hand | `mixamorig_LeftHand` | `mixamorig_LeftHand` | 0.6% | 50% |
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
- **Height**: In T-Pose, CoM Y should be higher than the Hips Y position.
- **Responsiveness**: Moving heavy segments (legs/trunk) should shift the CoM in the corresponding direction.
- **Stability**: The calculated CoM should not jitter when the character is stationary.

## 5. Audit Findings & Limitations

### Resolved Issues
*   **Trunk Simplified**: The single "Trunk" segment has been split into Pelvis, Lower Abdomen, Upper Abdomen, and Thorax segments. This allows the mass to follow the curve of the spine in poses like Pike and Bridge.
*   **Head/Neck Gap**: The "Head" segment is now defined from `Neck` to `Head`, and the `Thorax` segment connects `Spine2` to `Neck`, closing the gap.

### Remaining Limitations
*   **Mass Distribution Source**: The mass ratios for the split trunk segments are approximations derived from De Leva (1996) scaled to match the original total trunk mass (49.7%).
*   **CoM Ratios**: Default CoM ratios of 0.50 are used for the new trunk segments. Further refinement based on specific anthropometric data could improve accuracy.

### Future Improvements
*   Implement geometric volume estimation for more accurate per-segment mass.
*   Add joint limits to prevent impossible spine curvature.
