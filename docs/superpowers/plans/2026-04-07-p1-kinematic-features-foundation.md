# P1 — KinematicFeatures Foundation Implementation Plan

> **For agentic workers:** REQUIRED SUB-SKILL: Use superpowers:subagent-driven-development (recommended) or superpowers:executing-plans to implement this plan task-by-task. Steps use checkbox (`- [ ]`) syntax for tracking.

**Goal:** Build `ModelRigKit.KinematicFeatures` — a shared Swift module that computes the 11 derived kinematic features (inversion, body angle, joint angles, CoM + velocity, twist, ground contact) from 17 COCO keypoints. This module is the shared feature contract used by CheerCOM (authoring-time export), FlightFilter (inference-time runtime), and the Python training pipeline (numerically verified against a Swift-emitted golden values file).

**Architecture:** New file `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift` containing:
- `KinematicFeatures` value-type struct with 11 fields
- Static `compute(keypoints:previous:fps:)` entry point
- Pure helper functions with no hidden state — one frame in, one `KinematicFeatures` out
- Reuses existing `PoseAdapter` and `COMCalculator` for the CoM pathway so CheerCOM's anthropometric segment model stays the single source of truth

**Tech Stack:** Swift 5.9, Swift Package Manager, XCTest, SceneKit (for `SCNVector3` math only — no scene graph usage), ModelRigKit's existing `COCOKeypoint`, `COCOKeypointIndex`, `PoseAdapter`, `COMCalculator`.

**Working directory:** `/Users/ianrichardson/Projects/ModelRigKit` (separate repo from CheerCOM)

**Build command:** `cd /Users/ianrichardson/Projects/ModelRigKit && swift build`
**Test command:** `cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests`

---

## File Structure

All new files live in the `ModelRigKit` repository (not CheerCOM). This plan touches:

| File | Role | Status |
|---|---|---|
| `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift` | New: the feature struct + static compute entry point | Create |
| `Tests/ModelRigKitTests/KinematicFeaturesTests.swift` | New: unit tests covering each feature with golden values | Create |
| `Sources/ModelRigKit/Adapter/PoseAdapter.swift` | Existing: reused as-is for COCO → Joint mapping | No change |
| `Sources/ModelRigKit/Biomechanics/COMCalculator.swift` | Existing: reused via `calculateBodyCOM(jointPositions:)` for CoM | No change |

