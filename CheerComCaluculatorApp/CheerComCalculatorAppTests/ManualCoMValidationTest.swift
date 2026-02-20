import XCTest
import SceneKit
@testable import CheerComCalculatorApp

/// A manual validation test that runs without the full app environment.
/// It builds a mock skeleton, applies poses, and asserts CoM shifts match expectations.
final class ManualCoMValidationTest: XCTestCase {

    var calculator: COMCalculator!
    var rootNode: SCNNode!
    var nodes: [String: SCNNode]!

    // Baseline for relative checks
    var tPoseCOM: SCNVector3?

    override func setUp() {
        super.setUp()
        calculator = COMCalculator(bodyMass: 50.0) // 50kg
        (rootNode, nodes) = createConnectedSkeleton()
        calculator.bind(jointNodes: nodes)
    }

    func testDetailedValidation() {
        print("\n==========================================")
        print("🧪 MANUAL CoM VALIDATION AUDIT")
        print("==========================================\n")

        // 1. T-Pose Baseline
        validatePose(name: "T-Pose", setupClosure: applyTPose) { com in
            XCTAssertLessThan(abs(com.x), 0.1, "T-Pose CoM should be centered on X")
            self.tPoseCOM = com
        }

        guard let baseline = tPoseCOM else {
            XCTFail("T-Pose validation failed, cannot continue")
            return
        }

        // 2. Touchdown (Arms Up)
        validatePose(name: "Touchdown", setupClosure: applyTouchdown) { com in
            let diff = com.y - baseline.y
            print("   Delta Y: \(diff)")
            XCTAssertGreaterThan(diff, 2.0, "Touchdown CoM should be significantly higher than T-Pose")
        }

        // 3. Squat (Hips Down)
        validatePose(name: "Squat", setupClosure: applySquat) { com in
            let diff = baseline.y - com.y
            print("   Delta Y: \(diff)")
            XCTAssertGreaterThan(diff, 5.0, "Squat CoM should be lower than T-Pose")
        }

        // 4. Pike (Legs Forward)
        validatePose(name: "Pike", setupClosure: applyPike) { com in
            // Legs move forward (+Z or -Z depending on rig, assuming +Z is forward here?)
            // In our rig construction, legs are at (0, -40, 0).
            // Applying Pike (-90 deg X rot on UpLegs) brings legs up.
            // If +Z comes out of screen (SceneKit default), rotating -X moves +Y to +Z?
            // Right Hand Rule: Thumb +X. Fingers curl Y -> Z.
            // -X rotation: Y -> -Z.
            // So legs move to -Z (backward?).
            // Let's just check absolute Z shift.
            let diff = abs(com.z - baseline.z)
            print("   Delta Z: \(diff)")
            XCTAssertGreaterThan(diff, 2.0, "Pike CoM should shift significantly in Z")
        }

        print("\n==========================================")
        print("✅ AUDIT COMPLETE")
        print("==========================================\n")
    }

    // MARK: - Helper Methods

    private func validatePose(name: String, setupClosure: () -> Void, assertion: ((SCNVector3) -> Void)? = nil) {
        print("\n## Validating Pose: \(name)")

        // Reset
        applyTPose()

        // Apply Pose
        setupClosure()

        // Force update transforms
        // Walking the graph ensures worldTransforms are recalculated
        rootNode.enumerateChildNodes { (node, _) in
            _ = node.worldPosition
        }

        // Calculate
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        print("- **Total CoM**: \(formatVector(com))")

        logDetailedSegments(result: result)

        if let assertion = assertion {
            assertion(com)
            print("   ✅ Assertion Passed")
        }
    }

    private func logDetailedSegments(result: CalculationResult) {
        // print("\n### Segment Details") // Reduced noise

        func pad(_ s: String, _ len: Int) -> String {
            return s.padding(toLength: len, withPad: " ", startingAt: 0)
        }

        // print("| " + pad("Segment Name", 20) + " | " + pad("Mass (kg)", 10) + " | " + pad("CoM Position", 25) + " |")
        // print("|" + String(repeating: "-", count: 22) + "|" + String(repeating: "-", count: 12) + "|" + String(repeating: "-", count: 27) + "|")

        /*
        for segment in result.segmentCOMs {
            let massString = String(format: "%.3f", segment.mass)
            let posString = formatVector(segment.position)
            print("| " + pad(segment.name, 20) + " | " + pad(massString, 10) + " | " + pad(posString, 25) + " |")
        }
        */
    }

    private func formatVector(_ v: SCNVector3) -> String {
        return String(format: "(%.2f, %.2f, %.2f)", v.x, v.y, v.z)
    }

    // MARK: - Skeleton Construction & Poses

