// MARK: - ProgressView

/// A progress indicator showing completion of a task.
///
/// Usage:
/// ```swift
/// // Determinate (known progress)
/// ProgressView(value: 0.65)
///
/// // Indeterminate (spinner-style, not yet animated)
/// ProgressView()
/// ```
public struct ProgressView: View {
    public typealias Body = Never

    let value: Float?
    let label: String

    /// Create an indeterminate progress view (no specific progress).
    public init(label: String = "") {
        self.value = nil
        self.label = label
    }

    /// Create a determinate progress view with a specific value (0.0 to 1.0).
    public init(value: Float, label: String = "") {
        self.value = Swift.min(Swift.max(value, 0), 1)
        self.label = label
    }

    public var body: Never { fatalError("ProgressView is a primitive") }
}
