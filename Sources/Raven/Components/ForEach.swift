// MARK: - ForEach

/// Iterates over a collection and produces views for each element.
///
/// Usage:
/// ```swift
/// VStack {
///     ForEach(items) { item in
///         Text(item.name)
///     }
/// }
/// ```
public struct ForEach<Data: RandomAccessCollection, Content: View>: View where Data.Index: Hashable {
    public typealias Body = Never
    public var body: Never { fatalError("ForEach is a primitive view") }

    let data: Data
    let content: (Data.Element) -> Content

    public init(_ data: Data, @ViewBuilder content: @escaping (Data.Element) -> Content) {
        self.data = data
        self.content = content
    }
}

/// Integer range convenience
extension ForEach where Data == Range<Int> {
    public init(_ range: Range<Int>, @ViewBuilder content: @escaping (Int) -> Content) {
        self.data = range
        self.content = content
    }
}

// MARK: - ForEach Resolution

protocol AnyForEachView {
    func resolveForEach(path: String) -> LayoutNode
}

extension ForEach: AnyForEachView {
    func resolveForEach(path: String) -> LayoutNode {
        let node = LayoutNode()
        node.stackAxis = .vertical
        node.spacing = 0
        node.id = path

        var children: [LayoutNode] = []
        for (index, element) in data.enumerated() {
            let childView = content(element)
            let childNode = ViewResolver.resolve(childView, path: "\(path).fe\(index)")
            children.append(childNode)
        }

        node.children = children
        return node
    }
}
