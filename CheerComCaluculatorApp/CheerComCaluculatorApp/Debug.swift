import Foundation

/// Conditional debug logging utility.
/// Set `isEnabled` to false for release builds to silence debug output.
enum Debug {
    /// Set to false to disable all debug prints in production
    #if DEBUG
    static var isEnabled: Bool = true
    #else
    static var isEnabled: Bool = false
    #endif

    /// Log a debug message (only prints when `isEnabled` is true)
    static func log(_ message: String) {
        guard isEnabled else { return }
        print(message)
    }

    /// Log with a category prefix
    static func log(_ category: String, _ message: String) {
        guard isEnabled else { return }
        print("[\(category)] \(message)")
    }
}
