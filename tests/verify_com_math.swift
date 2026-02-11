// Tests/VerifyCOMMath.swift
// This script simulates the COM calculation logic to verify correctness without SceneKit runtime.

import Foundation

// MARK: - Mock SceneKit

struct SCNVector3 {
    var x: Float
    var y: Float
    var z: Float

    static let zero = SCNVector3(x: 0, y: 0, z: 0)
}

extension SCNVector3 {
    static func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        return SCNVector3(x: l.x + r.x, y: l.y + r.y, z: l.z + r.z)
    }

    static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        return SCNVector3(x: l.x - r.x, y: l.y - r.y, z: l.z - r.z)
    }

    static func * (v: SCNVector3, s: Float) -> SCNVector3 {
        return SCNVector3(x: v.x * s, y: v.y * s, z: v.z * s)
    }
}

class SCNNode {
    var name: String?
    var position: SCNVector3
    var worldPosition: SCNVector3 // Simplified for mock

    init(name: String? = nil, position: SCNVector3 = .zero) {
        self.name = name
        self.position = position
        self.worldPosition = position
    }
}

// MARK: - COM Logic (Copied from COMCalculator.swift)

struct SegmentResult {
    let name: String
    let position: SCNVector3
    let mass: Double
}

struct CalculationResult {
    let totalCOM: SCNVector3
    let segmentCOMs: [SegmentResult]
}

class COMCalculatorMock {
    var bodyMass: Double

