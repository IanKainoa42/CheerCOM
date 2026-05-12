import Foundation

struct AnimatorWorkspaceState: Codable {
    var version: Int
    var selectedAtomId: String
    var currentFrame: Int
    var keyframePoses: [Int: [String: [Float]]]
    var selectedJointName: String?
    var mirrorEnabled: Bool
    var transformMode: TransformMode
    var transformStepMultiplier: Float
    var poseLibraryExpanded: Bool
    var characterPosition: [Float]
    var characterEulerAngles: [Float]
    var characterScale: [Float]

    init(
        version: Int = 1,
        selectedAtomId: String,
        currentFrame: Int,
        keyframePoses: [Int: [String: [Float]]],
        selectedJointName: String?,
        mirrorEnabled: Bool,
        transformMode: TransformMode,
        transformStepMultiplier: Float,
        poseLibraryExpanded: Bool,
        characterPosition: [Float],
        characterEulerAngles: [Float],
        characterScale: [Float]
    ) {
        self.version = version
        self.selectedAtomId = selectedAtomId
        self.currentFrame = currentFrame
        self.keyframePoses = keyframePoses
        self.selectedJointName = selectedJointName
        self.mirrorEnabled = mirrorEnabled
        self.transformMode = transformMode
        self.transformStepMultiplier = transformStepMultiplier
        self.poseLibraryExpanded = poseLibraryExpanded
        self.characterPosition = characterPosition
        self.characterEulerAngles = characterEulerAngles
        self.characterScale = characterScale
    }
}
