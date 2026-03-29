// MARK: - ProgressView

/// A progress indicator that shows completion state.
/// Can be determinate (with a specific value) or indeterminate (spinner/pulse).
///
/// Usage:
/// ```swift
/// // Determinate — shows a filled progress bar:
/// ProgressView("Downloading...", value: 0.65)
///
/// // Custom total:
/// ProgressView("Files", value: 42, total: 100)
///
/// // Indeterminate — shows a pulsing bar:
/// ProgressView("Loading...")
/// ```
public struct ProgressView: View {
    public typealias Body = Never
    public var body: Never { fatalError("ProgressView is a primitive view") }

    /// Optional label displayed above the progress bar.
    public let label: String

    /// Current progress value. If nil, the progress view is indeterminate.
    public let value: Float?

    /// Maximum value (default 1.0).
    public let total: Float

    public init(_ label: String = "", value: Float? = nil, total: Float = 1.0) {
        self.label = label
        self.value = value
        self.total = total
    }
}
