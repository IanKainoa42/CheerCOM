import Foundation
import SceneKit



class PoseStorageManager {
    static let shared = PoseStorageManager()

    private let userDefaultsKey = "saved_poses"
    private let bodylineTagsKey = "saved_pose_bodylines"

    private init() {}

    // MARK: - Bodyline Tagging (sidecar)

    /// Loads the pose-id → bodyline-id map from sidecar storage.
    private func loadBodylineTags() -> [String: String] {
        guard let data = UserDefaults.standard.data(forKey: bodylineTagsKey),
              let map = try? JSONDecoder().decode([String: String].self, from: data) else {
            return [:]
        }
        return map
    }

    /// Persists the pose-id → bodyline-id map.
    private func persistBodylineTags(_ map: [String: String]) {
        guard let data = try? JSONEncoder().encode(map) else { return }
        UserDefaults.standard.set(data, forKey: bodylineTagsKey)
    }

    /// Tags a pose with a bodyline id. Nil id removes any existing tag.
    public func setBodyline(poseId: UUID, bodylineId: String?) {
        var map = loadBodylineTags()
        if let bodylineId = bodylineId {
            map[poseId.uuidString] = bodylineId
        } else {
            map.removeValue(forKey: poseId.uuidString)
        }
        persistBodylineTags(map)
    }

    public func bodyline(for poseId: UUID) -> String? {
        return loadBodylineTags()[poseId.uuidString]
    }

    /// Returns all saved poses paired with their bodyline tags.
    public func loadPosesWithBodylines() -> [BodylineTaggedPose] {
        let poses = loadPoses()
        let tags = loadBodylineTags()
        return poses.map { pose in
            BodylineTaggedPose(pose: pose, bodylineId: tags[pose.id.uuidString])
        }
    }

    /// Test-only: clear all bodyline tags.
    public func _resetBodylineTagsForTesting() {
        UserDefaults.standard.removeObject(forKey: bodylineTagsKey)
    }

    func savePose(name: String, jointPositions: [String: SCNVector3]) {
        var poses = loadPoses()

        // Convert SCNVector3 to [Float]
        var codableAngles: [String: [Float]] = [:]
        for (joint, angle) in jointPositions {
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
            print("Failed to load poses: \(error)")
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
            print("Saved \(poses.count) poses to storage")
        } catch {
            print("Failed to save poses: \(error)")
        }
    }

    // MARK: - Import/Export JSON

    func exportPosesToJSON() -> String? {
        let poses = loadPoses()
        let encoder = JSONEncoder()
        do {
            let data = try encoder.encode(poses)
            return String(data: data, encoding: .utf8)
        } catch {
            print("Failed to export poses: \(error)")
            return nil
        }
    }

    func importPosesFromJSON(jsonString: String) {
        guard let data = jsonString.data(using: .utf8) else { return }
        do {
            let importedPoses = try JSONDecoder().decode([SavedPose].self, from: data)
            var currentPoses = loadPoses()

            // Merge poses, preferring imported ones if IDs collide, or just append
            for pose in importedPoses {
                if let index = currentPoses.firstIndex(where: { $0.id == pose.id }) {
                    currentPoses[index] = pose
                } else {
                    currentPoses.append(pose)
                }
            }
            persist(currentPoses)
            print("Imported \(importedPoses.count) poses from JSON")
        } catch {
            print("Failed to import poses from JSON: \(error)")
        }
    }
}
