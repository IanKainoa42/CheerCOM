import Foundation
import SceneKit

/// Bilateral mirror map for mixamo rig bone names + euler-angle reflection.
///
/// Mixamo left/right bones share the same local axis convention but live on
/// opposite sides of the body's sagittal plane. Reflecting a pose across that
/// plane is approximated by negating the Y and Z components of the euler
/// angles while keeping X. This is the standard mixamo mirror trick — it's
/// not perfect for every joint, but it's the right starting point and easy
/// to disable per-edit if it misbehaves.
enum JointMirror {

    /// Returns the mirror partner bone name for a given mixamo bone, or nil
    /// for centerline bones (Hips, Spine, Head, ...) that have no partner.
    static func partner(of boneName: String) -> String? {
        if boneName.contains("Left") {
            return boneName.replacingOccurrences(of: "Left", with: "Right")
        }
        if boneName.contains("Right") {
            return boneName.replacingOccurrences(of: "Right", with: "Left")
        }
        return nil
    }

    /// Reflect euler angles across the body's sagittal (YZ) plane.
    /// Negates the Y and Z components, keeps X unchanged.
    static func mirroredAngles(_ angles: SCNVector3) -> SCNVector3 {
        #if os(macOS)
        return SCNVector3(angles.x, -angles.y, -angles.z)
        #else
        return SCNVector3(angles.x, -angles.y, -angles.z)
        #endif
    }
}
