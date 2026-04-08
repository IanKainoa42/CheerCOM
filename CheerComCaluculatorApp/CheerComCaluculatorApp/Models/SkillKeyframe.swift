import Foundation

/// A single keyframe in a skill animation timeline.
///
/// A keyframe can either reference a saved pose by id (legacy) or carry its own
/// inline joint-angle snapshot captured directly in the Skill Animator. New
/// keyframes authored from the animator always use `inlineJointAngles`; the
/// `poseId` path remains for backward compatibility with already-saved
/// animations.
public struct SkillKeyframe: Codable, Equatable, Identifiable {
    public var id: UUID
    public var poseId: UUID?                       // legacy reference to a SavedPose
    public var inlineJointAngles: [String: [Float]]? // bone name -> [x, y, z] euler radians
    public var frameIndex: Int                     // timeline position, 0-based
    public var bodylineId: String?                 // optional override (usually propagated from pose)

    public init(
        id: UUID = UUID(),
        poseId: UUID? = nil,
        inlineJointAngles: [String: [Float]]? = nil,
        frameIndex: Int,
        bodylineId: String? = nil
    ) {
        self.id = id
        self.poseId = poseId
        self.inlineJointAngles = inlineJointAngles
        self.frameIndex = frameIndex
        self.bodylineId = bodylineId
    }
}
