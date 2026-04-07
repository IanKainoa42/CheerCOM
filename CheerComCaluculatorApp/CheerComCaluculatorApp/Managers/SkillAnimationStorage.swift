import Foundation

/// File-based storage for SkillAnimations. Stores one JSON file per animation
/// in Documents/CheerCOMAnimations/<animation_id>.anim.json.
public final class SkillAnimationStorage {
    public static let shared = SkillAnimationStorage()

    private init() {}

    // MARK: - Directory

    private var animationsDirectory: URL {
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cheerDir = docsURL.appendingPathComponent("CheerCOMAnimations", isDirectory: true)
        if !fm.fileExists(atPath: cheerDir.path) {
            try? fm.createDirectory(at: cheerDir, withIntermediateDirectories: true)
        }
        return cheerDir
    }

    private func fileURL(for id: UUID) -> URL {
        animationsDirectory.appendingPathComponent("\(id.uuidString).anim.json")
    }

    // MARK: - CRUD

    public func save(_ animation: SkillAnimation) throws {
        var updated = animation
        updated.updatedAt = Date()
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(updated)
        try data.write(to: fileURL(for: updated.id), options: .atomic)
    }

    public func load(id: UUID) throws -> SkillAnimation {
        let data = try Data(contentsOf: fileURL(for: id))
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return try decoder.decode(SkillAnimation.self, from: data)
    }

    public func listAll() -> [SkillAnimation] {
        let fm = FileManager.default
        guard let files = try? fm.contentsOfDirectory(at: animationsDirectory, includingPropertiesForKeys: nil) else {
            return []
        }
        let animationFiles = files.filter { $0.lastPathComponent.hasSuffix(".anim.json") }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        return animationFiles.compactMap { url in
            guard let data = try? Data(contentsOf: url) else { return nil }
            return try? decoder.decode(SkillAnimation.self, from: data)
        }.sorted { $0.updatedAt > $1.updatedAt }
    }

    public func delete(id: UUID) throws {
        try FileManager.default.removeItem(at: fileURL(for: id))
    }

    // Test-only: wipe all animations in the directory.
    public func _resetForTesting() {
        let fm = FileManager.default
        if let files = try? fm.contentsOfDirectory(at: animationsDirectory, includingPropertiesForKeys: nil) {
            for url in files where url.lastPathComponent.hasSuffix(".anim.json") {
                try? fm.removeItem(at: url)
            }
        }
    }
}