    // Updated segments from COMCalculator.swift
    let segments: [(name: String, prox: String, dist: String, mass: Double, com: Double)] = [
        ("Pelvis", "mixamorig_Hips", "mixamorig_Spine", 0.146, 0.50),
        ("Abdomen Lower", "mixamorig_Spine", "mixamorig_Spine1", 0.0855, 0.50),
        ("Abdomen Upper", "mixamorig_Spine1", "mixamorig_Spine2", 0.0855, 0.50),
        ("Thorax", "mixamorig_Spine2", "mixamorig_Neck", 0.180, 0.50),
        ("Head", "mixamorig_Neck", "mixamorig_Head", 0.081, 0.50),

        // Corrected Arm Segments
        ("R Upper Arm", "mixamorig_RightArm", "mixamorig_RightForeArm", 0.028, 0.44),
        ("R Forearm", "mixamorig_RightForeArm", "mixamorig_RightHand", 0.016, 0.43),
        ("R Hand", "mixamorig_RightHand", "mixamorig_RightHandMiddle1", 0.006, 0.50),
        ("L Upper Arm", "mixamorig_LeftArm", "mixamorig_LeftForeArm", 0.028, 0.44),
        ("L Forearm", "mixamorig_LeftForeArm", "mixamorig_LeftHand", 0.016, 0.43),
        ("L Hand", "mixamorig_LeftHand", "mixamorig_LeftHandMiddle1", 0.006, 0.50),

        ("R Thigh", "mixamorig_RightUpLeg", "mixamorig_RightLeg", 0.100, 0.43),
        ("R Shank", "mixamorig_RightLeg", "mixamorig_RightFoot", 0.0465, 0.43),
        ("R Foot", "mixamorig_RightFoot", "mixamorig_RightToeBase", 0.0145, 0.50),
        ("L Thigh", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", 0.100, 0.43),
        ("L Shank", "mixamorig_LeftLeg", "mixamorig_LeftFoot", 0.0465, 0.43),
        ("L Foot", "mixamorig_LeftFoot", "mixamorig_LeftToeBase", 0.0145, 0.50)
    ]

    private struct BoundSegment {
        let name: String
        let prox: SCNNode
        let dist: SCNNode
        let massRatio: Double
        let comRatio: Double
    }

    private var boundSegments: [BoundSegment] = []

    init(bodyMass: Double) {
        self.bodyMass = bodyMass
    }

    func bind(jointNodes: [String: SCNNode]) {
        boundSegments.removeAll()

        for segment in segments {
            guard let proxNode = jointNodes[segment.prox] else {
                print("⚠️ Missing proximal joint for binding: \(segment.prox)")
                continue
            }

            var distNode = jointNodes[segment.dist]
            if distNode == nil {
                print("⚠️ Missing distal joint: \(segment.dist). Using proximal joint (length 0) for segment \(segment.name)")
                distNode = proxNode // Fallback logic
            }

            guard let validDistNode = distNode else { continue }

            boundSegments.append(BoundSegment(
                name: segment.name,
                prox: proxNode,
                dist: validDistNode,
                massRatio: segment.mass,
                comRatio: segment.com
            ))
        }
    }

    func calculateDetailedBodyCOM() -> CalculationResult {
        var totalWeighted = SCNVector3Zero
        var totalMass: Double = 0
        var segmentResults: [SegmentResult] = []

        for segment in boundSegments {
            let proxPos = segment.prox.worldPosition
            let distPos = segment.dist.worldPosition

            let segCOM = proxPos + ((distPos - proxPos) * Float(segment.comRatio))
            let segMass = bodyMass * segment.massRatio

            totalWeighted = totalWeighted + (segCOM * Float(segMass))
            totalMass += segMass

            segmentResults.append(SegmentResult(
                name: segment.name,
                position: segCOM,
                mass: segMass
            ))
        }

        let totalCOM = totalMass > 0 ? (totalWeighted * Float(1.0 / totalMass)) : SCNVector3Zero
        return CalculationResult(totalCOM: totalCOM, segmentCOMs: segmentResults)
    }
}

// MARK: - Verification Script

func runVerification() {
    print("🧪 Running CoM Verification...")

    let calculator = COMCalculatorMock(bodyMass: 70.0)
    var nodes: [String: SCNNode] = [:]

    // Create mock nodes (simplified T-Poseish)
    // Arms extending right
    nodes["mixamorig_RightArm"] = SCNNode(name: "RArm", position: SCNVector3(x: 20, y: 150, z: 0))
    nodes["mixamorig_RightForeArm"] = SCNNode(name: "RForeArm", position: SCNVector3(x: 50, y: 150, z: 0))
    nodes["mixamorig_RightHand"] = SCNNode(name: "RHand", position: SCNVector3(x: 80, y: 150, z: 0))
    // Missing "mixamorig_RightHandMiddle1" to test fallback

    // Bind
    print("\n--- Binding Nodes ---")
    calculator.bind(jointNodes: nodes)

    // Calculate
    print("\n--- Calculating CoM ---")
    let result = calculator.calculateDetailedBodyCOM()

    // Verify specific segments
    for seg in result.segmentCOMs {
        if seg.name == "R Hand" {
            print("✅ Hand Segment: \(seg.name)")
            print("   Position: (\(seg.position.x), \(seg.position.y), \(seg.position.z))")
            print("   Expected: (80.0, 150.0, 0.0) (Fallback to Wrist)")

            if abs(seg.position.x - 80.0) < 0.001 {
                print("   Result: PASS")
            } else {
                print("   Result: FAIL")
            }
        }
    }

    // Verify R Upper Arm (Should be between Arm and Forearm)
    // Arm (20) -> Forearm (50). CoM at 0.44.
    // 20 + (50-20)*0.44 = 20 + 30*0.44 = 20 + 13.2 = 33.2
    if let armSeg = result.segmentCOMs.first(where: { $0.name == "R Upper Arm" }) {
        print("\n✅ Upper Arm Segment: \(armSeg.name)")
        print("   Position X: \(armSeg.position.x)")
        print("   Expected X: 33.2")

        if abs(armSeg.position.x - 33.2) < 0.001 {
             print("   Result: PASS")
        } else {
             print("   Result: FAIL")
        }
    }

    print("\n✅ Verification Complete")
}

runVerification()
