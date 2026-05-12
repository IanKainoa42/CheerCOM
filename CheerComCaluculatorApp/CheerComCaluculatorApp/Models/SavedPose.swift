import Foundation

public struct SavedPose: Codable, Identifiable {
    public let id: UUID
    public let name: String
    public let jointAngles: [String: [Float]]
    public let timestamp: Date

    public init(id: UUID, name: String, jointAngles: [String: [Float]], timestamp: Date) {
        self.id = id
        self.name = name
        self.jointAngles = jointAngles
        self.timestamp = timestamp
    }
}
