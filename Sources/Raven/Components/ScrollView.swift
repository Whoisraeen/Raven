// MARK: - ScrollView

/// A scrollable container that clips its children to its bounds.
/// Uses Vulkan scissor rectangles for hardware-accelerated clipping.
///
/// Usage:
/// ```swift
/// ScrollView {
///     VStack(spacing: 8) {
///         ForEach(0..<100) { i in
///             Text("Item \(i)")
///         }
///     }
/// }
/// .frame(height: 400)
/// ```
public struct ScrollView: View {
    public typealias Body = Never
    public var body: Never { fatalError("ScrollView is a primitive view") }

    /// The content to scroll
    public let content: [any View]

    /// Scroll axis (.vertical or .horizontal)
    public let axis: ScrollAxis

    /// Shared scroll offset state (automatically created)
    public let scrollOffset: StateVar<Float>

    public init(_ axis: ScrollAxis = .vertical,
                @ViewBuilder content: () -> any View) {
        self.axis = axis
        self.scrollOffset = StateVar(0)
        // Store content as array for resolution
        let built = content()
        self.content = [built]
    }
}

// MARK: - ScrollAxis

public enum ScrollAxis: Sendable {
    case vertical
    case horizontal
}
