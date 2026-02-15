import XCTest
import SceneKit
@testable import CheerComCalculatorApp

final class COMCalculatorTests: XCTestCase {

    var calculator: COMCalculator!
    var mockJoints: [String: SCNNode]!

    override func setUp() {
        super.setUp()
        // Initialize calculator with standard mass
        calculator = COMCalculator(bodyMass: 52.2)

        // Setup mock skeleton
        mockJoints = setupMockSkeleton()

        // Bind calculator
        calculator.bind(jointNodes: mockJoints)
    }

    func setupMockSkeleton() -> [String: SCNNode] {
        // Create nodes for all required joints
        let jointNames = [
            "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
            "mixamorig_Neck", "mixamorig_Head",
            "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
            "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
            "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase"
        ]

        var joints: [String: SCNNode] = [:]
        for name in jointNames {
            let node = SCNNode()
            node.name = name
            joints[name] = node
        }

        // Build hierarchy (simplified for position calculation propagation)
        // Root
        let hips = joints["mixamorig_Hips"]!

        // Spine
        hips.addChildNode(joints["mixamorig_Spine"]!)
        joints["mixamorig_Spine"]!.addChildNode(joints["mixamorig_Spine1"]!)
        joints["mixamorig_Spine1"]!.addChildNode(joints["mixamorig_Spine2"]!)
        joints["mixamorig_Spine2"]!.addChildNode(joints["mixamorig_Neck"]!)
        joints["mixamorig_Neck"]!.addChildNode(joints["mixamorig_Head"]!)

        // Arms
        joints["mixamorig_Neck"]!.addChildNode(joints["mixamorig_RightShoulder"]!)
        joints["mixamorig_RightShoulder"]!.addChildNode(joints["mixamorig_RightArm"]!)
        joints["mixamorig_RightArm"]!.addChildNode(joints["mixamorig_RightForeArm"]!)
        joints["mixamorig_RightForeArm"]!.addChildNode(joints["mixamorig_RightHand"]!)

        joints["mixamorig_Neck"]!.addChildNode(joints["mixamorig_LeftShoulder"]!)
        joints["mixamorig_LeftShoulder"]!.addChildNode(joints["mixamorig_LeftArm"]!)
        joints["mixamorig_LeftArm"]!.addChildNode(joints["mixamorig_LeftForeArm"]!)
        joints["mixamorig_LeftForeArm"]!.addChildNode(joints["mixamorig_LeftHand"]!)

        // Legs
        hips.addChildNode(joints["mixamorig_RightUpLeg"]!)
        joints["mixamorig_RightUpLeg"]!.addChildNode(joints["mixamorig_RightLeg"]!)
        joints["mixamorig_RightLeg"]!.addChildNode(joints["mixamorig_RightFoot"]!)
        joints["mixamorig_RightFoot"]!.addChildNode(joints["mixamorig_RightToeBase"]!)

        hips.addChildNode(joints["mixamorig_LeftUpLeg"]!)
        joints["mixamorig_LeftUpLeg"]!.addChildNode(joints["mixamorig_LeftLeg"]!)
        joints["mixamorig_LeftLeg"]!.addChildNode(joints["mixamorig_LeftFoot"]!)
        joints["mixamorig_LeftFoot"]!.addChildNode(joints["mixamorig_LeftToeBase"]!)

        // Set default T-Pose positions (Approximate for testing)
        // Assuming unit length segments for simplicity where not specified
        // Hips at 0, 10, 0
        hips.position = SCNVector3(0, 10, 0)

        // Spine up (+Y)
        setRelativePos(joints, "mixamorig_Spine", SCNVector3(0, 1, 0))
        setRelativePos(joints, "mixamorig_Spine1", SCNVector3(0, 1, 0))
        setRelativePos(joints, "mixamorig_Spine2", SCNVector3(0, 1, 0))
        setRelativePos(joints, "mixamorig_Neck", SCNVector3(0, 1, 0))
        setRelativePos(joints, "mixamorig_Head", SCNVector3(0, 1, 0))

        // Shoulders side (+/- X)
        setRelativePos(joints, "mixamorig_RightShoulder", SCNVector3(1, 0, 0))
        setRelativePos(joints, "mixamorig_RightArm", SCNVector3(1, 0, 0))
        setRelativePos(joints, "mixamorig_RightForeArm", SCNVector3(1, 0, 0))
        setRelativePos(joints, "mixamorig_RightHand", SCNVector3(0, 0, 0)) // Hand is 0 length in this setup?

        setRelativePos(joints, "mixamorig_LeftShoulder", SCNVector3(-1, 0, 0))
        setRelativePos(joints, "mixamorig_LeftArm", SCNVector3(-1, 0, 0))
        setRelativePos(joints, "mixamorig_LeftForeArm", SCNVector3(-1, 0, 0))
        setRelativePos(joints, "mixamorig_LeftHand", SCNVector3(0, 0, 0))

        // Legs down (-Y)
        setRelativePos(joints, "mixamorig_RightUpLeg", SCNVector3(0.5, -1, 0)) // Offset from hips
        setRelativePos(joints, "mixamorig_RightLeg", SCNVector3(0, -4, 0))
        setRelativePos(joints, "mixamorig_RightFoot", SCNVector3(0, -4, 0))
        setRelativePos(joints, "mixamorig_RightToeBase", SCNVector3(0, -1, 0.5))

        setRelativePos(joints, "mixamorig_LeftUpLeg", SCNVector3(-0.5, -1, 0))
        setRelativePos(joints, "mixamorig_LeftLeg", SCNVector3(0, -4, 0))
        setRelativePos(joints, "mixamorig_LeftFoot", SCNVector3(0, -4, 0))
        setRelativePos(joints, "mixamorig_LeftToeBase", SCNVector3(0, -1, 0.5))

        // Force update of transforms
        updateTransforms(root: hips)

        return joints
    }