Why one file for `KinematicFeatures`: all 11 features are computed from the same input (a single frame's 17 keypoints + optionally the previous frame), share common helpers (vector math, midpoint, angle-between), and are consumed as a single struct. Splitting into 11 files would fragment the contract. ~300 lines total is well within the "one focused file" guideline.

---

## Task 1: Create the KinematicFeatures struct and failing test scaffolding

**Files:**
- Create: `/Users/ianrichardson/Projects/ModelRigKit/Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift`
- Create: `/Users/ianrichardson/Projects/ModelRigKit/Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

- [ ] **Step 1.1: Create the KinematicFeatures struct file with all 11 fields and a stub compute method**

Write this file at `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift`:

```swift
import Foundation
import SceneKit

/// Per-frame kinematic features derived from a single frame of COCO keypoints.
///
/// This struct is the **shared feature contract** used at three points in the pipeline:
/// 1. CheerCOM authoring-time export — computed from a rigged SceneKit pose
/// 2. FlightFilter inference-time runtime — computed from YOLOv8-pose output
/// 3. Python training pipeline — a Python port is tested for numerical equivalence
///    against Swift-generated golden values.
///
/// If you change any field's definition here, you MUST update the Python port and
/// regenerate the golden values or training/inference will diverge.
public struct KinematicFeatures: Codable, Sendable, Equatable {
    /// True when the head is below the hips in image Y (image Y increases downward).
    public let inversion: Bool

    /// Angle of the hip-midpoint → shoulder-midpoint vector from vertical, in degrees.
    /// 0° = upright, positive = leaning forward, 180° = upside-down.
    public let bodyAngleDeg: Double

    /// Trunk-to-thigh angle via shoulder → hip → knee, in degrees.
    /// ~180° = straight, ~90° = piked.
    public let hipAngleDeg: Double

    /// Left knee angle via hip → knee → ankle, in degrees. ~180° = straight leg.
    public let kneeAngleLeftDeg: Double

    /// Right knee angle via hip → knee → ankle, in degrees. ~180° = straight leg.
    public let kneeAngleRightDeg: Double

    /// Normalized center of mass X coordinate, [0, 1] in image space.
    public let comXNorm: Double

    /// Normalized center of mass Y coordinate, [0, 1] in image space.
    public let comYNorm: Double

    /// CoM velocity X (this frame minus previous frame), in normalized units per frame.
    /// Zero for the first frame.
    public let comVxNorm: Double

    /// CoM velocity Y, in normalized units per frame. Zero for the first frame.
    public let comVyNorm: Double

    /// Angular velocity of the body-angle vector in degrees per second.
    /// Zero for the first frame.
    public let hipAngularVelocityDps: Double

    /// Angle between the shoulder line and the hip line (in image plane), in degrees.
    /// Used as a twist proxy: a back full or double full will show this value accumulate
    /// across the airborne phase.
    public let shoulderHipTwistDeg: Double

    /// True when either foot is below the ground threshold in image Y.
    public let groundContact: Bool

    /// Stub entry point. Real implementation fills in across subsequent tasks.
    public static func compute(
        keypoints: [COCOKeypoint],
        previous: KinematicFeatures? = nil,
        fps: Double = 30.0
    ) -> KinematicFeatures {
        fatalError("compute() not implemented — stub only, fill in subsequent tasks")
    }
}
```

- [ ] **Step 1.2: Create the test file with an "it exists" test that will compile**

Write this file at `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`:

```swift
import XCTest
import SceneKit
@testable import ModelRigKit

final class KinematicFeaturesTests: XCTestCase {

    // MARK: - Fixtures

    /// 17 COCO keypoints representing an upright standing T-pose in normalized
    /// image coordinates. Head at top, feet at bottom.
    static let tPoseKeypoints: [COCOKeypoint] = [
        /* 0  nose           */ COCOKeypoint(x: 0.500, y: 0.100, confidence: 1.0),
        /* 1  left_eye       */ COCOKeypoint(x: 0.490, y: 0.095, confidence: 1.0),
        /* 2  right_eye      */ COCOKeypoint(x: 0.510, y: 0.095, confidence: 1.0),
        /* 3  left_ear       */ COCOKeypoint(x: 0.480, y: 0.100, confidence: 1.0),
        /* 4  right_ear      */ COCOKeypoint(x: 0.520, y: 0.100, confidence: 1.0),
        /* 5  left_shoulder  */ COCOKeypoint(x: 0.450, y: 0.200, confidence: 1.0),
        /* 6  right_shoulder */ COCOKeypoint(x: 0.550, y: 0.200, confidence: 1.0),
        /* 7  left_elbow     */ COCOKeypoint(x: 0.350, y: 0.200, confidence: 1.0),
        /* 8  right_elbow    */ COCOKeypoint(x: 0.650, y: 0.200, confidence: 1.0),
        /* 9  left_wrist     */ COCOKeypoint(x: 0.250, y: 0.200, confidence: 1.0),
        /* 10 right_wrist    */ COCOKeypoint(x: 0.750, y: 0.200, confidence: 1.0),
        /* 11 left_hip       */ COCOKeypoint(x: 0.470, y: 0.500, confidence: 1.0),
        /* 12 right_hip      */ COCOKeypoint(x: 0.530, y: 0.500, confidence: 1.0),
        /* 13 left_knee      */ COCOKeypoint(x: 0.470, y: 0.730, confidence: 1.0),
        /* 14 right_knee     */ COCOKeypoint(x: 0.530, y: 0.730, confidence: 1.0),
        /* 15 left_ankle     */ COCOKeypoint(x: 0.470, y: 0.950, confidence: 1.0),
        /* 16 right_ankle    */ COCOKeypoint(x: 0.530, y: 0.950, confidence: 1.0),
    ]

    func test_struct_has_all_eleven_fields() {
        // Construct a zero-initialized KinematicFeatures to verify the struct compiles.
        let k = KinematicFeatures(
            inversion: false,
            bodyAngleDeg: 0,
            hipAngleDeg: 0,
            kneeAngleLeftDeg: 0,
            kneeAngleRightDeg: 0,
            comXNorm: 0,
            comYNorm: 0,
            comVxNorm: 0,
            comVyNorm: 0,
            hipAngularVelocityDps: 0,
            shoulderHipTwistDeg: 0,
            groundContact: false
        )
        XCTAssertEqual(k.bodyAngleDeg, 0)
    }
}
```

- [ ] **Step 1.3: Run swift build and verify compilation**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift build
```

Expected: `Build complete!` with no errors. If errors mention missing public initializer on `KinematicFeatures`, add this memberwise initializer inside the struct:

```swift
public init(
    inversion: Bool,
    bodyAngleDeg: Double,
    hipAngleDeg: Double,
    kneeAngleLeftDeg: Double,
    kneeAngleRightDeg: Double,
    comXNorm: Double,
    comYNorm: Double,
    comVxNorm: Double,
    comVyNorm: Double,
    hipAngularVelocityDps: Double,
    shoulderHipTwistDeg: Double,
    groundContact: Bool
) {
    self.inversion = inversion
    self.bodyAngleDeg = bodyAngleDeg
    self.hipAngleDeg = hipAngleDeg
    self.kneeAngleLeftDeg = kneeAngleLeftDeg
    self.kneeAngleRightDeg = kneeAngleRightDeg
    self.comXNorm = comXNorm
    self.comYNorm = comYNorm
    self.comVxNorm = comVxNorm
    self.comVyNorm = comVyNorm
    self.hipAngularVelocityDps = hipAngularVelocityDps
    self.shoulderHipTwistDeg = shoulderHipTwistDeg
    self.groundContact = groundContact
}
```

- [ ] **Step 1.4: Run the stub test to verify it passes**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests.test_struct_has_all_eleven_fields
```

Expected: `Test Suite 'Selected tests' passed` with 1 test passing.

- [ ] **Step 1.5: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift Tests/ModelRigKitTests/KinematicFeaturesTests.swift && git commit -m "feat(kinematic): add KinematicFeatures struct scaffold with 11 fields

Adds the shared feature contract used by CheerCOM authoring-time
export, FlightFilter inference-time runtime, and the Python training
pipeline (via a numerically-verified port). Contains only the struct
and a failing compute() stub — implementations follow in subsequent
commits, one feature at a time.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 2: Implement `inversion` and `groundContact`

**Files:**
- Modify: `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift`
- Modify: `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

**Rationale:** Start with the two Bool features since they're the simplest. Both depend only on per-frame Y comparisons.

- [ ] **Step 2.1: Write failing tests for inversion and groundContact**

Add these test methods to `KinematicFeaturesTests`:

```swift
// MARK: - Inversion + ground contact

func test_inversion_false_for_upright_t_pose() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    XCTAssertFalse(k.inversion, "Upright T-pose should not be inverted")
}

func test_inversion_true_for_upside_down_pose() {
    // Flip the T-pose around y = 0.5: nose at bottom, feet at top
    let flipped = Self.tPoseKeypoints.map {
        COCOKeypoint(x: $0.x, y: 1.0 - $0.y, confidence: $0.confidence)
    }
    let k = KinematicFeatures.compute(keypoints: flipped)
    XCTAssertTrue(k.inversion, "Upside-down pose should be inverted")
}

func test_groundContact_true_for_upright_pose_with_feet_at_bottom() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    XCTAssertTrue(k.groundContact, "T-pose with ankles at y=0.95 should have ground contact")
}

func test_groundContact_false_for_airborne_pose_with_feet_raised() {
    // Same T-pose but ankles at y = 0.4 (legs raised, mid-tuck style)
    var airborne = Self.tPoseKeypoints
    airborne[15] = COCOKeypoint(x: 0.470, y: 0.400, confidence: 1.0)  // left_ankle
    airborne[16] = COCOKeypoint(x: 0.530, y: 0.400, confidence: 1.0)  // right_ankle
    let k = KinematicFeatures.compute(keypoints: airborne)
    XCTAssertFalse(k.groundContact, "Raised ankles should not indicate ground contact")
}
```

- [ ] **Step 2.2: Run the four failing tests to verify they fail**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests.test_inversion_false_for_upright_t_pose 2>&1 | tail -20
```

Expected: test crashes with `fatalError: compute() not implemented — stub only`. That's the expected failure mode — we'll remove the fatalError in the next step.

- [ ] **Step 2.3: Implement inversion and groundContact (and replace the fatalError stub)**

Replace the existing `compute` method in `KinematicFeatures.swift` with:

```swift
/// Y-threshold below which a foot is considered in ground contact.
/// Frames where the lowest foot has y > this value are treated as grounded.
/// 0.85 = the bottom 15% of the normalized image frame.
public static let groundYThreshold: Double = 0.85

public static func compute(
    keypoints: [COCOKeypoint],
    previous: KinematicFeatures? = nil,
    fps: Double = 30.0
) -> KinematicFeatures {
    precondition(keypoints.count == 17, "compute() requires exactly 17 COCO keypoints")

    let nose = keypoints[COCOKeypointIndex.nose.rawValue]
    let leftHip = keypoints[COCOKeypointIndex.leftHip.rawValue]
    let rightHip = keypoints[COCOKeypointIndex.rightHip.rawValue]
    let leftAnkle = keypoints[COCOKeypointIndex.leftAnkle.rawValue]
    let rightAnkle = keypoints[COCOKeypointIndex.rightAnkle.rawValue]

    let hipMidY = (Double(leftHip.y) + Double(rightHip.y)) / 2.0

    // Inversion: head below hips in image Y (image Y increases downward).
    let inversion = Double(nose.y) > hipMidY

    // Ground contact: max(leftAnkleY, rightAnkleY) — the lowest foot in image Y —
    // is below (greater than, because image Y increases downward) the threshold.
    let lowestFootY = max(Double(leftAnkle.y), Double(rightAnkle.y))
    let groundContact = lowestFootY > groundYThreshold

    return KinematicFeatures(
        inversion: inversion,
        bodyAngleDeg: 0,
        hipAngleDeg: 0,
        kneeAngleLeftDeg: 0,
        kneeAngleRightDeg: 0,
        comXNorm: 0,
        comYNorm: 0,
        comVxNorm: 0,
        comVyNorm: 0,
        hipAngularVelocityDps: 0,
        shoulderHipTwistDeg: 0,
        groundContact: groundContact
    )
}
```

- [ ] **Step 2.4: Run the four tests and verify they pass**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -15
```

Expected: 5 tests passing (the original `test_struct_has_all_eleven_fields` plus the 4 new tests for inversion and ground contact).

- [ ] **Step 2.5: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift Tests/ModelRigKitTests/KinematicFeaturesTests.swift && git commit -m "feat(kinematic): implement inversion and groundContact features

Both features are per-frame Y comparisons on COCO keypoints:
- inversion: nose y > hip-midpoint y (image Y increases downward)
- groundContact: lowest ankle y > 0.85 threshold (bottom 15% of frame)

Replaces the fatalError stub with a real compute() implementation
that fills these two fields and leaves the rest at zero.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 3: Implement `bodyAngleDeg`

**Files:**
- Modify: `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift`
- Modify: `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

**Rationale:** `bodyAngleDeg` is the foundation for orientation-aware features and for the hipAngularVelocity computation in Task 6. It's a pure trigonometric function of the hip-midpoint → shoulder-midpoint vector.

- [ ] **Step 3.1: Write failing tests for bodyAngleDeg**

Add these test methods to `KinematicFeaturesTests`:

```swift
// MARK: - Body angle

func test_bodyAngleDeg_zero_for_upright_t_pose() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    XCTAssertEqual(k.bodyAngleDeg, 0.0, accuracy: 1.0,
                   "Upright T-pose should have body angle near 0°")
}

