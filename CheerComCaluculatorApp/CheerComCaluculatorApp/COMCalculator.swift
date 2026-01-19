import SceneKit

struct SegmentResult {
    let name: String
    let position: SCNVector3
    let mass: Double
}

struct CalculationResult {
    let totalCOM: SCNVector3
    let segmentCOMs: [SegmentResult]
}

class COMCalculator {
    var bodyMass: Double  // kg
    
    // 14 body segments with (name, proximal_joint, distal_joint, mass_%, com_%)
    // Based on anthropometric data from Winter (2009) and de Leva (1996)
    // Updated for Mixamo skeleton with mixamorig_ prefix
    let segments: [(name: String, prox: String, dist: String, mass: Double, com: Double)] = [
        ("Trunk", "mixamorig_Hips", "mixamorig_Spine", 0.497, 0.50),
        ("Head", "mixamorig_Spine2", "mixamorig_Head", 0.081, 0.50),
        ("R Upper Arm", "mixamorig_RightShoulder", "mixamorig_RightArm", 0.028, 0.44),
        ("R Forearm", "mixamorig_RightArm", "mixamorig_RightForeArm", 0.016, 0.43),
        ("R Hand", "mixamorig_RightForeArm", "mixamorig_RightHand", 0.006, 0.50),
        ("L Upper Arm", "mixamorig_LeftShoulder", "mixamorig_LeftArm", 0.028, 0.44),
        ("L Forearm", "mixamorig_LeftArm", "mixamorig_LeftForeArm", 0.016, 0.43),
        ("L Hand", "mixamorig_LeftForeArm", "mixamorig_LeftHand", 0.006, 0.50),
        ("R Thigh", "mixamorig_RightUpLeg", "mixamorig_RightLeg", 0.100, 0.43),
        ("R Shank", "mixamorig_RightLeg", "mixamorig_RightFoot", 0.0465, 0.43),
        ("R Foot", "mixamorig_RightFoot", "mixamorig_RightToeBase", 0.0145, 0.50),
        ("L Thigh", "mixamorig_LeftUpLeg", "mixamorig_LeftLeg", 0.100, 0.43),
        ("L Shank", "mixamorig_LeftLeg", "mixamorig_LeftFoot", 0.0465, 0.43),
        ("L Foot", "mixamorig_LeftFoot", "mixamorig_LeftToeBase", 0.0145, 0.50)
    ]
    
    init(bodyMass: Double) {
        self.bodyMass = bodyMass
    }
    
    func calculateBodyCOM(jointPositions: [String: SCNVector3]) -> CalculationResult {
        var totalWeighted = SCNVector3Zero
        var totalMass: Double = 0
        var segmentResults: [SegmentResult] = []
        
        for segment in segments {
            guard let proxPos = jointPositions[segment.prox],
                  let distPos = jointPositions[segment.dist] else {
                print("⚠️ Missing joint: \(segment.prox) or \(segment.dist)")
                continue
            }
            
            // COM = proximal + (distal - proximal) * %
            let segCOM = proxPos + ((distPos - proxPos) * Float(segment.com))
            let segMass = bodyMass * segment.mass
            
            totalWeighted = totalWeighted + (segCOM * Float(segMass))
            totalMass += segMass

            segmentResults.append(SegmentResult(name: segment.name, position: segCOM, mass: segMass))
        }
        
        let totalCOM: SCNVector3
        if totalMass > 0 {
            totalCOM = totalWeighted * Float(1.0 / totalMass)
        } else {
            print("⚠️ Warning: Total mass is zero, returning origin")
            totalCOM = SCNVector3Zero
        }

        return CalculationResult(totalCOM: totalCOM, segmentCOMs: segmentResults)
    }
}

// MARK: - SCNVector3 Extensions

extension SCNVector3 {
    static func + (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        return SCNVector3(l.x + r.x, l.y + r.y, l.z + r.z)
    }
    
    static func - (l: SCNVector3, r: SCNVector3) -> SCNVector3 {
        return SCNVector3(l.x - r.x, l.y - r.y, l.z - r.z)
    }
    
    static func * (v: SCNVector3, s: Float) -> SCNVector3 {
        return SCNVector3(v.x * s, v.y * s, v.z * s)
    }
}
