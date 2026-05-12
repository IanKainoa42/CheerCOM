import Foundation

final class AnimatorWorkspaceStorage {
    static let shared = AnimatorWorkspaceStorage()

    private init() {}

    private var workspaceDirectory: URL {
        let fileManager = FileManager.default
        let documentsURL = fileManager.urls(for: .documentDirectory, in: .userDomainMask)[0]
        let directory = documentsURL.appendingPathComponent("CheerCOMAnimator", isDirectory: true)
        if !fileManager.fileExists(atPath: directory.path) {
            try? fileManager.createDirectory(at: directory, withIntermediateDirectories: true)
        }
        return directory
    }

    private var workspaceURL: URL {
        workspaceDirectory.appendingPathComponent("workspace.json")
    }

    func save(_ state: AnimatorWorkspaceState) throws {
        let encoder = JSONEncoder()
        encoder.outputFormatting = [.prettyPrinted, .sortedKeys]
        let data = try encoder.encode(state)
        try data.write(to: workspaceURL, options: .atomic)
    }

    func load() throws -> AnimatorWorkspaceState {
        let data = try Data(contentsOf: workspaceURL)
        return try JSONDecoder().decode(AnimatorWorkspaceState.self, from: data)
    }

    func loadIfPresent() -> AnimatorWorkspaceState? {
        try? load()
    }

    func clear() {
        try? FileManager.default.removeItem(at: workspaceURL)
    }
}