func test_bodyAngleDeg_approximately_180_for_upside_down_pose() {
    // Same flip as the inversion test
    let flipped = Self.tPoseKeypoints.map {
        COCOKeypoint(x: $0.x, y: 1.0 - $0.y, confidence: $0.confidence)
    }
    let k = KinematicFeatures.compute(keypoints: flipped)
    // Shoulders now below hips → vector points down → 180° from vertical up
    XCTAssertEqual(abs(k.bodyAngleDeg), 180.0, accuracy: 2.0,
                   "Upside-down pose should have body angle near ±180°")
}

func test_bodyAngleDeg_approximately_90_for_horizontal_layout() {
    // Body lying on its side: shoulders to the right of hips in x, same y
    var horizontal = Self.tPoseKeypoints
    let hipY = 0.500
    horizontal[5]  = COCOKeypoint(x: 0.700, y: Float(hipY - 0.01), confidence: 1.0) // l shoulder
    horizontal[6]  = COCOKeypoint(x: 0.700, y: Float(hipY + 0.01), confidence: 1.0) // r shoulder
    horizontal[11] = COCOKeypoint(x: 0.300, y: Float(hipY - 0.01), confidence: 1.0) // l hip
    horizontal[12] = COCOKeypoint(x: 0.300, y: Float(hipY + 0.01), confidence: 1.0) // r hip
    let k = KinematicFeatures.compute(keypoints: horizontal)
    // Vector from hip midpoint (0.3, 0.5) to shoulder midpoint (0.7, 0.5):
    //   dx = +0.4, dy = 0 → angle from vertical = 90° (leaning right)
    XCTAssertEqual(abs(k.bodyAngleDeg), 90.0, accuracy: 2.0,
                   "Horizontal pose should have body angle near ±90°")
}
```

- [ ] **Step 3.2: Run the tests and verify they fail**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests.test_bodyAngleDeg 2>&1 | tail -15
```

Expected: 3 tests failing with body angle values near 0 (because the field is currently hardcoded to 0 in the compute stub).

- [ ] **Step 3.3: Implement bodyAngleDeg**

Add this private helper function to `KinematicFeatures.swift`, placed just before the `compute` method:

```swift
/// Angle from vertical up (0, -1) to the vector (dx, dy), in degrees.
/// Image-space convention: Y increases downward, so the "vertical up" reference
/// vector in image space is (0, -1).
///
/// Return range: (-180°, 180°]. Positive = leaning right, negative = leaning left.
private static func angleFromVertical(dx: Double, dy: Double) -> Double {
    // atan2(dx, -dy) gives the signed angle from (0, -1) to (dx, dy).
    let radians = atan2(dx, -dy)
    return radians * 180.0 / .pi
}
```

Update the `compute` method body. Add this **after** the existing `let inversion = ...` line and **before** `return KinematicFeatures(...)`:

```swift
    let leftShoulder = keypoints[COCOKeypointIndex.leftShoulder.rawValue]
    let rightShoulder = keypoints[COCOKeypointIndex.rightShoulder.rawValue]

    let hipMidX = (Double(leftHip.x) + Double(rightHip.x)) / 2.0
    let shoulderMidX = (Double(leftShoulder.x) + Double(rightShoulder.x)) / 2.0
    let shoulderMidY = (Double(leftShoulder.y) + Double(rightShoulder.y)) / 2.0

    // Vector from hip midpoint → shoulder midpoint
    let dx = shoulderMidX - hipMidX
    let dy = shoulderMidY - hipMidY
    let bodyAngleDeg = angleFromVertical(dx: dx, dy: dy)
```

Change `bodyAngleDeg: 0` in the return statement to `bodyAngleDeg: bodyAngleDeg`.

- [ ] **Step 3.4: Run the tests and verify they pass**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -15
```

Expected: 8 tests passing (5 from before + 3 new body angle tests).

- [ ] **Step 3.5: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift Tests/ModelRigKitTests/KinematicFeaturesTests.swift && git commit -m "feat(kinematic): implement bodyAngleDeg

Computes the angle from image-space vertical-up (0, -1) to the
hip-midpoint → shoulder-midpoint vector using atan2(dx, -dy). Signed
in [-180°, 180°]: 0° = upright, ±90° = horizontal, ±180° = inverted.

Golden values:
- Upright T-pose: ~0°
- Upside-down flip: ~±180°
- Horizontal layout: ~±90°

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 4: Implement `hipAngleDeg`, `kneeAngleLeftDeg`, `kneeAngleRightDeg`

**Files:**
- Modify: `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift`
- Modify: `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

