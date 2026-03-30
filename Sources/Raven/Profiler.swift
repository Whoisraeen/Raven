import Foundation

// MARK: - Performance Profiler

/// A lightweight, cross-platform performance profiler for Raven.
/// Measures frame timing, layout duration, and GPU submission latency.
///
/// Usage:
/// ```swift
/// Profiler.shared.begin(.layout)
/// // ... layout work ...
/// Profiler.shared.end(.layout)
///
/// // Enable the overlay:
/// Profiler.shared.overlayEnabled = true
/// ```
///
/// Integration with Apple signpost on macOS:
/// ```swift
/// Profiler.shared.useSignposts = true  // macOS only
/// ```
public class Profiler: @unchecked Sendable {
    nonisolated(unsafe) public static let shared = Profiler()

    /// Profiling stages within a single frame.
    public enum Stage: String, CaseIterable, Sendable {
        case eventHandling = "Events"
        case viewResolve   = "ViewResolve"
        case layout        = "Layout"
        case animation     = "Animation"
        case renderCollect = "RenderCollect"
        case gpuSubmit     = "GPUSubmit"
        case frameTotal    = "Frame"
    }

    /// Whether to collect profiling data. Disabled in release builds by default.
    public var enabled: Bool = {
        #if DEBUG
        return true
        #else
        return false
        #endif
    }()

    /// Whether to display an on-screen performance overlay.
    public var overlayEnabled: Bool = false

    /// Whether to emit Apple signposts (macOS only).
    public var useSignposts: Bool = false

    /// Number of frames to keep in the rolling history.
    public var historySize: Int = 120

    // MARK: - Internal State

    private let lock = RavenLock()

    /// Current frame's start timestamps (nanoseconds).
    private var stageStarts: [Stage: UInt64] = [:]

    /// Current frame's measured durations (nanoseconds).
    private var currentFrame: [Stage: UInt64] = [:]

    /// Rolling history of frame durations for averaging.
    private var history: [Stage: [Double]] = [:]

    /// Last completed frame snapshot (for overlay rendering).
    private(set) var lastFrameTimings: [Stage: Double] = [:]

    /// Frame counter.
    private(set) var frameCount: UInt64 = 0

    private init() {
        for stage in Stage.allCases {
            history[stage] = []
        }
    }

    // MARK: - Timing API

    /// Mark the beginning of a profiling stage.
    public func begin(_ stage: Stage) {
        guard enabled else { return }
        let now = currentTimeNanos()
        lock.withLock {
            stageStarts[stage] = now
        }

        #if os(macOS)
        if useSignposts {
            emitSignpostBegin(stage)
        }
        #endif
    }

    /// Mark the end of a profiling stage.
    public func end(_ stage: Stage) {
        guard enabled else { return }
        let now = currentTimeNanos()

        lock.withLock {
            guard let start = stageStarts[stage] else { return }
            let elapsed = now - start
            currentFrame[stage] = elapsed
            stageStarts.removeValue(forKey: stage)
        }

        #if os(macOS)
        if useSignposts {
            emitSignpostEnd(stage)
        }
        #endif
    }

    /// Call at the end of each frame to finalize timings and update history.
    public func endFrame() {
        guard enabled else { return }

        lock.withLock {
            frameCount += 1

            for (stage, nanos) in currentFrame {
                let ms = Double(nanos) / 1_000_000.0
                lastFrameTimings[stage] = ms

                if history[stage] == nil {
                    history[stage] = []
                }
                history[stage]!.append(ms)
                if history[stage]!.count > historySize {
                    history[stage]!.removeFirst()
                }
            }

            currentFrame.removeAll(keepingCapacity: true)
        }
    }

    // MARK: - Query API

    /// Average duration for a stage over the rolling history window (in milliseconds).
    public func averageTime(for stage: Stage) -> Double {
        lock.withLock {
            guard let values = history[stage], !values.isEmpty else { return 0 }
            return values.reduce(0, +) / Double(values.count)
        }
    }

    /// Maximum duration for a stage over the rolling history window (in milliseconds).
    public func maxTime(for stage: Stage) -> Double {
        lock.withLock {
            return history[stage]?.max() ?? 0
        }
    }

    /// Minimum duration for a stage over the rolling history window (in milliseconds).
    public func minTime(for stage: Stage) -> Double {
        lock.withLock {
            return history[stage]?.min() ?? 0
        }
    }

    /// Current FPS based on the frame total timing.
    public var currentFPS: Double {
        guard let frameMs = lastFrameTimings[.frameTotal], frameMs > 0 else { return 0 }
        return 1000.0 / frameMs
    }

    /// Average FPS over the history window.
    public var averageFPS: Double {
        let avg = averageTime(for: .frameTotal)
        guard avg > 0 else { return 0 }
        return 1000.0 / avg
    }

    /// Generate a formatted summary string of current performance metrics.
    public func summary() -> String {
        var lines: [String] = []
        lines.append("=== Raven Profiler (frame #\(frameCount)) ===")
        lines.append(String(format: "FPS: %.1f (avg: %.1f)", currentFPS, averageFPS))

        for stage in Stage.allCases {
            let avg = averageTime(for: stage)
            let max = maxTime(for: stage)
            let last = lastFrameTimings[stage] ?? 0
            lines.append(String(format: "  %-14s  last: %6.2fms  avg: %6.2fms  max: %6.2fms",
                                (stage.rawValue as NSString).utf8String!,
                                last, avg, max))
        }

        return lines.joined(separator: "\n")
    }

    /// Generate overlay text commands for rendering the profiler on screen.
    /// Returns an array of (text, y-offset) pairs for the renderer.
    public func overlayLines() -> [(text: String, yOffset: Float)] {
        guard overlayEnabled else { return [] }
        var lines: [(String, Float)] = []
        var y: Float = 8

        lines.append((String(format: "FPS: %.0f", currentFPS), y))
        y += 16

        for stage in Stage.allCases where stage != .frameTotal {
            let ms = lastFrameTimings[stage] ?? 0
            let bar = String(repeating: "█", count: min(Int(ms * 2), 40))
            lines.append((String(format: "%-12s %5.2fms %@", stage.rawValue, ms, bar), y))
            y += 14
        }

        let frameMs = lastFrameTimings[.frameTotal] ?? 0
        lines.append((String(format: "Frame Total: %.2fms", frameMs), y))

        return lines
    }

    /// Reset all collected profiling data.
    public func reset() {
        lock.withLock {
            stageStarts.removeAll()
            currentFrame.removeAll()
            lastFrameTimings.removeAll()
            frameCount = 0
            for stage in Stage.allCases {
                history[stage] = []
            }
        }
    }

    // MARK: - High-Resolution Timing

    /// Returns the current time in nanoseconds.
    private func currentTimeNanos() -> UInt64 {
        return DispatchTime.now().uptimeNanoseconds
    }

    // MARK: - Signpost Integration (macOS only)

    #if os(macOS)
    private func emitSignpostBegin(_ stage: Stage) {
        // os_signpost integration placeholder
        // Requires importing os.signpost and creating a log handle
        // For now, this is a hook point for future integration
    }

    private func emitSignpostEnd(_ stage: Stage) {
        // os_signpost integration placeholder
    }
    #endif
}
