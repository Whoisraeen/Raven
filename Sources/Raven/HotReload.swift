import Foundation

// MARK: - HotReloadEngine

/// Advanced hot reload system for Raven.
///
/// Monitors source files for changes using a polling-based file watcher,
/// detects modifications, and triggers a view tree rebuild while preserving
/// application state. Uses a state snapshot/restore mechanism to keep
/// StateVar values across reloads.
///
/// ## Architecture
///
/// ```
/// FileWatcher (polls modification times)
///   ↓ change detected
/// StateSnapshotManager (serializes all registered StateVars)
///   ↓ state saved
/// RavenApp.contentBuilder() re-invoked
///   ↓ new view tree
/// ViewResolver + LayoutEngine (fresh layout pass)
///   ↓ rendered
/// StateSnapshotManager (restores saved state)
/// ```
///
/// ## Usage
///
/// Hot reload is enabled automatically in DEBUG builds:
/// ```swift
/// let app = RavenApp(title: "My App") { ... }
/// app.run()  // Hot reload active — edit source files and see changes live
/// ```
///
/// Configure via environment:
/// ```
/// RAVEN_HOT_RELOAD=1          # Force enable in release
/// RAVEN_HOT_RELOAD=0          # Force disable in debug
/// RAVEN_WATCH_PATHS=src,lib   # Custom watch directories (comma-separated)
/// RAVEN_WATCH_INTERVAL=500    # Poll interval in milliseconds (default: 500)
/// ```
public final class HotReloadEngine: @unchecked Sendable {
    /// Singleton instance
    @MainActor public static let shared = HotReloadEngine()

    /// Whether hot reload is currently active.
    public private(set) var isActive: Bool = false

    /// Paths being watched.
    public private(set) var watchedPaths: [String] = []

    /// Poll interval in milliseconds.
    public var pollIntervalMs: UInt64 = 500

    /// Callback invoked when a file change is detected.
    /// The RavenApp sets this to trigger a view rebuild.
    public var onReloadNeeded: (() -> Void)?

    /// Callback for reporting watch status changes.
    public var onStatusChange: ((HotReloadStatus) -> Void)?

    // The file modification time cache
    private var fileModificationCache: [String: Date] = [:]

    // Watcher state
    private var watcherThread: Thread?
    private var shouldStop: Bool = false
    private let lock = NSLock()

    // Statistics
    private var reloadCount: Int = 0
    private var lastReloadTime: Date?

    private init() {}

    // MARK: - Lifecycle

    /// Start watching for file changes.
    /// - Parameter paths: Directory paths to watch recursively for .swift files.
    ///   Defaults to `["Sources/"]` relative to the executable.
    public func start(watchPaths: [String]? = nil) {
        lock.lock()
        defer { lock.unlock() }

        guard !isActive else {
            RavenLogger.warning("HotReloadEngine already active")
            return
        }

        // Determine paths to watch
        let paths: [String]
        if let custom = watchPaths {
            paths = custom
        } else if let envPaths = getEnvironmentVariable("RAVEN_WATCH_PATHS") {
            paths = envPaths.split(separator: ",").map(String.init)
        } else {
            // Default: watch Sources/ relative to CWD and executable directory
            let cwd = FileManager.default.currentDirectoryPath
            paths = [
                "\(cwd)/Sources",
                "\(cwd)/src",
            ]
        }

        // Check for custom poll interval
        if let intervalStr = getEnvironmentVariable("RAVEN_WATCH_INTERVAL"),
           let interval = UInt64(intervalStr) {
            pollIntervalMs = interval
        }

        watchedPaths = paths.filter { FileManager.default.fileExists(atPath: $0) }

        if watchedPaths.isEmpty {
            RavenLogger.warning("HotReloadEngine: No valid watch paths found. Tried: \(paths)")
            return
        }

        // Build initial file cache
        fileModificationCache = buildFileCache(paths: watchedPaths)

        isActive = true
        shouldStop = false

        RavenLogger.info("Hot Reload active — watching \(watchedPaths.count) path(s), \(fileModificationCache.count) files")
        RavenLogger.info("  Paths: \(watchedPaths.joined(separator: ", "))")
        RavenLogger.info("  Poll interval: \(pollIntervalMs)ms")

        onStatusChange?(.started(paths: watchedPaths, fileCount: fileModificationCache.count))

        // Start watcher thread
        let thread = Thread {
            self.watchLoop()
        }
        thread.name = "RavenHotReload"
        thread.qualityOfService = .utility
        watcherThread = thread
        thread.start()
    }

