import XCTest
import SceneKit
@testable import CheerComCalculatorApp

final class COMCalculatorTests: XCTestCase {

    var calculator: COMCalculator!
    var mockNodes: [String: SCNNode]!
    var rootNode: SCNNode!

    override func setUp() {
        super.setUp()
        // Initialize calculator with standard mass
        calculator = COMCalculator(bodyMass: 100.0) // 100kg for easy calculation

        // Create mock node hierarchy
        mockNodes = [:]
        rootNode = SCNNode()

        // Helper to create nodes
        func createNode(name: String, position: SCNVector3) -> SCNNode {
            let node = SCNNode()
            node.name = name
            node.position = position
            // In this test setup, we treat all nodes as children of root for direct worldPosition control
            mockNodes[name] = node
            rootNode.addChildNode(node)
            return node
        }

        // Create all necessary joints
        // Initialize at Origin
        let joints = [
            "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
            "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
            "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
            "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase"
        ]

        for joint in joints {
            _ = createNode(name: joint, position: SCNVector3Zero)
        }

        // Bind the calculator
        calculator.bind(jointNodes: mockNodes)
    }

    override func tearDown() {
        calculator = nil
        mockNodes = nil
        rootNode = nil
        super.tearDown()
    }

    func testBindValidation() {
        let emptyCalc = COMCalculator(bodyMass: 70)
        emptyCalc.bind(jointNodes: [:])
        let result = emptyCalc.calculateDetailedBodyCOM()
        XCTAssertEqual(result.totalCOM.x, 0)
        XCTAssertTrue(result.segmentCOMs.isEmpty)
    }

    func testOriginCoM() {
        let result = calculator.calculateDetailedBodyCOM()
        XCTAssertEqual(result.totalCOM.x, 0, accuracy: 0.001)
        XCTAssertEqual(result.totalCOM.y, 0, accuracy: 0.001)
        XCTAssertEqual(result.totalCOM.z, 0, accuracy: 0.001)
    }

    func testSymmetryConstraint() {
        // Move Arms Out
        mockNodes["mixamorig_RightArm"]?.position = SCNVector3(10, 10, 0)
        mockNodes["mixamorig_RightForeArm"]?.position = SCNVector3(20, 10, 0)

        mockNodes["mixamorig_LeftArm"]?.position = SCNVector3(-10, 10, 0)
        mockNodes["mixamorig_LeftForeArm"]?.position = SCNVector3(-20, 10, 0)

        let result = calculator.calculateDetailedBodyCOM()
        XCTAssertEqual(result.totalCOM.x, 0, accuracy: 0.001, "CoM X should be 0 for symmetric pose")
    }

    func testTouchdownPose() {
        // Raise arms up (Y axis)
        let armJoints = [
            "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"
        ]

        for joint in armJoints {
            mockNodes[joint]?.position = SCNVector3(0, 10, 0)
        }

        let result = calculator.calculateDetailedBodyCOM()
        XCTAssertGreaterThan(result.totalCOM.y, 0.5, "CoM should rise when arms are raised")
    }

    func testSquatPose() {
        // Simulate Squat: Lower hips, bend knees
        // T-Pose (Conceptual): Hips at 100cm, Feet at 0cm.

        // 1. Move Hips and Upper Body down to 50cm
        let upperBody = [
            "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
            "mixamorig_Neck", "mixamorig_Head",
            "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"
        ]

        for joint in upperBody {
            mockNodes[joint]?.position = SCNVector3(0, 50, 0)
        }

        // 2. Legs: Thighs start at Hips (50), Knees forward at (0, 50, 30)? No, Knees halfway.
        // Hips (0, 50, 0). Feet (0, 0, 0).
        // Knees at (0, 25, 25) (Forward bend)

        mockNodes["mixamorig_RightUpLeg"]?.position = SCNVector3(10, 50, 0)
        mockNodes["mixamorig_RightLeg"]?.position = SCNVector3(10, 25, 25) // Knee
        mockNodes["mixamorig_RightFoot"]?.position = SCNVector3(10, 0, 0) // Foot

        mockNodes["mixamorig_LeftUpLeg"]?.position = SCNVector3(-10, 50, 0)
        mockNodes["mixamorig_LeftLeg"]?.position = SCNVector3(-10, 25, 25)
        mockNodes["mixamorig_LeftFoot"]?.position = SCNVector3(-10, 0, 0)

        // Baseline (Origin) CoM was 0.
        // But here we set positions relative to 0.
        // If we compare to a T-Pose where Hips are at 100...

        // Let's create a local T-Pose baseline for comparison in this test
        let tPoseCalc = COMCalculator(bodyMass: 100)
        var tPoseNodes: [String: SCNNode] = [:]
        // ... (Skipping full T-Pose setup for brevity, assuming we know Squat is lower than "Standing")

        // In "Standing", Hips would be at 100, Knees at 50, Feet at 0.
        // CoM would be roughly around Hips (100).
        // In this Squat, Hips are at 50. CoM should be around 50.

        let result = calculator.calculateDetailedBodyCOM()

        // Check reasonable bounds
        XCTAssertLessThan(result.totalCOM.y, 60.0, "CoM should be low in squat")
        XCTAssertGreaterThan(result.totalCOM.y, 20.0, "CoM should be above ground")
        XCTAssertGreaterThan(result.totalCOM.z, 5.0, "CoM should shift forward due to knees")
    }

    func testPikePose() {
        // Legs forward (horizontal)
        // Hips at 100.

        // Upper Body at 100+
        let upperBody = [
            "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2",
            "mixamorig_Neck", "mixamorig_Head"
        ]
        for joint in upperBody {
            mockNodes[joint]?.position = SCNVector3(0, 100, 0)
        }

        // Legs extended forward (+Z)
        // Right Leg
        mockNodes["mixamorig_RightUpLeg"]?.position = SCNVector3(10, 100, 0)
        mockNodes["mixamorig_RightLeg"]?.position = SCNVector3(10, 100, 40) // Knee
        mockNodes["mixamorig_RightFoot"]?.position = SCNVector3(10, 100, 80) // Foot

        // Left Leg
        mockNodes["mixamorig_LeftUpLeg"]?.position = SCNVector3(-10, 100, 0)
        mockNodes["mixamorig_LeftLeg"]?.position = SCNVector3(-10, 100, 40)
        mockNodes["mixamorig_LeftFoot"]?.position = SCNVector3(-10, 100, 80)

        let result = calculator.calculateDetailedBodyCOM()

        // CoM should be shifted significantly forward (+Z)
        XCTAssertGreaterThan(result.totalCOM.z, 20.0, "CoM should shift forward in Pike")
        // Height should be roughly same or slightly higher than hips due to legs being up?
        // Legs mass is ~30%. Upper body ~60%.
        // Upper body at 100. Legs at 100. CoM ~ 100.
        XCTAssertGreaterThan(result.totalCOM.y, 80.0, "CoM should be high")
    }

    func testMassConservation() {
        let result = calculator.calculateDetailedBodyCOM()
        var totalMass = 0.0
        for seg in result.segmentCOMs {
            totalMass += seg.mass
        }
        XCTAssertEqual(totalMass, 100.0, accuracy: 0.5, "Total mass should be conserved")
    }
}
