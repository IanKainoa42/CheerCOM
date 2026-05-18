import Foundation
import SceneKit


extension Notification.Name {
    static let jointAngleClamped = Notification.Name("jointAngleClamped")
}

struct JointLimit {
    let minAngle: SCNVector3
    let maxAngle: SCNVector3

    init(minX: Float, maxX: Float, minY: Float, maxY: Float, minZ: Float, maxZ: Float) {
        self.minAngle = SCNVector3(minX * .pi / 180, minY * .pi / 180, minZ * .pi / 180)
        self.maxAngle = SCNVector3(maxX * .pi / 180, maxY * .pi / 180, maxZ * .pi / 180)
    }
}

class JointLimits {
    static var constrainedJoints: [Joint] {
        return Joint.allCases.filter { limits.keys.contains($0.rawValue) }
    }

    static let limits: [String: JointLimit] = [
        // Knees
        "mixamorig_RightLeg": JointLimit(minX: -160, maxX: 0, minY: -360, maxY: 360, minZ: -360, maxZ: 360),
        "mixamorig_LeftLeg": JointLimit(minX: -160, maxX: 0, minY: -360, maxY: 360, minZ: -360, maxZ: 360),

        // Elbows
        "mixamorig_RightForeArm": JointLimit(minX: -360, maxX: 360, minY: -360, maxY: 360, minZ: 0, maxZ: 160),
        "mixamorig_LeftForeArm": JointLimit(minX: -360, maxX: 360, minY: -360, maxY: 360, minZ: -160, maxZ: 0),
        "mixamorig_RightArm": JointLimit(minX: -180, maxX: 90, minY: -90, maxY: 90, minZ: -180, maxZ: 0),
        "mixamorig_LeftArm": JointLimit(minX: -180, maxX: 90, minY: -90, maxY: 90, minZ: 0, maxZ: 180),
        "mixamorig_Spine": JointLimit(minX: -45, maxX: 45, minY: -45, maxY: 45, minZ: -45, maxZ: 45),
        "mixamorig_Spine1": JointLimit(minX: -45, maxX: 45, minY: -45, maxY: 45, minZ: -45, maxZ: 45),
        "mixamorig_Spine2": JointLimit(minX: -45, maxX: 45, minY: -45, maxY: 45, minZ: -45, maxZ: 45),
        "mixamorig_Neck": JointLimit(minX: -60, maxX: 60, minY: -80, maxY: 80, minZ: -45, maxZ: 45),
        "mixamorig_Head": JointLimit(minX: -60, maxX: 60, minY: -80, maxY: 80, minZ: -45, maxZ: 45),
        "mixamorig_RightUpLeg": JointLimit(minX: -180, maxX: 90, minY: -90, maxY: 90, minZ: -180, maxZ: 180),
        "mixamorig_LeftUpLeg": JointLimit(minX: -180, maxX: 90, minY: -90, maxY: 90, minZ: -180, maxZ: 180),
        "mixamorig_RightHand": JointLimit(minX: -90, maxX: 90, minY: -45, maxY: 45, minZ: -45, maxZ: 45),
        "mixamorig_LeftHand": JointLimit(minX: -90, maxX: 90, minY: -45, maxY: 45, minZ: -45, maxZ: 45),
        "mixamorig_RightFoot": JointLimit(minX: -45, maxX: 45, minY: -30, maxY: 30, minZ: -30, maxZ: 30),
        "mixamorig_LeftFoot": JointLimit(minX: -45, maxX: 45, minY: -30, maxY: 30, minZ: -30, maxZ: 30),

        // Toes
        "mixamorig_RightToeBase": JointLimit(minX: -45, maxX: 90, minY: -10, maxY: 10, minZ: -10, maxZ: 10),
        "mixamorig_LeftToeBase": JointLimit(minX: -45, maxX: 90, minY: -10, maxY: 10, minZ: -10, maxZ: 10)
    ]

    static func clampAngles(for jointName: String, angles: SCNVector3) -> SCNVector3 {
        guard let limit = limits[jointName] else { return angles }

        let clampedX = max(limit.minAngle.x, min(limit.maxAngle.x, angles.x))
        let clampedY = max(limit.minAngle.y, min(limit.maxAngle.y, angles.y))
        let clampedZ = max(limit.minAngle.z, min(limit.maxAngle.z, angles.z))

        if clampedX != angles.x || clampedY != angles.y || clampedZ != angles.z {
            let degX = angles.x * 180 / .pi
            let degY = angles.y * 180 / .pi
            let degZ = angles.z * 180 / .pi
            let cX = clampedX * 180 / .pi
            let cY = clampedY * 180 / .pi
            let cZ = clampedZ * 180 / .pi
            print(String(format: "⚠️ POSE VALIDATOR WARNING: Out-of-range angle clamped on %@. Attempted: (%.1f°, %.1f°, %.1f°) -> Clamped: (%.1f°, %.1f°, %.1f°)", jointName, degX, degY, degZ, cX, cY, cZ))

            NotificationCenter.default.post(
                name: .jointAngleClamped,
                object: nil,
                userInfo: ["jointName": jointName]
            )
        }

        return SCNVector3(clampedX, clampedY, clampedZ)
    }
}