    /// Stop the file watcher.
    public func stop() {
        lock.lock()
        defer { lock.unlock() }

        shouldStop = true
        isActive = false
        watcherThread = nil
        RavenLogger.info("Hot Reload stopped (total reloads: \(reloadCount))")
        onStatusChange?(.stopped(totalReloads: reloadCount))
    }

    // MARK: - Watch Loop

    private func watchLoop() {
        while true {
            lock.lock()
            let stop = shouldStop
            lock.unlock()

            if stop { break }

            // Sleep for the poll interval
            Thread.sleep(forTimeInterval: Double(pollIntervalMs) / 1000.0)

            // Check for changes
            let changes = detectChanges()
            if !changes.isEmpty {
                lock.lock()
                reloadCount += 1
                lastReloadTime = Date()
                let count = reloadCount
                lock.unlock()

                for change in changes {
                    RavenLogger.info("Hot Reload [\(count)]: \(change.type.symbol) \(change.relativePath)")
                }

                onStatusChange?(.reloading(changes: changes, reloadNumber: count))

                // Trigger the reload via the attached callback
                DispatchQueue.main.async {
                    self.onReloadNeeded?()
                }

                onStatusChange?(.reloaded(reloadNumber: count))
            }
        }
    }

    // MARK: - Change Detection

    private func detectChanges() -> [FileChange] {
        var changes: [FileChange] = []
        let currentCache = buildFileCache(paths: watchedPaths)

        // Check for modifications and new files
        for (path, modDate) in currentCache {
            if let previousDate = fileModificationCache[path] {
                if modDate > previousDate {
                    changes.append(FileChange(path: path, type: .modified))
                }
            } else {
                changes.append(FileChange(path: path, type: .added))
            }
        }

        // Check for deleted files
        for path in fileModificationCache.keys {
            if currentCache[path] == nil {
                changes.append(FileChange(path: path, type: .deleted))
            }
        }

        // Update cache
        lock.lock()
        fileModificationCache = currentCache
        lock.unlock()

        return changes
    }

    // MARK: - File Scanning

    private func buildFileCache(paths: [String]) -> [String: Date] {
        var cache: [String: Date] = [:]
        let fm = FileManager.default

        for basePath in paths {
            guard let enumerator = fm.enumerator(atPath: basePath) else { continue }

            while let relativePath = enumerator.nextObject() as? String {
                // Only watch Swift source files
                guard relativePath.hasSuffix(".swift") else { continue }

                // Optimized path building to avoid interpolation overhead in tight loops
                let fullPath = [basePath, relativePath].joined(separator: "/")

                if let attrs = try? fm.attributesOfItem(atPath: fullPath),
                   let modDate = attrs[.modificationDate] as? Date {
                    cache[fullPath] = modDate
                }
            }
        }

        return cache
    }

    // MARK: - Helpers

    private func getEnvironmentVariable(_ name: String) -> String? {
        ProcessInfo.processInfo.environment[name]
    }

    /// Get reload statistics.
    public var statistics: HotReloadStatistics {
        lock.lock()
        defer { lock.unlock() }
        return HotReloadStatistics(
            isActive: isActive,
            reloadCount: reloadCount,
            lastReloadTime: lastReloadTime,
            watchedFileCount: fileModificationCache.count,
            watchedPaths: watchedPaths,
            pollIntervalMs: pollIntervalMs
        )
    }
}

// MARK: - State Snapshot Manager

/// Manages serialization and restoration of StateVar values across hot reloads.
/// State is preserved by storing values keyed by their declaration identity (label).
///
/// How it works:
/// 1. Before a reload, all registered StateVars are snapshotted to a dictionary.
/// 2. After the view tree is rebuilt, matching StateVars are restored from the snapshot.
/// 3. Unmatched StateVars (new or deleted) are initialized/discarded gracefully.
public final class StateSnapshotManager: @unchecked Sendable {
    @MainActor public static let shared = StateSnapshotManager()

