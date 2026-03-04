import Foundation

/// Centralized debug logging for CheerCOM.
/// Set `DebugLogger.isEnabled` to `false` to silence all debug output in production.
enum DebugLogger {

    #if DEBUG
    static var isEnabled = true
    #else
    static var isEnabled = false
    #endif

    /// Log a message at the default level.
    static func log(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        print(message())
    }

    /// Log a warning (prefixed with ⚠️).
    static func warn(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        guard isEnabled else { return }
        print("⚠️ \(message())")
    }

    /// Log an error (always prints, regardless of `isEnabled`).
    static func error(_ message: @autoclosure () -> String, file: String = #file, line: Int = #line) {
        print("❌ \(message())")
    }
}
