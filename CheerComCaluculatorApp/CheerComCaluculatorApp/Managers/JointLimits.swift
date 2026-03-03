import Foundation
import SceneKit

struct JointLimits {

    /// Clamps the given Euler angles (in radians) for a specific joint to prevent impossible poses.
    /// - Parameters:
    ///   - jointName: The name of the joint (e.g., "mixamorig_RightLeg").
    ///   - angles: The current or proposed Euler angles in radians.
    /// - Returns: The clamped Euler angles in radians.
    static func clampEulerAngles(forJoint jointName: String, angles: SCNVector3) -> SCNVector3 {
        var clampedAngles = angles

        switch jointName {
        // Knees: Hinge joint, flexes backward. X-axis limited to [-160°, 0°]
        case "mixamorig_RightLeg", "mixamorig_LeftLeg":
            clampedAngles.x = clamp(value: angles.x, minDegrees: -160, maxDegrees: 0)

        // Right Elbow: Hinge joint, flexes forward. Z-axis limited to [0°, 160°]
        case "mixamorig_RightForeArm":
            clampedAngles.z = clamp(value: angles.z, minDegrees: 0, maxDegrees: 160)

        // Left Elbow: Hinge joint, flexes forward. Z-axis limited to [-160°, 0°]
        case "mixamorig_LeftForeArm":
            clampedAngles.z = clamp(value: angles.z, minDegrees: -160, maxDegrees: 0)

        default:
            break
        }

        return clampedAngles
    }

    // Helper to clamp a radian value using degree limits
    private static func clamp(value: Float, minDegrees: Float, maxDegrees: Float) -> Float {
        let minRad = minDegrees * .pi / 180.0
        let maxRad = maxDegrees * .pi / 180.0
        return Swift.max(minRad, Swift.min(maxRad, value))
    }
}
