import XCTest
import SceneKit
@testable import CheerComCalculatorApp

final class COMCalculatorTests: XCTestCase {

    var calculator: COMCalculator!
    var rootNode: SCNNode!
    var jointNodes: [String: SCNNode] = [:]

    override func setUp() {
        super.setUp()
        // Initialize calculator with standard mass (e.g., 70kg)
        calculator = COMCalculator(bodyMass: 70.0)
        setupMockSkeleton()
        calculator.bind(jointNodes: jointNodes)
    }

    override func tearDown() {
        calculator = nil
        rootNode = nil
        jointNodes = [:]
        super.tearDown()
    }

    func setupMockSkeleton() {
        rootNode = SCNNode()

        // List of joints used by COMCalculator
        let joints = [
            "mixamorig_Hips",
            "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
            "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
            "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
            "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase"
        ]

        // Create a flat hierarchy where all nodes are children of root
        // This allows us to set .position which acts as worldPosition (since root is at 0,0,0)
        for name in joints {
            let node = SCNNode()
            node.name = name
            rootNode.addChildNode(node)
            jointNodes[name] = node
        }
    }

    /// Helper to set positions for multiple joints
    func setPose(positions: [String: SCNVector3]) {
        for (name, pos) in positions {
            if let node = jointNodes[name] {
                node.position = pos
            }
        }
    }

    func testInitialization() {
        XCTAssertNotNil(calculator)
        XCTAssertEqual(calculator.bodyMass, 70.0)
    }

    func testTPoseCOM() {
        // Define a symmetric T-Pose
        var positions: [String: SCNVector3] = [:]

        // Trunk (Vertical)
        positions["mixamorig_Hips"] = SCNVector3(0, 1.0, 0)
        positions["mixamorig_Spine"] = SCNVector3(0, 1.1, 0)
        positions["mixamorig_Spine1"] = SCNVector3(0, 1.2, 0)
        positions["mixamorig_Spine2"] = SCNVector3(0, 1.3, 0)
        positions["mixamorig_Neck"] = SCNVector3(0, 1.4, 0)
        positions["mixamorig_Head"] = SCNVector3(0, 1.5, 0)

        // Legs (Vertical below hips)
        // Left
        positions["mixamorig_LeftUpLeg"] = SCNVector3(0.1, 1.0, 0)
        positions["mixamorig_LeftLeg"] = SCNVector3(0.1, 0.5, 0)
        positions["mixamorig_LeftFoot"] = SCNVector3(0.1, 0.1, 0)
        positions["mixamorig_LeftToeBase"] = SCNVector3(0.1, 0.0, 0.1)
        // Right
        positions["mixamorig_RightUpLeg"] = SCNVector3(-0.1, 1.0, 0)
        positions["mixamorig_RightLeg"] = SCNVector3(-0.1, 0.5, 0)
        positions["mixamorig_RightFoot"] = SCNVector3(-0.1, 0.1, 0)
        positions["mixamorig_RightToeBase"] = SCNVector3(-0.1, 0.0, 0.1)

        // Arms (Horizontal T)
        // Left (Positive X)
        positions["mixamorig_LeftShoulder"] = SCNVector3(0.1, 1.35, 0)
        positions["mixamorig_LeftArm"] = SCNVector3(0.2, 1.35, 0)
        positions["mixamorig_LeftForeArm"] = SCNVector3(0.4, 1.35, 0)
        positions["mixamorig_LeftHand"] = SCNVector3(0.6, 1.35, 0)
        // Right (Negative X)
        positions["mixamorig_RightShoulder"] = SCNVector3(-0.1, 1.35, 0)
        positions["mixamorig_RightArm"] = SCNVector3(-0.2, 1.35, 0)
        positions["mixamorig_RightForeArm"] = SCNVector3(-0.4, 1.35, 0)
        positions["mixamorig_RightHand"] = SCNVector3(-0.6, 1.35, 0)

        setPose(positions: positions)

        // Calculate COM
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        // Verification
        // 1. Symmetry: X should be 0
        XCTAssertEqual(com.x, 0, accuracy: 0.01, "CoM X should be 0 for symmetric T-Pose")

        // 2. Plane: Z should be close to 0 (slight offset due to toes but mostly planar)
        XCTAssertEqual(com.z, 0, accuracy: 0.05, "CoM Z should be near 0")

        // 3. Height: Should be between hips (1.0) and shoulders (1.35)
        XCTAssertGreaterThan(com.y, 1.0, "CoM should be above hips")
        XCTAssertLessThan(com.y, 1.35, "CoM should be below shoulders")

        print("Test T-Pose CoM: \(com)")
    }

    func testArmsUpRise() {
        // Establish baseline T-Pose
        testTPoseCOM()
        let tPoseCOM = calculator.calculateBodyCOM()

        // Move Arms Up (Vertical)
        // Update ForeArm and Hand positions to be above Arm
        // Left
        jointNodes["mixamorig_LeftForeArm"]?.position = SCNVector3(0.2, 1.55, 0) // Above elbow
        jointNodes["mixamorig_LeftHand"]?.position = SCNVector3(0.2, 1.75, 0) // Above forearm
        // Right
        jointNodes["mixamorig_RightForeArm"]?.position = SCNVector3(-0.2, 1.55, 0)
        jointNodes["mixamorig_RightHand"]?.position = SCNVector3(-0.2, 1.75, 0)

        let armsUpCOM = calculator.calculateBodyCOM()

        print("Test ArmsUp CoM: \(armsUpCOM)")

        // Verify CoM rose
        XCTAssertGreaterThan(armsUpCOM.y, tPoseCOM.y + 0.05, "CoM should rise significantly when arms are raised")

        // Verify Symmetry maintained
        XCTAssertEqual(armsUpCOM.x, 0, accuracy: 0.01)
    }

    func testDetailedOutput() {
        testTPoseCOM()
        let result = calculator.calculateDetailedBodyCOM()

        XCTAssertFalse(result.segmentCOMs.isEmpty)
        XCTAssertEqual(result.segmentCOMs.count, 17) // 17 segments in model

        // Verify total mass calculation implicitly (should match sum of segments if logic holds)
        var sumMass: Double = 0
        for seg in result.segmentCOMs {
            sumMass += seg.mass
        }
        XCTAssertEqual(sumMass, calculator.bodyMass, accuracy: 0.1)
    }
}
