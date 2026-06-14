import XCTest
import SceneKit
@testable import CheerComCalculatorApp

final class COMCalculatorTests: XCTestCase {

    var calculator: COMCalculator!
    var nodes: [String: SCNNode]!

    override func setUp() {
        super.setUp()
        calculator = COMCalculator(bodyMass: 50.0) // 50kg for easy math
        nodes = createMockSkeleton()
        calculator.bind(jointNodes: nodes)
    }

    func createMockSkeleton() -> [String: SCNNode] {
        // Create nodes for all joints required by COMCalculator
        let jointNames = [
            "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
            "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
            "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
            "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase"
        ]

        var nodes = [String: SCNNode]()
        for name in jointNames {
            let node = SCNNode()
            node.name = name
            nodes[name] = node
        }

        return nodes
    }

    func setupTPose() {
        // Arrange: Set positions for T-Pose
        // Hips at 0,100,0 (1m up)
        nodes["mixamorig_Hips"]?.position = SCNVector3(0, 100, 0)

        // Spine going up
        nodes["mixamorig_Spine"]?.position = SCNVector3(0, 110, 0)
        nodes["mixamorig_Spine1"]?.position = SCNVector3(0, 120, 0)
        nodes["mixamorig_Spine2"]?.position = SCNVector3(0, 130, 0)
        nodes["mixamorig_Neck"]?.position = SCNVector3(0, 140, 0)
        nodes["mixamorig_Head"]?.position = SCNVector3(0, 150, 0)

        // Arms (Symmetric)
        nodes["mixamorig_RightShoulder"]?.position = SCNVector3(10, 135, 0)
        nodes["mixamorig_RightArm"]?.position = SCNVector3(20, 135, 0)
        nodes["mixamorig_RightForeArm"]?.position = SCNVector3(40, 135, 0)
        nodes["mixamorig_RightHand"]?.position = SCNVector3(60, 135, 0)

        nodes["mixamorig_LeftShoulder"]?.position = SCNVector3(-10, 135, 0)
        nodes["mixamorig_LeftArm"]?.position = SCNVector3(-20, 135, 0)
        nodes["mixamorig_LeftForeArm"]?.position = SCNVector3(-40, 135, 0)
        nodes["mixamorig_LeftHand"]?.position = SCNVector3(-60, 135, 0)

        // Legs
        nodes["mixamorig_RightUpLeg"]?.position = SCNVector3(10, 100, 0)
        nodes["mixamorig_RightLeg"]?.position = SCNVector3(10, 50, 0)
        nodes["mixamorig_RightFoot"]?.position = SCNVector3(10, 10, 0)
        nodes["mixamorig_RightToeBase"]?.position = SCNVector3(10, 0, 5) // Feet forward

        nodes["mixamorig_LeftUpLeg"]?.position = SCNVector3(-10, 100, 0)
        nodes["mixamorig_LeftLeg"]?.position = SCNVector3(-10, 50, 0)
        nodes["mixamorig_LeftFoot"]?.position = SCNVector3(-10, 10, 0)
        nodes["mixamorig_LeftToeBase"]?.position = SCNVector3(-10, 0, 5)
    }

    func testTPose_CoM() {
        setupTPose()

        // Act
        let result = calculator.calculateDetailedBodyCOM()
        let com = result.totalCOM

        // Assert
        XCTAssertEqual(com.x, 0, accuracy: 2.0, "CoM X should be symmetric (near 0)")
        XCTAssertGreaterThan(com.y, 80, "CoM Y should be relatively high (body is upright)")
        XCTAssertLessThan(com.y, 120, "CoM Y should be below shoulders")
        XCTAssertEqual(com.z, 0, accuracy: 5.0, "CoM Z should be near 0 for planar T-Pose")
    }

    func testSquat_CoM_Lowers() {
        setupTPose()
        let highCOM = calculator.calculateDetailedBodyCOM().totalCOM.y

        // Simulate Squat by lowering hips and upper body
        // Move hips and everything above/connected down by 40 units
        let dropAmount: Float = 40.0

        let upperBodyJoints = [
            "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine1", "mixamorig_Spine2", "mixamorig_Neck", "mixamorig_Head",
            "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
            "mixamorig_RightUpLeg", "mixamorig_LeftUpLeg" // Thighs move down too (proximal)
        ]

        for name in upperBodyJoints {
            if let node = nodes[name] {
                node.position.y -= dropAmount
            }
        }

        // Knees stay same height (approx) but move forward/out? For simplicity, just lowering mass.

        let lowCOM = calculator.calculateDetailedBodyCOM().totalCOM.y

        XCTAssertLessThan(lowCOM, highCOM, "Squatting (lowering body mass) should lower CoM")
        XCTAssertEqual(highCOM - lowCOM, dropAmount * 0.8, accuracy: 10.0, "Drop should be roughly proportional to mass moved")
    }

