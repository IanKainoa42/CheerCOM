import Foundation

/// Loads and saves VocabularyManifest to a JSON file in the app's Documents directory.
/// Singleton; use `VocabularyManager.shared`.
public final class VocabularyManager {
    public static let shared = VocabularyManager()

    private let manifestFilename = "vocabulary_manifest.json"
    private var cachedManifest: VocabularyManifest?

    private init() {}

    // MARK: - File URL

    private var manifestURL: URL {
        let fm = FileManager.default
        let docsURL = fm.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let cheerDir = docsURL.appendingPathComponent("CheerCOMAnimations", isDirectory: true)
        if !fm.fileExists(atPath: cheerDir.path) {
            try? fm.createDirectory(at: cheerDir, withIntermediateDirectories: true)
        }
        return cheerDir.appendingPathComponent(manifestFilename)
    }

    // MARK: - Load / Save

    public func load() -> VocabularyManifest {
        if let cached = cachedManifest { return cached }

        let fm = FileManager.default
        guard fm.fileExists(atPath: manifestURL.path),
              let data = try? Data(contentsOf: manifestURL) else {
            let seed = VocabularyManifest()
            cachedManifest = seed
            return seed
        }
        let decoder = JSONDecoder()
        decoder.dateDecodingStrategy = .iso8601
        guard let manifest = try? decoder.decode(VocabularyManifest.self, from: data) else {
            let seed = VocabularyManifest()
            cachedManifest = seed
            return seed
        }
        cachedManifest = manifest
        return manifest
    }

    public func save(_ manifest: VocabularyManifest) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        let data = try encoder.encode(manifest)
        try data.write(to: manifestURL, options: .atomic)
        cachedManifest = manifest
    }

    // MARK: - Mutations

    @discardableResult
    public func addAtom(
        id: String,
        displayName: String,
        category: String = "tumbling",
        tags: Set<String> = []
    ) throws -> VocabularyManifest {
        var manifest = load()
        guard !manifest.atoms.contains(where: { $0.id == id }) else {
            throw VocabularyError.atomAlreadyExists(id: id)
        }
        manifest.atoms.append(VocabularyAtom(
            id: id, displayName: displayName, category: category, tags: tags
        ))
        try save(manifest)
        return manifest
    }

    @discardableResult
    public func addBodyline(id: String, displayName: String) throws -> VocabularyManifest {
        var manifest = load()
        guard !manifest.bodylines.contains(where: { $0.id == id }) else {
            throw VocabularyError.bodylineAlreadyExists(id: id)
        }
        manifest.bodylines.append(VocabularyBodyline(id: id, displayName: displayName))
        try save(manifest)
        return manifest
    }

    @discardableResult
    public func removeAtom(id: String) throws -> VocabularyManifest {
        var manifest = load()
        manifest.atoms.removeAll { $0.id == id }
        try save(manifest)
        return manifest
    }

    @discardableResult
    public func removeBodyline(id: String) throws -> VocabularyManifest {
        var manifest = load()
        manifest.bodylines.removeAll { $0.id == id }
        try save(manifest)
        return manifest
    }

    // Test-only: reset the in-memory cache and delete the on-disk manifest.
    public func _resetForTesting() {
        cachedManifest = nil
        try? FileManager.default.removeItem(at: manifestURL)
    }
}

public enum VocabularyError: Error, Equatable {
    case atomAlreadyExists(id: String)
    case bodylineAlreadyExists(id: String)
}
