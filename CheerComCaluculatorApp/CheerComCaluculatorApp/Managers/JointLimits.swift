import Foundation
import SceneKit

struct JointLimit {
    let minX: Float?
    let maxX: Float?
    let minY: Float?
    let maxY: Float?
    let minZ: Float?
    let maxZ: Float?

    init(minX: Float? = nil, maxX: Float? = nil, minY: Float? = nil, maxY: Float? = nil, minZ: Float? = nil, maxZ: Float? = nil) {
        self.minX = minX
        self.maxX = maxX
        self.minY = minY
        self.maxY = maxY
        self.minZ = minZ
        self.maxZ = maxZ
    }

    func clamp(vector: SCNVector3) -> SCNVector3 {
        var result = vector
        if let minX = minX, let maxX = maxX { result.x = min(max(result.x, minX), maxX) }
        else if let minX = minX { result.x = max(result.x, minX) }
        else if let maxX = maxX { result.x = min(result.x, maxX) }

        if let minY = minY, let maxY = maxY { result.y = min(max(result.y, minY), maxY) }
        else if let minY = minY { result.y = max(result.y, minY) }
        else if let maxY = maxY { result.y = min(result.y, maxY) }

        if let minZ = minZ, let maxZ = maxZ { result.z = min(max(result.z, minZ), maxZ) }
        else if let minZ = minZ { result.z = max(result.z, minZ) }
        else if let maxZ = maxZ { result.z = min(result.z, maxZ) }
        return result
    }
}

class JointLimits {
    static let shared = JointLimits()

    private let limits: [String: JointLimit]

    private init() {
        func deg(_ degrees: Float) -> Float {
            return degrees * .pi / 180
        }

        limits = [
            // Knees: Only bend backwards (flexion). Range: [-160, 0] degrees on X-axis.
            "mixamorig_RightLeg": JointLimit(minX: deg(-160), maxX: deg(0)),
            "mixamorig_LeftLeg": JointLimit(minX: deg(-160), maxX: deg(0)),

            // Elbows: Hinge joint. Range: 160 degree range limit on Z-axis.
            // Right elbow bends such that Z becomes positive (0 to 160).
            "mixamorig_RightForeArm": JointLimit(minZ: deg(0), maxZ: deg(160)),
            // Left elbow bends such that Z becomes negative (0 to -160).
            "mixamorig_LeftForeArm": JointLimit(minZ: deg(-160), maxZ: deg(0))
        ]
    }

    func clampAngles(_ angles: SCNVector3, forJoint jointName: String) -> SCNVector3 {
        if let limit = limits[jointName] {
            return limit.clamp(vector: angles)
        }
        return angles // No limits defined for this joint
    }
}
