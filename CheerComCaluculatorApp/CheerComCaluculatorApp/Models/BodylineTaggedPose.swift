import Foundation


/// Pairs a SavedPose with an optional bodyline tag referencing an entry in
/// VocabularyManifest.bodylines. Bodyline tags are stored in a sidecar

public struct BodylineTaggedPose {
    public let pose: SavedPose
    public let bodylineId: String?

    public init(pose: SavedPose, bodylineId: String?) {
        self.pose = pose
        self.bodylineId = bodylineId
    }
}
