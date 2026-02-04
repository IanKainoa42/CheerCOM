import XCTest
import SceneKit
@testable import CheerComCalculatorApp

final class COMCalculatorTests: XCTestCase {

    var calculator: COMCalculator!
    var mockNodes: [String: SCNNode]!
    var rootNode: SCNNode!

    override func setUp() {
        super.setUp()
        calculator = COMCalculator(bodyMass: 70.0) // 70kg standard
        let (nodes, root) = createMockHierarchy()
        mockNodes = nodes
        rootNode = root
    }

    // Builds a simplified T-Pose hierarchy
    func createMockHierarchy() -> ([String: SCNNode], SCNNode) {
        var nodes: [String: SCNNode] = [:]

        func createNode(_ name: String, offset: SCNVector3, parent: SCNNode?) -> SCNNode {
            let node = SCNNode()
            node.name = name
            node.position = offset
            if let p = parent {
                p.addChildNode(node)
            }
            nodes[name] = node
            return node
        }

        // Root
        let hips = createNode("mixamorig_Hips", offset: SCNVector3(0, 100, 0), parent: nil) // Hips at 1m height

        // Spine Chain (Up)
        let spine = createNode("mixamorig_Spine", offset: SCNVector3(0, 10, 0), parent: hips)
        let spine1 = createNode("mixamorig_Spine1", offset: SCNVector3(0, 10, 0), parent: spine)
        let spine2 = createNode("mixamorig_Spine2", offset: SCNVector3(0, 10, 0), parent: spine1)
        let neck = createNode("mixamorig_Neck", offset: SCNVector3(0, 10, 0), parent: spine2)
        let head = createNode("mixamorig_Head", offset: SCNVector3(0, 10, 0), parent: neck)

        // Right Arm Chain (Out X)
        let rShoulder = createNode("mixamorig_RightShoulder", offset: SCNVector3(10, 10, 0), parent: spine2)
        let rArm = createNode("mixamorig_RightArm", offset: SCNVector3(10, 0, 0), parent: rShoulder)
        let rForeArm = createNode("mixamorig_RightForeArm", offset: SCNVector3(30, 0, 0), parent: rArm)
        let rHand = createNode("mixamorig_RightHand", offset: SCNVector3(25, 0, 0), parent: rForeArm)

        // Left Arm Chain (Out -X)
        let lShoulder = createNode("mixamorig_LeftShoulder", offset: SCNVector3(-10, 10, 0), parent: spine2)
        let lArm = createNode("mixamorig_LeftArm", offset: SCNVector3(-10, 0, 0), parent: lShoulder)
        let lForeArm = createNode("mixamorig_LeftForeArm", offset: SCNVector3(-30, 0, 0), parent: lArm)
        let lHand = createNode("mixamorig_LeftHand", offset: SCNVector3(-25, 0, 0), parent: lForeArm)

        // Right Leg Chain (Down)
        let rUpLeg = createNode("mixamorig_RightUpLeg", offset: SCNVector3(10, -5, 0), parent: hips)
        let rLeg = createNode("mixamorig_RightLeg", offset: SCNVector3(0, -40, 0), parent: rUpLeg)
        let rFoot = createNode("mixamorig_RightFoot", offset: SCNVector3(0, -40, 0), parent: rLeg)
        let rToe = createNode("mixamorig_RightToeBase", offset: SCNVector3(0, -5, 15), parent: rFoot)

        // Left Leg Chain (Down)
        let lUpLeg = createNode("mixamorig_LeftUpLeg", offset: SCNVector3(-10, -5, 0), parent: hips)
        let lLeg = createNode("mixamorig_LeftLeg", offset: SCNVector3(0, -40, 0), parent: lUpLeg)
        let lFoot = createNode("mixamorig_LeftFoot", offset: SCNVector3(0, -40, 0), parent: lLeg)
        let lToe = createNode("mixamorig_LeftToeBase", offset: SCNVector3(0, -5, 15), parent: lFoot)

        return (nodes, hips)
    }

    // Helper to degrees to radians
    func deg(_ d: Float) -> Float { return d * .pi / 180 }