    func testPike_CoM_ShiftsForward() {
        setupTPose()
        let startZ = calculator.calculateDetailedBodyCOM().totalCOM.z

        // Pike: Legs move forward (Z+)
        // Move feet and knees forward
        nodes["mixamorig_RightLeg"]?.position.z += 50
        nodes["mixamorig_RightFoot"]?.position.z += 50
        nodes["mixamorig_RightToeBase"]?.position.z += 50

        nodes["mixamorig_LeftLeg"]?.position.z += 50
        nodes["mixamorig_LeftFoot"]?.position.z += 50
        nodes["mixamorig_LeftToeBase"]?.position.z += 50

        let endZ = calculator.calculateDetailedBodyCOM().totalCOM.z

        XCTAssertGreaterThan(endZ, startZ, "Pike (legs forward) should shift CoM forward (Z+)")
    }

    func testTouchdown_CoM_Rises() {
        setupTPose()
        let startY = calculator.calculateDetailedBodyCOM().totalCOM.y

        // Touchdown: Arms up
        // Move arms up
        let liftAmount: Float = 50.0

        let armJoints = [
            "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand"
        ]

        for name in armJoints {
            if let node = nodes[name] {
                node.position.y += liftAmount
            }
        }

        let endY = calculator.calculateDetailedBodyCOM().totalCOM.y

        XCTAssertGreaterThan(endY, startY, "Touchdown (arms up) should raise CoM")
    }

    func testDetailedCalculationOutputsSegments() {
        setupTPose()

        // Act
        let result = calculator.calculateDetailedBodyCOM(detailed: true)

        // Assert
        XCTAssertEqual(result.segmentCOMs.count, 17, "There should be exactly 17 segments in the standard model")

        let totalComputedMass = result.segmentCOMs.map { $0.mass }.reduce(0, +)
        XCTAssertEqual(totalComputedMass, 50.0, accuracy: 0.001, "The sum of segment masses should equal the total body mass")

        // Verify that position properties exist and are valid vectors
        for segment in result.segmentCOMs {
            XCTAssertFalse(segment.position.x.isNaN, "Segment position X should not be NaN")
            XCTAssertFalse(segment.position.y.isNaN, "Segment position Y should not be NaN")
            XCTAssertFalse(segment.position.z.isNaN, "Segment position Z should not be NaN")
        }
    }

    func testBodyPresetsAdjustMassDistribution() {
        setupTPose()

        // 1. Calculate neutral baseline
        calculator.setPreset(.averageNeutral)
        let neutralResult = calculator.calculateDetailedBodyCOM(detailed: true)

        // Use XCTUnwrap to safely check values
        guard let neutralArmMass = neutralResult.segmentCOMs.first(where: { $0.name.contains("Arm") })?.mass,
              let neutralThighMass = neutralResult.segmentCOMs.first(where: { $0.name.contains("Thigh") })?.mass else {
            XCTFail("Failed to unwrap neutral masses")
            return
        }

        // 2. Change to athletic male (heavier upper body, lighter lower body)
        calculator.setPreset(.athleticMale)
        let athleticMaleResult = calculator.calculateDetailedBodyCOM(detailed: true)

        guard let maleArmMass = athleticMaleResult.segmentCOMs.first(where: { $0.name.contains("Arm") })?.mass,
              let maleThighMass = athleticMaleResult.segmentCOMs.first(where: { $0.name.contains("Thigh") })?.mass else {
            XCTFail("Failed to unwrap male masses")
            return
        }

        XCTAssertGreaterThan(maleArmMass, neutralArmMass, "Athletic male preset should have heavier arms than neutral")
        XCTAssertLessThan(maleThighMass, neutralThighMass, "Athletic male preset should have lighter thighs than neutral")

        // 3. Change to athletic female (lighter upper body, heavier lower body)
        calculator.setPreset(.athleticFemale)
        let athleticFemaleResult = calculator.calculateDetailedBodyCOM(detailed: true)

        guard let femaleArmMass = athleticFemaleResult.segmentCOMs.first(where: { $0.name.contains("Arm") })?.mass,
              let femaleThighMass = athleticFemaleResult.segmentCOMs.first(where: { $0.name.contains("Thigh") })?.mass else {
            XCTFail("Failed to unwrap female masses")
            return
        }

        XCTAssertLessThan(femaleArmMass, neutralArmMass, "Athletic female preset should have lighter arms than neutral")
        XCTAssertGreaterThan(femaleThighMass, neutralThighMass, "Athletic female preset should have heavier thighs than neutral")

        // Verify that total mass is preserved across all presets
        let maleTotalMass = athleticMaleResult.segmentCOMs.map { $0.mass }.reduce(0, +)
        let femaleTotalMass = athleticFemaleResult.segmentCOMs.map { $0.mass }.reduce(0, +)

        XCTAssertEqual(maleTotalMass, 50.0, accuracy: 0.001, "Total mass should be preserved with .athleticMale preset")
        XCTAssertEqual(femaleTotalMass, 50.0, accuracy: 0.001, "Total mass should be preserved with .athleticFemale preset")
    }
}
