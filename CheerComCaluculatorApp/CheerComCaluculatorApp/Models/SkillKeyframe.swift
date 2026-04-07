import Foundation

/// A single keyframe in a skill animation timeline: a reference to a saved pose
/// + the frame index at which that pose should appear.
public struct SkillKeyframe: Codable, Equatable, Identifiable {
    public var id: UUID
    public var poseId: UUID               // refers to a SavedPose in PoseStorageManager
    public var frameIndex: Int            // timeline position, 0-based
    public var bodylineId: String?        // optional override (usually propagated from pose)

    public init(
        id: UUID = UUID(),
        poseId: UUID,
        frameIndex: Int,
        bodylineId: String? = nil
    ) {
        self.id = id
        self.poseId = poseId
        self.frameIndex = frameIndex
        self.bodylineId = bodylineId
    }
}
