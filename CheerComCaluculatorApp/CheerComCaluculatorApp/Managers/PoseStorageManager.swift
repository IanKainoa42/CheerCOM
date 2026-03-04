import Foundation
import SceneKit

struct SavedPose: Codable {
    let id: UUID
    let name: String
    let jointAngles: [String: [Float]] // [x, y, z] in radians
    let timestamp: Date

    // Helper to convert to SceneKit vector
    func getVector(for joint: String) -> SCNVector3? {
        guard let angles = jointAngles[joint], angles.count == 3 else { return nil }
        return SCNVector3(angles[0], angles[1], angles[2])
    }
}

class PoseStorageManager {
    static let shared = PoseStorageManager()

    private let userDefaultsKey = "saved_poses"

    private init() {}

    func savePose(name: String, jointPositions: [String: SCNVector3]) {
        var poses = loadPoses()

        // Convert SCNVector3 to [Float]
        var codableAngles: [String: [Float]] = [:]
        for (joint, angle) in jointPositions {
            // Only save non-zero angles to save space, or save all?
            // Saving all is safer to ensure complete state restoration.
            // However, we should only save controllable joints.
            codableAngles[joint] = [angle.x, angle.y, angle.z]
        }

        let newPose = SavedPose(
            id: UUID(),
            name: name,
            jointAngles: codableAngles,
            timestamp: Date()
        )

        poses.append(newPose)
        persist(poses)
    }

    func loadPoses() -> [SavedPose] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        do {
            let poses = try JSONDecoder().decode([SavedPose].self, from: data)
            return poses.sorted(by: { $0.timestamp > $1.timestamp }) // Newest first
        } catch {
            DebugLogger.error("Failed to load poses: \(error)")
            return []
        }
    }

    func deletePose(id: UUID) {
        var poses = loadPoses()
        poses.removeAll { $0.id == id }
        persist(poses)
    }

    private func persist(_ poses: [SavedPose]) {
        do {
            let data = try JSONEncoder().encode(poses)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
            DebugLogger.log("✅ Saved \(poses.count) poses to storage")
        } catch {
            DebugLogger.error("Failed to save poses: \(error)")
        }
    }
}
