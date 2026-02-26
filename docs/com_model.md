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
5.  **Head** (8.1%): Neck → Head
    *   *Assumption*: The CoM is located at 50% along the Neck bone. This is an approximation; realistically, the CoM is higher (inside the cranium), but this segment definition captures the general mass location relative to the spine.

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

## Verification

To verify the CoM calculation in the app:
1.  Launch the app.
2.  Tap the **"Run Diagnostics"** button in the top-right corner.
3.  The app will cycle through standard poses:
    *   **T-Pose**: Baseline. CoM should be symmetric (X ≈ 0, Z ≈ 0) and above hips.
    *   **Touchdown**: Arms up. CoM should rise significantly (~5-10 units).
    *   **Squat**: Hips lower. CoM should lower significantly (~10-20 units).
    *   **Pike**: Legs forward. CoM should shift forward (Z+).
    *   **Layout**: Straight body. CoM similar to Touchdown/T-Pose but higher than T-Pose.
    *   **Side Lean**: Trunk lateral flexion. CoM should shift laterally (X-axis).
4.  A detailed report is printed to the console and the on-screen overlay.

### Verification Script (Python)

For independent verification of the mathematical model (segment mass ratios, fallbacks) without running the app:
1.  Run `python3 tests/verify_com_math.py`
2.  This script mocks the SceneKit vector math and verifies that:
    *   **Mass Ratios**: Total mass ratio sums to exactly 1.0.
    *   **Hand Fallback**: Correctly defaults to proximal joint if distal tip is missing.
    *   **T-Pose**: Baseline CoM calculation is reasonable.
    *   **Touchdown**: CoM rises significantly when arms are raised.
    *   **Squat**: CoM lowers significantly when hips are lowered.

## Known Limitations

1.  **Clavicle Segment**: The shoulder girdle (clavicle) is not modeled as a separate moving segment. Its mass is effectively lumped into the Thorax.
2.  **Head CoM**: The Head segment uses `Neck` → `Head` joints. This places the CoM lower than anatomical reality (mid-neck vs cranium).
3.  **Rig Dependency**: The calculation relies on specific `mixamorig_` bone names. If a custom character uses different naming, the calculator must be updated.
