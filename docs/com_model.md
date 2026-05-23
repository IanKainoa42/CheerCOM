# Center of Mass (CoM) Model

This document describes the Center of Mass model used in the CheerCOM app.

## Overview

The CoM calculator uses a **17-segment model** based on anthropometric data from Winter (2009) and de Leva (1996). It calculates the total body center of mass as the weighted average of the individual segment centers of mass.

Formula:
$$ CoM_{total} = \frac{\sum (m_i \times p_i)}{\sum m_i} $$

Where:
- $m_i$ is the mass of segment $i$.
- $p_i$ is the position of the center of mass of segment $i$.

## Coordinate System

- **Origin**: The world origin (0,0,0) is typically at the center of the floor plane.
- **Y-Axis**: Vertical (Up). Gravity acts along -Y.
- **X-Axis**: Lateral (Right).
- **Z-Axis**: Anterior-Posterior (Forward/Backward).

The model assumes the character is rigged with a standard Mixamo skeleton (`mixamorig_` prefix).

## Segments

The body is divided into 17 segments. Each segment is defined by a **Proximal Joint** (start) and a **Distal Joint** (end). The segment's CoM is located at a fixed percentage along the line connecting these two joints.

### Trunk (49.7% of Total Mass)
The trunk is subdivided into 4 segments to better approximate spinal curvature:
1.  **Pelvis** (14.6%): Hips → Spine (L5/S1 to L1)
2.  **Abdomen Lower** (8.55%): Spine → Spine1 (L1 to T12)
3.  **Abdomen Upper** (8.55%): Spine1 → Spine2 (T12 to T1)
4.  **Thorax** (18.0%): Spine2 → Neck (T1 to C7)

*Note: The Clavicle/Scapula mass is considered integrated into the Thorax segment.*

### Head & Neck (8.1%)
5.  **Head** (8.1%): Head → HeadTop_End
    *   *Assumption*: The CoM is located at 50% along the line from the head base to the crown.

### Upper Limbs (10.0%)
Left and Right sides are symmetric.
6.  **Upper Arm** (2.8%): Shoulder (Humerus Head) → Elbow
    *   *Joints*: `mixamorig_RightArm` → `mixamorig_RightForeArm`
7.  **Forearm** (1.6%): Elbow → Wrist
    *   *Joints*: `mixamorig_RightForeArm` → `mixamorig_RightHand`
8.  **Hand** (0.6%): Wrist → Knuckles
    *   *Joints*: `mixamorig_RightHand` → `mixamorig_RightHandMiddle1`
    *   *Fallback*: If the distal joint is missing, the CoM defaults to the wrist position.

### Lower Limbs (32.2%)
9.  **Thigh** (10.0%): Hip → Knee
    *   *Joints*: `mixamorig_RightUpLeg` → `mixamorig_RightLeg`
10. **Shank** (4.65%): Knee → Ankle
    *   *Joints*: `mixamorig_RightLeg` → `mixamorig_RightFoot`
11. **Foot** (1.45%): Ankle → Toes
    *   *Joints*: `mixamorig_RightFoot` → `mixamorig_RightToeBase`

## How to verify correctness (Verification)

To verify the CoM calculation in the app:
1.  Launch the app.
2.  Tap the **"Run Diagnostics"** button in the top-right corner.
3.  The app will cycle through standard poses:
    *   **T-Pose**: Baseline. CoM should be symmetric (X ≈ 0, Z ≈ 0) and above hips.
    *   **High V**: Arms raised in V shape. CoM should rise compared to T-Pose, but less than Touchdown.
    *   **Touchdown**: Arms straight up. CoM should rise significantly (~5-10 units).
    *   **Squat**: Hips lower. CoM should lower significantly (~10-20 units).
    *   **Pike**: Legs forward. CoM should shift forward (Z+).
    *   **Layout**: Straight body. CoM similar to Touchdown/T-Pose but higher than T-Pose.
    *   **Side Lean**: Trunk lateral flexion. CoM should shift laterally (X-axis).
    *   **Bow and Arrow**: Asymmetric arm extension. CoM should shift laterally (X-axis) away from the baseline.
    *   **Lunge**: Asymmetric leg stance (one forward, one back). CoM should lower compared to T-Pose.
    *   **Liberty**: One leg raised and arms up. CoM should rise compared to T-Pose and shift slightly laterally.
    *   **Prep Position**: Knees slightly bent, hands near chest. CoM should drop slightly but less than a full squat.
    *   **Bridge**: Backbend pose with hands and feet on the ground. CoM should drop significantly and shift backwards (Z-).
    *   **Handstand**: Inverted body with hands as the base. CoM should elevate significantly due to legs raising above hips.
    *   **Test Pose 1**: Arms slightly lowered. Similar to T-Pose, CoM Y should drop slightly or remain similar.
    *   **Test Pose 2**: Arms raised high. Similar to Touchdown. CoM should rise significantly.
    *   **Test Pose 3**: Legs bent forward. Hips remain, legs raise forward. CoM should shift forward (+Z direction) and slightly up.
    *   **Test Pose 4**: Legs extended backward. CoM should shift backward (-Z direction) and slightly up.
    *   **Test Pose 5**: Arms extended forward. CoM should shift forward (+Z direction).
    *   **Test Pose 6**: Combined full squat with arms up (touchdown). The vertical drop of the heavy base outweighs the rise of the arms.

    These represent a deterministic set of poses used to test different CoM transformations (vertical shift, forward shift, lateral shift, combined vertical stresses, and asymmetry).
