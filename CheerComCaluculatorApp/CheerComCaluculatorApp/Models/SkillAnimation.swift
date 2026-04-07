import Foundation

/// A complete skill animation: atom id, fps, character metadata, and an ordered
/// list of keyframes. Exported from CheerCOM and consumed by the training pipeline.
public struct SkillAnimation: Codable, Equatable, Identifiable {
    public var id: UUID
    public var name: String
    public var atomId: String
    public var category: String
    public var notes: String
    public var fps: Int
    public var numFrames: Int
    public var characterRig: String
    public var characterHeightM: Double
    public var characterProportionsPreset: String
    public var keyframes: [SkillKeyframe]
    public var createdAt: Date
    public var updatedAt: Date

    public init(
        id: UUID = UUID(),
        name: String,
        atomId: String,
        category: String = "tumbling",
        notes: String = "",
        fps: Int = 30,
        numFrames: Int = 25,
        characterRig: String = "mixamo",
        characterHeightM: Double = 1.65,
        characterProportionsPreset: String = "average_adult_female",
        keyframes: [SkillKeyframe] = [],
        createdAt: Date = Date(),
        updatedAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.atomId = atomId
        self.category = category
        self.notes = notes
        self.fps = fps
        self.numFrames = numFrames
        self.characterRig = characterRig
        self.characterHeightM = characterHeightM
        self.characterProportionsPreset = characterProportionsPreset
        self.keyframes = keyframes
        self.createdAt = createdAt
        self.updatedAt = updatedAt
    }

    public var sortedKeyframes: [SkillKeyframe] {
        keyframes.sorted(by: { $0.frameIndex < $1.frameIndex })
    }
}