**Rationale:** All three joint angles are computed the same way — the angle between two vectors at a common pivot. Implementing them together avoids duplicating a shared helper.

- [ ] **Step 4.1: Write failing tests for joint angles**

Add these test methods to `KinematicFeaturesTests`:

```swift
// MARK: - Joint angles

func test_hipAngleDeg_approximately_180_for_straight_t_pose() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    // T-pose has shoulders directly above hips directly above knees → straight ~180°
    XCTAssertEqual(k.hipAngleDeg, 180.0, accuracy: 5.0,
                   "Straight T-pose should have hip angle near 180°")
}

func test_hipAngleDeg_approximately_90_for_piked_pose() {
    // Piked: knees forward (x to the right), shoulders still above hips
    var piked = Self.tPoseKeypoints
    piked[13] = COCOKeypoint(x: 0.750, y: 0.500, confidence: 1.0) // left_knee
    piked[14] = COCOKeypoint(x: 0.750, y: 0.500, confidence: 1.0) // right_knee
    let k = KinematicFeatures.compute(keypoints: piked)
    XCTAssertEqual(k.hipAngleDeg, 90.0, accuracy: 10.0,
                   "Piked pose with knees at 90° to trunk should have hip angle near 90°")
}

func test_kneeAngleLeftDeg_approximately_180_for_straight_leg() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    XCTAssertEqual(k.kneeAngleLeftDeg, 180.0, accuracy: 5.0,
                   "Straight T-pose leg should have knee angle near 180°")
}

func test_kneeAngleRightDeg_approximately_180_for_straight_leg() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    XCTAssertEqual(k.kneeAngleRightDeg, 180.0, accuracy: 5.0,
                   "Straight T-pose leg should have knee angle near 180°")
}

func test_kneeAngleLeftDeg_approximately_90_for_bent_knee() {
    // Left knee at hip x, left ankle forward of knee → 90° bend
    var bent = Self.tPoseKeypoints
    bent[13] = COCOKeypoint(x: 0.470, y: 0.730, confidence: 1.0) // left_knee (unchanged)
    bent[15] = COCOKeypoint(x: 0.700, y: 0.730, confidence: 1.0) // left_ankle forward
    let k = KinematicFeatures.compute(keypoints: bent)
    XCTAssertEqual(k.kneeAngleLeftDeg, 90.0, accuracy: 10.0,
                   "Bent left knee should have angle near 90°")
}
```

- [ ] **Step 4.2: Run tests and verify they fail**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -20
```

Expected: 5 new tests failing with joint angles at 0 (field is still hardcoded to 0).

- [ ] **Step 4.3: Implement the joint angle helper and wire up the three features**

Add this private helper to `KinematicFeatures.swift`, placed right after `angleFromVertical`:

```swift
/// Angle at vertex B between the vectors (A → B) and (C → B), in degrees.
/// Returns 0–180. Straight = 180, fully folded = 0.
private static func angleBetween(
    a: (x: Double, y: Double),
    vertex b: (x: Double, y: Double),
    c: (x: Double, y: Double)
) -> Double {
    let v1x = a.x - b.x
    let v1y = a.y - b.y
    let v2x = c.x - b.x
    let v2y = c.y - b.y

    let dot = v1x * v2x + v1y * v2y
    let mag1 = (v1x * v1x + v1y * v1y).squareRoot()
    let mag2 = (v2x * v2x + v2y * v2y).squareRoot()

    guard mag1 > 1e-6, mag2 > 1e-6 else { return 180.0 }

    let cosine = max(-1.0, min(1.0, dot / (mag1 * mag2)))
    return acos(cosine) * 180.0 / .pi
}
```

Update the `compute` method. Add this **after** the `let bodyAngleDeg = ...` line and **before** `return KinematicFeatures(...)`:

```swift
    let leftKnee = keypoints[COCOKeypointIndex.leftKnee.rawValue]
    let rightKnee = keypoints[COCOKeypointIndex.rightKnee.rawValue]
    let leftAnkleKP = keypoints[COCOKeypointIndex.leftAnkle.rawValue]
    let rightAnkleKP = keypoints[COCOKeypointIndex.rightAnkle.rawValue]

    // Hip angle: shoulder_mid → hip_mid → knee_mid  (trunk vs thigh)
    let kneeMidX = (Double(leftKnee.x) + Double(rightKnee.x)) / 2.0
    let kneeMidY = (Double(leftKnee.y) + Double(rightKnee.y)) / 2.0
    let hipAngleDeg = angleBetween(
        a: (shoulderMidX, shoulderMidY),
        vertex: (hipMidX, hipMidY),
        c: (kneeMidX, kneeMidY)
    )

    // Knee angles: hip → knee → ankle  (thigh vs shank)
    let kneeAngleLeftDeg = angleBetween(
        a: (Double(leftHip.x), Double(leftHip.y)),
        vertex: (Double(leftKnee.x), Double(leftKnee.y)),
        c: (Double(leftAnkleKP.x), Double(leftAnkleKP.y))
    )
    let kneeAngleRightDeg = angleBetween(
        a: (Double(rightHip.x), Double(rightHip.y)),
        vertex: (Double(rightKnee.x), Double(rightKnee.y)),
        c: (Double(rightAnkleKP.x), Double(rightAnkleKP.y))
    )
```

Change the return statement fields:
```swift
hipAngleDeg: hipAngleDeg,
kneeAngleLeftDeg: kneeAngleLeftDeg,
kneeAngleRightDeg: kneeAngleRightDeg,
```

- [ ] **Step 4.4: Run tests and verify they pass**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -20
```

Expected: 13 tests passing (8 from before + 5 new joint angle tests).

- [ ] **Step 4.5: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift Tests/ModelRigKitTests/KinematicFeaturesTests.swift && git commit -m "feat(kinematic): implement hipAngleDeg and knee angles

All three use the shared angleBetween(a, vertex, c) helper:
- hipAngleDeg: shoulder-mid → hip-mid → knee-mid (trunk vs thigh)
- kneeAngleLeftDeg: left_hip → left_knee → left_ankle
- kneeAngleRightDeg: right_hip → right_knee → right_ankle

All three return 0–180° where 180 = straight and smaller values
indicate increasing flexion (tuck, pike).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 5: Implement `comXNorm`, `comYNorm` via PoseAdapter + COMCalculator

**Files:**
- Modify: `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift`
- Modify: `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

**Rationale:** Reusing `PoseAdapter.adaptCOCOKeypoints` and `COMCalculator.calculateBodyCOM(jointPositions:)` guarantees the CoM math is identical across CheerCOM (authoring) and FlightFilter (inference). There is no second CoM implementation to drift out of sync.

- [ ] **Step 5.1: Write failing tests for CoM**

Add these test methods to `KinematicFeaturesTests`:

```swift
// MARK: - Center of mass