    /// Registry of named state values. StateVars register themselves on creation.
    private var registry: [String: AnyStateSnapshot] = [:]
    private let lock = NSLock()

    /// Last snapshot taken before a reload.
    private var snapshot: [String: Any] = [:]

    private init() {}

    // MARK: - Registration

    /// Register a StateVar with a string key for state preservation.
    public func register<T: Sendable>(_ stateVar: StateVar<T>, key: String) {
        lock.lock()
        defer { lock.unlock() }

        registry[key] = AnyStateSnapshot(
            save: { stateVar.value },
            restore: { value in
                if let typedValue = value as? T {
                    stateVar.value = typedValue
                }
            }
        )
    }

    /// Unregister a state key.
    public func unregister(key: String) {
        lock.lock()
        defer { lock.unlock() }
        registry.removeValue(forKey: key)
    }

    // MARK: - Snapshot & Restore

    /// Take a snapshot of all registered state. Call before reload.
    public func takeSnapshot() {
        lock.lock()
        defer { lock.unlock() }

        snapshot.removeAll(keepingCapacity: true)
        for (key, entry) in registry {
            snapshot[key] = entry.save()
        }

        RavenLogger.debug("State snapshot taken: \(snapshot.count) values")
    }

    /// Restore state from the last snapshot. Call after rebuild.
    public func restoreSnapshot() {
        lock.lock()
        defer { lock.unlock() }

        var restored = 0
        var skipped = 0

        for (key, value) in snapshot {
            if let entry = registry[key] {
                entry.restore(value)
                restored += 1
            } else {
                skipped += 1
            }
        }

        RavenLogger.debug("State restored: \(restored) values (\(skipped) unmatched)")
        snapshot.removeAll()
    }

    /// Check if a snapshot is available.
    public var hasSnapshot: Bool {
        lock.lock()
        defer { lock.unlock() }
        return !snapshot.isEmpty
    }

    /// The number of registered state keys.
    public var registeredCount: Int {
        lock.lock()
        defer { lock.unlock() }
        return registry.count
    }
}

// MARK: - Supporting Types

/// A type-erased wrapper for state snapshot operations.
private struct AnyStateSnapshot {
    let save: () -> Any
    let restore: (Any) -> Void
}

/// Describes a detected file change.
public struct FileChange: Sendable {
    public let path: String
    public let type: ChangeType

    public var relativePath: String {
        // Strip common path prefixes for clean display
        let components = path.split(separator: "/")
        if components.count > 2 {
            return components.suffix(2).joined(separator: "/")
        }
        return path
    }

    public enum ChangeType: Sendable {
        case modified
        case added
        case deleted

        public var symbol: String {
            switch self {
            case .modified: return "📝"
            case .added: return "➕"
            case .deleted: return "🗑️"
            }
        }
    }
}

/// Hot reload status events.
public enum HotReloadStatus: Sendable {
    case started(paths: [String], fileCount: Int)
    case reloading(changes: [FileChange], reloadNumber: Int)
    case reloaded(reloadNumber: Int)
    case stopped(totalReloads: Int)
    case error(String)
}

/// Hot reload statistics.
public struct HotReloadStatistics: Sendable {
    public let isActive: Bool
    public let reloadCount: Int
    public let lastReloadTime: Date?
    public let watchedFileCount: Int
    public let watchedPaths: [String]
    public let pollIntervalMs: UInt64
}

// MARK: - StateVar Extension for Hot Reload

extension StateVar {
    /// Register this StateVar for state preservation across hot reloads.
    /// Call this when creating named state to ensure values survive reloads.
    ///
    /// Usage:
    /// ```swift
    /// let counter = StateVar(0).preserveOnReload("counter")
    /// let name = StateVar("Raven").preserveOnReload("userName")
    /// ```
    @discardableResult
    public func preserveOnReload(_ key: String) -> Self {
        StateSnapshotManager.shared.register(self, key: key)
        return self
    }
}
