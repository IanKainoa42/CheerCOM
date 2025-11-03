import SceneKit

class COMCalculator {
    var bodyMass: Double  // kg
    
    // 14 body segments with (proximal_joint, distal_joint, mass_%, com_%)
    // Based on anthropometric data from Winter (2009) and de Leva (1996)
    // Updated for Mixamo skeleton with mixamorig_ prefix
    let segments: [(prox: String, dist: String, mass: Double, com: Double)] = [
        ("mixamorig_Hips", "mixamorig_Spine", 0.497, 0.50),              // Trunk
        ("mixamorig_Spine2", "mixamorig_Head", 0.081, 0.50),             // Head/neck
        ("mixamorig_RightShoulder", "mixamorig_RightArm", 0.028, 0.44),  // R upper arm
        ("mixamorig_RightArm", "mixamorig_RightForeArm", 0.016, 0.43),   // R forearm
        ("mixamorig_RightForeArm", "mixamorig_RightHand", 0.006, 0.50),  // R hand
        ("mixamorig_LeftShoulder", "mixamorig_LeftArm", 0.028, 0.44),    // L upper arm
        ("mixamorig_LeftArm", "mixamorig_LeftForeArm", 0.016, 0.43),     // L forearm
        ("mixamorig_LeftForeArm", "mixamorig_LeftHand", 0.006, 0.50),    // L hand
        ("mixamorig_RightUpLeg", "mixamorig_RightLeg", 0.100, 0.43),     // R thigh
        ("mixamorig_RightLeg", "mixamorig_RightFoot", 0.0465, 0.43),     // R shank
        ("mixamorig_RightFoot", "mixamorig_RightToeBase", 0.0145, 0.50), // R foot
        ("mixamorig_LeftUpLeg", "mixamorig_LeftLeg", 0.100, 0.43),       // L thigh
        ("mixamorig_LeftLeg", "mixamorig_LeftFoot", 0.0465, 0.43),       // L shank
        ("mixamorig_LeftFoot", "mixamorig_LeftToeBase", 0.0145, 0.50)    // L foot
    ]
    
    init(bodyMass: Double) {
        self.bodyMass = bodyMass
    }
    
    func calculateBodyCOM(jointPositions: [String: SCNVector3]) -> SCNVector3 {
        var totalWeighted = SCNVector3Zero
        var totalMass: Double = 0
        
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
        }
        
        if totalMass > 0 {
            return totalWeighted * Float(1.0 / totalMass)
        } else {
            print("⚠️ Warning: Total mass is zero, returning origin")
            return SCNVector3Zero
        }
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

