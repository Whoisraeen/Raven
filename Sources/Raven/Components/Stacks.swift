// MARK: - VStack

/// A view that arranges its children vertically.
public struct VStack: View {
    public typealias Body = Never
    public var body: Never { fatalError("VStack is a primitive view") }

    public let spacing: Float
    public let alignment: HorizontalAlignment
    internal let childViews: [any View]

    public init(
        alignment: HorizontalAlignment = .center,
        spacing: Float = 8,
        @ViewBuilder content: () -> some View
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.childViews = [content()]
    }

    func resolvedChildren(path: String) -> [LayoutNode] {
        childViews.enumerated().flatMap { index, view -> [LayoutNode] in
            let childPath = "\(path).v\(index)"
            let node = resolveAny(view, path: childPath)
            // If the resolved node is a bare stack (from TupleView), unwrap its children
            if node.stackAxis == .vertical && node.backgroundColor == nil && node.text == nil {
                return node.children
            }
            return [node]
        }
    }
}

// MARK: - HStack

/// A view that arranges its children horizontally.
public struct HStack: View {
    public typealias Body = Never
    public var body: Never { fatalError("HStack is a primitive view") }

    public let spacing: Float
    public let alignment: VerticalAlignment
    internal let childViews: [any View]

    public init(
        alignment: VerticalAlignment = .center,
        spacing: Float = 8,
        @ViewBuilder content: () -> some View
    ) {
        self.alignment = alignment
        self.spacing = spacing
        self.childViews = [content()]
    }

    func resolvedChildren(path: String) -> [LayoutNode] {
        childViews.enumerated().flatMap { index, view -> [LayoutNode] in
            let childPath = "\(path).h\(index)"
            let node = resolveAny(view, path: childPath)
            if node.stackAxis == .vertical && node.backgroundColor == nil && node.text == nil {
                return node.children
            }
            return [node]
        }
    }
}

// MARK: - ZStack

/// A view that overlays its children on top of each other.
public struct ZStack: View {
    public typealias Body = Never
    public var body: Never { fatalError("ZStack is a primitive view") }

    internal let childViews: [any View]

    public init(
        @ViewBuilder content: () -> some View
    ) {
        self.childViews = [content()]
    }

    func resolvedChildren(path: String) -> [LayoutNode] {
        childViews.enumerated().flatMap { index, view -> [LayoutNode] in
            let childPath = "\(path).z\(index)"
            let node = resolveAny(view, path: childPath)
            if node.stackAxis == .vertical && node.backgroundColor == nil && node.text == nil {
                return node.children
            }
            return [node]
        }
    }
}

// MARK: - Helper

/// Type-erased view resolution helper
func resolveAny(_ view: any View, path: String) -> LayoutNode {
    func doResolve<V: View>(_ v: V) -> LayoutNode {
        ViewResolver.resolve(v, path: path)
    }
    return doResolve(view)
}