func test_comXNorm_near_middle_for_symmetric_t_pose() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    XCTAssertEqual(k.comXNorm, 0.5, accuracy: 0.05,
                   "Symmetric T-pose should have CoM X near 0.5")
}

func test_comYNorm_in_plausible_range_for_t_pose() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    // Anthropometric CoM for upright human is roughly navel-height. For the
    // T-pose with shoulders at y=0.2 and hips at y=0.5 and ankles at y=0.95,
    // the CoM should land somewhere in [0.4, 0.6] — torso-ish.
    XCTAssertGreaterThan(k.comYNorm, 0.4, "CoM Y should be below shoulder level")
    XCTAssertLessThan(k.comYNorm, 0.65, "CoM Y should be above knee level")
}

func test_comXNorm_shifts_right_when_body_leans_right() {
    // Shift every keypoint right by 0.1
    let shifted = Self.tPoseKeypoints.map {
        COCOKeypoint(x: $0.x + 0.1, y: $0.y, confidence: $0.confidence)
    }
    let k = KinematicFeatures.compute(keypoints: shifted)
    XCTAssertEqual(k.comXNorm, 0.6, accuracy: 0.05,
                   "Shifted T-pose should have CoM X near 0.6")
}
```

- [ ] **Step 5.2: Run tests and verify they fail**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -15
```

Expected: 3 new tests failing with CoM values at 0.0.

- [ ] **Step 5.3: Implement CoM by delegating to PoseAdapter and COMCalculator**

Add this static member inside `KinematicFeatures` (place it near `groundYThreshold`):

```swift
/// Shared COMCalculator instance used by compute(). Body mass is a placeholder —
/// CoM position is mass-ratio-weighted, so absolute mass doesn't affect the normalized
/// output coordinates.
private static let comCalculator: COMCalculator = COMCalculator(bodyMass: 60.0)
```

Update the `compute` method body. Add this **after** the knee angle computations and **before** `return KinematicFeatures(...)`:

```swift
    // Center of mass via existing ModelRigKit pipeline.
    // Step 1: COCO keypoints → Joint positions (2D, z=0)
    let jointPositions = PoseAdapter.adaptCOCOKeypoints(keypoints)

    // Step 2: Joint positions → weighted CoM via anthropometric segment model
    let com3D = comCalculator.calculateBodyCOM(jointPositions: jointPositions)
    let comXNorm = Double(com3D.x)
    let comYNorm = Double(com3D.y)
```

Change the return statement fields:
```swift
comXNorm: comXNorm,
comYNorm: comYNorm,
```

- [ ] **Step 5.4: Run tests and verify they pass**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -20
```

Expected: 16 tests passing (13 from before + 3 new CoM tests).

If the CoM Y test fails because the value is outside the [0.4, 0.65] range, inspect the actual value in the test failure output. The anthropometric model may place CoM closer to the hips for a T-pose than expected. Widen the assertion range to match reality rather than tightening the pose.

- [ ] **Step 5.5: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift Tests/ModelRigKitTests/KinematicFeaturesTests.swift && git commit -m "feat(kinematic): implement comXNorm and comYNorm via COMCalculator

Delegates to PoseAdapter.adaptCOCOKeypoints + COMCalculator to
guarantee the CoM math is identical across CheerCOM authoring and
FlightFilter inference — the anthropometric segment model is the
single source of truth.

For a symmetric T-pose, CoM X ≈ 0.5 and CoM Y lands in the torso
region (~0.4–0.65 depending on exact segment weights).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 6: Implement `comVxNorm`, `comVyNorm`, `hipAngularVelocityDps`

**Files:**
- Modify: `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift`
- Modify: `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

**Rationale:** All three are frame-to-frame deltas that need the `previous` parameter. Zero for the first frame when `previous == nil`. Implemented together because they share the same previous-frame-handling logic.

- [ ] **Step 6.1: Write failing tests for velocities**

Add these test methods to `KinematicFeaturesTests`:

```swift
// MARK: - Velocity features

func test_comVxNorm_zero_when_previous_is_nil() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints, previous: nil)
    XCTAssertEqual(k.comVxNorm, 0.0, accuracy: 0.001,
                   "First frame (no previous) should have zero velocity")
    XCTAssertEqual(k.comVyNorm, 0.0, accuracy: 0.001)
    XCTAssertEqual(k.hipAngularVelocityDps, 0.0, accuracy: 0.001)
}

func test_comVxNorm_matches_delta_when_body_shifts_right() {
    let prev = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    let shifted = Self.tPoseKeypoints.map {
        COCOKeypoint(x: $0.x + 0.1, y: $0.y, confidence: $0.confidence)
    }
    let curr = KinematicFeatures.compute(keypoints: shifted, previous: prev)
    XCTAssertEqual(curr.comVxNorm, 0.1, accuracy: 0.02,
                   "CoM X velocity should equal the horizontal shift")
    XCTAssertEqual(curr.comVyNorm, 0.0, accuracy: 0.02,
                   "CoM Y velocity should be zero for horizontal shift")
}

func test_hipAngularVelocityDps_matches_body_angle_delta_times_fps() {
    // Frame 1: upright (bodyAngleDeg ≈ 0)
    let prev = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints, fps: 30.0)

    // Frame 2: rotated 30° (shoulder shifted right of hip by tan(30°) * trunk_length)
    // Simpler: construct a pose where bodyAngleDeg is approximately 30°.
    var rotated = Self.tPoseKeypoints
    rotated[5] = COCOKeypoint(x: 0.587, y: 0.250, confidence: 1.0) // l shoulder (shifted right + down)
    rotated[6] = COCOKeypoint(x: 0.687, y: 0.250, confidence: 1.0) // r shoulder
    // hip unchanged at y=0.5, x midpoint 0.5
    // hip mid at (0.5, 0.5), shoulder mid at (0.637, 0.25)
    // dx = 0.137, dy = -0.25
    // atan2(0.137, 0.25) * 180/pi ≈ 28.7°
    let curr = KinematicFeatures.compute(keypoints: rotated, previous: prev, fps: 30.0)

    let expectedDps = (curr.bodyAngleDeg - prev.bodyAngleDeg) * 30.0
    XCTAssertEqual(curr.hipAngularVelocityDps, expectedDps, accuracy: 1.0,
                   "Angular velocity should equal (Δ body angle) × fps")
}
```

- [ ] **Step 6.2: Run tests and verify they fail**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -20
```

Expected: 3 new tests failing (velocity fields still hardcoded to 0 for non-nil previous).

- [ ] **Step 6.3: Implement the velocity features**

Update the `compute` method body. Add this **after** the CoM computation and **before** `return KinematicFeatures(...)`:

```swift
    // Frame-to-frame velocities. Zero when no previous frame is provided.
    let comVxNorm: Double
    let comVyNorm: Double
    let hipAngularVelocityDps: Double
    if let previous = previous {
        comVxNorm = comXNorm - previous.comXNorm
        comVyNorm = comYNorm - previous.comYNorm
        hipAngularVelocityDps = (bodyAngleDeg - previous.bodyAngleDeg) * fps
    } else {
        comVxNorm = 0.0
        comVyNorm = 0.0
        hipAngularVelocityDps = 0.0
    }