    /// Creates a hierarchical skeleton with approximate Mixamo proportions
    func createConnectedSkeleton() -> (SCNNode, [String: SCNNode]) {
        let root = SCNNode()
        root.name = "Root"
        var nodes = [String: SCNNode]()

        func createBone(_ name: String, parent: SCNNode, position: SCNVector3) -> SCNNode {
            let node = SCNNode()
            node.name = name
            node.position = position // Local position relative to parent
            parent.addChildNode(node)
            nodes[name] = node
            return node
        }

        // Hips (Root of body) - 1m off ground (100 units)
        let hips = createBone("mixamorig_Hips", parent: root, position: SCNVector3(0, 100, 0))

        // Spine Chain (Up)
        let spine = createBone("mixamorig_Spine", parent: hips, position: SCNVector3(0, 10, 0))
        let spine1 = createBone("mixamorig_Spine1", parent: spine, position: SCNVector3(0, 10, 0))
        let spine2 = createBone("mixamorig_Spine2", parent: spine1, position: SCNVector3(0, 10, 0))
        let neck = createBone("mixamorig_Neck", parent: spine2, position: SCNVector3(0, 10, 0))
        let head = createBone("mixamorig_Head", parent: neck, position: SCNVector3(0, 10, 0))
        let headTop = createBone("mixamorig_HeadTop_End", parent: head, position: SCNVector3(0, 15, 0)) // Unused but structural

        // Arms (Symmetric)
        // Right
        // Clavicle (Shoulder)
        let rShoulder = createBone("mixamorig_RightShoulder", parent: spine2, position: SCNVector3(5, 5, 0))
        // Humerus (RightArm)
        let rArm = createBone("mixamorig_RightArm", parent: rShoulder, position: SCNVector3(10, 0, 0)) // Out to right
        // Forearm
        let rForeArm = createBone("mixamorig_RightForeArm", parent: rArm, position: SCNVector3(25, 0, 0))
        // Hand
        let rHand = createBone("mixamorig_RightHand", parent: rForeArm, position: SCNVector3(25, 0, 0))
        // Fingers
        let rHandTip = createBone("mixamorig_RightHandMiddle1", parent: rHand, position: SCNVector3(10, 0, 0))

        // Left
        let lShoulder = createBone("mixamorig_LeftShoulder", parent: spine2, position: SCNVector3(-5, 5, 0))
        let lArm = createBone("mixamorig_LeftArm", parent: lShoulder, position: SCNVector3(-10, 0, 0)) // Out to left
        let lForeArm = createBone("mixamorig_LeftForeArm", parent: lArm, position: SCNVector3(-25, 0, 0))
        let lHand = createBone("mixamorig_LeftHand", parent: lForeArm, position: SCNVector3(-25, 0, 0))
        let lHandTip = createBone("mixamorig_LeftHandMiddle1", parent: lHand, position: SCNVector3(-10, 0, 0))

        // Legs
        // Right
        let rUpLeg = createBone("mixamorig_RightUpLeg", parent: hips, position: SCNVector3(10, -5, 0))
        let rLeg = createBone("mixamorig_RightLeg", parent: rUpLeg, position: SCNVector3(0, -40, 0))
        let rFoot = createBone("mixamorig_RightFoot", parent: rLeg, position: SCNVector3(0, -40, 0))
        let rToe = createBone("mixamorig_RightToeBase", parent: rFoot, position: SCNVector3(0, -5, 10))

        // Left
        let lUpLeg = createBone("mixamorig_LeftUpLeg", parent: hips, position: SCNVector3(-10, -5, 0))
        let lLeg = createBone("mixamorig_LeftLeg", parent: lUpLeg, position: SCNVector3(0, -40, 0))
        let lFoot = createBone("mixamorig_LeftFoot", parent: lLeg, position: SCNVector3(0, -40, 0))
        let lToe = createBone("mixamorig_LeftToeBase", parent: lFoot, position: SCNVector3(0, -5, 10))

        return (root, nodes)
    }

    // Poses
    // We manually set Euler Angles to simulate poses.
    // Note: In SceneKit, eulerAngles are in radians.

    func deg(_ d: Float) -> Float { return d * .pi / 180 }

    func applyTPose() {
        // Reset all rotations
        for (_, node) in nodes {
            node.eulerAngles = SCNVector3Zero
        }
    }

    func applyTouchdown() {
        // Arms straight up.
        // Arms are built along X axis.
        // Right Hand Rule: Thumb +Z (Out). Fingers X -> Y.
        // +90 around Z moves +X to +Y.
        nodes["mixamorig_RightArm"]?.eulerAngles.z = deg(90)

        // Left Arm is along -X.
        // Rotation around Z (+90) moves +X to +Y.
        // So -X moves to -Y?
        // We want -X to move to +Y. That is -90 rotation.
        nodes["mixamorig_LeftArm"]?.eulerAngles.z = deg(-90)
    }

    func applySquat() {
        // Lower hips
        nodes["mixamorig_Hips"]?.position.y = 60 // Drop from 100

        // Flex hips and knees to look realistic?
        // Thighs forward (-X rot?)
        // If +X is right, Y is up, Z is Out.
        // Rotation around X. +X moves Y to Z.
        // Thigh is -Y.
        // +X rot moves -Y to -Z (back).
        // -X rot moves -Y to +Z (forward).
        // So Thighs -90.
        nodes["mixamorig_RightUpLeg"]?.eulerAngles.x = deg(-90)
        nodes["mixamorig_LeftUpLeg"]?.eulerAngles.x = deg(-90)

        // Knees back (+X rot)
        nodes["mixamorig_RightLeg"]?.eulerAngles.x = deg(90)
        nodes["mixamorig_LeftLeg"]?.eulerAngles.x = deg(90)
    }

    func applyPike() {
        // Legs forward (Hips flex 90)
        nodes["mixamorig_RightUpLeg"]?.eulerAngles.x = deg(-90)
        nodes["mixamorig_LeftUpLeg"]?.eulerAngles.x = deg(-90)

        // Knees straight (0)
        nodes["mixamorig_RightLeg"]?.eulerAngles.x = 0
        nodes["mixamorig_LeftLeg"]?.eulerAngles.x = 0
    }
}
