import Foundation
import ModelRigKit

/// Pairs a SavedPose with an optional bodyline tag referencing an entry in
/// VocabularyManifest.bodylines. Bodyline tags are stored in a sidecar
/// UserDefaults dictionary so SavedPose itself (in ModelRigKit) stays unchanged.
public struct BodylineTaggedPose {
    public let pose: SavedPose
    public let bodylineId: String?

    public init(pose: SavedPose, bodylineId: String?) {
        self.pose = pose
        self.bodylineId = bodylineId
    }
}
