import Foundation
import SceneKit

final class JointPresetStorageManager {
    static let shared = JointPresetStorageManager()

    private let userDefaultsKey = "saved_joint_presets"

    private init() {}

    func loadPresets(for jointName: String) -> [SavedJointPreset] {
        loadAllPresets()
            .filter { $0.jointName == jointName }
            .sorted { $0.createdAt > $1.createdAt }
    }

    func savePreset(name: String, jointName: String, angles: SCNVector3) {
        var presets = loadAllPresets()
        presets.append(
            SavedJointPreset(
                name: name,
                jointName: jointName,
                jointAngles: [angles.x, angles.y, angles.z]
            )
        )
        persist(presets)
    }

    func deletePreset(id: UUID) {
        var presets = loadAllPresets()
        presets.removeAll { $0.id == id }
        persist(presets)
    }

    private func loadAllPresets() -> [SavedJointPreset] {
        guard let data = UserDefaults.standard.data(forKey: userDefaultsKey) else {
            return []
        }

        do {
            return try JSONDecoder().decode([SavedJointPreset].self, from: data)
        } catch {
            print("Failed to load joint presets: \(error)")
            return []
        }
    }

    private func persist(_ presets: [SavedJointPreset]) {
        do {
            let data = try JSONEncoder().encode(presets)
            UserDefaults.standard.set(data, forKey: userDefaultsKey)
        } catch {
            print("Failed to save joint presets: \(error)")
        }
    }
}