    func testMassSum() {
        var totalMassRatio = 0.0
        for segment in calculator.segments {
            totalMassRatio += segment.mass
        }
        XCTAssertEqual(totalMassRatio, 1.0, accuracy: 0.001, "Total mass ratio should sum to approx 1.0")
    }

    func testBindSegments() {
        calculator.bind(jointNodes: mockNodes)
        // With corrected mapping: 17 segments should bind
        let result = calculator.calculateDetailedBodyCOM()
        XCTAssertEqual(result.segmentCOMs.count, 17, "Should have 17 bound segments")
    }

    func testTPose() {
        calculator.bind(jointNodes: mockNodes)
        // Reset rotations
        for node in mockNodes.values { node.eulerAngles = SCNVector3Zero }

        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        // T-Pose should be symmetric X ~ 0
        XCTAssertEqual(com.x, 0, accuracy: 1.0)
        // CoM should be above hips (Hips are at 100)
        XCTAssertGreaterThan(com.y, 100.0)
    }

    func testTouchdown() {
        calculator.bind(jointNodes: mockNodes)
        // Reset
        for node in mockNodes.values { node.eulerAngles = SCNVector3Zero }

        let tPoseY = calculator.calculateBodyCOM().y

        // Raise Arms: Rotate Shoulders or Arms around Z
        // Right Arm (Along +X). Rotate +90 Z to point Up (+Y)
        // Left Arm (Along -X). Rotate -90 Z to point Up (+Y)
        mockNodes["mixamorig_RightArm"]?.eulerAngles.z = deg(90)
        mockNodes["mixamorig_LeftArm"]?.eulerAngles.z = deg(-90)

        let touchdownY = calculator.calculateBodyCOM().y

        XCTAssertGreaterThan(touchdownY, tPoseY + 2.0, "CoM should rise significantly in Touchdown")
    }

    func testSquat() {
        calculator.bind(jointNodes: mockNodes)
        // Reset
        for node in mockNodes.values { node.eulerAngles = SCNVector3Zero }

        let tPoseY = calculator.calculateBodyCOM().y

        // Squat: Rotate Thighs up (Flexion, -X?), Rotate Knees back (Flexion +X?)
        // Assuming X is pitch.
        // Hips -> UpLeg (0, -40, 0).
        // Rotate UpLeg -90 on X -> Leg points Forward (+Z)
        // Rotate Leg +90 on X -> Foot points Down (-Y)

        mockNodes["mixamorig_RightUpLeg"]?.eulerAngles.x = deg(-90)
        mockNodes["mixamorig_LeftUpLeg"]?.eulerAngles.x = deg(-90)

        mockNodes["mixamorig_RightLeg"]?.eulerAngles.x = deg(90)
        mockNodes["mixamorig_LeftLeg"]?.eulerAngles.x = deg(90)

        // Also usually spine bends forward, but let's stick to legs

        let squatY = calculator.calculateBodyCOM().y

        XCTAssertLessThan(squatY, tPoseY - 10.0, "CoM should lower significantly in Squat")
    }

    func testPike() {
        calculator.bind(jointNodes: mockNodes)
        // Reset
        for node in mockNodes.values { node.eulerAngles = SCNVector3Zero }

        let tPoseZ = calculator.calculateBodyCOM().z

        // Pike: Legs straight forward (+Z)
        // Rotate UpLegs -90 on X

        mockNodes["mixamorig_RightUpLeg"]?.eulerAngles.x = deg(-90)
        mockNodes["mixamorig_LeftUpLeg"]?.eulerAngles.x = deg(-90)

        // Arms overhead? Usually.
        mockNodes["mixamorig_RightArm"]?.eulerAngles.z = deg(90)
        mockNodes["mixamorig_LeftArm"]?.eulerAngles.z = deg(-90)

        let pikeZ = calculator.calculateBodyCOM().z

        // Legs are heavy (approx 30-40% mass with feet). Moving them forward should shift CoM forward (+Z)
        XCTAssertGreaterThan(pikeZ, tPoseZ + 5.0, "CoM should shift forward in Pike")
    }
}