    func setRelativePos(_ joints: [String: SCNNode], _ name: String, _ pos: SCNVector3) {
        joints[name]?.position = pos
    }

    func updateTransforms(root: SCNNode) {
        // Manually update world transforms if needed (SceneKit usually does this on render loop)
        // For unit tests, we might need to rely on position accumulation
        // But SCNNode.worldPosition should work if the hierarchy is built.
        // However, without a scene and physics world, it might be lazy.
        // Let's force a traverse.

        // Note: SCNNode.worldPosition is computed on the fly based on parent.
        // We just need to make sure positions are set.
    }

    // MARK: - Tests

    func testTPoseCoM() {
        // Given T-Pose (Default)

        // When
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        // Then
        // Symmetry check
        XCTAssertEqual(com.x, 0, accuracy: 0.1, "T-Pose CoM X should be symmetric (approx 0)")
        XCTAssertEqual(com.z, 0, accuracy: 1.0, "T-Pose CoM Z should be approx 0")

        // Height check (Should be around Hips Y or slightly higher/lower depending on mass dist)
        // Hips are at Y=10. Legs go down. Torso goes up.
        // Torso mass ~50%, Legs ~35%. Torso COM is higher than Hips. Legs COM is lower.
        XCTAssertGreaterThan(com.y, 8.0, "T-Pose CoM Y should be relatively high")

        print("T-Pose CoM: \(com)")
    }

    func testTouchdownCoM() {
        // Given Touchdown (Arms Up)
        // Rotate Arms 180 deg around Z or set positions
        // Simplified: Move arm segments UP (+Y) instead of Side (+X)

        // Reset arms to local 0
        setRelativePos(mockJoints, "mixamorig_RightArm", SCNVector3(0, 1, 0))
        setRelativePos(mockJoints, "mixamorig_RightForeArm", SCNVector3(0, 1, 0))

        setRelativePos(mockJoints, "mixamorig_LeftArm", SCNVector3(0, 1, 0))
        setRelativePos(mockJoints, "mixamorig_LeftForeArm", SCNVector3(0, 1, 0))

        // When
        let tPoseResult = calculator.calculateBodyCOM() // Baseline

        // Apply changes
        // (In a real test we would measure T-Pose first, then change)

        // Calculate new
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        print("Touchdown CoM: \(com)")

        // Then
        // Y should be higher than a baseline (we can compare to known T-Pose value or assume > 10)
        XCTAssertGreaterThan(com.y, 10.0, "Touchdown CoM should be higher due to arms up")
    }

    func testSquatCoM() {
        // Given Squat
        // Lower hips, bend knees
        let hips = mockJoints["mixamorig_Hips"]!
        hips.position.y = 5.0 // Drop hips

        // When
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        print("Squat CoM: \(com)")

        // Then
        XCTAssertLessThan(com.y, 8.0, "Squat CoM should be lower than standing")
    }

    func testPikeCoM() {
        // Given Pike (Legs Forward)
        // Rotate legs 90 deg around X (Forward is +Z in our assumption?)
        // Let's set leg positions to be forward (+Z) relative to hips

        setRelativePos(mockJoints, "mixamorig_RightUpLeg", SCNVector3(0.5, 0, 1))
        setRelativePos(mockJoints, "mixamorig_RightLeg", SCNVector3(0, 0, 1))
        setRelativePos(mockJoints, "mixamorig_RightFoot", SCNVector3(0, 0, 1))

        setRelativePos(mockJoints, "mixamorig_LeftUpLeg", SCNVector3(-0.5, 0, 1))
        setRelativePos(mockJoints, "mixamorig_LeftLeg", SCNVector3(0, 0, 1))
        setRelativePos(mockJoints, "mixamorig_LeftFoot", SCNVector3(0, 0, 1))

        // When
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        print("Pike CoM: \(com)")

        // Then
        XCTAssertGreaterThan(com.z, 0.5, "Pike CoM Z should shift forward")
    }
}
