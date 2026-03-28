// MARK: - FlowStack

/// A view that arranges its children horizontally, wrapping to the next line when
/// the available width is exceeded. This is the `flex-wrap` equivalent.
///
/// Usage:
/// ```swift
/// FlowStack(spacing: 8, lineSpacing: 12) {
///     Text("Tag 1").padding(8).background(.surface).cornerRadius(4)
///     Text("Tag 2").padding(8).background(.surface).cornerRadius(4)
///     Text("Tag 3").padding(8).background(.surface).cornerRadius(4)
///     // ... wraps automatically
/// }
/// ```
public struct FlowStack: View {
    public typealias Body = Never
    public var body: Never { fatalError("FlowStack is a primitive view") }

    public let spacing: Float
    public let lineSpacing: Float
    internal let childViews: [any View]

    public init(
        spacing: Float = 8,
        lineSpacing: Float = 8,
        @ViewBuilder content: () -> some View
    ) {
        self.spacing = spacing
        self.lineSpacing = lineSpacing
        self.childViews = [content()]
    }

    func resolvedChildren(path: String) -> [LayoutNode] {
        childViews.enumerated().flatMap { index, view -> [LayoutNode] in
            let childPath = "\(path).fw\(index)"
            let node = resolveAny(view, path: childPath)
            if node.stackAxis == .vertical && node.backgroundColor == nil && node.text == nil {
                return node.children
            }
            return [node]
        }
    }
}