```

Change the return statement fields:
```swift
comVxNorm: comVxNorm,
comVyNorm: comVyNorm,
hipAngularVelocityDps: hipAngularVelocityDps,
```

- [ ] **Step 6.4: Run tests and verify they pass**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -20
```

Expected: 19 tests passing (16 from before + 3 new velocity tests).

- [ ] **Step 6.5: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift Tests/ModelRigKitTests/KinematicFeaturesTests.swift && git commit -m "feat(kinematic): implement frame-to-frame velocity features

Adds comVxNorm, comVyNorm, and hipAngularVelocityDps. All three
compute as (current - previous), with hipAngularVelocityDps scaled
by fps to yield degrees-per-second. Returns zero when previous is
nil (first frame of a sequence).

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 7: Implement `shoulderHipTwistDeg`

**Files:**
- Modify: `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift`
- Modify: `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

**Rationale:** The twist feature is the signed angle between the shoulder line (right - left) and the hip line (right - left). For a non-twisting pose both vectors point the same direction → 0°. For a full twist they point opposite → 180°. This is how the TCN can distinguish a back layout (0° twist) from a back full (~360° cumulative twist).

- [ ] **Step 7.1: Write failing tests for twist**

Add these test methods to `KinematicFeaturesTests`:

```swift
// MARK: - Shoulder-hip twist

func test_shoulderHipTwistDeg_zero_for_aligned_t_pose() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    XCTAssertEqual(k.shoulderHipTwistDeg, 0.0, accuracy: 5.0,
                   "T-pose has aligned shoulders and hips → twist ~0°")
}

func test_shoulderHipTwistDeg_around_180_for_fully_swapped_shoulders() {
    // Swap left and right shoulders → shoulder line reversed
    var swapped = Self.tPoseKeypoints
    swapped[5] = COCOKeypoint(x: 0.550, y: 0.200, confidence: 1.0) // l shoulder (was right)
    swapped[6] = COCOKeypoint(x: 0.450, y: 0.200, confidence: 1.0) // r shoulder (was left)
    let k = KinematicFeatures.compute(keypoints: swapped)
    XCTAssertEqual(abs(k.shoulderHipTwistDeg), 180.0, accuracy: 5.0,
                   "Swapped shoulder line should produce ±180° twist")
}

func test_shoulderHipTwistDeg_around_90_for_perpendicular_shoulders() {
    // Shoulders in vertical line (above each other), hips still horizontal
    var perp = Self.tPoseKeypoints
    perp[5] = COCOKeypoint(x: 0.500, y: 0.150, confidence: 1.0) // l shoulder above
    perp[6] = COCOKeypoint(x: 0.500, y: 0.250, confidence: 1.0) // r shoulder below
    let k = KinematicFeatures.compute(keypoints: perp)
    XCTAssertEqual(abs(k.shoulderHipTwistDeg), 90.0, accuracy: 10.0,
                   "Perpendicular shoulder line should produce ±90° twist")
}
```

- [ ] **Step 7.2: Run tests and verify they fail**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -15
```

Expected: 3 new tests failing (twist field still hardcoded to 0).

- [ ] **Step 7.3: Implement twist**

Add this private helper to `KinematicFeatures.swift`, placed right after `angleBetween`:

```swift
/// Signed angle in degrees to rotate vector A onto vector B, around the z-axis.
/// Return range: (-180°, 180°]. Positive = counter-clockwise in image space.
private static func signedAngleBetween(
    a: (x: Double, y: Double),
    b: (x: Double, y: Double)
) -> Double {
    // 2D cross product magnitude (gives sign) and dot product (gives cosine)
    let cross = a.x * b.y - a.y * b.x
    let dot = a.x * b.x + a.y * b.y
    let radians = atan2(cross, dot)
    return radians * 180.0 / .pi
}
```

Update the `compute` method body. Add this **after** the velocity computation and **before** `return KinematicFeatures(...)`:

```swift
    // Shoulder-hip twist: signed angle from hip-line to shoulder-line.
    let shoulderVecX = Double(rightShoulder.x) - Double(leftShoulder.x)
    let shoulderVecY = Double(rightShoulder.y) - Double(leftShoulder.y)
    let hipVecX = Double(rightHip.x) - Double(leftHip.x)
    let hipVecY = Double(rightHip.y) - Double(leftHip.y)

    let shoulderHipTwistDeg = signedAngleBetween(
        a: (hipVecX, hipVecY),
        b: (shoulderVecX, shoulderVecY)
    )
```

Change the return statement field:
```swift
shoulderHipTwistDeg: shoulderHipTwistDeg,
```

- [ ] **Step 7.4: Run tests and verify they pass**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -20
```

Expected: 22 tests passing (19 from before + 3 new twist tests).

- [ ] **Step 7.5: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift Tests/ModelRigKitTests/KinematicFeaturesTests.swift && git commit -m "feat(kinematic): implement shoulderHipTwistDeg

Signed angle (-180°, 180°] from the hip-line vector (L→R) to the
shoulder-line vector (L→R) using atan2(cross, dot). Aligned = 0°,
swapped = ±180°, perpendicular = ±90°. Feeds the TCN's ability to
distinguish a back layout from a back full/double full via
cumulative twist across airborne frames.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 8: End-to-end integration tests and golden-values test

**Files:**
- Modify: `Tests/ModelRigKitTests/KinematicFeaturesTests.swift`

**Rationale:** The feature-by-feature tests verify each field independently with isolated assertions. This task adds a cumulative test that computes a full `KinematicFeatures` struct against a single canonical pose and asserts every field simultaneously. This is the "golden values" reference the Python port will be tested against in P3.

- [ ] **Step 8.1: Write the canonical golden-values test**

Add this test method to `KinematicFeaturesTests`:

```swift
// MARK: - Golden values reference

func test_golden_values_for_canonical_t_pose() {
    let k = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)

    // These exact values become the reference that the Python port
    // (training_pipeline/kinematic_features.py) must reproduce to within 1e-4.
    // Do NOT loosen these tolerances without updating the Python golden file.
    XCTAssertFalse(k.inversion)
    XCTAssertEqual(k.bodyAngleDeg, 0.0, accuracy: 0.5)
    XCTAssertEqual(k.hipAngleDeg, 180.0, accuracy: 1.0)
    XCTAssertEqual(k.kneeAngleLeftDeg, 180.0, accuracy: 1.0)
    XCTAssertEqual(k.kneeAngleRightDeg, 180.0, accuracy: 1.0)
    XCTAssertEqual(k.comXNorm, 0.5, accuracy: 0.05)
    XCTAssertGreaterThan(k.comYNorm, 0.4)
    XCTAssertLessThan(k.comYNorm, 0.65)
    XCTAssertEqual(k.comVxNorm, 0.0)
    XCTAssertEqual(k.comVyNorm, 0.0)
    XCTAssertEqual(k.hipAngularVelocityDps, 0.0)
    XCTAssertEqual(k.shoulderHipTwistDeg, 0.0, accuracy: 0.5)
    XCTAssertTrue(k.groundContact)
}