4.  A detailed report is printed to the console and the on-screen overlay, verifying segment masses, individual segment COM points, and the final CoM.

### Verification Script (Python)

For independent verification of the mathematical model (segment mass ratios, fallbacks) without running the app:
1.  Run `python3 tests/verify_com_math.py`
2.  This script mocks the SceneKit vector math and verifies that:
    *   **Mass Ratios**: Total mass ratio sums to exactly 1.0.
    *   **Segment Mass and COM Points**: The script outputs the segment mass and segment COM points for the baseline T-Pose.
    *   **Hand Fallback**: Correctly defaults to proximal joint if distal tip is missing.
    *   **T-Pose**: Baseline CoM calculation is reasonable.
    *   **High V**: CoM rises when arms are raised diagonally.
    *   **Touchdown**: CoM rises significantly when arms are raised.
    *   **Layout**: CoM rises similarly to Touchdown when arms are raised and body is straight.
    *   **Squat**: CoM lowers significantly when hips are lowered.
    *   **Lunge**: CoM lowers significantly when stance is widened and hips are lowered.
    *   **Liberty**: CoM rises when one leg is raised and arms are in high V.
    *   **Prep Position**: CoM drops slightly when knees are bent.

## Visible CoM Marker
Within the SceneKit view, a prominent bright green sphere (radius 10) dynamically tracks the total body Center of Mass. Auxiliary cyan spheres represent individual segment COMs, showing exactly where each segment's mass is centered. A pulsing green ground projection circle also directly maps the CoM onto the XZ ground plane to help assess stability over the base of support.

## Joint Constraints

Realistic joint limits are enforced within the application to prevent impossible poses that would otherwise invalidate the CoM calculation. The following primary limits are currently implemented:
-   **Knees (`mixamorig_RightLeg`, `mixamorig_LeftLeg`)**: Hinge joint. X-axis limited to [-160°, 0°].
-   **Elbows (`mixamorig_RightForeArm`, `mixamorig_LeftForeArm`)**: Hinge joint. Z-axis limited (Right: [0°, 160°], Left: [-160°, 0°]).
-   **Shoulders (`mixamorig_RightArm`, `mixamorig_LeftArm`)**: Ball-and-socket. Bounded ranges across X, Y, and Z to prevent hyper-extension.
-   **Spine (`mixamorig_Spine`, `mixamorig_Spine1`, `mixamorig_Spine2`)**: Segmented limits. Each bounded to [-45°, 45°] across all axes.
-   **Neck/Head (`mixamorig_Neck`, `mixamorig_Head`)**: Limited range of motion to simulate physiological boundaries.
-   **Hips (`mixamorig_RightUpLeg`, `mixamorig_LeftUpLeg`)**: Broad ball-and-socket constraints bounding extreme internal/external rotation and hyper-extension.

## Known Limitations

1.  **Clavicle Segment**: The shoulder girdle (clavicle) is not modeled as a separate moving segment. Its mass is effectively lumped into the Thorax.
2.  **Rig Dependency**: The calculation relies on specific `mixamorig_` bone names. If a custom character uses different naming, the calculator must be updated.

* Note: Added a ground plane visualization for baseline sanity checking.
* Verified for baseline audit.
