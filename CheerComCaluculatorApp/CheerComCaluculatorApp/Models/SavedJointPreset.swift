import Foundation

struct SavedJointPreset: Codable, Equatable, Identifiable {
    var id: UUID
    var name: String
    var jointName: String
    var jointAngles: [Float]
    var createdAt: Date

    init(
        id: UUID = UUID(),
        name: String,
        jointName: String,
        jointAngles: [Float],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.name = name
        self.jointName = jointName
        self.jointAngles = jointAngles
        self.createdAt = createdAt
    }
}