func test_golden_values_for_two_frame_sequence_with_rightward_motion() {
    let frame1 = KinematicFeatures.compute(keypoints: Self.tPoseKeypoints)
    let shifted = Self.tPoseKeypoints.map {
        COCOKeypoint(x: $0.x + 0.05, y: $0.y, confidence: $0.confidence)
    }
    let frame2 = KinematicFeatures.compute(keypoints: shifted, previous: frame1)

    XCTAssertEqual(frame1.comVxNorm, 0.0)
    XCTAssertEqual(frame2.comVxNorm, 0.05, accuracy: 0.01)
    XCTAssertEqual(frame2.comVyNorm, 0.0, accuracy: 0.01)
    XCTAssertEqual(frame2.hipAngularVelocityDps, 0.0, accuracy: 1.0)
    XCTAssertEqual(frame2.comXNorm, 0.55, accuracy: 0.05)
}
```

- [ ] **Step 8.2: Run all tests and verify they pass**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesTests 2>&1 | tail -20
```

Expected: 24 tests passing (22 from before + 2 new golden-values tests).

- [ ] **Step 8.3: Run the full ModelRigKit test suite to confirm no regressions**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test 2>&1 | tail -20
```

Expected: all existing tests pass AND the 24 new KinematicFeatures tests pass. No test count should decrease compared to before this plan began.

If anything from the existing suites (`COMCalculatorTests`, `PoseAdapterTests`, `JointLimitsTests`) fails, revert the most recent change and diagnose before proceeding. Existing tests must not be broken by the new module.

- [ ] **Step 8.4: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Tests/ModelRigKitTests/KinematicFeaturesTests.swift && git commit -m "test(kinematic): add golden-values tests for canonical T-pose

Two cumulative tests that verify every field on KinematicFeatures
simultaneously against a canonical upright T-pose and a two-frame
rightward-motion sequence. These values become the reference that
the Python port (training_pipeline/kinematic_features.py) must
reproduce to within 1e-4 in Plan 3 — do not loosen tolerances
without updating the Python golden file.

Total KinematicFeatures tests: 24 (all passing). Full ModelRigKit
suite remains green.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 9: Emit a golden JSON file for downstream Python verification

**Files:**
- Create: `Tests/ModelRigKitTests/KinematicFeaturesGoldenTests.swift`
- Create: `Tests/ModelRigKitTests/Fixtures/kinematic_features_golden.json` (generated)

**Rationale:** P3's Python pipeline needs to verify that its `kinematic_features.py` port matches the Swift implementation. The easiest way is to have Swift write out a golden JSON file with (input keypoints → output features) pairs, then have Python load the JSON and assert equivalence. This task produces that golden file from the existing Swift tests.

- [ ] **Step 9.1: Create the golden-values emitter test**

Write this file at `Tests/ModelRigKitTests/KinematicFeaturesGoldenTests.swift`:

```swift
import XCTest
import Foundation
@testable import ModelRigKit

/// Emits a JSON file containing reference (input, output) pairs for the
/// KinematicFeatures contract. Consumed by the Python pipeline in Plan 3
/// (training_pipeline/tests/test_kinematic_features_parity.py) to verify
/// that the Python port is numerically equivalent.
///
/// Run this test manually when the Swift implementation changes:
///     swift test --filter KinematicFeaturesGoldenTests.test_emit_golden_json
///
/// Then copy the printed JSON into:
///     training_pipeline/tests/fixtures/kinematic_features_golden.json
final class KinematicFeaturesGoldenTests: XCTestCase {

    struct GoldenCase: Codable {
        let name: String
        let keypoints: [GoldenKeypoint]
        let previous: GoldenKeypoints?
        let fps: Double
        let output: KinematicFeatures
    }

    struct GoldenKeypoint: Codable {
        let x: Double
        let y: Double
        let confidence: Double

        init(_ kp: COCOKeypoint) {
            self.x = Double(kp.x)
            self.y = Double(kp.y)
            self.confidence = Double(kp.confidence)
        }
    }

    struct GoldenKeypoints: Codable {
        let keypoints: [GoldenKeypoint]
    }

    func test_emit_golden_json() throws {
        let tPose = KinematicFeaturesTests.tPoseKeypoints
        let shifted = tPose.map {
            COCOKeypoint(x: $0.x + 0.05, y: $0.y, confidence: $0.confidence)
        }
        let inverted = tPose.map {
            COCOKeypoint(x: $0.x, y: 1.0 - $0.y, confidence: $0.confidence)
        }

        let frame1 = KinematicFeatures.compute(keypoints: tPose, previous: nil, fps: 30.0)
        let frame2 = KinematicFeatures.compute(keypoints: shifted, previous: frame1, fps: 30.0)

        let cases: [GoldenCase] = [
            GoldenCase(
                name: "canonical_t_pose_frame_1",
                keypoints: tPose.map(GoldenKeypoint.init),
                previous: nil,
                fps: 30.0,
                output: frame1
            ),
            GoldenCase(
                name: "rightward_shift_frame_2",
                keypoints: shifted.map(GoldenKeypoint.init),
                previous: GoldenKeypoints(keypoints: tPose.map(GoldenKeypoint.init)),
                fps: 30.0,
                output: frame2
            ),
            GoldenCase(
                name: "inverted_t_pose",
                keypoints: inverted.map(GoldenKeypoint.init),
                previous: nil,
                fps: 30.0,
                output: KinematicFeatures.compute(keypoints: inverted, previous: nil, fps: 30.0)
            ),
        ]

        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(cases)
        let json = String(data: data, encoding: .utf8)!

        print("=== kinematic_features_golden.json BEGIN ===")
        print(json)
        print("=== kinematic_features_golden.json END ===")

        // Sanity check: make sure the JSON is decodable back
        let decoder = JSONDecoder()
        let roundTripped = try decoder.decode([GoldenCase].self, from: data)
        XCTAssertEqual(roundTripped.count, cases.count)
        XCTAssertEqual(roundTripped[0].output, cases[0].output)
    }
}
```

You'll need to make `KinematicFeaturesTests.tPoseKeypoints` accessible from this file. It's already `static` in the other file's class, so as long as it's not `private`, this reference works. If the build complains about access, change the declaration in `KinematicFeaturesTests.swift` from:

```swift
static let tPoseKeypoints: [COCOKeypoint] = [...]
```

to:

```swift
static let tPoseKeypoints: [COCOKeypoint] = [...]
```

(no change needed — `internal` is the default, and both test classes are in the same test module).

- [ ] **Step 9.2: Run the emitter test to produce the JSON**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test --filter KinematicFeaturesGoldenTests.test_emit_golden_json 2>&1
```

