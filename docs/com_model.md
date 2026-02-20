# Center of Mass (CoM) Model

This document describes the anthropometric model used to calculate the Center of Mass (CoM) for the CheerComCalculatorApp.

## Overview

The CoM calculation is based on a **17-segment rigid body model**, using anthropometric data adapted from **Winter (2009)** and **de Leva (1996)**. The model approximates the human body by defining segments with specific mass ratios and local CoM locations relative to their proximal and distal joints.

## Coordinate System

The application uses the **SceneKit Coordinate System**:
*   **Y-axis:** Up (Vertical)
*   **X-axis:** Right (Lateral)
*   **Z-axis:** Forward/Backward (Depth) - *Note: Direction depends on camera, but typically +Z is forward for the character.*

The character is rigged using the **Mixamo** skeleton convention (`mixamorig_*`).

## Segment Definitions

The total body mass is distributed across 17 segments. The sum of all segment mass ratios is approximately **1.0**.

| Segment Name | Proximal Joint (Start) | Distal Joint (End) | Mass Ratio (%) | CoM % (from Proximal) |
| :--- | :--- | :--- | :--- | :--- |
| **Head** | `mixamorig_Neck` | `mixamorig_Head` | 8.10% | 50% |
| **Thorax** | `mixamorig_Spine2` | `mixamorig_Neck` | 18.00% | 50% |
| **Abdomen Upper** | `mixamorig_Spine1` | `mixamorig_Spine2` | 8.55% | 50% |
| **Abdomen Lower** | `mixamorig_Spine` | `mixamorig_Spine1` | 8.55% | 50% |
| **Pelvis** | `mixamorig_Hips` | `mixamorig_Spine` | 14.60% | 50% |
| **R Upper Arm** | `mixamorig_RightArm` | `mixamorig_RightForeArm` | 2.80% | 44% |
| **R Forearm** | `mixamorig_RightForeArm` | `mixamorig_RightHand` | 1.60% | 43% |
| **R Hand** | `mixamorig_RightHand` | `mixamorig_RightHandMiddle1` | 0.60% | 50% |
| **L Upper Arm** | `mixamorig_LeftArm` | `mixamorig_LeftForeArm` | 2.80% | 44% |
| **L Forearm** | `mixamorig_LeftForeArm` | `mixamorig_LeftHand` | 1.60% | 43% |
| **L Hand** | `mixamorig_LeftHand` | `mixamorig_LeftHandMiddle1` | 0.60% | 50% |
| **R Thigh** | `mixamorig_RightUpLeg` | `mixamorig_RightLeg` | 10.00% | 43% |
| **R Shank** | `mixamorig_RightLeg` | `mixamorig_RightFoot` | 4.65% | 43% |
| **R Foot** | `mixamorig_RightFoot` | `mixamorig_RightToeBase` | 1.45% | 50% |
| **L Thigh** | `mixamorig_LeftUpLeg` | `mixamorig_LeftLeg` | 10.00% | 43% |
| **L Shank** | `mixamorig_LeftLeg` | `mixamorig_LeftFoot` | 4.65% | 43% |
| **L Foot** | `mixamorig_LeftFoot` | `mixamorig_LeftToeBase` | 1.45% | 50% |

### Key Assumptions & Notes

1.  **Clavicle:** The Clavicle segment (Shoulder -> Arm) is explicitly **excluded** from the segment list. Its mass is assumed to be integrated into the **Thorax** mass (18.0%).
2.  **Hand Tips:** The model attempts to use `mixamorig_RightHandMiddle1` (and Left equivalent) as the distal joint for the hand. If this joint is missing in the rig, the calculator falls back to using the proximal joint (`mixamorig_RightHand`) as the distal point, effectively placing the Hand CoM at the wrist (Zero length segment).
3.  **Trunk Subdivision:** The trunk is subdivided into 4 segments (Pelvis, Abdomen Lower, Abdomen Upper, Thorax) to better approximate the CoM shift during spinal flexion/extension, rather than treating the trunk as a single rigid body.

## Verification

### 1. In-App Diagnostics
The application includes a **CoM Validation Harness**.
*   **Action:** Tap "Run Diagnostics" in the main view.
*   **Behavior:** The character will cycle through deterministic poses (T-Pose, Touchdown, Squat, Pike, Layout).
*   **Output:** A debug overlay displays the calculated CoM, segment details, and a Pass/Fail status based on expected CoM shifts (e.g., CoM must rise during Touchdown).

### 2. Unit Tests
A manual validation test suite exists in `CheerComCalculatorAppTests/ManualCoMValidationTest.swift`.
*   **Purpose:** verifies the calculation logic without the full 3D rendering overhead.
*   **Method:** Constructs a programmatic skeleton, applies rotations, and asserts that the CoM moves in the expected direction relative to the T-Pose baseline.
