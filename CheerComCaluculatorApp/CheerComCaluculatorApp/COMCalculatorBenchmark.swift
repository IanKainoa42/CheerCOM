import XCTest
import SceneKit
@testable import CheerComCaluculatorApp

class COMCalculatorBenchmark: XCTestCase {

    var calculator: COMCalculator!
    var mockNodes: [String: SCNNode]!

    override func setUp() {
        super.setUp()
        calculator = COMCalculator(bodyMass: 70.0)
        mockNodes = createMockNodes()
        calculator.bind(jointNodes: mockNodes)
    }

    func createMockNodes() -> [String: SCNNode] {
        var nodes: [String: SCNNode] = [:]
        // Create nodes for all segments defined in COMCalculator
        let jointNames = [
            "mixamorig_Hips", "mixamorig_Spine", "mixamorig_Spine2", "mixamorig_Head",
            "mixamorig_RightShoulder", "mixamorig_RightArm", "mixamorig_RightForeArm", "mixamorig_RightHand",
            "mixamorig_LeftShoulder", "mixamorig_LeftArm", "mixamorig_LeftForeArm", "mixamorig_LeftHand",
            "mixamorig_RightUpLeg", "mixamorig_RightLeg", "mixamorig_RightFoot", "mixamorig_RightToeBase",
            "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", "mixamorig_LeftFoot", "mixamorig_LeftToeBase"
        ]

        for name in jointNames {
            let node = SCNNode()
            node.name = name
            node.position = SCNVector3(Float.random(in: 0...1), Float.random(in: 0...1), Float.random(in: 0...1))
            nodes[name] = node
        }
        return nodes
    }

    // Baseline: Creating full detailed results just to get the total COM
    func testCalculateDetailedBodyCOM_Overhead() {
        measure {
            for _ in 0..<1000 {
                let result = calculator.calculateDetailedBodyCOM()
                _ = result.totalCOM
            }
        }
    }

    // Optimization Target: Using the optimized calculateBodyCOM method
    func testCalculateBodyCOM_Optimized() {
        measure {
            for _ in 0..<1000 {
                _ = calculator.calculateBodyCOM()
            }
        }
    }
}