Expected: test passes and the JSON output appears between the `BEGIN/END` markers in the console. Copy the JSON block into a file for later use in Plan 3.

- [ ] **Step 9.3: Run the full ModelRigKit test suite one more time**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && swift test 2>&1 | tail -20
```

Expected: 25 KinematicFeatures tests passing (24 from earlier tasks + 1 golden emitter). All other ModelRigKit tests remain passing. No regressions.

- [ ] **Step 9.4: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add Tests/ModelRigKitTests/KinematicFeaturesGoldenTests.swift && git commit -m "test(kinematic): add golden-values JSON emitter for Python parity

Emits a JSON file containing three (input, output) reference pairs
(canonical T-pose, rightward shift sequence, inverted T-pose).
Plan 3's Python pipeline will load this JSON and verify that its
kinematic_features.py port produces bit-equivalent outputs for each
input case within 1e-4 tolerance.

Run manually via:
    swift test --filter KinematicFeaturesGoldenTests.test_emit_golden_json

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Task 10: Bump ModelRigKit version and document the new API

**Files:**
- Modify: `/Users/ianrichardson/Projects/ModelRigKit/README.md` (or create if missing)

**Rationale:** ModelRigKit is consumed by both CheerCOM and FlightFilter via Swift Package Manager. A brief note in the README lets both downstream consumers know the new `KinematicFeatures` module exists. No version tag or semver bump is required — local dependencies don't need it.

- [ ] **Step 10.1: Check if README.md exists**

Run:
```bash
ls /Users/ianrichardson/Projects/ModelRigKit/README.md 2>/dev/null && echo "exists" || echo "missing"
```

If it exists, read it first to understand the current structure. If it's missing, skip Step 10.2 and create a new one in Step 10.3.

- [ ] **Step 10.2: If README.md exists, add a KinematicFeatures section**

Append this section after the existing Biomechanics or COM documentation:

```markdown
## Kinematic Features

`ModelRigKit.KinematicFeatures` computes 11 per-frame derived features from
17 COCO keypoints — inversion, body angle, joint angles, CoM + velocity,
shoulder-hip twist, and ground contact. It is the shared feature contract
used by CheerCOM (authoring-time export), FlightFilter (inference-time
runtime), and the Python training pipeline (numerically verified port).

```swift
let features = KinematicFeatures.compute(
    keypoints: cocoKeypoints,            // [COCOKeypoint] with exactly 17 elements
    previous: previousFrameFeatures,     // nil for the first frame of a sequence
    fps: 30.0
)

print(features.inversion)            // Bool
print(features.bodyAngleDeg)         // Double, (-180°, 180°]
print(features.comXNorm)             // Double, [0, 1]
```

See `Tests/ModelRigKitTests/KinematicFeaturesGoldenTests.swift` for the reference
golden values used to verify Python-port numerical parity in the CheerCOM
tumbling skill classification training pipeline.
```

- [ ] **Step 10.3: If README.md is missing, create a minimal one**

Create `/Users/ianrichardson/Projects/ModelRigKit/README.md`:

```markdown
# ModelRigKit

Shared Swift package for humanoid rig math — Mixamo joint model, COCO
keypoint adaptation, center-of-mass anthropometry, and per-frame kinematic
features. Consumed by CheerCOM and FlightFilter.

## Modules

- `Core` — vector math, joint enums, angle conversions
- `Adapter` — `PoseAdapter` (COCO 17 → Mixamo joints), `COCOKeypoint`
- `Biomechanics` — `COMCalculator`, `SegmentData`, `BodyPreset`, `KinematicFeatures`
- `Poses` — joint limits, pose definitions, pose presets

## Kinematic Features

`ModelRigKit.KinematicFeatures` computes 11 per-frame derived features from
17 COCO keypoints — inversion, body angle, joint angles, CoM + velocity,
shoulder-hip twist, and ground contact. It is the shared feature contract
used by CheerCOM (authoring-time export), FlightFilter (inference-time
runtime), and the Python training pipeline (numerically verified port).

```swift
let features = KinematicFeatures.compute(
    keypoints: cocoKeypoints,            // [COCOKeypoint] with exactly 17 elements
    previous: previousFrameFeatures,     // nil for the first frame of a sequence
    fps: 30.0
)
```

See `Tests/ModelRigKitTests/KinematicFeaturesGoldenTests.swift` for the
reference golden values.

## Testing

```bash
swift test
```
```

- [ ] **Step 10.4: Commit**

Run:
```bash
cd /Users/ianrichardson/Projects/ModelRigKit && git add README.md && git commit -m "docs(readme): document KinematicFeatures module

Adds a brief README section describing KinematicFeatures — its role
as the shared feature contract between CheerCOM, FlightFilter, and
the Python training pipeline — and a short usage example.

Co-Authored-By: Claude Opus 4.6 (1M context) <noreply@anthropic.com>"
```

---

## Completion checklist

Before declaring Plan 1 complete, verify all of the following:

- [ ] `swift build` in `ModelRigKit` produces no errors and no warnings
- [ ] `swift test` in `ModelRigKit` passes all tests (existing + 25 new KinematicFeatures tests)
- [ ] `Sources/ModelRigKit/Biomechanics/KinematicFeatures.swift` exists and compiles
- [ ] `Tests/ModelRigKitTests/KinematicFeaturesTests.swift` exists with 24 tests covering all 11 fields
- [ ] `Tests/ModelRigKitTests/KinematicFeaturesGoldenTests.swift` exists and emits a valid JSON reference
- [ ] README.md contains a KinematicFeatures section
- [ ] Ten commits landed on the working branch, one per task
- [ ] No commit broke any pre-existing test in the ModelRigKit suite

Once these are all green, Plan 1 is done. The shared Swift module is ready for consumption by:
- **Plan 2** (CheerCOM Skill Animator) — imports `ModelRigKit` and calls `KinematicFeatures.compute` during JSON export
- **Plan 3** (Python training pipeline) — ports `KinematicFeatures` to Python and tests against `kinematic_features_golden.json`
- **Plan 4** (FlightFilter integration) — calls `KinematicFeatures.compute` inside `TCNFeatureBuilder` at inference time

## Next up

After Plan 1 is complete, come back to writing-plans to generate:
- **Plan 2** — `p2-cheercom-vocabulary-and-skill-animator.md`
- **Plan 3** — `p3-python-training-pipeline.md`
- **Plan 4** — `p4-flightfilter-skill-classification-integration.md`

Plans 2 and 3 can execute in parallel once Plan 1 lands.
