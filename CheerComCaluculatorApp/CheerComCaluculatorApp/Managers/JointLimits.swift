import Foundation
import SceneKit

struct JointLimit {
    let minAngle: SCNVector3
    let maxAngle: SCNVector3

    init(minX: Float, maxX: Float, minY: Float, maxY: Float, minZ: Float, maxZ: Float) {
        self.minAngle = SCNVector3(minX * .pi / 180, minY * .pi / 180, minZ * .pi / 180)
        self.maxAngle = SCNVector3(maxX * .pi / 180, maxY * .pi / 180, maxZ * .pi / 180)
    }
}

class JointLimits {
    static let limits: [String: JointLimit] = [
        // Knees
        "mixamorig_RightLeg": JointLimit(minX: -160, maxX: 0, minY: -360, maxY: 360, minZ: -360, maxZ: 360),
        "mixamorig_LeftLeg": JointLimit(minX: -160, maxX: 0, minY: -360, maxY: 360, minZ: -360, maxZ: 360),

        // Elbows
        "mixamorig_RightForeArm": JointLimit(minX: -360, maxX: 360, minY: -360, maxY: 360, minZ: 0, maxZ: 160),
        "mixamorig_LeftForeArm": JointLimit(minX: -360, maxX: 360, minY: -360, maxY: 360, minZ: -160, maxZ: 0),

        // Shoulders
        "mixamorig_RightArm": JointLimit(minX: -90, maxX: 90, minY: -90, maxY: 90, minZ: -180, maxZ: 45),
        "mixamorig_LeftArm": JointLimit(minX: -90, maxX: 90, minY: -90, maxY: 90, minZ: -45, maxZ: 180),

        // Hips
        "mixamorig_RightUpLeg": JointLimit(minX: -180, maxX: 45, minY: -90, maxY: 90, minZ: -90, maxZ: 90),
        "mixamorig_LeftUpLeg": JointLimit(minX: -180, maxX: 45, minY: -90, maxY: 90, minZ: -90, maxZ: 90),

        // Spine
        "mixamorig_Spine": JointLimit(minX: -45, maxX: 45, minY: -45, maxY: 45, minZ: -45, maxZ: 45),
        "mixamorig_Spine1": JointLimit(minX: -45, maxX: 45, minY: -45, maxY: 45, minZ: -45, maxZ: 45),
        "mixamorig_Spine2": JointLimit(minX: -45, maxX: 45, minY: -45, maxY: 45, minZ: -45, maxZ: 45),

        // Neck
        "mixamorig_Neck": JointLimit(minX: -60, maxX: 60, minY: -60, maxY: 60, minZ: -60, maxZ: 60),

        // Ankles
        "mixamorig_RightFoot": JointLimit(minX: -45, maxX: 45, minY: -45, maxY: 45, minZ: -45, maxZ: 45),
        "mixamorig_LeftFoot": JointLimit(minX: -45, maxX: 45, minY: -45, maxY: 45, minZ: -45, maxZ: 45)
    ]

    static func clampAngles(for jointName: String, angles: SCNVector3) -> SCNVector3 {
        guard let limit = limits[jointName] else { return angles }

        let clampedX = max(limit.minAngle.x, min(limit.maxAngle.x, angles.x))
        let clampedY = max(limit.minAngle.y, min(limit.maxAngle.y, angles.y))
        let clampedZ = max(limit.minAngle.z, min(limit.maxAngle.z, angles.z))

        return SCNVector3(clampedX, clampedY, clampedZ)
    }
}
