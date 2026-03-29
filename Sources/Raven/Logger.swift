import Foundation

// MARK: - RavenLogger

/// A structured logging system for Raven.
/// Replaces raw `print()` calls with severity-tagged, filterable log output.
///
/// Usage:
/// ```swift
/// RavenLogger.info("Renderer initialized")
/// RavenLogger.warning("Atlas near capacity: \(usage)%")
/// RavenLogger.error("Failed to load font", error: FontError.notFound)
/// ```
///
/// Configuration:
/// ```swift
/// RavenLogger.minimumLevel = .warning  // Suppress info/debug in production
/// ```
public enum RavenLogger {
    /// Log levels in order of severity.
    public enum Level: Int, Comparable, Sendable {
        case debug = 0
        case info = 1
        case warning = 2
        case error = 3
        case critical = 4

        public static func < (lhs: Level, rhs: Level) -> Bool {
            lhs.rawValue < rhs.rawValue
        }

        var tag: String {
            switch self {
            case .debug:    return "[DEBUG]"
            case .info:     return "[INFO]"
            case .warning:  return "[WARNING]"
            case .error:    return "[ERROR]"
            case .critical: return "[CRITICAL]"
            }
        }
    }

    /// Minimum level to output. Messages below this level are silently dropped.
    /// Default: `.debug` in debug builds, `.warning` in release builds.
    public nonisolated(unsafe) static var minimumLevel: Level = {
        #if DEBUG
        return .debug
        #else
        return .warning
        #endif
    }()

    /// Optional custom log handler. If set, receives all log messages instead of printing to stderr.
    /// Useful for integrating with external logging frameworks.
    public nonisolated(unsafe) static var customHandler: ((Level, String, String, String, UInt) -> Void)?

    // MARK: - Log Methods

    public static func debug(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: UInt = #line
    ) {
        log(.debug, message(), file: file, line: line)
    }

    public static func info(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: UInt = #line
    ) {
        log(.info, message(), file: file, line: line)
    }

    public static func warning(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: UInt = #line
    ) {
        log(.warning, message(), file: file, line: line)
    }

    public static func error(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: UInt = #line
    ) {
        log(.error, message(), file: file, line: line)
    }

    public static func critical(
        _ message: @autoclosure () -> String,
        file: String = #fileID,
        line: UInt = #line
    ) {
        log(.critical, message(), file: file, line: line)
    }

    // MARK: - Core Implementation

    private static func log(_ level: Level, _ message: String, file: String, line: UInt) {
        guard level >= minimumLevel else { return }

        if let handler = customHandler {
            handler(level, message, "Raven", file, line)
            return
        }

        // Extract filename from full path
        let filename = file.split(separator: "/").last.map(String.init) ?? file

        let output = "\(level.tag) [\(filename):\(line)] \(message)"
        
        // Write to stderr for log messages (stdout is for app output)
        #if os(Windows)
        print(output)
        #else
        fputs(output + "\n", stderr)
        #endif
    }
}

// MARK: - Error Types

/// Font loading and rendering errors.
public enum FontError: Error, CustomStringConvertible {
    case fileNotFound(String)
    case invalidFont
    case atlasFull
    case glyphNotFound(UInt32)

    public var description: String {
        switch self {
        case .fileNotFound(let path): return "Font file not found: \(path)"
        case .invalidFont: return "Invalid or corrupt font data"
        case .atlasFull: return "Font atlas is full and cannot grow further"
        case .glyphNotFound(let cp): return "Glyph not found for codepoint: \(cp)"
        }
    }
}

/// Vulkan rendering errors.
public enum RendererError: Error, CustomStringConvertible {
    case initializationFailed(String)
    case shaderCompilationFailed(String)
    case deviceLost
    case swapchainOutOfDate

    public var description: String {
        switch self {
        case .initializationFailed(let msg): return "Renderer initialization failed: \(msg)"
        case .shaderCompilationFailed(let msg): return "Shader compilation failed: \(msg)"
        case .deviceLost: return "Vulkan device lost"
        case .swapchainOutOfDate: return "Swapchain out of date"
        }
    }
}

/// Platform layer errors.
public enum PlatformError: Error, CustomStringConvertible {
    case unsupported(String)
    case operationFailed(String)
    case permissionDenied(String)

    public var description: String {
        switch self {
        case .unsupported(let feature): return "Platform feature not supported: \(feature)"
        case .operationFailed(let msg): return "Platform operation failed: \(msg)"
        case .permissionDenied(let msg): return "Permission denied: \(msg)"
        }
    }
}
