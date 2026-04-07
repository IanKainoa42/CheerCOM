import Foundation
import CryptoKit

/// Source of truth for the tumbling skill vocabulary. Edited by the user in CheerCOM,
/// consumed by the training pipeline and FlightFilter runtime.
public struct VocabularyManifest: Codable, Equatable {
    public let schemaVersion: Int
    public var atoms: [VocabularyAtom]
    public var bodylines: [VocabularyBodyline]

    public init(
        schemaVersion: Int = 1,
        atoms: [VocabularyAtom] = [],
        bodylines: [VocabularyBodyline] = []
    ) {
        self.schemaVersion = schemaVersion
        self.atoms = atoms
        self.bodylines = bodylines
    }

    /// Stable SHA-256 hash of the manifest's sorted, JSON-encoded content.
    /// Used to verify that a trained model and a manifest match at runtime.
    /// The hash is order-independent for tag sets (tags are sorted before encoding).
    public func contentHash() -> String {
        // Re-encode with a canonical form: sort tags alphabetically so set order
        // doesn't influence the hash.
        let canonical = VocabularyManifest(
            schemaVersion: schemaVersion,
            atoms: atoms.map { atom in
                VocabularyAtom(
                    id: atom.id,
                    displayName: atom.displayName,
                    category: atom.category,
                    tags: Set(atom.tags),
                    createdAt: atom.createdAt
                )
            },
            bodylines: bodylines
        )
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.sortedKeys]
        encoder.dateEncodingStrategy = .iso8601
        guard let data = try? encoder.encode(canonical) else { return "" }
        let digest = SHA256.hash(data: data)
        return digest.map { String(format: "%02x", $0) }.joined()
    }
}

public struct VocabularyAtom: Codable, Equatable, Identifiable {
    public let id: String
    public var displayName: String
    public var category: String
    public var tags: Set<String>
    public let createdAt: Date

    public init(
        id: String,
        displayName: String,
        category: String,
        tags: Set<String> = [],
        createdAt: Date = Date()
    ) {
        self.id = id
        self.displayName = displayName
        self.category = category
        self.tags = tags
        self.createdAt = createdAt
    }

    public func hasTag(_ tag: String) -> Bool { tags.contains(tag) }

    // Custom Codable to ensure tag-set encoding is stable (sorted) for hash equality.
    enum CodingKeys: String, CodingKey {
        case id, displayName, category, tags, createdAt
    }

    public init(from decoder: Decoder) throws {
        let c = try decoder.container(keyedBy: CodingKeys.self)
        self.id = try c.decode(String.self, forKey: .id)
        self.displayName = try c.decode(String.self, forKey: .displayName)
        self.category = try c.decode(String.self, forKey: .category)
        let tagArray = try c.decode([String].self, forKey: .tags)
        self.tags = Set(tagArray)
        self.createdAt = try c.decode(Date.self, forKey: .createdAt)
    }

    public func encode(to encoder: Encoder) throws {
        var c = encoder.container(keyedBy: CodingKeys.self)
        try c.encode(id, forKey: .id)
        try c.encode(displayName, forKey: .displayName)
        try c.encode(category, forKey: .category)
        try c.encode(tags.sorted(), forKey: .tags)
        try c.encode(createdAt, forKey: .createdAt)
    }
}

public struct VocabularyBodyline: Codable, Equatable, Identifiable {
    public let id: String
    public var displayName: String
    public let createdAt: Date

    public init(id: String, displayName: String, createdAt: Date = Date()) {
        self.id = id
        self.displayName = displayName
        self.createdAt = createdAt
    }
}
