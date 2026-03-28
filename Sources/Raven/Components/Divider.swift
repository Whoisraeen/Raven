// MARK: - Divider

/// A visual separator line.
///
/// Usage:
/// ```swift
/// VStack {
///     Text("Above")
///     Divider()
///     Text("Below")
/// }
/// ```
public struct Divider: View {
    public typealias Body = Never
    public var body: Never { fatalError("Divider is a primitive view") }

    public init() {}
}
